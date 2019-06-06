(eval-when-compile
  (require 'flywind-const))

;; Directory operations
(use-package dired
  :ensure nil
  :bind (:map dired-mode-map
			  ("C-c C-p" . wdired-change-to-wdired-mode))
  :config
  ;; Always delete and copy recursively
  (setq dired-recursive-deletes 'always)
  (setq dired-recursive-copies 'always)

  (when sys/macp
	;; Suppress the warning: `ls does not support --dired'.
	(setq dired-use-ls-dired nil)

	(when (executable-find "gls")
	  ;; Use GNU ls as `gls' from `coreutils' if available.
	  (setq insert-directory-program "gls")))

  (when (or (and sys/macp (executable-find "gls"))
			(and (not sys/macp) (executable-find "ls")))
	;; Using `insert-directory-program'
	(setq ls-lisp-use-insert-directory-program t)

	;; Show directory first
	(setq dired-listing-switches "-alh --group-directories-first")

	;; Quick sort dired buffers via hydra
	(use-package dired-quick-sort
	  :bind (:map dired-mode-map
				  ("S" . hydra-dired-quick-sort/body))))

  ;; Allow rsync from dired buffers
  (use-package dired-rsync
	:bind (:map dired-mode-map
				("C-c C-r" . dired-rsync)))

  ;; Colourful dired
  (use-package diredfl
	:init (diredfl-global-mode 1))

  ;; Shows icons
  ;; (use-package all-the-icons-dired
  ;;	:diminish
  ;;	:custom-face (all-the-icons-dired-dir-face ((t (:foreground nil))))
  ;;	:hook (dired-mode . all-the-icons-dired-mode)
  ;;	:config
  ;;	(defun my-all-the-icons-dired--display ()
  ;;	  "Display the icons of files without colors in a dired buffer."
  ;;	  ;; Don't display icons after dired commands (e.g insert-subdir, create-directory)
  ;;	  ;; @see https://github.com/jtbm37/all-the-icons-dired/issues/11
  ;;	  (all-the-icons-dired--reset)

  ;;	  (when (and (not all-the-icons-dired-displayed) dired-subdir-alist)
  ;;		(setq-local all-the-icons-dired-displayed t)
  ;;		(let ((inhibit-read-only t)
  ;;			  (remote-p (and (fboundp 'tramp-tramp-file-p)
  ;;							 (tramp-tramp-file-p default-directory))))
  ;;		  (save-excursion
  ;;			;; TRICK: Use TAB to align icons
  ;;			(setq-local tab-width 1)
  ;;			(goto-char (point-min))
  ;;			(while (not (eobp))
  ;;			  (when (dired-move-to-filename nil)
  ;;				(insert " ")
  ;;				(let ((file (dired-get-filename 'verbatim t)))
  ;;				  (unless (member file '("." ".."))
  ;;					(let ((filename (file-local-name (dired-get-filename nil t))))
  ;;					  (if (file-directory-p filename)
  ;;						  (let ((icon (cond
  ;;									   (remote-p
  ;;										(all-the-icons-octicon "file-directory" :v-adjust all-the-icons-dired-v-adjust :face 'all-the-icons-dired-dir-face))
  ;;									   ((file-symlink-p filename)
  ;;										(all-the-icons-octicon "file-symlink-directory" :v-adjust all-the-icons-dired-v-adjust :face 'all-the-icons-dired-dir-face))
  ;;									   ((all-the-icons-dir-is-submodule filename)
  ;;										(all-the-icons-octicon "file-submodule" :v-adjust all-the-icons-dired-v-adjust :face 'all-the-icons-dired-dir-face))
  ;;									   ((file-exists-p (format "%s/.git" filename))
  ;;										(all-the-icons-octicon "repo" :height 1.1 :v-adjust all-the-icons-dired-v-adjust :face 'all-the-icons-dired-dir-face))
  ;;									   (t (let ((matcher (all-the-icons-match-to-alist file all-the-icons-dir-icon-alist)))
  ;;											(apply (car matcher) (list (cadr matcher) :face 'all-the-icons-dired-dir-face :v-adjust all-the-icons-dired-v-adjust)))))))
  ;;							(insert icon))
  ;;						(insert (all-the-icons-icon-for-file file :v-adjust all-the-icons-dired-v-adjust))))
  ;;					(insert "\t"))))
  ;;			  (forward-line 1))))))
  ;;	(advice-add #'all-the-icons-dired--display :override #'my-all-the-icons-dired--display)

  ;;	;; TRICK: The buffer isn't refreshed after some operations due to the TAB
  ;;	;;        before the file name. Refresh it by force.
  ;;	(advice-add #'dired-do-rename :after #'dired-revert)
  ;;	(advice-add #'dired-do-delete :after #'dired-revert)
  ;;	(advice-add #'dired-do-flagged-delete :after #'dired-revert))

  ;; Extra Dired functionality
  ;; (use-package dired-aux :ensure nil)
  ;; (use-package dired-x
  ;;	:ensure nil
  ;;	:demand
  ;;	:config
  ;;	(let ((cmd (cond
  ;;				(sys/mac-x-p "open")
  ;;				(sys/linux-x-p "xdg-open")
  ;;				(sys/win32p "start")
  ;;				(t ""))))
  ;;	  (setq dired-guess-shell-alist-user
  ;;			`(("\\.pdf\\'" ,cmd)
  ;;			  ("\\.docx\\'" ,cmd)
  ;;			  ("\\.\\(?:djvu\\|eps\\)\\'" ,cmd)
  ;;			  ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\)\\'" ,cmd)
  ;;			  ("\\.\\(?:xcf\\)\\'" ,cmd)
  ;;			  ("\\.csv\\'" ,cmd)
  ;;			  ("\\.tex\\'" ,cmd)
  ;;			  ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
  ;;			  ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
  ;;			  ("\\.html?\\'" ,cmd)
  ;;			  ("\\.md\\'" ,cmd))))

  ;;	(setq dired-omit-files
  ;;		  (concat dired-omit-files
  ;;				  "\\|^.DS_Store$\\|^.projectile$\\|^.git*\\|^.svn$\\|^.vscode$\\|\\.js\\.meta$\\|\\.meta$\\|\\.elc$\\|^.emacs.*")))
  )


