;; Group ibuffer's list by project root
(use-package ibuffer-projectile
  :bind ("C-x C-b" . ibuffer)
  :init
  (setq ibuffer-filter-group-name-face 'font-lock-function-name-face)
  (add-hook 'ibuffer-hook
			(lambda ()
			  (ibuffer-auto-mode 1)
			  (ibuffer-projectile-set-filter-groups)
			  (unless (eq ibuffer-sorting-mode 'alphabetic)
				(ibuffer-do-sort-by-alphabetic)))))


(provide 'flywind-ibuffer)
