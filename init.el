;;; init.el --- the heart of the beast -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 本文件只负责：package 初始化、use-package 默认值、模块装载、缺包提示、按需字节编译。
;; 目录变量与 load-path 在 early-init.el。
;; 启动期不联网：不 `package-refresh-contents'、不 `:ensure'，缺包只 `warn'。
;; 安装缺失包：M-x flywind-install-missing-packages
;;
;;; Code:

;;;; 目录变量、load-path（user-lisp/ 与 3rdparty/）与 package 源均在 early-init.el 配置

;;;; package.el
;; 源与目录在 early-init.el 中配置。
(require 'package)
(package-initialize)

;;;; user-lisp/ 按需字节编译
;; Emacs 31 的 `user-lisp-auto-scrape' 已在 early-init.el 关闭：它会在 init.el 之前
;; 按目录顺序把模块加载一遍（那时 ELPA 还没激活）。这里改为在 package-initialize
;; 之后、加载模块之前自己编译过期文件：编译期能看到 ELPA/3rdparty 的宏与变量，
;; 且启动时永远加载最新代码。`byte-recompile-file' 自己比时间戳，无改动即零成本。
(defun flywind-byte-compile-dir (dir)
  "字节编译 DIR 中过期的 .el（递归）。DIR 不存在则忽略。
编译期间把 DIR 的各子目录临时加入 `load-path'：3rdparty 的模块（lsp-bridge 的
acm/ 等）靠运行时自行加路径，编译期不加就会报 Cannot open load file。"
  (when (file-directory-p dir)
    (require 'bytecomp)
    (let* ((backup-inhibited t)
           (subdirs (seq-filter (lambda (d)
                                  (not (string-match-p "/\\.[^/]*\\'" d)))
                                (directory-files-recursively dir "\\'" t)))
           (load-path (append load-path subdirs)))
      (dolist (file (directory-files-recursively dir "\\.el\\'"))
        ;; ARG=0：只编译，不加载。
        (byte-recompile-file file nil 0)))))

(defun flywind-prepare-lisp ()
  "编译自有模块与被使用的 3rdparty 子模块。
3rdparty 的 .elc 落在子模块工作区里，已在各子模块的 `.git/info/exclude' 中排除，
不会污染 `git status'。"
  (flywind-byte-compile-dir flywind-user-lisp-dir)
  (dolist (sub '("lsp-bridge" "aweshell" "color-rg"))
    (flywind-byte-compile-dir (expand-file-name sub flywind-3rdparty-dir))))

(flywind-prepare-lisp)

;;;; use-package（Emacs 31 内置，不再从 ELPA 安装旧版）
(require 'use-package)
(setq use-package-always-ensure nil      ; 启动期绝不自动安装
      use-package-always-defer nil       ; 由每个包自己决定是否 :defer
      use-package-expand-minimally t
      use-package-enable-imenu-support t
      use-package-verbose nil)

;;;; load-path 已在 early-init.el 完成（那里早于 user-lisp 模块的首次加载）

;;;; 包清单
(defconst flywind-packages
  '(vertico orderless marginalia consult
    magit
    doom-themes doom-modeline
    company company-posframe yasnippet
    neotree nerd-icons eyebrowse zoom-window
    easy-kill
    hungry-delete
    volatile-highlights rainbow-mode rainbow-delimiters
    exec-path-from-shell
    diredfl dired-rainbow dired-rsync
    multi-term shell-pop xterm-color
    treesit-auto
    jupyter
    diminish
    ;; lsp-bridge 的 elisp 端声明依赖 markdown-mode（子模块对 package.el 不可见）
    markdown-mode)
  "本配置需要的 ELPA 包清单（内置包不列入）。")

(defun flywind--missing-packages ()
  "返回 `flywind-packages' 中尚未安装的包。"
  (seq-filter (lambda (pkg) (not (package-installed-p pkg))) flywind-packages))

;;;###autoload
(defun flywind-install-missing-packages ()
  "刷新索引并安装 `flywind-packages' 中缺失的包（需要网络）。"
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
      (message "缺失包安装完成"))))

;;;###autoload
(defun flywind-sync-package-selected-packages ()
  "把 `flywind-packages' 写入 `package-selected-packages' 并存入 custom-file。
package.el 的 `package-autoremove' / `package-menu' 依赖这个变量判断哪些包是
“用户选的”；本配置用 `flywind-packages' 作为清单，所以需要同步一次。"
  (interactive)
  (require 'custom)
  (customize-set-variable 'package-selected-packages flywind-packages)
  (customize-save-variable 'package-selected-packages flywind-packages)
  (message "package-selected-packages 已同步为 %d 个包" (length flywind-packages)))

(add-hook 'after-init-hook
          (lambda ()
            (and-let* ((missing (flywind--missing-packages)))
              (warn "以下包未安装，执行 M-x flywind-install-missing-packages 安装：%s"
                    (mapconcat #'symbol-name missing " ")))))

;;;; 模块装载
(require 'flywind-basic)
(require 'flywind-ui)
(require 'flywind-org)
(require 'flywind-completion)
(require 'flywind-company)
(require 'flywind-dired)
(require 'flywind-window)
(require 'flywind-kill-ring)
(require 'flywind-neotree)
(require 'flywind-lsp)
(require 'flywind-colorrg)
(require 'flywind-git)
(require 'flywind-python)
(require 'flywind-eshell)
(require 'flywind-shell)
(require 'flywind-treesit)

;;;; Custom
(setq custom-file (expand-file-name "custom.el" flywind-etc-dir))
(when (file-readable-p custom-file)
  (load custom-file 'noerror 'nomessage))

(provide 'init)
;;; init.el ends here
