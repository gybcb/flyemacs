;;; flywind-window.el --- 窗口与弹出布局 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 用 Emacs 原生 display-buffer-alist 取代 popwin（popwin 依赖旧的
;; display-buffer 语义，在 Emacs 30/31 的 quit-restore/side-window 重构下不可靠）。
;; 同时抵消 Emacs 31 的几个新默认值，保持既有手感：
;;   split-window-preferred-direction 'vertical（31 默认 longest）
;;   split-width-threshold 160（31 默认 150）
;;
;;; Code:

(eval-when-compile
  (require 'windmove)
  (require 'ace-window)
  (require 'zoom-window)
  (require 'eyebrowse)
  ;; `transpose-dedicated-windows' 定义在 window-x.el，编译期不可见
  (defvar transpose-dedicated-windows))

;; ---------------------------------------------------------------------------
;; 31 新默认的兼容开关
;; ---------------------------------------------------------------------------
(setq split-window-preferred-direction 'vertical
      split-width-threshold 160
      split-height-threshold 0
      transpose-dedicated-windows nil
      quit-window-kill-buffer nil
      kill-buffer-quit-windows nil
      windmove-allow-repeated-command-override nil
      help-window-select t)

;; ---------------------------------------------------------------------------
;; 弹出窗口布局（原 popwin:special-display-config 的等价物）
;; ---------------------------------------------------------------------------
(defvar flywind-bottom-buffer-names
  '("*compilation*" "*Compile-Log*" "*Warnings*" "*Completions*"
    "*Shell Command Output*" "*grep*" "*Occur*" "*xref*" "*rg*"
    "*ert*" "*nosetests*" "*vc-diff*" "*vc-change-log*" "*Package List*")
  "以底部 side window 展示的只读/输出类 buffer。")

(defvar flywind-bottom-interactive-buffer-names
  '("*shell*" "*eshell*" "*Python*" "*term*" "*ansi-term*")
  "以底部 side window 展示、但允许切进去输入的交互类 buffer。
这些不设置 `no-other-window'，否则 `C-x o' 无法进入。")

(defvar flywind-right-buffer-names
  '("*undo-tree*")
  "以右侧专用 side window 展示的 buffer 名。")

(defun flywind--buffer-name-regexp (names)
  "把 buffer 名列表 NAMES 编成锚定的正则。"
  (concat "\\`" (regexp-opt names 'tags) "\\'"))

(defun flywind--side-window-config (side slot size-param size &optional reusable)
  "构造 side window 的 display-buffer 参数。
SIDE / SLOT / SIZE-PARAM / SIZE 含义见 `display-buffer-in-side-window'。
REUSABLE 非 nil 时不设 `dedicated'、也不隐藏 mode-line（交互 buffer 要能切进去）。"
  (let ((params (list (cons 'side side)
                      (cons 'slot slot)
                      (cons size-param size))))
    (unless reusable
      (setq params
            (append params
                    (list '(dedicated . t)
                          (cons 'window-parameters
                                '((no-other-window . t)
                                  (mode-line-format . none)))))))
    (cons #'display-buffer-in-side-window params)))

(setq display-buffer-alist
      (append
       (list
        (cons (flywind--buffer-name-regexp flywind-bottom-buffer-names)
              (flywind--side-window-config 'bottom -1 'window-height 0.35))
        ;; multi-term 的 buffer 名是 *terminal@host-N*，一并归到可交互的底部窗
        (cons (concat (flywind--buffer-name-regexp flywind-bottom-interactive-buffer-names)
                      "\\|\\`\\*terminal")
              (flywind--side-window-config 'bottom -1 'window-height 0.35 t))
        (cons (flywind--buffer-name-regexp flywind-right-buffer-names)
              (flywind--side-window-config 'right -1 'window-width 0.3))
        ;; 只读提示类：更矮一些
        (cons "\\`\\*\\(?:Help\\|Buffer List\\|WoMan.*\\)\\*\\'"
              (flywind--side-window-config 'bottom -1 'window-height 0.25)))
       display-buffer-alist))

;; ---------------------------------------------------------------------------
;; 窗口导航 / 布局管理
;; ---------------------------------------------------------------------------
(use-package windmove
  :ensure nil
  :demand t
  :config
  (windmove-default-keybindings))

(use-package winner
  :ensure nil
  :demand t
  :config
  (winner-mode 1))

;; 快速选窗（数字选择，取代原 window-numbering 的编号显示）
(use-package ace-window
  :bind ("C-x o" . ace-window)
  :custom
  (aw-keys '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9))
  (aw-disallow-alternate-window t)
  :config
  (ace-window-display-mode 1))

;; tmux 式窗口缩放
(use-package zoom-window
  :bind ("C-x C-z" . zoom-window-zoom)
  :custom
  (zoom-window-mode-line-color "DarkGreen")
  (zoom-window-use-quiet-exit t)
  :config
  (zoom-window-setup))

;; 工作区（多个窗口布局）
(use-package eyebrowse
  :demand t
  :custom
  (eyebrowse-wrap-around t)
  :config
  (eyebrowse-mode 1))

(provide 'flywind-window)
;;; flywind-window.el ends here
