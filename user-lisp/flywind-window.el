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
    "*ert*" "*vc-diff*" "*vc-change-log*" "*Package List*"
    "*flywind-check-config*")
  "以底部 side window 展示的只读/输出类 buffer。")

(defvar flywind-bottom-interactive-buffer-names
  '("*shell*" "*eshell*" "*term*" "*ansi-term*" "*terminal*")
  "以底部 side window 展示、但允许切进去输入的交互类 buffer。
这些不设置 `no-other-window'，否则 `C-x o' 无法进入。")

(defvar flywind-right-buffer-names nil
  "以右侧专用 side window 展示的 buffer 名。
原配置这里只有 *undo-tree*，而 undo-tree 从没装过：空表比留一个不存在的
buffer 名好。 `display-buffer-alist' 的构造对空表就是不生成条目。")

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
       ;; 空名单直接不生成条目：`regexp-opt' 对空表返回的不是“永不匹配”，
       ;; 把它拼成 buffer 名正则会把不相干的 buffer 吸进 side window。
       (delq nil
             (list
              (cons (flywind--buffer-name-regexp flywind-bottom-buffer-names)
                    (flywind--side-window-config 'bottom -1 'window-height 0.35))
              ;; multi-term 的 buffer 名是 *terminal@host-N*，一并归到可交互的底部窗
              (cons (concat (flywind--buffer-name-regexp flywind-bottom-interactive-buffer-names)
                            "\\|\\`\\*terminal")
                    (flywind--side-window-config 'bottom -1 'window-height 0.35 t))
              (when flywind-right-buffer-names
                (cons (flywind--buffer-name-regexp flywind-right-buffer-names)
                      (flywind--side-window-config 'right -1 'window-width 0.3)))
              ;; 只读提示类：更矮一些
              (cons "\\`\\*\\(?:Help\\|Buffer List\\)\\*\\'"
                    (flywind--side-window-config 'bottom -1 'window-height 0.25))))
       display-buffer-alist))

;; ---------------------------------------------------------------------------
;; 窗口导航 / 布局管理
;;
;; 不引入 ace-window： Emacs 31 内置的 windmove 已覆盖选窗 / 交换 / 关闭 /
;; 指定方向展示，绑在同一个 `C-x' 前缀下，没编号直选（失去 ace-window 的
;; “按数字跳到第 N 个窗口”，换来少两个包：ace-window + avy）。
;;   S-<方向>       选窗口            （windmove）
;;   C-x o / C-x O  循环下一个 / 上一个   （内置 other-window / other-window-backward）
;;   C-x S-<方向>   与那边窗口交换 buffer
;;   C-x M-<方向>   关闭那边窗口
;;   C-x 4 <方向>   在那边窗口显示下一个命令的 buffer
;; ---------------------------------------------------------------------------
(use-package windmove
  :ensure nil
  :demand t
  :bind
  (("<S-left>"  . windmove-left)
   ("<S-right>" . windmove-right)
   ("<S-up>"    . windmove-up)
   ("<S-down>"  . windmove-down)
   ("C-x <S-left>"  . windmove-swap-states-left)
   ("C-x <S-right>" . windmove-swap-states-right)
   ("C-x <S-up>"    . windmove-swap-states-up)
   ("C-x <S-down>"  . windmove-swap-states-down)
   ("C-x <M-left>"  . windmove-delete-left)
   ("C-x <M-right>" . windmove-delete-right)
   ("C-x <M-up>"    . windmove-delete-up)
   ("C-x <M-down>"  . windmove-delete-down)
   ("C-x 4 <left>"  . windmove-display-left)
   ("C-x 4 <right>" . windmove-display-right)
   ("C-x 4 <up>"    . windmove-display-up)
   ("C-x 4 <down>"  . windmove-display-down)
   ("C-x 4 0"       . windmove-display-same-window)))

(use-package winner
  :ensure nil
  :demand t
  :config
  (winner-mode 1))

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
