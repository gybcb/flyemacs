;; 编程模式的通用设置

(require 'awesome-pair)

(dolist (hook (list
			   'c-mode-common-hook
			   'c-mode-hook
			   'c++-mode-hook
			   'java-mode-hook
			   'haskell-mode-hook
			   'emacs-lisp-mode-hook
			   'lisp-interaction-mode-hook
			   'lisp-mode-hook
			   'maxima-mode-hook
			   'ielm-mode-hook
			   'sh-mode-hook
			   'makefile-gmake-mode-hook
			   'php-mode-hook
			   'python-mode-hook
			   'js-mode-hook
			   'go-mode-hook
			   'qml-mode-hook
			   'jade-mode-hook
			   'css-mode-hook
			   'ruby-mode-hook
			   'coffee-mode-hook
			   'rust-mode-hook
			   'qmake-mode-hook
			   'lua-mode-hook
			   'swift-mode-hook
			   'minibuffer-inactive-mode-hook
			   ))
  (add-hook hook '(lambda () (awesome-pair-mode 1))))

(define-key awesome-pair-mode-map (kbd "(") 'awesome-pair-open-round)
(define-key awesome-pair-mode-map (kbd "[") 'awesome-pair-open-bracket)
(define-key awesome-pair-mode-map (kbd "{") 'awesome-pair-open-curly)
(define-key awesome-pair-mode-map (kbd ")") 'awesome-pair-close-round)
(define-key awesome-pair-mode-map (kbd "]") 'awesome-pair-close-bracket)
(define-key awesome-pair-mode-map (kbd "}") 'awesome-pair-close-curly)
(define-key awesome-pair-mode-map (kbd "%") 'awesome-pair-match-paren)
(define-key awesome-pair-mode-map (kbd "\"") 'awesome-pair-double-quote)
(define-key awesome-pair-mode-map (kbd "M-o") 'awesome-pair-backward-delete)
(define-key awesome-pair-mode-map (kbd "C-k") 'awesome-pair-kill)
(define-key awesome-pair-mode-map (kbd "M-\"") 'awesome-pair-wrap-double-quote)
(define-key awesome-pair-mode-map (kbd "M-[") 'awesome-pair-wrap-bracket)
(define-key awesome-pair-mode-map (kbd "M-{") 'awesome-pair-wrap-curly)
(define-key awesome-pair-mode-map (kbd "M-(") 'awesome-pair-wrap-round)
(define-key awesome-pair-mode-map (kbd "M-)") 'awesome-pair-unwrap)
(define-key awesome-pair-mode-map (kbd "M-n") 'awesome-pair-jump-right)
(define-key awesome-pair-mode-map (kbd "M-p") 'awesome-pair-jump-left)
(define-key awesome-pair-mode-map (kbd "M-:") 'awesome-pair-jump-out-pair-and-newline)

(use-package yaml-mode
  :init (progn
		  (add-to-list 'auto-mode-alist '("\\.yml\\'" . yaml-mode))
		  )
)

(provide 'flywind-prog)
