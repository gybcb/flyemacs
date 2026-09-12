;;; flywind-ui.el --- 外观与显示 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 帧装饰、行号、字体/主题、括号与空白可视化。
;; Emacs 31 相关修正：
;;   * 废弃的 `window-system' 函数 -> `display-graphic-p'
;;   * 去掉 `:fontset' face 属性与 `create-fontset-from-fontset-spec'（现代 Emacs 无效且重复调用会 error）
;;   * `write-file-functions' -> 内置 `delete-trailing-whitespace-mode'
;;   * whitespace 不再 auto-cleanup（31 起会顺带补 EOF 换行）
;;
;;; Code:

(eval-when-compile
  (require 'volatile-highlights)
  (require 'rainbow-delimiters)
  (require 'doom-themes)
  (require 'doom-modeline))

;; ---------------------------------------------------------------------------
;; 帧装饰
;; ---------------------------------------------------------------------------
(dolist (fn '(tool-bar-mode scroll-bar-mode menu-bar-mode))
  (when (fboundp fn)
    (funcall fn -1)))

(when (display-graphic-p)
  (setq frame-title-format
        '("%S" (buffer-file-name "%f" (dired-directory dired-directory "%b")))))

;; Emacs 31 在兼容终端默认开启 xterm-mouse-mode，这里显式关闭以免干扰 iTerm/tmux 选择。
(when (and (not (display-graphic-p)) (fboundp 'xterm-mouse-mode))
  (xterm-mouse-mode -1))

;; ---------------------------------------------------------------------------
;; 行号 / 列宽
;; ---------------------------------------------------------------------------
(setq-default fill-column 80)
(setq column-number-mode nil)

(defvar flywind-line-numbers-excluded-modes
  '(term-mode shell-mode eshell-mode dired-mode neotree-mode
              special-mode help-mode Custom-mode
              package-menu-mode completion-list-mode bookmark-bmenu-mode
              tabulated-list-mode custom-theme-edit-mode)
  "不显示行号的 major mode。")

(defun flywind--disable-line-numbers ()
  "按 `flywind-line-numbers-excluded-modes' 关闭当前 buffer 的行号。"
  (when (memq major-mode flywind-line-numbers-excluded-modes)
    (display-line-numbers-mode -1)))

(use-package display-line-numbers
  :ensure nil
  :custom
  (display-line-numbers-width 3)
  (display-line-numbers-grow-starting-width t)
  :config
  (global-display-line-numbers-mode 1)
  (add-hook 'after-change-major-mode-hook #'flywind--disable-line-numbers))

(use-package display-fill-column-indicator
  :ensure nil
  :hook (prog-mode . display-fill-column-indicator-mode))

;; tab
(setq-default tab-width 4)

;; ---------------------------------------------------------------------------
;; 主题与 modeline（仅 GUI）
;; ---------------------------------------------------------------------------
(when (display-graphic-p)
  (use-package doom-themes
    :demand t
    :config
    (load-theme 'doom-solarized-dark t))

  ;; org 表格用等宽中文字体对齐；只设一次，不再动态改 fontset。
  (with-eval-after-load 'org
    (set-face-attribute 'org-table nil :font "Sarasa Fixed SC 18"))

  (use-package doom-modeline
    :hook (after-init . doom-modeline-mode)
    :custom
    (doom-modeline-buffer-file-name-style 'relative-from-project)))

;; TTY 下的时间显示
(use-package time
  :ensure nil
  :unless (display-graphic-p)
  :custom
  (display-time-24hr-format t)
  (display-time-day-and-date t)
  :config
  (display-time-mode 1))

;; ---------------------------------------------------------------------------
;; 括号 / 高亮
;; ---------------------------------------------------------------------------
(use-package paren
  :ensure nil
  :custom
  (show-paren-delay 0.1)
  (show-paren-highlight-openparen t)
  (show-paren-when-point-inside-paren t)
  (show-paren-when-point-in-periphery t)
  :config
  (show-paren-mode 1))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package volatile-highlights
  :diminish volatile-highlights-mode
  :config
  (volatile-highlights-mode 1))

(use-package rainbow-mode
  :diminish rainbow-mode
  :hook ((emacs-lisp-mode . rainbow-mode)
         (css-mode . rainbow-mode)))

;; ---------------------------------------------------------------------------
;; 空白可视化（只提示，不改文件）
;; ---------------------------------------------------------------------------
(use-package whitespace
  :ensure nil
  :diminish whitespace-mode
  :hook ((prog-mode conf-mode) . whitespace-mode)
  :config
  ;; 31 起 whitespace-cleanup 会补 EOF 换行，配合 auto-cleanup 会静默改文件，
  ;; 故只做可视化；清理交给 delete-trailing-whitespace-mode。
  (setq whitespace-action nil
        whitespace-line-column fill-column
        whitespace-style '(face trailing space-before-tab
                              indentation empty space-after-tab)))

;; 保存时只删行尾空白（Emacs 31 内置，取代废弃的 write-file-functions）
(use-package simple
  :ensure nil
  :hook (prog-mode . delete-trailing-whitespace-mode))

;; ---------------------------------------------------------------------------
;; 杂项
;; ---------------------------------------------------------------------------
(fset 'yes-or-no-p 'y-or-n-p)
(setq inhibit-startup-screen t)

(provide 'flywind-ui)
;;; flywind-ui.el ends here
