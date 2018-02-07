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
		(exec-path-from-shell-initialize)
		)
	  )

;; (use-package smartparens
;;   :init
;;   (smartparens-global-mode +1)
;;   )

;; Automatic parenthesis pairing
(use-package elec-pair
  :ensure nil
  :init (add-hook 'after-init-hook 'electric-pair-mode))

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

;; 这个命令配合 comment-dwim 基本上能满足所有注释的需求
(global-set-key (kbd "C-c C-g") 'comment-or-uncomment-region)

(provide 'flywind-basic)
