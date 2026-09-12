;;; flywind-neotree.el --- 文件树 -*- lexical-binding: t; -*-

;;; Code:

(eval-when-compile
  (require 'neotree)
  (require 'winner))

(use-package neotree
  :diminish (neotree-mode)
  :commands neotree-show neotree-hide neotree-toggle neotree-dir neotree-find
  :bind ("<f8>" . neotree-toggle)
  :custom
  (neo-create-file-auto-open nil)
  (neo-auto-indent-point nil)
  (neo-autorefresh nil)
  (neo-mode-line-type 'none)
  (neo-window-width 25)
  (neo-show-updir-line nil)
  (neo-theme 'nerd)
  (neo-banner-message nil)
  (neo-confirm-create-file #'off-p)
  (neo-confirm-create-directory #'off-p)
  (neo-show-hidden-files nil)
  (neo-keymap-style 'concise)
  (neo-hidden-regexp-list
   '(;; vcs folders
     "^\\.\\(git\\|hg\\|svn\\)$"
     ;; compiled files
     "\\.\\(pyc\\|o\\|elc\\|lock\\|css.map\\)$"
     ;; generated files, caches or local pkgs
     "^\\(node_modules\\|vendor\\|.\\(project\\|cask\\|yardoc\\|sass-cache\\)\\)$"
     ;; org-mode folders
     "^\\.\\(sync\\|export\\|attach\\)$"
     "~$"
     "^#.*#$"))
  :config
  ;; 图标主题需要 nerd-icons
  (require 'nerd-icons)
  ;; winner 恢复窗口时忽略 neotree 的侧边 buffer
  (with-eval-after-load 'winner
    (add-to-list 'winner-boring-buffers neo-buffer-name)))

(provide 'flywind-neotree)
;;; flywind-neotree.el ends here
