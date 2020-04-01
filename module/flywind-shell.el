(eval-when-compile
  (require 'flywind-const))

(use-package shell
  :ensure nil
  :commands comint-send-string comint-simple-send comint-strip-ctrl-m
  :preface
  (defun n-shell-simple-send (proc command)
	"Various PROC COMMANDs pre-processing before sending to shell."
	(cond
	 ;; Checking for clear command and execute it.
	 ((string-match "^[ \t]*clear[ \t]*$" command)
	  (comint-send-string proc "\n")
	  (erase-buffer))
	 ;; Checking for man command and execute it.
	 ((string-match "^[ \t]*man[ \t]*" command)
	  (comint-send-string proc "\n")
	  (setq command (replace-regexp-in-string "^[ \t]*man[ \t]*" "" command))
	  (setq command (replace-regexp-in-string "[ \t]+$" "" command))
	  ;;(message (format "command %s command" command))
	  (funcall 'man command))
	 ;; Send other commands to the default handler.
	 (t (comint-simple-send proc command))))
  (defun n-shell-mode-hook ()
	"Shell mode customizations."
	(local-set-key '[up] 'comint-previous-input)
	(local-set-key '[down] 'comint-next-input)
	(local-set-key '[(shift tab)] 'comint-next-matching-input-from-input)
	(setq comint-input-sender 'n-shell-simple-send))
  :hook ((shell-mode . ansi-color-for-comint-mode-on)
		 (shell-mode . n-shell-mode-hook))
  :config
  (setq system-uses-terminfo nil)       ; don't use system term info

  (add-hook 'comint-output-filter-functions #'comint-strip-ctrl-m)

  ;; ANSI & XTERM 256 color support
  (use-package xterm-color
	:defines compilation-environment
	:init
	(setenv "TERM" "xterm-256color")
	(setq comint-output-filter-functions
		  (remove 'ansi-color-process-output comint-output-filter-functions))

	(add-hook 'shell-mode-hook
			  (lambda () (add-hook 'comint-preoutput-filter-functions 'xterm-color-filter nil t)))))

;; Multi term
(use-package multi-term
  :config
  (setq multi-term-program "/bin/zsh")
  )

;; Shell Pop
(use-package shell-pop
  :bind ([f9] . shell-pop)
  :init (let ((val
			   (if sys/win32p
				   '("eshell" "*eshell*" (lambda () (eshell)))
				 '("ansi-term" "*ansi-term*"
				   (lambda () (ansi-term shell-pop-term-shell))))))
		  (setq shell-pop-shell-type val)))

(provide 'flywind-shell)
