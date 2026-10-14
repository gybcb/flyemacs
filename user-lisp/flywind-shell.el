;;; flywind-shell.el --- shell / terminal -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; ANSI 着色统一交给 xterm-color（因此从 comint-output-filter-functions
;; 里移除一次 ansi-color-process-output，避免双重处理）。
;; 启动成本：eat / shell-pop / xterm-color 都靠 autoload/:bind/:custom 懒加载，
;; require 本模块只是设几个变量。
;; 终端选型：不装 multi-term（没人调它）；选 eat 不选 vterm：eat 是纯 Elisp
;; 终端仿真（自带 term/eat.el，不依赖 libvterm/编译链），macOS 与 neomacs
;; 两侧都装完即用；vterm 需要 cmake + libvterm + 动态模块 API，本机跑不起来。
;; 重输出场景（MB 级刷屏）vterm 更快，真有需要时再加，两者不互斥。
;; 平台判断就地写 `system-type'，不再有个 flywind-const 模块。
;;
;;; Code:

(eval-when-compile
  (require 'shell-pop)
  (require 'xterm-color)
  (require 'eat))

(defgroup flywind-shell nil
  "shell / terminal。"
  :group 'convenience
  :prefix "flywind-shell-")

(defcustom flywind-shell-pop-shell-type "ansi-term"
  "F9 底部弹层用的终端类型（`shell-pop-shell-type' 的开关）。
只接两个预设：
  \"ansi-term\" = 内置 term.el，默认；
  \"eat\"       = 纯 Elisp 终端仿真，char mode / shell 集成更好。
Windows 下无视本变量，固定 eshell（沿用原行为）。
改了本变量要重开 F9 弹层才生效。eat 直接 `M-x eat' 时走普通 buffer（可
C-x 1 顶满）；F9 那条才由 shell-pop 弹底部窗。"
  :type '(choice (const :tag "ansi-term（内置，默认）" "ansi-term")
                 (const :tag "eat（纯 Elisp 终端）" "eat"))
  :group 'flywind-shell)

(defun flywind-shell--pop-shell-type ()
  "按 `flywind-shell-pop-shell-type' 给出 `shell-pop-shell-type' 的值。
eat 那条与 shell-pop 自带预设同形（带 fboundp 守卫，不硬依赖）；
shell-pop 升过预设里的 (eat shell-pop-term-shell)，这里沿用。"
  (cond
   ((eq system-type 'windows-nt)
    '("eshell" "*eshell*" (lambda () (eshell))))
   ((equal flywind-shell-pop-shell-type "eat")
    '("eat" "*eat*"
      (lambda ()
        (when (fboundp 'eat)
          (eat shell-pop-term-shell)))))
   (t
    '("ansi-term" "*ansi-term*"
      (lambda () (ansi-term shell-pop-term-shell))))))

(use-package shell
  :ensure nil
  :commands comint-send-string comint-simple-send comint-strip-ctrl-m
  :preface
  (defun flywind-shell-simple-send (proc command)
    "对 PROC 的 COMMAND 做预处理后再发送。"
    (cond
     ;; clear：清屏
     ((string-match "^[ \t]*clear[ \t]*$" command)
      (comint-send-string proc "\n")
      (erase-buffer))
     ;; man：用 Emacs 的 man 模式
     ((string-match "^[ \t]*man[ \t]*" command)
      (comint-send-string proc "\n")
      (funcall #'man (string-trim-right (string-remove-prefix "man" (string-trim command)))))
     ;; 其它原样发送
     (t (comint-simple-send proc command))))
  (defun flywind-shell-mode-hook ()
    "shell-mode 自定义。"
    (local-set-key [up] #'comint-previous-input)
    (local-set-key [down] #'comint-next-input)
    (local-set-key [S-tab] #'comint-next-matching-input-from-input)
    (setq-local comint-input-sender #'flywind-shell-simple-send)
    ;; TERM 与着色过滤都在进 shell buffer 时才动，不占启动时间；
    ;; xterm-color 没有 autoload，到这里才 require。 只挂 preoutput（逐 buffer），
    ;; 不要再生到全局 comint-output-filter-functions 里去，否则双重着色。
    (require 'xterm-color)
    (setenv "TERM" "xterm-256color")
    (add-hook 'comint-preoutput-filter-functions #'xterm-color-filter nil t))
  :hook ((shell-mode . ansi-color-for-comint-mode-on)
         (shell-mode . flywind-shell-mode-hook))
  :config
  (setq system-uses-terminfo nil)
  (add-hook 'comint-output-filter-functions #'comint-strip-ctrl-m)
  ;; 内置 ansi-color 不再处理输出：着色由上面 preoutput 里的 xterm-color 负责。
  (setq comint-output-filter-functions
        (remq 'ansi-color-process-output comint-output-filter-functions)))

(use-package shell-pop
  :bind ([f9] . shell-pop)
  :custom
  (shell-pop-term-shell "/bin/zsh")
  (shell-pop-window-size 30)
  (shell-pop-window-position "bottom")
  :init
  (setq shell-pop-shell-type (flywind-shell--pop-shell-type)))

;;;; eat：纯 Elisp 终端仿真（M-x eat 直接开；F9 走上面 shell-pop 那条）
(use-package eat
  :defer t
  :custom
  ;; 默认 128K 字符；配置文件编辑器场景下终端主要敲命令，留默认就够，
  ;; 这里显式写出以免升级时丢参考。
  (eat-term-scrollback-size 131072))

(provide 'flywind-shell)
;;; flywind-shell.el ends here
