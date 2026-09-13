;;; flywind-basic.el --- 基础编辑环境 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 编码、备份/自动保存位置、kill-ring、常用编辑增强。
;; Emacs 31 相关修正：
;;   * `write-file-functions'（24.3 起废弃）-> 内置 `delete-trailing-whitespace-mode'（见 flywind-ui.el）
;;   * 不再用 exec-path-from-shell：它在启动期跑 `bash -l' 子进程。PATH 改由
;;     early-init.el 的 `flywind-extra-exec-path' 静态注入。
;;   * 不再从 shell 导入 PYTHONPATH（当前 shell 有激活的 venv，会污染解释器）
;;
;;; Code:

(eval-when-compile
  (require 'hungry-delete)
  (require 'easy-kill))

;;;; UTF-8 作为默认编码系统
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))
(prefer-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(setq locale-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8)

;;;; 文件与备份
(setq-default
 abbrev-file-name (expand-file-name "abbrev.el" flywind-local-dir)
 auto-save-list-file-prefix (expand-file-name "autosave/" flywind-cache-dir)
 backup-directory-alist `(("." . ,(expand-file-name "backup/" flywind-cache-dir)))
 make-backup-files nil)            ; 不生成 ~ 备份文件

;;;; 铃声
(setq visible-bell nil
      ring-bell-function #'ignore)

;;;; kill-ring
;; 浏览交给 `consult-yank-pop'（见 flywind-completion.el 的 M-y 绑定）。
(setq kill-ring-max 200
      save-interprogram-paste-before-kill t)   ; 粘贴前先把剪贴板内容存入 kill-ring

(use-package easy-kill
  :bind (([remap kill-ring-save] . easy-kill)
         ([remap mark-sexp] . easy-mark)))

;;;; 成对符号
(use-package elec-pair
  :ensure nil
  :custom
  (electric-pair-preserve-balance t)
  (electric-pair-delete-adjacent-pairs t)
  (electric-pair-open-newline-between-pairs t)
  :config
  (electric-pair-mode 1))

;;;; 最近文件
(use-package recentf
  :ensure nil
  :custom
  (recentf-max-saved-items 200)
  (recentf-save-file (expand-file-name "recentf" flywind-cache-dir))
  :config
  (recentf-mode 1)
  (add-to-list 'recentf-exclude (expand-file-name package-user-dir))
  (add-to-list 'recentf-exclude "bookmarks")
  (add-to-list 'recentf-exclude "COMMIT_EDITMSG\\'"))

;;;; 删除增强
(use-package hungry-delete
  :config
  (global-hungry-delete-mode 1))

;;;; 注释
(global-set-key (kbd "C-c C-g") #'comment-or-uncomment-region)

;;;; mode line 上的噪音 lighter
;;
;; 不用 ELPA 的 diminish 包，两条实测理由：
;;   * Emacs 31 里它不是内建（emacs -Q 下 fboundp 为 nil），而抹 lighter 发生在 init
;;     期，调它等于在启动路径上多加载一个包；
;;   * byte-comp 时编译环境里没有它的 autoload，直接报
;;     “the function 'diminish' is not known to be defined”。
;; 对「条目已经在 alist 里」的 mode，diminish 做的事就是换掉那个 cdr，这里等价。
(defconst flywind--empty-minor-mode-lighter '("")
  "抹 lighter 时写进去的形态：空串外面包一层列表。
裸空串在 tty 的 mode line 渲染路径里会被判成无效，打出 *invalid*（实测）。
mode line 认的是列表形式的 lighter，真 diminish 产出的也是这个形态。")

(defun flywind-hide-minor-mode-lighter (mode)
  "抹掉 minor mode MODE 在 mode line 上的 lighter（原地改 alist）。
只改 `minor-mode-alist' 一个表：老 Emacs（24 那代）另有个
`global-minor-mode-alist' 放全局 minor mode 的 lighter，Emacs 31 里它已经不存在
（实测 void-variable），which-key / volatile-highlights 这类全局 mode 的 lighter
实测就挂在 `minor-mode-alist' 上，改一个表就够。

MODE 还没加载时本函数是空转：alist 里还拿不到它的条目。所以要么在 use-package
的 :config 里调（那时包已经加载），要么包在 `with-eval-after-load' 里。"
  ;; 形态必须是 '("")：mode line 的 lighter 位认「列表形式的 lighter」，裸空串在
  ;; tty 的 C 渲染路径里判成无效（实测四个被抹的 mode 打出四个 *invalid*）。
  ;; 另有 (MODE MODE LIGHTER) 这种形状，整段换掉会破坏结构，按 diminish 的做法在
  ;; lighter 位前放一个 'ignore 保住它。
  (when-let* ((cell (assq mode minor-mode-alist)))
    (setcdr cell (if (and (consp (cdr cell)) (eq (nth 1 cell) mode))
                     (cons 'ignore flywind--empty-minor-mode-lighter)
                   flywind--empty-minor-mode-lighter))))

(provide 'flywind-basic)
;;; flywind-basic.el ends here
