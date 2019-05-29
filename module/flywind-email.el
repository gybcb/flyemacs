(use-package gnus)
(use-package notmuch
  :after gnus
  :ensure nil
  :config
  (setq mail-user-agent 'message-user-agent)
  )

(use-package bbdb)
(use-package smtpmail-multi)

(provide 'flywind-email)
