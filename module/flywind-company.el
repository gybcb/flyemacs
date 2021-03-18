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

;; (use-package company
;;   :diminish company-mode
;;   :defines (company-dabbrev-ignore-case company-dabbrev-downcase)
;;   :preface
;;   (defvar company-enable-yas t
;;	"Enable yasnippet for all backends.")

;;   (defun company-backend-with-yas (backend)
;;	(if (or (not company-enable-yas)
;;			(and (listp backend) (member 'company-yasnippet backend)))
;;		backend
;;	  (append (if (consp backend) backend (list backend))
;;			  '(:with company-yasnippet))))
;;   :bind (("M-/" . company-complete)
;;		 ("C-c C-y" . company-yasnippet)
;;		 :map company-active-map
;;		 ("C-p" . company-select-previous)
;;		 ("C-n" . company-select-next)
;;		 ("TAB" . company-complete-common-or-cycle)
;;		 ("<tab>" . company-complete-common-or-cycle)
;;		 ("S-TAB" . company-select-previous)
;;		 ("<backtab>" . company-select-previous)
;;		 :map company-search-map
;;		 ("C-p" . company-select-previous)
;;		 ("C-n" . company-select-next))
;;   :hook (after-init . global-company-mode)
;;   :config
;;   (setq company-tooltip-align-annotations t ; aligns annotation to the right
;;		company-tooltip-limit 12            ; bigger popup window
;;		company-idle-delay 0.3               ; decrease delay before autocompletion popup shows
;;		;;company-echo-delay 0                ; remove annoying blinking
;;		company-minimum-prefix-length 2
;;		company-require-match nil
;;		company-dabbrev-ignore-case nil
;;		company-dabbrev-downcase nil)

;;   ;; Popup documentation for completion candidates
;;   (when (display-graphic-p)
;;	(use-package company-quickhelp
;;	  :bind (:map company-active-map
;;				  ("M-h" . company-quickhelp-manual-begin))
;;	  :hook (global-company-mode . company-quickhelp-mode)
;;	  :config (setq company-quickhelp-delay 0.8)))

;;   ;; Support yas in commpany
;;   ;; Note: Must be the last to involve all backends
;;   (setq company-backends (mapcar #'company-backend-with-yas company-backends)))


(use-package company-posframe
  :config (company-posframe-mode 1)
  )


(provide 'flywind-company)
