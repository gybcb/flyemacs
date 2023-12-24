(use-package treesit-auto
  :pin melpa
  :demand t
  :config
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode))

(setq treesit-font-lock-level 4)

(provide 'flywind-treesit)
