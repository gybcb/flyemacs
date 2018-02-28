(use-package counsel
  :diminish ivy-mode counsel-mode
  :bind(("C-s" . counsel-grep-or-swiper)
		("C-S-s" . swiper-all)

		("C-x C-r" . counsel-recentf)
		)
  :init (add-hook 'after-init-hook
				  (lambda ()
					(ivy-mode 1)
					(counsel-mode 1)))
  :config
  (setq ivy-use-virtual-buffers t
		ivy-height 12
		ivy-do-completion-in-region nil
		ivy-fixed-height-minibuffer t
		smex-completion-method 'ivy

		;; Don't use ^ as initial input
		ivy-initial-inputs-alist nil
		;; highlight til EOL
		ivy-format-function #'ivy-format-function-line
		;; disable magic slash on non-match
		ivy-magic-slash-non-match-action nil
		;; don't show recent files in switch-buffer nil disable t enable
		;; ivy-use-virtual-buffers nil
		;; ...but if that ever changes, show their full path
		ivy-virtual-abbreviate 'full
		smex-save-file (concat flywind-cache-dir "/smex-items")
		)
  (with-eval-after-load 'projectile
	(setq projectile-completion-system 'ivy))

  (with-eval-after-load 'magit
	(setq magit-completing-read-function 'ivy-completing-read))

  ;; Exact same behaviors as isearch
  (bind-key "C-w" 'ivy-yank-word ivy-minibuffer-map)

  (let ((command
		 (cond
		  ((executable-find "rg")
		   "rg -i -M 120 --no-heading --line-number --color never '%s' %s")
		  ((executable-find "ag")
		   "ag -i --noheading --nocolor --nofilename --numbers '%s' %s"))))
	(setq counsel-grep-base-command command))

  ;; Enhance M-x
  (use-package smex)

  ;; Additional key bindings for Ivy
  (use-package ivy-hydra
	:bind (:map ivy-minibuffer-map
				("M-o" . ivy-dispatching-done-hydra)))

  ;; More friendly display transformer for Ivy
  (use-package ivy-rich
	:init
	(setq ivy-virtual-abbreviate 'full
		  ivy-rich-switch-buffer-align-virtual-buffer nil)
	(setq ivy-rich-abbreviate-paths t)

	(ivy-set-display-transformer 'ivy-switch-buffer
								 'ivy-rich-switch-buffer-transformer)

	(with-eval-after-load 'counsel-projectile
	  (ivy-set-display-transformer 'counsel-projectile
								   'ivy-rich-switch-buffer-transformer)
	  (ivy-set-display-transformer 'counsel-projectile-switch-to-buffer
								   'ivy-rich-switch-buffer-transformer)))

	;; Ivy integration for Projectile
  (use-package counsel-projectile
	:init (counsel-projectile-mode))

  (with-eval-after-load 'counsel-projectile
	(ivy-set-display-transformer 'counsel-projectile
								 'ivy-rich-switch-buffer-transformer)
	(ivy-set-display-transformer 'counsel-projectile-switch-to-buffer
								 'ivy-rich-switch-buffer-transformer))


  )


(provide 'flywind-ivy)
