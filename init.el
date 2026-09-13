;;; init.el --- 配置文件编辑器的入口 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 本文件只负责：package 初始化、use-package 默认值、模块装载、缺包提示，
;; 以及两个自检命令（`flywind-check-config'、`flywind-byte-compile-config'）。
;; 目录变量、load-path、exec-path 静态注入都在 early-init.el。
;;
;; 启动期不联网：不 `package-refresh-contents'、不 `:ensure'，缺包只 `warn'。
;; 启动期只做一次极便宜的字节编译（时间戳比对，见 `flywind-byte-compile-config'），
;; 不联网、不扫第三方目录。
;;
;; 安装缺失包：M-x flywind-install-missing-packages
;; 检查配置健康：M-x flywind-check-config
;;
;;; Code:

;;;; package.el（源与目录在 early-init.el 配置）
(require 'package)
(package-initialize)

;;;; use-package（Emacs 31 内置，不再从 ELPA 装旧版）
(require 'use-package)
(setq use-package-always-ensure nil      ; 启动期绝不自动安装
      use-package-always-defer nil       ; 由每个包自己决定是否 :defer
      use-package-expand-minimally t
      use-package-enable-imenu-support t
      use-package-verbose nil)

;;;; 包清单
(defconst flywind-packages
  '(vertico orderless marginalia consult
    magit
    doom-themes
    easy-kill
    hungry-delete
    volatile-highlights rainbow-mode rainbow-delimiters
    diredfl dired-rainbow dired-rsync
    multi-term shell-pop xterm-color
    eyebrowse zoom-window)
  "本配置需要的 ELPA 包清单（内置包不列入）。
language server 与 tree-sitter 语法库也不列入：它们不走 package.el，
见 `flywind-check-config' 的报告与 README.org 的安装命令。

不装 diminish：抹 mode line 上的噪音 lighter 由 flywind-basic.el 自己改
`minor-mode-alist'（详见 `flywind-hide-minor-mode-lighter'）。
不装 doom-modeline（连带它的依赖 nerd-icons）：mode line 自己拼，实测启动省
60ms、单次渲染只有它三分之一代价，见 flywind-modeline.el 的 Commentary。")

(defun flywind--missing-packages ()
  "返回 `flywind-packages' 中尚未安装的包。"
  (seq-filter (lambda (pkg) (not (package-installed-p pkg))) flywind-packages))

(defun flywind--package-dir (pkg)
  "返回已安装包 PKG 的解包目录；没装则 nil。"
  (let ((desc (car (cdr (assq pkg package-alist)))))
    (and (package-desc-p desc) (package-desc-dir desc))))

(defun flywind--el-needs-byte-compile (file)
  "FILE（.el）值不值得编一次：没有 .elc、或 .elc 比源码旧，才算需要。"
  (let ((elc (concat file "c")))
    (not (and (file-exists-p elc)
              (file-newer-than-file-p elc file)))))

