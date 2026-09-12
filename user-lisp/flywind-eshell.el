;;; flywind-eshell.el --- eshell / aweshell -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 使用 manateelazycat/aweshell（git submodule，3rdparty/aweshell）。
;; Emacs 31 兼容：aweshell 仍调用旧命名 `subseq'（Emacs 25 起移除，cl-lib 只提供
;; `cl-subseq'），在加载前做一次条件性别名，避免创建 eshell buffer 时报 void-function。
;;
;;; Code:

(eval-when-compile (require 'aweshell))

(require 'cl-lib)
(unless (fboundp 'subseq)
  (defalias 'subseq #'cl-subseq))

(require 'aweshell)

(provide 'flywind-eshell)
;;; flywind-eshell.el ends here
