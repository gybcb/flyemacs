;;; flywind-config.el --- 配置文件编辑与语法校验 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 本配置的定位是「配置文件编辑器」，本模块只负责两件事：
;;
;; 1. 把配置文件映射到合适的 major mode
;;    * JSON / YAML / TOML 用 Emacs 31 内置的 `json-ts-mode' / `yaml-ts-mode' /
;;      `toml-ts-mode'，需要 tree-sitter 语法库：`M-x flywind-install-treesit-grammars'。
;;    * 语法库缺失时退回内置的 `js-json-mode' / `conf-toml-mode'；YAML 没有内置退路，
;;      只能 `fundamental-mode' 打开，并在启动时 warn 一次。
;;    * INI / .env / nginx.conf / tmux.conf / ssh_config / gitconfig / gitignore /
;;      shellrc 用内置 `conf-windows-mode' / `conf-unix-mode' / `sh-mode'。
;;
;; 2. 语法校验：内置 eglot 懒拉起 language server
;;    * 只在 `flywind-config-lsp-modes' 列出的 mode 上挂 hook，启动期不加载 eglot。
;;    * 只做语法校验（不做 JSON Schema）。
;;    * ini / .env / nginx.conf / tmux.conf / ssh_config / gitconfig 没有主流
;;      language server，按设计只高亮、不校验。
;;    * server 不可用只 warn 一次并跳过，不阻塞启动、不弹窗。
;;
;; 外部命令（都不在启动路径上，装完即生效）：
;;   npm i -g yaml-language-server vscode-langservers-extracted taplo bash-language-server
;;   .sh 的语法诊断还要 shellcheck（brew install shellcheck）：没有它
;;   bash-language-server 只给符号跳转，不给语法错误。
;;
;;; Code:

