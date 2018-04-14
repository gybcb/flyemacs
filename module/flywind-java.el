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

(use-package lsp-javacomp
  :commands lsp-javacomp-enable
  :init
  (use-package company-lsp)
  (add-hook 'java-mode-hook
			(lambda ()
			  ;; Load company-lsp before enabling lsp-javacomp, so that function
			  ;; parameter snippet works.
			  (require 'company-lsp)
			  (lsp-javacomp-enable)
			  ;; Use company-lsp as the company completion backend
			  (set (make-variable-buffer-local 'company-backends) '(company-lsp))
			  ;; Optional company-mode settings
			  (set (make-variable-buffer-local 'company-idle-delay) 0.1)
			  (set (make-variable-buffer-local 'company-minimum-prefix-length) 1)))
  ;; Optional, make sure JavaComp is installed. See below.
  (setq lsp-javacomp-server-install-dir (concat flywind-cache-dir "javacomp/"))
  :config
  (lsp-javacomp-install-server)
  )

;; (use-package lsp-java
;;   :init
;;   (use-package lsp-mode)
;;   (use-package lsp-ui)
;;   (use-package company-lsp)
;;   (setq lsp-java-server-install-dir (concat flywind-cache-dir "eclipse.jdt.ls/server/"))
;;   :config
;;   (add-hook 'java-mode-hook
;;			(lambda ()
;;			  (require 'company-lsp)
;;			  (require 'lsp-java)
;;			  (lsp-java-enable)
;;			  (set (make-variable-buffer-local 'company-backends) '(company-lsp))
;;			  ))
;;   (add-hook 'lsp-mode-hook 'lsp-ui-mode)
;;   )

(provide 'flywind-java)
