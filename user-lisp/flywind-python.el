;;; flywind-python.el --- Python -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Emacs 31 相关修正：
;;   * 移除 ein（上游停更；依赖 polymode/zmq/simple-httpd 等，与新版 Emacs 冲突面最大）
;;   * 保留 jupyter（org 内嵌 python 代码块仍走 jupyter kernel）
;;   * `python-indent' / `default-tab-width' 不是有效变量，删除
;;
;;; Code:

(eval-when-compile (require 'ob-jupyter))

(use-package jupyter
  :config
  ;; `org-babel-jupyter-override-src-block' 定义在 ob-jupyter.el，且没有 autoload。
  (require 'ob-jupyter)
  (org-babel-jupyter-override-src-block "python"))

(defun flywind-python-mode-config ()
  "Python buffer 的基础设置。"
  (setq-local python-indent-offset 4)
  (setq-local indent-tabs-mode nil))

(add-hook 'python-mode-hook #'flywind-python-mode-config)
(add-hook 'python-ts-mode-hook #'flywind-python-mode-config)

(provide 'flywind-python)
;;; flywind-python.el ends here
