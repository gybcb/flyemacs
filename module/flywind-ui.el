;; Menu/Tool/Scroll bars
(when (and (fboundp 'tool-bar-mode) tool-bar-mode)
  (tool-bar-mode -1))
(when (and (fboundp 'scroll-bar-mode) scroll-bar-mode)
  (scroll-bar-mode -1))

(when window-system
  (setq frame-title-format
		'("%S" (buffer-file-name "%f"
								 (dired-directory dired-directory "%b")))))

;; Line and Column
(setq-default fill-column 80)
(setq column-number-mode nil)

;; (setq line-number-mode nil)

(dolist (hook (list
			   'c-mode-common-hook
			   'c-mode-hook
			   'emacs-lisp-mode-hook
			   'lisp-interaction-mode-hook
			   'lisp-mode-hook
			   'emms-playlist-mode-hook
			   'java-mode-hook
			   'asm-mode-hook
			   'haskell-mode-hook
			   'rcirc-mode-hook
			   'emms-lyrics-mode-hook
			   'erc-mode-hook
			   'sh-mode-hook
			   'makefile-gmake-mode-hook
			   'python-mode-hook
			   'js-mode-hook
			   'html-mode-hook
			   'css-mode-hook
			   'apt-utils-mode-hook
			   'tuareg-mode-hook
			   'go-mode-hook
			   'coffee-mode-hook
			   'qml-mode-hook
			   'markdown-mode-hook
			   'slime-repl-mode-hook
			   'package-menu-mode-hook
			   'cmake-mode-hook
			   'php-mode-hook
			   'web-mode-hook
			   'coffee-mode-hook
			   'sws-mode-hook
			   'jade-mode-hook
			   'vala-mode-hook
			   'rust-mode-hook
			   'ruby-mode-hook
			   'qmake-mode-hook
			   'lua-mode-hook
			   'swift-mode-hook
			   ))
  (add-hook hook (lambda () (display-line-numbers-mode))))


;; tab
(setq-default tab-width 4)

(if (featurep 'cocoa)
	(progn
	  ;; 在Mac平台, Emacs不能进入Mac原生的全屏模式,否则会导致 `make-frame' 创建时也集成原生全屏属性后造成白屏和左右滑动现象.
	  ;; 所以先设置 `ns-use-native-fullscreen' 和 `ns-use-fullscreen-animation' 禁止Emacs使用Mac原生的全屏模式.
	  ;; 而是采用传统的全屏模式, 传统的全屏模式, 只会在当前工作区全屏,而不是切换到Mac那种单独的全屏工作区,
	  ;; 这样执行 `make-frame' 先关代码或插件时,就不会因为Mac单独工作区左右滑动产生的bug.
	  ;;
	  ;; Mac平台下,不能直接使用 `set-frame-parameter' 和 `fullboth' 来设置全屏,
	  ;; 那样也会导致Mac窗口管理器直接把Emacs窗口扔到单独的工作区, 从而对 `make-frame' 产生同样的Bug.
	  ;; 所以, 启动的时候通过 `set-frame-parameter' 和 `maximized' 先设置Emacs为最大化窗口状态, 启动5秒以后再设置成全屏状态,
	  ;; Mac就不会移动Emacs窗口到单独的工作区, 最终解决Mac平台下原生全屏窗口导致 `make-frame' 左右滑动闪烁的问题.
	  (setq ns-use-native-fullscreen nil)
	  (setq ns-use-fullscreen-animation nil)
	  (run-at-time "5sec" nil
				   (lambda ()
					 (let ((fullscreen (frame-parameter (selected-frame) 'fullscreen)))
					   ;; If emacs has in fullscreen status, maximized window first, drag emacs window from Mac's single space.
					   (when (memq fullscreen '(fullscreen fullboth))
						 (set-frame-parameter (selected-frame) 'fullscreen 'maximized))
					   ;; Call `toggle-frame-fullscreen' to fullscreen emacs.
					   (toggle-frame-fullscreen)))))

  ;; 非Mac平台直接全屏
  ;;(require 'fullscreen)
  ;;(fullscreen)
  )

(setq frame-resize-pixelwise t) ;设置缩放的模式,避免Mac平台最大化窗口以后右边和下边有空隙

;; (require 'lazycat-theme)
;; (use-package doom-themes
;; 	     :init (load-theme 'doom-nord-light t))

(use-package doom-themes
  :init (load-theme 'doom-one t))

(require 'awesome-tray)
;; (setq awesome-tray-active-modules '("location" "buffer-name" "projectile-or-parentdir"
;; 									"git" "mode-name" "date"))
(setq awesome-tray-active-modules '("location" "buffer-name" "parent-dir"
									"git" "mode-name" "date"))
(awesome-tray-mode 1)

;; (use-package doom-modeline
;;   :ensure t
;;   :defer t
;;   :hook (after-init . doom-modeline-init)
;;   :config
;;   (setq doom-modeline-buffer-file-name-style 'relative-from-project)
;;   )

;; Modeline
;; (use-package spaceline-config
;;   :ensure spaceline
;;   :commands (spaceline-spacemacs-theme
;;			 spaceline-info-mode)
;;   :init
;;   (setq powerline-default-separator nil)
;;   (add-hook 'after-init-hook
;;			(lambda ()
;;			  (spaceline-spacemacs-theme)))
;;   :config
;;   ;; (setq
;;   ;;  spaceline-window-numbers-unicode t
;;   ;;  spaceline-workspace-numbers-unicode t
;;   ;;  )
;;   (spaceline-info-mode 1)
;;   (spaceline-toggle-buffer-encoding-on)
;;   (use-package diminish
;;	:init
;;	(diminish 'counsel-mode)
;;	(diminish 'ivy-mode)
;;	(diminish 'rainbow-mode)
;;	(diminish 'volatile-highlights-mode)
;;	(diminish 'whitespace-mode)
;;	(diminish 'eldoc-mode)
;;	(diminish 'company-mode "C")
;;	)
;;   )

;; (use-package diminish
;;   :init
;;   (diminish 'counsel-mode)
;;   (diminish 'ivy-mode)
;;   (diminish 'rainbow-mode)
;;   (diminish 'volatile-highlights-mode)
;;   (diminish 'whitespace-mode)
;;   (diminish 'eldoc-mode)
;;   )

(use-package cnfonts
  :init (cnfonts-enable)
  :config
  (setq cnfonts-directory (expand-file-name "cnfont" flywind-etc-dir)
		cnfonts-profiles '("notebook" "desktop")
		cnfonts--profiles-steps '(("notebook" . 1)
								  ("desktop"  . 2))
		)
  )

;; Revert to built-in linum
;; https://github.com/syl20bnr/spacemacs/issues/6104
;; (global-linum-mode)

;; ;; paren mode
;; (setq show-paren-delay 0.1
;;       show-paren-highlight-openparen t
;;       show-paren-when-point-inside-paren t)
;; (show-paren-mode)

;; Display Time
(use-package time
  :ensure nil
  :unless (display-graphic-p)
  :preface
  (setq display-time-24hr-format t)
  (setq display-time-day-and-date t)
  :init (add-hook 'after-init-hook 'display-time-mode))

;; Highlight matching paren
(use-package paren
  :ensure nil
  :init (add-hook 'after-init-hook 'show-paren-mode)
  :config
  (setq show-paren-when-point-inside-paren t)
  (setq show-paren-when-point-in-periphery t))

;; Highlight surrounding parentheses
(use-package highlight-parentheses
  :diminish highlight-parentheses-mode
  :init (add-hook 'prog-mode-hook 'highlight-parentheses-mode)
  :config (set-face-attribute 'hl-paren-face nil :weight 'ultra-bold))

;; Highlight indentions
(use-package indent-guide
  :diminish indent-guide-mode
  :init
  (add-hook 'prog-mode-hook 'indent-guide-mode)
  ;; (add-hook 'after-init-hook 'indent-guide-global-mode)
  :config (setq indent-guide-delay 0.5))

;; Colorize color names in buffers
(use-package rainbow-mode
  :diminish rainbow-mode
  :init
  (add-hook 'emacs-lisp-mode-hook 'rainbow-mode)
  (with-eval-after-load 'web-mode
	(add-hook 'web-mode-hook 'rainbow-mode))
  (with-eval-after-load 'css-mode
	(add-hook 'css-mode-hook 'rainbow-mode)))

;; Highlight brackets according to their depth
(use-package rainbow-delimiters
  :init (add-hook 'prog-mode-hook 'rainbow-delimiters-mode))

;; Highlight some operations
(use-package volatile-highlights
  :diminish volatile-highlights-mode
  :init (add-hook 'after-init-hook 'volatile-highlights-mode))

;; Visualize TAB, (HARD) SPACE, NEWLINE
(use-package whitespace
  :ensure nil
  :diminish whitespace-mode
  :init
  (dolist (hook '(prog-mode-hook outline-mode-hook conf-mode-hook))
	(add-hook hook #'whitespace-mode))
  :config
  (setq whitespace-line-column fill-column) ;; limit line length
  ;; automatically clean up bad whitespace
  (setq whitespace-action '(auto-cleanup))
  ;; only show bad whitespace
  (setq whitespace-style '(face
						   trailing space-before-tab
						   indentation empty space-after-tab))

  (with-eval-after-load 'popup
	;; advice for whitespace-mode conflict with popup
	(defvar my-prev-whitespace-mode nil)
	(make-local-variable 'my-prev-whitespace-mode)

	(defadvice popup-draw (before my-turn-off-whitespace activate compile)
	  "Turn off whitespace mode before showing autocomplete box."
	  (if whitespace-mode
		  (progn
			(setq my-prev-whitespace-mode t)
			(whitespace-mode -1))
		(setq my-prev-whitespace-mode nil)))

	(defadvice popup-delete (after my-restore-whitespace activate compile)
	  "Restore previous whitespace mode when deleting autocomplete box."
	  (if my-prev-whitespace-mode
		  (whitespace-mode 1)))))

;; ;; indent
;; (use-package indent-guide
;;   :init
;;   (indent-guide-global-mode))

;; Misc
(fset 'yes-or-no-p 'y-or-n-p)
(setq inhibit-startup-screen t)


(provide 'flywind-ui)
