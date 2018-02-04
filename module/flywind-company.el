
(use-package company
  :diminish company-mode
  :bind (("M-/"  .  company-complete)

	 :map company-active-map
	 ("C-p"  .  company-select-previous)
	 ("C-n"  .  company-select-next)
	 ("Tab"  .  company-complete-common-or-cycle)
	 )
  :init (add-hook 'after-init-hook 'global-company-mode)
  :config
  ;; aligns annotation to the right hand side
  (setq company-tooltip-align-annotations t)

  (setq company-idle-delay 0.3
        company-minimum-prefix-length 2
        company-require-match nil)
)

(provide 'flywind-company)
