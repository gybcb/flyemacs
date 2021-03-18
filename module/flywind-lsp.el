;; (require 'nox)
;; (dolist (hook (list
;;			   'js-mode-hook
;;			   'python-mode-hook
;;			   'java-mode-hook
;;			   'sh-mode-hook
;;			   'c-mode-common-hook
;;			   'c-mode-hook
;;			   'c++-mode-hook
;;			   ))
;;   (add-hook hook '(lambda () (nox-ensure))))

;; (setq nox-python-path "~/.pyenv/versions/3.9.1/bin/python")

;; (use-package lsp-mode
;;   :defer t
;;   :commands lsp
;;   :custom
;;   (lsp-auto-guess-root nil)
;;   (lsp-prefer-flymake nil) ; Use flycheck instead of flymake
;;   (lsp-file-watch-threshold 2000)
;;   (read-process-output-max (* 1024 1024))
;;   (lsp-eldoc-hook nil)
;;   :bind (:map lsp-mode-map ("C-c C-f" . lsp-format-buffer))
;;   :hook ((java-mode python-mode go-mode
;;		  js-mode js2-mode typescript-mode web-mode
;;		  c-mode c++-mode objc-mode) . lsp))


;; (use-package lsp-ui
;;   :after lsp-mode
;;   :diminish
;;   :commands lsp-ui-mode
;;   :custom-face
;;   (lsp-ui-doc-background ((t (:background nil))))
;;   (lsp-ui-doc-header ((t (:inherit (font-lock-string-face italic)))))
;;   :bind
;;   (:map lsp-ui-mode-map
;;		([remap xref-find-definitions] . lsp-ui-peek-find-definitions)
;;		([remap xref-find-references] . lsp-ui-peek-find-references)
;;		("C-c u" . lsp-ui-imenu)
;;		("M-i" . lsp-ui-doc-focus-frame))
;;   (:map lsp-mode-map
;;		("M-n" . forward-paragraph)
;;		("M-p" . backward-paragraph))
;;   :custom
;;   (lsp-ui-doc-header t)
;;   (lsp-ui-doc-include-signature t)
;;   (lsp-ui-doc-border (face-foreground 'default))
;;   (lsp-ui-sideline-enable nil)
;;   (lsp-ui-sideline-ignore-duplicate t)
;;   (lsp-ui-sideline-show-code-actions nil)
;;   :config
;;   ;; Use lsp-ui-doc-webkit only in GUI
;;   (if (display-graphic-p)
;;	  (setq lsp-ui-doc-use-webkit t))
;;   ;; WORKAROUND Hide mode-line of the lsp-ui-imenu buffer
;;   ;; https://github.com/emacs-lsp/lsp-ui/issues/243
;;   (defadvice lsp-ui-imenu (after hide-lsp-ui-imenu-mode-line activate)
;;	(setq mode-line-format nil)))


;; (use-package eglot
;;   :hook (prog-mode . eglot-ensure)
;;   )

(use-package lsp-mode
  :diminish lsp-mode
  :hook (prog-mode . lsp)
  :bind (:map lsp-mode-map
			  ("C-c C-d" . lsp-describe-thing-at-point))
  :init
  (setq lsp-auto-guess-root t)       ; Detect project root
  (setq lsp-prefer-flymake nil)      ; Use lsp-ui and flycheck
  (setq flymake-fringe-indicator-position 'right-fringe)
  :config
  ;; Configure LSP clients
  (use-package lsp-clients
	:ensure nil
	:init
	(setq lsp-clients-python-library-directories '("/usr/local/" "/usr/")))
  )

(use-package lsp-ui
  :custom-face
  (lsp-ui-doc-background ((t (:background nil))))
  (lsp-ui-doc-header ((t (:inherit (font-lock-string-face italic)))))
  :bind (:map lsp-ui-mode-map
			  ([remap xref-find-definitions] . lsp-ui-peek-find-definitions)
			  ([remap xref-find-references] . lsp-ui-peek-find-references)
			  ("C-c u" . lsp-ui-imenu))
  :init (setq lsp-ui-doc-enable t
			  lsp-ui-doc-header t
			  lsp-ui-doc-include-signature t
			  lsp-ui-doc-position 'top
			  lsp-ui-doc-use-webkit t
			  lsp-ui-doc-border (face-foreground 'default)

			  lsp-ui-sideline-enable nil
			  lsp-ui-sideline-ignore-duplicate t)
  :config
  ;; WORKAROUND Hide mode-line of the lsp-ui-imenu buffer
  ;; https://github.com/emacs-lsp/lsp-ui/issues/243
  (defadvice lsp-ui-imenu (after hide-lsp-ui-imenu-mode-line activate)
	(setq mode-line-format nil)))

(use-package yasnippet
  :config
  (yas-global-mode 1)
  (add-hook 'prog-mode-hook #'yas-minor-mode))

;; (use-package company-lsp
;;   :init (setq company-lsp-cache-candidates 'auto))

;; `lsp-mode' and `treemacs' integration.
(use-package lsp-treemacs
  :bind (:map lsp-mode-map
			  ("M-9" . lsp-treemacs-errors-list)))

;; C/C++/Objective-C support
(use-package ccls
  :defines projectile-project-root-files-top-down-recurring
  :hook ((c-mode c++-mode objc-mode cuda-mode) . (lambda ()
												   (require 'ccls)
												   (lsp)))
  :config
  (with-eval-after-load 'projectile
	(setq projectile-project-root-files-top-down-recurring
		  (append '("compile_commands.json"
					".ccls")
				  projectile-project-root-files-top-down-recurring))))

;; Java support
(use-package lsp-java
  :hook (java-mode . (lambda ()
					   (require 'lsp-java)
					   (lsp))))

;; python support
(use-package lsp-python-ms
  :ensure t
  :init (setq lsp-python-ms-auto-install-server t)
  :hook (python-mode . (lambda ()
						  (require 'lsp-python-ms)
						  (lsp-deferred))))  ; or lsp-deferred


(provide 'flywind-lsp)
