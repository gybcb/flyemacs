
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
        ;; don't show recent files in switch-buffer
        ivy-use-virtual-buffers nil
        ;; ...but if that ever changes, show their full path
        ivy-virtual-abbreviate 'full
	)
  (let ((command
         (cond
          ((executable-find "rg")
           "rg -i -M 120 --no-heading --line-number --color never '%s' %s")
          ((executable-find "ag")
           "ag -i --noheading --nocolor --nofilename --numbers '%s' %s"))))
    (setq counsel-grep-base-command command))

  (use-package smex)
  )
  

(provide 'flywind-ivy)
