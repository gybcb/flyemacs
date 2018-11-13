;; (use-package meghanada
;;   :defer t
;;   :init
;;   (progn
;;	(setq meghanada-server-install-dir (concat flywind-cache-dir "meghanada/")
;;		  company-meghanada-prefix-length 1
;;		  ))
;;   :config
;;   (progn
;;	(add-hook 'java-mode-hook
;;			  (lambda ()
;;				;; meghanada-mode on
;;				(meghanada-mode t)
;;				(add-hook 'before-save-hook 'meghanada-code-beautify-before-save)))
;;	)
;;   )

;; (use-package lsp-javacomp
;;   :commands lsp-javacomp-enable
;;   :init
;;   (use-package company-lsp)
;;   (add-hook 'java-mode-hook
;;			(lambda ()
;;			  ;; Load company-lsp before enabling lsp-javacomp, so that function
;;			  ;; parameter snippet works.
;;			  (require 'company-lsp)
;;			  (lsp-javacomp-enable)
;;			  ;; Use company-lsp as the company completion backend
;;			  (set (make-variable-buffer-local 'company-backends) '(company-lsp))
;;			  ;; Optional company-mode settings
;;			  (set (make-variable-buffer-local 'company-idle-delay) 0.1)
;;			  (set (make-variable-buffer-local 'company-minimum-prefix-length) 1)))
;;   ;; Optional, make sure JavaComp is installed. See below.
;;   (setq lsp-javacomp-server-install-dir (concat flywind-cache-dir "javacomp/"))
;;   :config
;;   (lsp-javacomp-install-server)
;;   )

(when (featurep 'cocoa)
  ;; Initialize environment from user's shell to make eshell know every PATH by other shell.
  (require 'exec-path-from-shell)
  (exec-path-from-shell-initialize))

(use-package company-lsp
  :init
  (use-package lsp-mode)
  :config
  (setq company-lsp-async t)
  )

(use-package lsp-java
  :commands lsp-java-enable
  :init
  (use-package lsp-mode)
 ;; (use-package lsp-ui)
  (use-package company-lsp)
  (setq lsp-java-server-install-dir (concat flywind-cache-dir "eclipse.jdt.ls/server/"))
  :config
  (add-hook 'java-mode-hook
			(lambda ()
			  (require 'company-lsp)
			  (require 'lsp-java)
			  (lsp-java-enable)
			  (set (make-variable-buffer-local 'company-backends) '(company-lsp))
			  ))
;;  (add-hook 'lsp-mode-hook 'lsp-ui-mode)
  )

(use-package lsp-python
  :commands lsp-python-enable
  :init
  (use-package lsp-mode)
;;  (use-package lsp-ui)
  (use-package company-lsp)
  :config
  (add-hook 'python-mode-hook
			(lambda ()
			  (require 'lsp-mode)
			  (require 'company-lsp)
			  (require 'lsp-python)
			  (lsp-python-enable)
			  (set (make-variable-buffer-local 'company-backend) '(company-lsp)
				   (company-idle-delay nil)
				   )
			  ))
;;  (add-hook 'lsp-mode-hook 'lsp-ui-mode)
  )

;; (use-package lsp-python
;;   :commands lsp-python-enable
;;   :init
;;   (use-package lsp-mode)
;;   (use-package lsp-ui)
;;   (use-package company-lsp)
;;   :config
;;   (require 'lsp-mode)
;;   (require 'company-lsp)
;;   (require 'lsp-python)
;;   (setq lsp-message-project-root-warning t)
;;   (push 'company-lsp company-backends)
;;   (add-hook 'python-mode-hook #'lsp-python-enable)
;;   (add-hook 'lsp-mode-hook 'lsp-ui-mode)
;;   )

(provide 'flywind-java)
