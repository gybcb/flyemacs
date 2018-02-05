
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

(use-package cnfonts
  :init (cnfonts-enable)
  :config
  (setq cnfonts-profiles
	'("notebook" "desktop"))
  (setq cnfonts--profiles-steps '(("notebook" . 1)
				  ("desktop"  . 2))))

;; Revert to built-in linum
;; https://github.com/syl20bnr/spacemacs/issues/6104
(global-linum-mode)

;; paren mode
(setq show-paren-delay 0.1
      show-paren-highlight-openparen t
      show-paren-when-point-inside-paren t)
(show-paren-mode)

(use-package smartparens
  :init
  (smartparens-global-mode +1)
  )

;; indent
(use-package indent-guide
  :init
  (indent-guide-global-mode))

;; Misc
(fset 'yes-or-no-p 'y-or-n-p)
(setq inhibit-startup-screen t)


(provide 'flywind-ui)
