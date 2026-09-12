;;; flywind-basic.el --- 基础编辑环境 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 编码、备份/自动保存位置、常用编辑增强。
;; Emacs 31 相关修正：
;;   * `write-file-functions'（24.3 起废弃）-> 内置 `delete-trailing-whitespace-mode'（见 flywind-ui.el）
;;   * 不再从 shell 导入 PYTHONPATH（当前 shell 有激活的 venv，会污染 lsp-bridge/jupyter 解释器）
;;
;;; Code:

(eval-when-compile (require 'hungry-delete)
                 (require 'exec-path-from-shell))

;;;; UTF-8 作为默认编码系统
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))
(prefer-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(setq locale-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8)

;;;; 文件与备份
(setq-default
 abbrev-file-name (expand-file-name "abbrev.el" flywind-local-dir)
 auto-save-list-file-prefix (expand-file-name "autosave/" flywind-cache-dir)
 backup-directory-alist `(("." . ,(expand-file-name "backup/" flywind-cache-dir)))
 make-backup-files nil)            ; 不生成 ~ 备份文件

;;;; 铃声
(setq visible-bell nil
      ring-bell-function #'ignore)

;;;; 环境变量（macOS GUI 启动时从登录 shell 取 PATH）
(when (eq system-type 'darwin)
  (use-package exec-path-from-shell
    :custom
    (exec-path-from-shell-check-startup-files nil)
    (exec-path-from-shell-variables '("PATH" "MANPATH"))
    (exec-path-from-shell-arguments '("-l"))
    :config
    (when (memq window-system '(mac ns x))
      (exec-path-from-shell-initialize))))

;;;; 成对符号
(use-package elec-pair
  :ensure nil
  :custom
  (electric-pair-preserve-balance t)
  (electric-pair-delete-adjacent-pairs t)
  (electric-pair-open-newline-between-pairs t)
  :config
  (electric-pair-mode 1))

;;;; 最近文件
(use-package recentf
  :ensure nil
  :custom
  (recentf-max-saved-items 200)
  (recentf-save-file (expand-file-name "recentf" flywind-cache-dir))
  :config
  (recentf-mode 1)
  (add-to-list 'recentf-exclude (expand-file-name package-user-dir))
  (add-to-list 'recentf-exclude "bookmarks")
  (add-to-list 'recentf-exclude "COMMIT_EDITMSG\\'"))

;;;; 删除增强
(use-package hungry-delete
  :config
  (global-hungry-delete-mode 1))

;;;; 注释
(global-set-key (kbd "C-c C-g") #'comment-or-uncomment-region)

(provide 'flywind-basic)
;;; flywind-basic.el ends here
