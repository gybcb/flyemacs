(use-package gnus)
(use-package notmuch
  :after gnus
  :ensure nil
  :config
  (setq mail-user-agent 'message-user-agent)
  )

(provide 'flywind-email)
