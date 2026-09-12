;;; flywind-treesit.el --- tree-sitter -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Emacs 31 内置大量 *-ts-mode，语法库 ABI 需与之匹配：
;;   * treesit-auto 升级到上游最新，自动按需要的 ABI 下载语法库
;;   * `treesit-auto-install' 用 'melpa 而非 'prompt（无人值守启动会卡在询问）
;;   * 全局 font-lock level 降为 3，只在少数语言局部提到 4
;;
;;; Code:

(eval-when-compile (require 'treesit-auto))

(use-package treesit-auto
  :demand t
  :custom
  (treesit-auto-install 'melpa)
  (treesit-font-lock-level 3)
  :config
  (global-treesit-auto-mode 1)
  ;; 需要更细粒度高亮的语言单独提高 level
  (dolist (fn '(python-ts-mode-hook java-ts-mode-hook c-ts-mode-hook
                   c++-ts-mode-hook bash-ts-mode-hook))
    (add-hook fn (lambda () (setq-local treesit-font-lock-level 4)))))

(provide 'flywind-treesit)
;;; flywind-treesit.el ends here
