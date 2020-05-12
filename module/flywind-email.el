;; (use-package gnus)
;; (use-package notmuch
;;   :after gnus
;;   :ensure nil
;;   :config
;;   (setq mail-user-agent 'message-user-agent)
;;   )

;; (use-package bbdb)
;; (use-package smtpmail-multi)

(use-package wanderlust
  :config
  (if (boundp 'mail-user-agent)
	  (setq mail-user-agent 'wl-user-agent))
  (if (fboundp 'define-mail-user-agent)
	  (define-mail-user-agent
		'wl-user-agent
		'wl-user-agent-compose
		'wl-draft-send
		'wl-draft-kill
		'mail-send-hook))
  (setq wl-stay-folder-window t)
  (setq wl-message-ignored-field-list
	  '(".")
	  wl-message-visible-field-list
	  '("^\\(To\\|Cc\\):"
		"^Subject:"
		"^\\(From\\|Reply-To\\):"
		"^\\(Posted\\|Date\\):"
		"^Organization:"
		"^X-\\(Face\\(-[0-9]+\\)?\\|Weather\\|Fortune\\|Now-Playing\\):")
	  wl-message-sort-field-list
	  (append wl-message-sort-field-list
			  '("^Reply-To" "^Posted" "^Date" "^Organization")))

	;; ---------------------------------------------------------------------------
  ;; Summary
  (setq wl-auto-select-next 'unread
		wl-summary-width nil
		wl-summary-weekday-name-lang "en"
		wl-summary-showto-folder-regexp ".Sent.*"
		wl-summary-line-format "%T%P%M/%D(%W)%h:%m %[ %17f %]%[%1@%] %t%C%s"
		wl-message-mode-line-format (propertize "%f" 'face 'powerline-active1)
		;; Summary threads
		wl-thread-insert-opened t
		wl-thread-open-reading-thread t
		)
  )

(provide 'flywind-email)
