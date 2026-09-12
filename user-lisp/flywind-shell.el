;;; flywind-shell.el --- shell / terminal -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; ANSI 着色统一交给 xterm-color（因此从 comint-output-filter-functions
;; 里移除一次 ansi-color-process-output，避免双重处理）。
;; 启动成本：multi-term / shell-pop / xterm-color 都靠 :bind/:custom 懒加载，
;; require 本模块只是设几个变量。
;; 平台判断就地写 `system-type'，不再有个 flywind-const 模块。
;;
;;; Code:

(eval-when-compile
  (require 'shell-pop)
  (require 'xterm-color)
  (require 'multi-term))

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

(use-package multi-term
  ;; multi-term 没有 autoload，而只有 :custom 的 use-package 形式会直接 require。
  ;; 它只在 shell-pop 拉 ANSI term 时才用得上，所以显式延后。
  :defer t
  :custom
  (multi-term-program "/bin/zsh"))

(use-package shell-pop
  :bind ([f9] . shell-pop)
  :custom
  (shell-pop-term-shell "/bin/zsh")
  (shell-pop-window-size 30)
  (shell-pop-window-position "bottom")
  :init
  (setq shell-pop-shell-type
        (if (eq system-type 'windows-nt)
            '("eshell" "*eshell*" (lambda () (eshell)))
          '("ansi-term" "*ansi-term*"
            (lambda () (ansi-term shell-pop-term-shell))))))

(provide 'flywind-shell)
;;; flywind-shell.el ends here
