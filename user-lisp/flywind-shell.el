;;; flywind-shell.el --- shell / terminal -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; ANSI 着色统一交给 xterm-color（因此从 comint-output-filter-functions
;; 里移除一次 ansi-color-process-output，避免双重处理）。
;;
;;; Code:

(eval-when-compile
  (require 'shell-pop)
  (require 'xterm-color)
  (require 'multi-term))

(require 'flywind-const)

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
    (setq-local comint-input-sender #'flywind-shell-simple-send))
  :hook ((shell-mode . ansi-color-for-comint-mode-on)
         (shell-mode . flywind-shell-mode-hook))
  :config
  (setq system-uses-terminfo nil)
  (add-hook 'comint-output-filter-functions #'comint-strip-ctrl-m)

  ;; ANSI / 256 色
  (use-package xterm-color
    :init
    (setenv "TERM" "xterm-256color")
    (setq comint-output-filter-functions
          (remq 'ansi-color-process-output comint-output-filter-functions))
    (add-hook 'shell-mode-hook
              (lambda ()
                (add-hook 'comint-preoutput-filter-functions
                          #'xterm-color-filter nil t)))))

(use-package multi-term
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
        (if sys/win32p
            '("eshell" "*eshell*" (lambda () (eshell)))
          '("ansi-term" "*ansi-term*"
            (lambda () (ansi-term shell-pop-term-shell))))))

(provide 'flywind-shell)
;;; flywind-shell.el ends here
