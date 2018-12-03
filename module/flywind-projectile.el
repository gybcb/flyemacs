;; Manage and navigate projects
(use-package projectile
  ;; :bind (("C-x p" . projectile-find-file))  ; Cmd-t for Mac and Super-t for Linux
  :bind (:map projectile-mode-map
			  ("C-c p" . projectile-command-map))
  :init
  (add-hook 'after-init-hook 'projectile-mode)
  (setq projectile-cache-file (concat flywind-cache-dir "projectile.cache")
		projectile-enable-caching (not noninteractive)
		projectile-indexing-method 'alien
		projectile-known-projects-file (concat flywind-cache-dir "projectile.projects")
		projectile-require-project-root nil
		projectile-globally-ignored-files '(".DS_Store" "Icon" "TAGS")
		projectile-globally-ignored-file-suffixes '(".elc" ".pyc" ".o")
		)
  :config
  (setq projectile-mode-line
		'(:eval (format "[%s]" (projectile-project-name))))

  (setq projectile-sort-order 'recentf)
  (setq projectile-use-git-grep t)

  ;; Use faster search tools: ripgrep or the silver search
  (let ((command
		 (cond
		  ((executable-find "rg")
		   "rg -0 --files --color=never --hidden --sort-files")
		  ((executable-find "ag")
		   (concat "ag -0 -l --nocolor --hidden"
				   (mapconcat #'identity
							  (cons "" projectile-globally-ignored-directories)
							  " --ignore-dir="))))))
	(setq projectile-generic-command command))

  ;; Support Perforce project
  (let ((val (or (getenv "P4CONFIG") ".p4config")))
	(add-to-list 'projectile-project-root-files-bottom-up val))

  ;; supprt projectile-ag
  (use-package ag
	:init
	(setq ag-context-lines 5
		  ag-highlight-search t
		  ))
  )

(provide 'flywind-projectile)
