;;; flywind-dired.el --- Dired 配置 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 启动成本：dired 是内置包，但 diredfl / dired-rainbow / dired-rsync 都不在启动期
;; 加载 —— diredfl 按 buffer 挂在 dired-mode-hook 上，dired-rainbow 与 dired-rsync
;; 等 dired 第一次被加载之后才动（前者只在宏展开里调 font-lock-add-keywords，
;; 后者靠 autoload）。
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
  ;; `dired-rainbow-define' / `-define-chmod' 是宏：展开期要读 dired-hacks-utils 的
  ;; 变量，而且展开结果里有 `(push ... dired-rainbow-ext-to-face)'。 编译期不
  ;; require 就会把它们编成普通函数调用，运行时报 void-variable。
  (require 'dired-rainbow))

(use-package dired
  :ensure nil
  ;; dired 自身有 autoload（C-x d）；这里必须 :defer：use-package 只要碰到
  ;; `:bind (:map dired-mode-map ...)' 就会为了拿到 keymap 直接 require dired，
  ;; 启动期就多了 dired + dired-x + dired-rainbow 一串。 键位改到下面
  ;; with-eval-after-load 里做。
  :defer t
  :custom
  (dired-recursive-deletes 'always)
  (dired-recursive-copies 'always)
  (dired-dwim-target t)
  (global-auto-revert-non-file-buffers t)
  (auto-revert-verbose nil)
  ;; macOS 的 ls 不支持 --dired；有 coreutils 的 gls 就用它
  (dired-use-ls-dired (if (executable-find "gls") t (not (eq system-type 'darwin))))
  (insert-directory-program (or (executable-find "gls")
                                (executable-find "ls")
                                "ls"))
  (dired-listing-switches "-alh --group-directories-first")
  ;; Emacs 31：文件名含换行时用 -b 显示为 \n，避免 Dired 操作出错
  (dired-auto-toggle-b-switch t)
  :config
  (put 'dired-find-alternate-file 'disabled nil))

(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c C-p") #'wdired-change-to-wdired-mode)
  ;; 不包 with-no-warnings 会报 “dired-sort-toggle-or-edit might not be defined at
  ;; runtime”，但那是文件头 eval-when-compile (require (quote dired)) 带来的：函数
  ;; 只在编译期那个 session 里认识，编译器不敢保证运行时也有。实测只 (require
  ;; (quote dired)) 之后它就 fboundp（要么就真是 autoload 件，两者运行时都能用），
  ;; 而这里整块跑在 dired 加载之后，所以告警是假报。
  (with-no-warnings
    (define-key dired-mode-map (kbd "S") #'dired-sort-toggle-or-edit)))

;;;; 着色（都不在启动期加载）
(use-package diredfl
  :hook (dired-mode . diredfl-mode))

(use-package dired-rainbow
  ;; `dired-rainbow-define' 是宏，只能在包加载后调用（:init 早于 require，
  ;; 会被当成普通函数求值而报 void-function）。 这里用 :after dired，让这十几组
  ;; font-lock 关键词等到第一次用 dired 时才注册。
  :after dired
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
  ;; 不套 quote：宏直接把 face-props 呮给 defface，多一层 quote 会让 Emacs 报
  ;; “Non-keyword in face attribute list: 'quote” 且样式失效。
  (dired-rainbow-define log (:inherit default :italic t) ".*\\.log")
  (dired-rainbow-define-chmod executable-unix "green" "-[rw-]+x.*"))

(use-package dired-rsync
  :defer t
  :bind (:map dired-mode-map
              ("C-c C-r" . dired-rsync)))

;;;; 附加功能
(use-package dired-aux :ensure nil :defer t)

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
  ;; @eaDir 是群晖等设备生成的缩略图目录，跟 .DS_Store 一样该藏掉。
  ;; 这条原本在 2022-02-28 那笔（另一台机器）里，合并时结转过来。
  (setq dired-omit-files
        (concat dired-omit-files
                "\\|^.DS_Store$\\|^.projectile$\\|^\\.git$\\|^.svn$\\|^.vscode$\\|\\.js\\.meta$\\|\\.meta$\\|\\.elc$\\|^.emacs.*\\|@eaDir$"))
  :bind (:map dired-mode-map
              ("C-h" . dired-omit-mode)))

(provide 'flywind-dired)
;;; flywind-dired.el ends here
