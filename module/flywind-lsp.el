;; (use-package eglot
;;   :hook (prog-mode . eglot-ensure)
;;   )

(use-package lsp-mode
  :diminish lsp-mode
  :hook (lsp-after-open . lsp-enable-imenu)
  :config
  (setq lsp-inhibit-message t)
  (setq lsp-message-project-root-warning t)
  (setq create-lockfiles nil)

  ;; Restart server/workspace in case the lsp server exits unexpectedly.
  ;; https://emacs-china.org/t/topic/6392
  (defun lsp-restart-server ()
	"Restart LSP server."
	(interactive)
	(lsp-restart-workspace)
	(revert-buffer t t)
	(message "LSP server restarted."))

  ;; Support LSP in org babel
  ;; https://github.com/emacs-lsp/lsp-mode/issues/377
  (cl-defmacro lsp-org-babel-enbale (lang &optional enable-name)
	"Support LANG in org source code block. "
	(cl-check-type lang string)
	(cl-check-type enable-name (or null string))
	(let ((edit-pre (intern (format "org-babel-edit-prep:%s" lang)))
		  (intern-pre (intern (format "lsp--org-babel-edit-prep:%s" lang)))
		  (client (intern (format "lsp-%s-enable" (or enable-name lang)))))
	  `(progn
		 (defun ,intern-pre (info)
		   (let ((lsp-file (or (->> info caddr (alist-get :file))
							   buffer-file-name)))
			 (setq-local buffer-file-name lsp-file)
			 (setq-local lsp-buffer-uri (lsp--path-to-uri lsp-file))
			 (,client)))
		 (if (fboundp ',edit-pre)
			 (advice-add ',edit-pre :after ',intern-pre)
		   (progn
			 (defun ,edit-pre (info)
			   (,intern-pre info))
			 (put ',edit-pre 'function-documentation
				  (format "Prepare local buffer environment for org source block (%s)."
						  (upcase ,lang))))))))

  ;; FIXME: Project detection
  ;; If nil, use the current directory
  ;; https://github.com/emacs-lsp/lsp-python/issues/28
  ;; (defun my-default-directory ()
  ;;   "Returns the current directory."
  ;;   default-directory)
  ;; (advice-add #'lsp--suggest-project-root :after-until #'my-default-directory)
  )

(use-package lsp-ui
  :bind (:map lsp-ui-mode-map
			  ([remap xref-find-definitions] . lsp-ui-peek-find-definitions)
			  ([remap xref-find-references] . lsp-ui-peek-find-references)
			  ("C-c u" . lsp-ui-imenu))
  :hook (lsp-mode . lsp-ui-mode))

(use-package company-lsp
  :after company
  :defines company-backends
  :functions company-backend-with-yas
  :init (cl-pushnew (company-backend-with-yas 'company-lsp) company-backends))

;; Go support for lsp-mode using Sourcegraph's Go Language Server
;; Install: go get -u github.com/sourcegraph/go-langserver
(use-package lsp-go
  :commands lsp-go-enable
  :hook (go-mode . lsp-go-enable)
  :config (lsp-org-babel-enbale "go"))

;; Python support for lsp-mode using pyls.
;; Install: pip install python-language-server
(use-package lsp-python
  :commands lsp-python-enable
  :hook (python-mode . lsp-python-enable)
  :config
  (lsp-org-babel-enbale "python")
  (lsp-org-babel-enbale "ipython" "python"))

(provide 'flywind-lsp)
