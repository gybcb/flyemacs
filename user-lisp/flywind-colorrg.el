;;; flywind-colorrg.el --- 搜索 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; manateelazycat/color-rg（git submodule，3rdparty/color-rg）。
;; 依赖外部 rg 或 ag；两者都没有时不加载。
;;
;;; Code:

(eval-when-compile (require 'color-rg))

(when (or (executable-find "rg") (executable-find "ag"))
  (require 'color-rg)
  (global-set-key (kbd "C-S-f") #'color-rg-search-input))

(provide 'flywind-colorrg)
;;; flywind-colorrg.el ends here