;; 只是编译期拿进来：下面都在 with-eval-after-load 里写 eglot / treesit 的变量，
;; 编译器看不到定义就会报 reference / assignment to free variable。运行时不靠这两行。
;; （treesit-auto-install-grammar 是 Emacs 31 的真变量，默认 ask；告警曾经差点把它
;; 误判成名字写错，这里把它和 eglot 一起注掉。）
(eval-when-compile
  (require 'eglot)
  (require 'treesit))

(defgroup flywind-config nil
  "配置文件编辑与语法校验。"
  :group 'convenience
  :prefix "flywind-config-")

;;;; 一、tree-sitter 语法库
(defcustom flywind-config-treesit-sources
  '((json . ("https://github.com/tree-sitter/tree-sitter-json" "master" "src"))
    (yaml . ("https://github.com/tree-sitter-grammars/tree-sitter-yaml" "master" "src"))
    (toml . ("https://github.com/tree-sitter/tree-sitter-toml" "master" "src")))
  "配置文件所需语法库的来源，装进 `treesit-language-source-alist'。
31.1 的默认值里没有 json/yaml/toml，必须自带。 三个仓库的默认分支都是 master；
alist 的第三个元素是仓库里 grammar 的相对目录。"
  :type '(alist :key-type symbol
                :value-type (group (string :tag "URL")
                                   (string :tag "Revision")
                                   (string :tag "子目录")))
  :group 'flywind-config)

(defcustom flywind-config-grammar-dir
  (file-name-as-directory (locate-user-emacs-file "tree-sitter"))
  "语法库的安装与搜索目录。"
  :type 'directory
  :group 'flywind-config)

;; Emacs 31 的 `treesit-ensure-installed' 默认会在第一次打开 .json 时弹
;; “grammar for `json' is missing; install it? (y or n)”：那是出现在无关 buffer 里的
;; 交互式提问，还会顺带联网 + 调 git/cc/tree-sitter 编译。这里关掉，改由
;; `flywind-install-treesit-grammars' 显式安装。
(with-eval-after-load 'treesit
  (setq treesit-auto-install-grammar nil)
  (dolist (src flywind-config-treesit-sources)
    (add-to-list 'treesit-language-source-alist src)))

;; `treesit-load' 找的文件名形如 libtree-sitter-json.dylib / libjson.so。
(defvar flywind-config--grammar-file-stems '("libtree-sitter-%s" "lib%s")
  "语法库文件名模板（不含后缀）。")

(defvar flywind-config--grammar-file-suffixes '(".dylib" ".so" ".dll")
  "语法库文件后缀候选。")

(defun flywind-config--grammar-installed-p (lang)
  "LANG（symbol）的语法库是否已安装。
只做文件探测：权威判断 `treesit-language-available-p' 会把 treesit.el 连它的
C 接口一起拉进来，而这个判断发生在启动期。 权威复核放在 `flywind-check-config'
（交互式，成本无所谓）里做。"
  (let* ((name (symbol-name lang))
         (dirs (append (and (boundp 'treesit-extra-load-path) treesit-extra-load-path)
                       (list flywind-config-grammar-dir))))
    (seq-some
     (lambda (dir)
       (seq-some
        (lambda (stem)
          (seq-some (lambda (suffix)
                      (file-exists-p (expand-file-name
                                       (concat (format stem name) suffix) dir)))
                    flywind-config--grammar-file-suffixes))
        flywind-config--grammar-file-stems))
     dirs)))

;;;; 二、major mode 映射
(defconst flywind-config-treesit-mapping
  '((json "\\.jsonc?\\'" json-ts-mode js-json-mode)
    (yaml "\\.ya?ml\\'"  yaml-ts-mode)
    (toml "\\.toml\\'"   toml-ts-mode conf-toml-mode))
  "配置文件语法库映射：(语法 文件名正则 tree-sitter mode 退路 mode ...)。
退路是 Emacs 内置的非 tree-sitter mode；没有退路（yaml）就不建映射，
让 buffer 落在 fundamental-mode，比让 json-ts-mode 在打开文件时报错好。")

(defconst flywind-config-builtin-modes
  '(;; INI 家族：[section] + key = value，; 注释
    ("\\.ini\\'" . conf-windows-mode)
    ("\\.cfg\\'" . conf-windows-mode)
    ("\\.gitconfig\\(?:-global\\)?\\'" . conf-windows-mode)
    ("\\.?config/git/config\\'" . conf-windows-mode)
    ("\\.git/config\\'" . conf-windows-mode)
    ;; 环境变量与只读展示类配置：# 注释 + key=value
    ("\\.env\\(?:\\.[^.]+\\)?\\'" . conf-unix-mode)
    ("nginx\\.conf\\'" . conf-unix-mode)
    ("\\.nginx\\'" . conf-unix-mode)
    ("[/.]tmux\\.conf\\'" . conf-unix-mode)
    ("\\.ssh/config\\'" . conf-unix-mode)
    ("ssh_config\\'" . conf-unix-mode)
    ("ssh_config\\.d/[^/]+\\'" . conf-unix-mode)
    ("\\.gitignore\\(?:_global\\|s\\)?\\'" . conf-unix-mode)
    ("_gitignore\\'" . conf-unix-mode)
    ("\\.gitattributes\\'" . conf-unix-mode)
    ;; shellrc 与 .envrc（direnv 的是脚本，不是 key=value）
    ("\\.bashrc\\'" . sh-mode)
    ("\\.bash_profile\\'" . sh-mode)
    ("\\.bash_aliases\\'" . sh-mode)
    ("\\.zshrc\\'" . sh-mode)
    ("\\.zshenv\\'" . sh-mode)
    ("\\.zprofile\\'" . sh-mode)
    ("\\.profile\\'" . sh-mode)
    ("\\.envrc\\'" . sh-mode))
  "不依赖语法库、也不做校验的配置文件 mode 映射。")

(defvar flywind-config--missing-grammars nil
  "最近一次探测到的缺失语法库（symbol 列表），供 `flywind-check-config' 报告。")

(defun flywind-config--set-auto-mode (regexp mode)
  "让 REGEXP 唯一地映射到 MODE：先删同 REGEXP 的旧项，再前插。
装完语法库后刷新时靠它把退路项换成 ts-mode 项。"
  (dolist (entry (copy-sequence auto-mode-alist))
    (when (equal (car entry) regexp)
      (setq auto-mode-alist (delete entry auto-mode-alist))))
  (add-to-list 'auto-mode-alist (cons regexp mode)))

;;;###autoload
(defun flywind-config-refresh-mode-mappings ()
  "按当前已安装的语法库重建 auto-mode-alist 映射。
返回并记录缺失的语法列表。 装完语法库后会自动再跑一次，不用重启。"
  (interactive)
  (let (missing)
    (dolist (entry flywind-config-treesit-mapping)
      (let ((lang (nth 0 entry))
            (regexp (nth 1 entry))
            (ts-mode (nth 2 entry))
            (fallback (nth 3 entry)))
        (if (flywind-config--grammar-installed-p lang)
            (flywind-config--set-auto-mode regexp ts-mode)
          (push lang missing)
          (when fallback
            (flywind-config--set-auto-mode regexp fallback)))))
    (dolist (entry flywind-config-builtin-modes)
      (flywind-config--set-auto-mode (car entry) (cdr entry)))
    (setq flywind-config--missing-grammars (nreverse missing))))

;;;; 三、语法校验：eglot 懒拉起
(defcustom flywind-config-lsp-programs
  '((json . (("vscode-json-language-server" "--stdio")))
    (yaml . (("yaml-language-server" "--stdio")))
    (toml . (("taplo" "lsp" "stdio") ("tombi" "lsp")))
    (sh   . (("bash-language-server" "start"))))
  "配置文件 language server 命令候选，按顺序取第一个可执行的。
toml 两个候选：taplo，以及 Emacs 31 eglot 自带的 tombi 默认项，装哪个都行。
改了这里要重启 Emacs：`eglot-server-programs' 只在 eglot 加载时算一次。"
  :type '(alist :key-type symbol :value-type (repeat (repeat string)))
  :group 'flywind-config)

(defconst flywind-config-lsp-modes
  '((json-ts-mode . json)
    (js-json-mode . json)
    (yaml-ts-mode . yaml)
    (toml-ts-mode . toml)
    (conf-toml-mode . toml)
    (sh-mode . sh))
  "挂校验的 major mode -> `flywind-config-lsp-programs' 里的语言键。
ts-mode 和它的退路 mode 都要列，这样没装语法库时照样有语法校验。")

(defvar flywind-config--lsp-warned nil
  "已经提示过缺失的 language server，避免每开一个 buffer 刷一条。")

(defun flywind-config-lsp-command (lang)
  "返回 LANG 第一个可执行的 server 命令（可执行文件为绝对路径）。
都不可用返回 nil。"
  (seq-some
   (lambda (cmd)
     (and-let* ((exe (car cmd))
                ((stringp exe))
                (found (executable-find exe)))
       (cons found (cdr cmd))))
   (cdr (assq lang flywind-config-lsp-programs))))

(defcustom flywind-config-lsp-settings
  '(:json (:validate (:enable t)))
  "配置文件校验需要的 workspace 配置，原样交给 eglot。

形状就是 eglot 要求的 SECTION-VALUE plist（见 `eglot-workspace-configuration'
文档：`:pylsp (:plugins ...)' 那个例子），这里 section 是 `:json'。

这一项是必需的：eglot 连上后会 push 一个 settings，
vscode-json-language-server 把“收到 settings 但 json.validate.enable 未设”
当成校验关闭，于是再坏的 JSON 也一条诊断都不发（实测：settings 空 -> 0 条；
enable=t -> 立刻报 “Property expected”）。yaml / toml / bash 不依赖这一项。"
  :type 'plist
  :group 'flywind-config)

(defun flywind-config--maybe-validate ()
  "当前 buffer 该校验就拉起 eglot；server 缺失只 warn 一次然后跳过。"
  (when-let* ((lang (cdr (assq major-mode flywind-config-lsp-modes))))
    (if (flywind-config-lsp-command lang)
        (eglot-ensure)
      (unless (memq lang flywind-config--lsp-warned)
        (push lang flywind-config--lsp-warned)
        (warn "%s 的 language server 未安装（候选：%s）：本 buffer 不做语法校验"
              lang
              (mapconcat (lambda (c) (car c))
                         (cdr (assq lang flywind-config-lsp-programs)) " / "))))))

(with-eval-after-load 'eglot
  ;; 我们的候选要排在 Emacs 31 自带项（toml 走 tombi 等）之前。
  (dolist (pair flywind-config-lsp-modes)
    (when-let* ((cmd (flywind-config-lsp-command (cdr pair))))
      (add-to-list 'eglot-server-programs (cons (car pair) cmd))))
  ;; 校验场景只要诊断：不要进度条、不要阻塞式连接。
  ;; 事件 buffer 保留 eglot 默认（校验不工作时唯一的排查入口，别关）。
  (setq eglot-report-progress nil
        eglot-sync-connect nil)
  (when flywind-config-lsp-settings
    ;; eglot 读的是 buffer-local 值；在 eval-after-load 里用 setq 只会
    ;; 写进当时那个 buffer，对后面的 buffer 无效 —— 必须写默认值。
    (setq-default eglot-workspace-configuration
                  (append flywind-config-lsp-settings
                          (and (listp (default-value 'eglot-workspace-configuration))
                               (default-value 'eglot-workspace-configuration))))))

(dolist (pair flywind-config-lsp-modes)
  (add-hook (intern (format "%s-hook" (car pair))) #'flywind-config--maybe-validate))

;;;; 四、语法库安装
;;;###autoload
(defun flywind-install-treesit-grammars ()
  "下载并编译 `flywind-config-treesit-sources' 里的语法库。
需要联网，以及 git / cc / tree-sitter CLI。 已存在的跳过，装完自动刷新映射。"
  (interactive)
  (require 'treesit)
  (unless (treesit-available-p)
    (user-error "这个 Emacs 构建没有 tree-sitter 支持"))
  (dolist (src flywind-config-treesit-sources)
    (add-to-list 'treesit-language-source-alist src))
  (let (failed)
    (dolist (src flywind-config-treesit-sources)
      (let* ((lang (car src))
             (err (and (not (treesit-language-available-p lang))
                       (condition-case err
                           (progn
                             (treesit-install-language-grammar
                              lang flywind-config-grammar-dir)
                             nil)
                         ((debug error) err)))))
        (cond
         ((null err) (message "语法库 %s 就绪" lang))
         (t (push lang failed) (message "语法库 %s 安装失败：%S" lang err)))))
    (flywind-config-refresh-mode-mappings)
    (if failed
        (warn "语法库安装失败：%s（需要 git / cc / tree-sitter CLI + 网络）"
              (mapconcat #'symbol-name failed " "))
      (message "配置文件语法库已就绪：%s"
               (mapconcat #'symbol-name (mapcar #'car flywind-config-treesit-sources) " ")))))

;;;; 启动：建映射 + 缺库提示
(flywind-config-refresh-mode-mappings)
(when flywind-config--missing-grammars
  (warn "缺少 tree-sitter 语法库 %s：JSON 退到 js-json-mode、TOML 退到 conf-toml-mode、YAML 没有内置退路（fundamental-mode）。执行 M-x flywind-install-treesit-grammars 安装"
        (mapconcat #'symbol-name flywind-config--missing-grammars " ")))

(provide 'flywind-config)
;;; flywind-config.el ends here