;;;###autoload
(defun flywind-byte-compile-packages (&optional dirs)
  "把已安装 ELPA 包的 .el 编成 .elc，返回 (编了 跳了 失败列表)。

package.el 本来在装包时就编一次，但包是从别处拷进 elpa/ 的（本机正是这种：
实测 190 个源码 / 0 个 .elc）、或者上次编译被打断时，ELPA 里会只剩源码。那样
每次加载都在现场解析 .el，启动预算直接被吃掉：本机补齐 .elc 之前启动 0.25s，
补齐之后 0.19s。Emacs 31 的 `load' 还会对没写 `lexical-binding' cookie 的源码
告警（Missing `lexical-binding' cookie），那串噪音就是这么来的。

只有两个调用点：`M-x flywind-byte-compile-packages' 手跑，和
`flywind-install-missing-packages' 装完包后自动跑。启动路径不扫第三方目录 ——
那是本配置的硬约束（见 `flywind-byte-compile-config'），所以这里不挂任何 hook。

写了 `no-byte-compile: t' 的文件拿不到 .elc：`byte-compile-file' 对它们直接返回
那个符号、不报错，所以判成败要看 .elc 到没到手。那是上游的选择（doom-themes 的
87 个主题文件就是这样），算跳过的不算失败。`*-autoloads.el'、`*-pkg.el'、
`.dir-locals.el' 也跳过：前两个由 package.el 生成。

DIRS 给定就只编这些目录（装包那条用它，只编新装的）。"
  (interactive nil)
  (require 'bytecomp)
  (let ((compiled 0) (skipped 0) (failed nil) (backup-inhibited t))
    (dolist (root (or dirs (list package-user-dir)))
      (when (file-directory-p root)
        (dolist (file (directory-files-recursively root "\\.el\\'"))
          (cond
           ((string-match-p "\\(-autoloads\\|-pkg\\|\\.dir-locals\\)\\.el\\'" file)
            (cl-incf skipped))
           ((not (flywind--el-needs-byte-compile file))
            (cl-incf skipped))
           (t
            (condition-case err
                (progn
                  (byte-compile-file file)
                  (if (file-exists-p (concat file "c"))
                      (cl-incf compiled)
                    (cl-incf skipped)))
              (error
               (push (format "%s :: %s" (file-name-nondirectory file)
                             (or (nth 1 err) (car err)))
                     failed))))))))
    (message "ELPA 字节编译：%d 个 .elc，跳过 %d 个%s"
             compiled skipped
             (if failed (format "，失败 %d 个：%s"
                                (length failed)
                                (mapconcat #'identity failed "; "))
               ""))
    (list compiled skipped failed)))

;;;###autoload
(defun flywind-install-missing-packages ()
  "刷新索引并安装 `flywind-packages' 中缺失的包（需要网络）。
装完顺手把新装的包编成 .elc：package.el 自己会在安装时编，但编译失败或被跳过时
它不声张，elpa/ 里留一堆源码，代价是以后每次启动都在现场解析 .el。"
  (interactive)
  (let ((missing (flywind--missing-packages)))
    (if (null missing)
        (message "所有包均已安装")
      (package-refresh-contents)
      (dolist (pkg missing)
        (message "安装 %s ..." pkg)
        (condition-case err
            (package-install pkg)
          (error (message "安装 %s 失败: %S" pkg err))))
      (let ((dirs (delq nil (mapcar #'flywind--package-dir missing))))
        (when dirs
          (flywind-byte-compile-packages dirs)))
      (message "缺失包安装完成"))))

;;;###autoload
(defun flywind-sync-package-selected-packages ()
  "把 `flywind-packages' 写入 `package-selected-packages' 并存入 custom-file。
package.el 的 `package-autoremove' / `package-menu' 依赖这个变量判断哪些包是
“用户选的”；本配置用 `flywind-packages' 作为清单，所以清单改动后要同步一次，
之后 `M-x package-autoremove' 才会把旧清单里的包当孤立依赖卸掉。"
  (interactive)
  (require 'custom)
  (customize-set-variable 'package-selected-packages flywind-packages)
  (customize-save-variable 'package-selected-packages flywind-packages)
  (message "package-selected-packages 已同步为 %d 个包" (length flywind-packages)))

;;;; 编译与自检
(defun flywind--config-el-files ()
  "返回需要编译/检查的 .el：early-init.el、init.el、user-lisp/ 下的全部。"
  (append
   (seq-filter #'file-readable-p
               (list (expand-file-name "early-init.el" flywind-emacs-dir)
                     (expand-file-name "init.el" flywind-emacs-dir)))
   (sort (directory-files-recursively flywind-user-lisp-dir "\\.el\\'") #'string<)))

;;;###autoload
(defun flywind-byte-compile-config (&optional force)
  "把自有配置（early-init.el、init.el、user-lisp/*.el）编成 .elc。
启动期会自动跑一次（那时它只做时间戳比对，没改动就零成本），因为留着旧的
.elc 会让 Emacs 加载旧字节码、盖掉刚改的 .el。 手动调用时会给结果汇报。
带 `C-u' 前缀（FORCE）连还没过期的也重编一遍。"
  (interactive "P")
  (require 'bytecomp)
  (let ((backup-inhibited t)
        (files (flywind--config-el-files))
        (compiled 0) (skipped 0) (failed nil))
    (dolist (file files)
      ;; ARG=0：.elc 不存在也编；FORCE：连最新的也重编；LOAD 不传 = 编译但不加载。
      (let ((result (condition-case err
                        (byte-recompile-file file force 0)
                      ((debug error) (list 'flywind-compile-error err)))))
        (cond
         ((eq result 'no-byte-compile) (setq skipped (1+ skipped)))
         ((eq (car-safe result) 'flywind-compile-error)
          (push (cons file (error-message-string (cadr result))) failed))
         (t (setq compiled (1+ compiled))))))
    (cond
     (failed
      (warn "字节编译失败 %d 个：%s" (length failed)
            (mapconcat (lambda (f) (format "%s（%s）" (car f) (cdr f)))
                       (nreverse failed) "、")))
     ;; 启动时静默：只有手动调用才报“完成了什么”，避免往 *Messages* 里刷噪。
     ((not (called-interactively-p 'any)) nil)
     ((eq compiled 0) (message "配置已是最新（跳过 %d 个）" skipped))
     (t (message "配置字节编译完成（编译 %d 个，跳过 %d 个）" compiled skipped)))))

;;;; 启动期字节编译（只自有配置）
;; 为什么不能完全不编：同目录下一个 .elc 比 .el 新就会被加载，改动会被
;; 旧字节码静默盖掉（Emacs 只在 *Messages* 里给一条 “Source file … newer than
;; byte-compiled file; using older file”）。 Emacs 31.1 没有可以改这个行为的
;; 选项，所以启动时得跑一次。 成本：`byte-recompile-file' 自己比时间戳，没改动
;; 的文件零成本；3rdparty 已经不扫了，只剩 11 个文件。
;; 必须在 `package-initialize' 之后：编译期要能看到 ELPA 包里的宏。
(flywind-byte-compile-config)

;;;; 模块装载
;; 顺序只影响“谁先拿到全局状态”，模块之间没有互相 require。
;; basic/ui/window/completion 是常驻核心；config 负责配置文件映射与校验 hook；
;; dired/git/shell 里的包全部懒加载，require 本身几乎不花钱。
(require 'flywind-basic)
(require 'flywind-ui)
(require 'flywind-modeline)
(require 'flywind-config)
(require 'flywind-completion)
(require 'flywind-dired)
(require 'flywind-window)
(require 'flywind-git)
(require 'flywind-shell)
(require 'flywind-org)

;;;###autoload
(defun flywind-check-config (&optional force)
  "检查配置健康，结果写进 `*flywind-check-config*'。
四节：
1. 自有配置能否字节编译（Error 即失败；Warning 单独计）；
2. `flywind-packages' 里缺哪些 ELPA 包；
3. 配置文件需要的 tree-sitter 语法库是否就位（权威判断，非文件探测）；
4. 语法校验用的 language server 是否可执行。
默认只重编过期的文件，已经是最新的不会重报旧警告；带 `C-u' 前缀（FORCE）
全量重编，把每个文件的警告都重现一遍。"
  (interactive "P")
  (require 'bytecomp)
  (require 'treesit)
  (let* ((buf-name "*flywind-check-config*")
         (log-name "*flywind-compile-log*")
         (files (flywind--config-el-files))
         (errors 0) (warnings 0) (untouched 0))
    (with-current-buffer (get-buffer-create log-name)
      (erase-buffer))
    (with-current-buffer (get-buffer-create buf-name)
      (let ((inhibit-read-only t)
            (buffer-read-only nil)
            (byte-compile-log-buffer log-name))
        (erase-buffer)
        (insert (format-time-string "配置检查 @ %Y-%m-%d %H:%M:%S\n"))
        (insert (format "Emacs %s / %s\n\n" emacs-version system-type))

        (insert (format "1. 字节编译%s\n" (if force "（全量）" "（只重编过期的）")))
        (dolist (file files)
          (let ((before (with-current-buffer (get-buffer-create log-name) (buffer-size))))
            (condition-case err
                (let ((result (byte-recompile-file file force 0)))
                  (cond
                   ((eq result 'no-byte-compile)
                    (setq untouched (1+ untouched))
                    (insert (format "   ok    %s（未改动，未重编）\n" file)))
                   ((> (with-current-buffer (get-buffer-create log-name) (buffer-size))
                       before)
                    (setq warnings (1+ warnings))
                    (insert (format "   警告  %s\n" file)))
                   (t (insert (format "   ok    %s\n" file)))))
              ((debug error)
               (setq errors (1+ errors))
               (insert (format "   失败  %s\n         %s\n"
                               file (error-message-string err)))))))
        (when (or (> errors 0) (> warnings 0))
          (insert (format "   （详细编译输出见 %s）\n" log-name)))
        (when (> untouched 0)
          (insert (format "   %d 个文件未改动；要全量重编并重现所有警告：C-u M-x flywind-check-config\n"
                          untouched)))

        (insert "\n2. ELPA 包\n")
        (let ((missing (flywind--missing-packages)))
          (if missing
              (insert (format "   缺失 %d 个：%s\n   执行 M-x flywind-install-missing-packages\n"
                              (length missing)
                              (mapconcat #'symbol-name missing " ")))
            (insert (format "   ok    %d 个包都已安装\n" (length flywind-packages)))))

        (insert "\n3. tree-sitter 语法库（配置文件用）\n")
        (dolist (src flywind-config-treesit-sources)
          (let ((lang (car src)))
            (insert
             (format "   %-6s %s\n" lang
                     (if (treesit-language-available-p lang)
                         "ok"
                       (let ((fallback (nth 3 (assq lang
                                                    flywind-config-treesit-mapping))))
                         (format "缺失（%s）"
                                 (if fallback
                                     (format "已退到 %s" fallback)
                                   "没有内置退路"))))))))
        (insert "   安装：M-x flywind-install-treesit-grammars\n")

        (insert "\n4. language server（语法校验）\n")
        (dolist (entry flywind-config-lsp-programs)
          (let* ((lang (car entry))
                 (cmd (flywind-config-lsp-command lang)))
            (insert (format "   %-6s %s\n" lang
                            (if cmd
                                (format "ok（%s）" (car cmd))
                              (format "缺失（候选：%s）"
                                      (mapconcat (lambda (c) (car c)) (cdr entry) " / ")))))))
        (insert "   安装见 README.org；ini/.env/nginx/tmux/ssh_config/gitconfig 按设计不校验。\n")

        (insert (format "\n结论：%s\n"
                        (cond
                         ((> errors 0) (format "编译有 %d 个错误，先修它们" errors))
                         ((or (> warnings 0) (> (length (flywind--missing-packages)) 0)
                              flywind-config--missing-grammars)
                          "可用，但有上面列出的缺项/警告")
                         (t "一切正常"))))
        (special-mode)
        (goto-char (point-min))))
    (pop-to-buffer buf-name)))

;;;; Custom
(setq custom-file (expand-file-name "custom.el" flywind-etc-dir))
(when (file-readable-p custom-file)
  (load custom-file 'noerror 'nomessage))

;;;; 缺包提示
(add-hook 'after-init-hook
          (lambda ()
            (and-let* ((missing (flywind--missing-packages)))
              (warn "以下包未安装，执行 M-x flywind-install-missing-packages 安装：%s"
                    (mapconcat #'symbol-name missing " ")))))

(provide 'init)
;;; init.el ends here
