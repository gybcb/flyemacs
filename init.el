;;; init.el --- the heart of the beast -*- lexical-binding: t; -*-

;; 变量定义
(defvar flywind-emacs-dir (file-truename user-emacs-directory)
  "emacs.d 目录")

(defvar flywind-modules-dir (concat flywind-emacs-dir "module/")
  "modules 目录")

(defvar flywind-3rdmodules-dir (concat flywind-modules-dir "3rdparty/")
  "第三方modules目录"
  )

(defvar flywind-local-dir (concat flywind-emacs-dir ".local/")
  "Root directory for local Emacs files. Use this as permanent storage for files
that are safe to share across systems (if this config is symlinked across
several computers).")

(defvar flywind-etc-dir (concat flywind-local-dir "etc/")
  "Directory for non-volatile storage.

Use this for files that don't change much, like servers binaries, external
dependencies or long-term shared data.")

(defvar flywind-cache-dir (concat flywind-local-dir "cache/")
  "Directory for volatile storage.

Use this for files that change often, like cache files.")

(defvar flywind-packages-dir (concat flywind-local-dir "packages/")
  "Where package.el and quelpa plugins (and their caches) are stored.")

;; create dirs
(dolist (dir (list flywind-local-dir flywind-etc-dir flywind-cache-dir flywind-packages-dir))
  (message dir)
  (unless (file-directory-p dir)
	(make-directory dir t)))

;; Optimize loading performance
(defvar default-file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(setq gc-cons-threshold 30000000)
(add-hook 'emacs-startup-hook
		  (lambda ()
			"Restore defalut values after init"
			(setq file-name-handler-alist default-file-name-handler-alist)
			(setq gc-cons-threshold 800000)))

;; init melpa
(require 'package)
(setq package-user-dir (expand-file-name "elpa" flywind-packages-dir)
	  package-enable-at-startup nil
	  package-archives '(
						 ("gnu"      .   "http://elpa.emacs-china.org/gnu/")
						 ("melpa"    .   "http://elpa.emacs-china.org/melpa/")
						 ("org"      .   "http://elpa.emacs-china.org/org/")))
(package-initialize)

(if (not (package-installed-p 'use-package))
	(progn
	  (package-refresh-contents)
	  (package-install 'use-package)))

(require 'use-package)

(setq use-package-always-ensure t)
(setq use-package-always-defer t)
(setq use-package-expand-minimally t)
(setq use-package-enable-imenu-support t)

(defun add-subdirs-to-load-path (dir)
  "Recursive add directories to `load-path'."
  (let ((default-directory (file-name-as-directory dir)))
	(add-to-list 'load-path dir)
	(normal-top-level-add-subdirs-to-load-path)))

(add-to-list 'load-path flywind-modules-dir)
(add-subdirs-to-load-path flywind-3rdmodules-dir)

;; 加载自定义配置
(require 'flywind-basic)
(require 'flywind-ui)
(require 'flywind-org)
(require 'flywind-company)
(require 'flywind-ivy)
(require 'flywind-dired)
(require 'flywind-window)
(require 'flywind-kill-ring)
(require 'flywind-neotree)
;; (require 'flywind-projectile)
(require 'flywind-dash)
;;(require 'flywind-java)
;;(require 'flywind-prog)
(require 'flywind-lsp)
(require 'flywind-colorrg)
(require 'flywind-email)
(require 'flywind-git)
(require 'flywind-python)
(require 'flywind-eshell)
(require 'flywind-shell)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(xterm-color eshell-z esh-help esh-autosuggest eshell-prompt-extras all-the-icons-dired diredfl dired-rsync dired-quick-sort dired-k company-posframe company-quickhelp doom-themes zoom-window window-numbering volatile-highlights use-package smex smart-hungry-delete rainbow-mode rainbow-delimiters popwin neotree magit lsp-ui lsp-python lsp-java ivy-rich ivy-hydra indent-guide hungry-delete highlight-parentheses eyebrowse exec-path-from-shell easy-kill dired-rainbow dash-at-point counsel-projectile company-lsp cnfonts browse-kill-ring ag ace-window)))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(lsp-ui-doc-background ((t (:background nil))))
 '(lsp-ui-doc-header ((t (:inherit (font-lock-string-face italic))))))
