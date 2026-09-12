;;; flywind-kill-ring.el --- kill-ring 增强 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; browse-kill-ring 已移除：kill-ring 浏览改由 `consult-yank-pop' 承担
;; （见 flywind-completion.el 的 M-y 绑定）。
;;
;;; Code:

(eval-when-compile (require 'easy-kill))

(setq kill-ring-max 200
      save-interprogram-paste-before-kill t)   ; 粘贴前先把剪贴板内容存入 kill-ring

(use-package easy-kill
  :bind (([remap kill-ring-save] . easy-kill)
         ([remap mark-sexp] . easy-mark)))

(provide 'flywind-kill-ring)
;;; flywind-kill-ring.el ends here
