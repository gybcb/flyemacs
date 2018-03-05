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
(setq column-number-mode t)
(setq line-number-mode t)

;; tab
(setq-default tab-width 4)

(use-package doom-themes
  :init (load-theme 'doom-one t))

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

(use-package diminish
  :init
  (diminish 'counsel-mode)
  (diminish 'ivy-mode)
  (diminish 'rainbow-mode)
  (diminish 'volatile-highlights-mode)
  (diminish 'whitespace-mode)
  (diminish 'eldoc-mode)
  )

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
(global-linum-mode)

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
