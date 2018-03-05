;;; init.el --- the heart of the beast -*- lexical-binding: t; -*-

;; 变量定义
(defvar flywind-emacs-dir (file-truename user-emacs-directory)
  "emacs.d 目录")

(defvar flywind-modules-dir (concat flywind-emacs-dir "module/")
  "modules 目录")

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

(add-to-list 'load-path flywind-modules-dir)

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
(require 'flywind-projectile)
(require 'flywind-dash)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
	("3c83b3676d796422704082049fc38b6966bcad960f896669dfc21a7a37a748fa" default)))
 '(package-selected-packages
   (quote
	(ag neotree diminish ivy-hydra counsel-projectile ivy-rich ibuffer-projectile eyebrowse popwin zoom-window window-numbering ace-window volatile-highlights rainbow-delimiters rainbow-mode highlight-parentheses dired-k dired-rainbow dired exec-path-from-shell smex use-package))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(add-hook 'after-init-hook
		  '(lambda ()
			 (message "Emacs loaded in %.03fs"
					  (float-time (time-subtract (current-time) before-init-time)))
			 ))
