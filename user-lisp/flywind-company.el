;;; flywind-company.el --- 代码补全前端 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; company 只服务非 lsp-bridge 场景；lsp buffer 内的补全交给 acm
;; （见 flywind-lsp.el 中的互斥处理）。
;; 注意：原配置 use-package-always-defer=t + 只写 :config，导致
;; company-posframe-mode 从未被真正打开，这里用 :demand t 修正。
;;
;;; Code:

(eval-when-compile (require 'company))   ; company-active-map 供 :bind 展开使用

(use-package company
  :diminish company-mode
  :bind (("M-/" . company-complete)
         (:map company-active-map
               ("C-p" . company-select-previous)
               ("C-n" . company-select-next)
               ("TAB" . company-complete-common-or-cycle)
               ("<tab>" . company-complete-common-or-cycle)))
  :custom
  (company-tooltip-align-annotations t)
  (company-idle-delay 0.3)
  (company-minimum-prefix-length 2)
  (company-require-match nil)
  (company-dabbrev-ignore-case nil)
  (company-dabbrev-downcase nil)
  :config
  (global-company-mode 1))

(use-package company-posframe
  :demand t
  :after company
  :config
  (company-posframe-mode 1))

(provide 'flywind-company)
;;; flywind-company.el ends here
