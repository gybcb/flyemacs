;;; early-init.el --- 启动早期设置 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 本文件在 site-start.el 之前、任何帧创建与 package 初始化之前被加载
;; （Emacs 31 起 site-start.el 早于 early-init.el，但仍在帧创建之前）。
;; 只放必须最早生效的设置：GC 策略、目录与 exec-path、load-path、package.el 配置。
;;
;; 环境变量：不再用 exec-path-from-shell（它要在启动期跑 `bash -l` 子进程，
;; 是原配置最大的一段固定启动开销）。 macOS GUI 启动确实拿不到 /opt/homebrew/bin，
;; 而 magit / consult-ripgrep / eglot 拉起 language server 都要用它，所以改成
;; 静态目录注入：见 `flywind-extra-exec-path'。
;;
;;; Code:

;;;; GC / file-name-handler：启动期放宽，启动完成后恢复
;; 原配置在 init.el 里设 30MB；这里在更早的启动阶段放宽，恢复值仍是 800000。
(setq gc-cons-threshold #x2000000
      gc-cons-percentage 0.3)

(defvar flywind--default-file-name-handler-alist file-name-handler-alist
  "启动期间的 `file-name-handler-alist' 原值，供 `after-init-hook' 恢复。")
(setq file-name-handler-alist nil)

(add-hook 'after-init-hook
          (lambda ()
            "恢复启动期被临时放宽的设置。"
            (setq file-name-handler-alist flywind--default-file-name-handler-alist
                  gc-cons-threshold 800000
                  gc-cons-percentage 0.1)
            (garbage-collect)))

;;;; 目录变量（模块会在早期被加载，故路径常量必须在此定义）
(defvar flywind-emacs-dir (file-truename user-emacs-directory)
  "emacs.d 目录。")

(defvar flywind-user-lisp-dir
  (file-name-as-directory (locate-user-emacs-file "user-lisp"))
  "自有配置模块目录（Emacs 31 的 User Lisp directory）。")

(defvar flywind-local-dir (file-name-as-directory (locate-user-emacs-file ".local"))
  "跳机器共享的本地文件根目录。")

(defvar flywind-etc-dir (file-name-as-directory (expand-file-name "etc" flywind-local-dir))
  "非易失存储：外部依赖、长期共享数据。")

(defvar flywind-cache-dir (file-name-as-directory (expand-file-name "cache" flywind-local-dir))
  "易失存储：缓存文件。")

(defvar flywind-packages-dir (file-name-as-directory (expand-file-name "packages" flywind-local-dir))
  "package.el 及其缓存的存放目录。")

(dolist (dir (list flywind-local-dir flywind-etc-dir flywind-cache-dir flywind-packages-dir))
  (unless (file-directory-p dir)
    (make-directory dir t)))

;;;; exec-path：静态注入，不起子进程
(defcustom flywind-extra-exec-path
  '("/opt/homebrew/bin" "/opt/homebrew/sbin" "/usr/local/bin" "~/.local/bin")
  "追加到 `exec-path' 前面的目录。
用来取代 exec-path-from-shell：magit 要 git、consult-ripgrep 要 rg、
eglot 要 language server，而 macOS 下从 Dock/Launchpad 启动的 Emacs
只有 /usr/bin:/bin。 不存在的目录会被跳过。"
  :type '(repeat directory)
  :group 'environment)

(defun flywind--activate-extra-exec-path ()
  "把 `flywind-extra-exec-path' 里存在的目录前置进 `exec-path'，去重。"
  (let ((fresh (delq nil
                     (mapcar (lambda (dir)
                               (let ((expanded (expand-file-name dir)))
                                 (when (file-directory-p expanded)
                                   (directory-file-name expanded))))
                             flywind-extra-exec-path))))
    (setq exec-path (append fresh
                            (seq-difference exec-path fresh #'equal)))))

(flywind--activate-extra-exec-path)

;;;; user-lisp/：关闭自动 scrape
;; Emacs 31 默认会在 init.el 之前把 user-lisp/ 里每个 .el 加载一次（ scrape ）：
;; 顺序不可控，且那时 ELPA 包尚未激活，模块里的 require 会失败。
;; 这里只保留 load-path 激活（`prepare-user-lisp t'）；字节编译由 init.el 在
;; `package-initialize' 之后按需处理（只自有配置，没改动零成本）。
;; （需重新抓取 autoload cookie 时手动 M-x prepare-user-lisp。）
(setq user-lisp-auto-scrape nil)
(add-to-list 'load-path (directory-file-name flywind-user-lisp-dir))

;;;; package.el：源与目录（此处不 package-initialize，交给 init.el）
(setq package-enable-at-startup nil
      package-user-dir (locate-user-emacs-file ".local/packages/elpa"))

;; 全部使用 https；不再配置 org 源（Emacs 31 内置 Org 9.8）。
;; 不设 `url-proxy-services'：清华镜像直连。 装包是手动动作（见 init.el），
;; 启动期不联网。
(setq package-archives
      `(("gnu"    . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("melpa"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
        ("nongnu" . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")))

;; 复用已存在的 ELPA 签名 keyring（package-user-dir 已搬家，默认值会指向空目录，
;; 导致每次刷新都要重新导入公钥、校验更容易失败）。
(setq package-gnupghome-dir (locate-user-emacs-file "elpa/gnupg"))

;; （native-comp-available-p）=> nil：本机 Homebrew Emacs 31.1 未启用 native compilation，
;; 因此不设置 eln 相关项。

;;;; 字节编译在 init.el：`flywind-byte-compile-config'，只处理自有配置，不扫第三方目录。

(provide 'early-init)
;;; early-init.el ends here
