;; (use-package lsp-python-ms
;;   :ensure t
;;   :hook (python-mode . (lambda ()
;;						  (require 'lsp-python-ms)
;;						  (lsp))))  ; or lsp-deferred

(use-package ein
  :ensure t)

(use-package jupyter
  :ensure t
  :config
  (org-babel-jupyter-override-src-block "python"))

(defun my-python-mode-config ()
  (setq python-indent-offset 4
        python-indent 4
        indent-tabs-mode nil
        default-tab-width 4
        )

;;  (set (make-local-variable 'electric-indent-mode) nil)
  )

(add-hook 'python-mode-hook 'my-python-mode-config)

(provide 'flywind-python)
