;;; flywind-dired.el --- Dired 配置 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Emacs 31 相关修正：
;;   * 去掉 `ls-lisp-use-insert-directory-program'（insert-directory-program 已是 gls，走外部 ls）
;;   * 移除 dired-quick-sort（MELPA 已 orphan、依赖 hydra、且从未安装成功），
;;     S 改绑 Emacs 内置 `dired-sort-toggle-or-edit'
;;   * 顺带适配 31 的 ls 错误处理与 -b 开关相关选项
;;
;;; Code:

(eval-when-compile
  (require 'dired)
  (require 'dired-x)
  (require 'diredfl)
  (require 'dired-rainbow)
  (require 'dired-rsync))

(require 'flywind-const)

(use-package dired
  :ensure nil
  :bind (:map dired-mode-map
              ("C-c C-p" . wdired-change-to-wdired-mode)
              ("S" . dired-sort-toggle-or-edit))
  :custom
  (dired-recursive-deletes 'always)
  (dired-recursive-copies 'always)
  (dired-dwim-target t)
  (global-auto-revert-non-file-buffers t)
  (auto-revert-verbose nil)
  ;; macOS 的 ls 不支持 --dired；有 coreutils 的 gls 就用它
  (dired-use-ls-dired (if (executable-find "gls") t (not sys/macp)))
  (insert-directory-program (or (executable-find "gls")
                                (executable-find "ls")
                                "ls"))
  (dired-listing-switches "-alh --group-directories-first")
  ;; Emacs 31：文件名含换行时用 -b 显示为 \n，避免 Dired 操作出错
  (dired-auto-toggle-b-switch t)
  :config
  (put 'dired-find-alternate-file 'disabled nil))

;; 彩色/分类着色
(use-package diredfl
  :config
  (diredfl-global-mode 1))

(use-package dired-rainbow
  ;; 注：`dired-rainbow-define' 是宏，只能在包加载后调用（:init 早于 require，
  ;; 会被当成普通函数求值而报 void-variable / void-function）。
  :config
  (dired-rainbow-define dotfiles "gray" "\\..*")
  (dired-rainbow-define web "#4e9a06"
    ("htm" "html" "xhtml" "xml" "xaml" "css" "js" "json" "asp" "aspx" "haml"
     "php" "jsp" "ts" "coffee" "scss" "less" "phtml"))
  (dired-rainbow-define prog "yellow3"
    ("el" "l" "ml" "py" "rb" "pl" "pm" "c" "cpp" "cxx" "c++" "h" "hpp" "hxx"
     "h++" "m" "cs" "mk" "make" "swift" "go" "java" "asm" "robot" "yml" "yaml"
     "rake" "lua"))
  (dired-rainbow-define sh "green yellow"
    ("sh" "bash" "zsh" "fish" "csh" "ksh" "awk" "ps1" "psm1" "psd1" "bat" "cmd"))
  (dired-rainbow-define text "yellow green"
    ("txt" "md" "org" "ini" "conf" "rc" "vim" "vimrc" "exrc"))
  (dired-rainbow-define doc "spring green"
    ("doc" "docx" "ppt" "pptx" "xls" "xlsx" "csv" "rtf" "wps" "pdf" "texi"
     "tex" "odt" "ott" "odp" "otp" "ods" "ots" "odg" "otg"))
  (dired-rainbow-define misc "gray50"
    ("DS_Store" "projectile" "cache" "elc" "dat" "meta"))
  (dired-rainbow-define media "#ce5c00"
    ("mp3" "mp4" "MP3" "MP4" "wav" "wma" "wmv" "mov" "3gp" "avi" "mpg" "mkv"
     "flv" "ogg" "rm" "rmvb"))
  (dired-rainbow-define picture "purple3"
    ("bmp" "jpg" "jpeg" "gif" "png" "tiff" "ico" "svg" "psd" "pcd" "raw" "exif"
     "BMP" "JPG" "PNG"))
  (dired-rainbow-define archive "saddle brown"
    ("zip" "tar" "gz" "tgz" "7z" "rar" "gzip" "xz" "001" "ace" "bz2" "lz"
     "lzma" "bzip2" "cab" "jar" "iso"))
  (dired-rainbow-define log '(:inherit default :italic t) ".*\\.log")
  (dired-rainbow-define-chmod executable-unix "green" "-[rw-]+x.*"))

;; rsync
(use-package dired-rsync
  :bind (:map dired-mode-map
              ("C-c C-r" . dired-rsync)))

;; 附加功能
(use-package dired-aux :ensure nil)

(use-package dired-x
  :ensure nil
  :after dired
  :config
  (when (display-graphic-p)
    (setq dired-guess-shell-alist-user
          '(("\\.pdf\\'" "open")
            ("\\.docx\\'" "open")
            ("\\.\\(?:djvu\\|eps\\)\\'" "open")
            ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\)\\'" "open")
            ("\\.\\(?:xcf\\)\\'" "open")
            ("\\.csv\\'" "open")
            ("\\.tex\\'" "open")
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'"
             "open")
            ("\\.\\(?:mp3\\|flac\\)\\'" "open")
            ("\\.html?\\'" "open")
            ("\\.md\\'" "open"))))
  (setq dired-omit-files
        (concat dired-omit-files
                "\\|^.DS_Store$\\|^.projectile$\\|^\\.git$\\|^.svn$\\|^.vscode$\\|\\.js\\.meta$\\|\\.meta$\\|\\.elc$\\|^.emacs.*"))
  :bind (:map dired-mode-map
              ("C-h" . dired-omit-mode)))

(provide 'flywind-dired)
;;; flywind-dired.el ends here
