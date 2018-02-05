;;; init.el --- the heart of the beast -*- lexical-binding: t; -*-

;; 变量定义
(defvar flywind-emacs-dir (file-truename user-emacs-directory)
  "emacs.d 目录")

(defvar flywind-modules-dir (concat flywind-emacs-dir "module/")
  "modules 目录")

;; init melpa
(require 'package)
(setq package-archives '(
			 ("gnu"      .   "http://elpa.emacs-china.org/gnu/")
			 ("melpa"    .   "http://elpa.emacs-china.org/melpa/")
			 ("org"      .   "http://elpa.emacs-china.org/org/")))

(setq package-enable-at-startup nil) ; To prevent initialising twice
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

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
	(ivy-rich ibuffer-projectile eyebrowse popwin zoom-window window-numbering ace-window volatile-highlights rainbow-delimiters rainbow-mode highlight-parentheses dired-k dired-rainbow dired exec-path-from-shell smex use-package))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