;; backup

;; (use-package dired
;;   :ensure nil
;;   :init
;;   (setq
;;    ;; Always copy/delete recursively
;;    dired-recursive-copies 'always
;;    dired-recursive-deletes 'always
;;    ;; Auto refresh dired, but be quiet about it
;;    global-auto-revert-non-file-buffers t
;;    auto-revert-verbose nil
;;    )
;;   )


;; Extra Dired functionality
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
		(concat dired-omit-files "\\|^.DS_Store$\\|^.projectile$\\|^.git*\\|^.svn$\\|^.vscode$\\|\\.js\\.meta$\\|\\.meta$\\|\\.elc$\\|^.emacs.*")))

(use-package dired-rainbow
  :commands dired-rainbow-define dired-rainbow-define-chmod
  :init
  (dired-rainbow-define dotfiles "gray" "\\..*")

  (dired-rainbow-define web "#4e9a06" ("htm" "html" "xhtml" "xml" "xaml" "css" "js"
									   "json" "asp" "aspx" "haml" "php" "jsp" "ts"
									   "coffee" "scss" "less" "phtml"))
  (dired-rainbow-define prog "yellow3" ("el" "l" "ml" "py" "rb" "pl" "pm" "c"
										"cpp" "cxx" "c++" "h" "hpp" "hxx" "h++"
										"m" "cs" "mk" "make" "swift" "go" "java"
										"asm" "robot" "yml" "yaml" "rake" "lua"))
  (dired-rainbow-define sh "green yellow" ("sh" "bash" "zsh" "fish" "csh" "ksh"
										   "awk" "ps1" "psm1" "psd1" "bat" "cmd"))
  (dired-rainbow-define text "yellow green" ("txt" "md" "org" "ini" "conf" "rc"
											 "vim" "vimrc" "exrc"))
  (dired-rainbow-define doc "spring green" ("doc" "docx" "ppt" "pptx" "xls" "xlsx"
											"csv" "rtf" "wps" "pdf" "texi" "tex"
											"odt" "ott" "odp" "otp" "ods" "ots"
											"odg" "otg"))
  (dired-rainbow-define misc "gray50" ("DS_Store" "projectile" "cache" "elc"
									   "dat" "meta"))
  (dired-rainbow-define media "#ce5c00" ("mp3" "mp4" "MP3" "MP4" "wav" "wma"
										 "wmv" "mov" "3gp" "avi" "mpg" "mkv"
										 "flv" "ogg" "rm" "rmvb"))
  (dired-rainbow-define picture "purple3" ("bmp" "jpg" "jpeg" "gif" "png" "tiff"
										   "ico" "svg" "psd" "pcd" "raw" "exif"
										   "BMP" "JPG" "PNG"))
  (dired-rainbow-define archive "saddle brown" ("zip" "tar" "gz" "tgz" "7z" "rar"
												"gzip" "xz" "001" "ace" "bz2" "lz"
												"lzma" "bzip2" "cab" "jar" "iso"))

  ;; boring regexp due to lack of imagination
  (dired-rainbow-define log (:inherit default :italic t) ".*\\.log")

  ;; highlight executable files, but not directories
  (dired-rainbow-define-chmod executable-unix "green" "-[rw-]+x.*"))


;; ;; Hightlights dired buffer like k
;; (use-package dired-k
;;   :bind (:map dired-mode-map ("K" . dired-k))
;;   :init
;;   (setq dired-k-padding 1)
;;   (setq dired-k-human-readable t)
;;   :config
;;   (setq dired-k-style 'git)
;;   )

(provide 'flywind-dired)
