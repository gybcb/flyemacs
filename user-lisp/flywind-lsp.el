;;; flywind-lsp.el --- lsp-bridge -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 使用 manateelazycat/lsp-bridge（git submodule，3rdparty/lsp-bridge）。
;; Emacs 31 相关处理：
;;   * Python 解释器固定为专用 venv（.local/etc/lsp-bridge-venv，Python 3.13），
;;     不受 shell 里激活的 venv / Homebrew python3.14 影响（lsp-bridge 要求 >=3.13,<3.14）
;;   * lsp buffer 内关闭 company（上游 README 明确要求 lsp-bridge 不与 company 并存）
;;   * 解释器/依赖不可用时只 warn，不阻塞启动
;;
;;; Code:

(eval-when-compile
  (require 'yasnippet)
  (require 'lsp-bridge))

;;;; 代码片段
(use-package yasnippet
  :demand t
  :diminish yas-minor-mode
  :config
  (yas-global-mode 1))

;;;; lsp-bridge
(defvar flywind-lsp-bridge-python-candidates
  (list (expand-file-name "etc/lsp-bridge-venv/bin/python3" flywind-local-dir)
        "/opt/homebrew/bin/python3" "/usr/local/bin/python3" "/usr/bin/python3")
  "lsp-bridge 使用的 python3 候选（按顺序取第一个存在的）。")

(defun flywind-lsp-bridge-python-command ()
  "返回可用的 python3 绝对路径，找不到返回 nil。"
  (seq-find #'file-executable-p flywind-lsp-bridge-python-candidates))

(defun flywind-lsp-bridge-available-p ()
  "lsp-bridge 的 elisp 与 python 端是否都可用。"
  (and (locate-library "lsp-bridge")
       (flywind-lsp-bridge-python-command)))

(defun flywind--lsp-buffer-disable-company ()
  "lsp-bridge 接管的 buffer 内关闭 company（补全交给 acm）。"
  (when (fboundp 'company-mode)
    (company-mode -1)))

(if (not (flywind-lsp-bridge-available-p))
    (warn "lsp-bridge 不可用（缺少 elisp 文件或 python3）：已跳过 global-lsp-bridge-mode")
  (require 'lsp-bridge)

  (setq lsp-bridge-python-command (flywind-lsp-bridge-python-command))

  ;; 本机只有 pyright（无 basedpyright/ruff）
  (setq lsp-bridge-python-lsp-server "pyright"
        lsp-bridge-python-multi-lsp-server "pyright")

  (add-hook 'lsp-bridge-mode-on-hook #'flywind--lsp-buffer-disable-company)

  ;; 新 version 的上游若提供 company 互斥开关，可在此替换上面的 hook。
  ;; 注意：新版 `global-lsp-bridge-mode' 是无参函数（不是 globalized minor mode），
  ;; 带参调用会报 wrong-number-of-arguments。
  (global-lsp-bridge-mode)

  (use-package lsp-bridge-jdtls :ensure nil :after lsp-bridge))

(provide 'flywind-lsp)
;;; flywind-lsp.el ends here
