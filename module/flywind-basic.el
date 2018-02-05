
(use-package recentf
  :init
  (setq recentf-max-saved-items 200)
  :config
  (add-hook 'find-file-hook (lambda () (unless recentf-mode
					 (recentf-mode)
					 (recentf-track-opened-file))))
  (add-to-list 'recentf-exclude (expand-file-name package-user-dir))
  (add-to-list 'recentf-exclude "bookmarks")
  (add-to-list 'recentf-exclude "COMMIT_EDITMSG\\'")
  )

;;;
;; UTF-8 as the default coding system
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))     ; pretty
(prefer-coding-system        'utf-8)   ; pretty
(set-terminal-coding-system  'utf-8)   ; pretty
(set-keyboard-coding-system  'utf-8)   ; pretty
(set-selection-coding-system 'utf-8)   ; perdy
(setq locale-coding-system   'utf-8)   ; please
(setq-default buffer-file-coding-system 'utf-8) ; with sugar on top

(setq-default
 make-backup-files nil ; don't create backup ~ files
 )

(when (eq system-type 'darwin)
	  (use-package exec-path-from-shell
		:init
		(setq exec-path-from-shell-check-startup-files nil)
		(setq exec-path-from-shell-variables '("PATH" "MANPATH" "PYTHONPATH"))
		(setq exec-path-from-shell-arguments '("-l"))
		)
	  )

(provide 'flywind-basic)  
