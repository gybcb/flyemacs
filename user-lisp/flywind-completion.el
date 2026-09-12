;;; flywind-completion.el --- Vertico/Consult 补全与完成栈 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 取代原 flywind-ivy.el（Ivy/Counsel/Swiper 上游已停更）。
;; 组合：Vertico（竖直完成）+ Orderless（不规则匹配）+ Marginalia（标注）
;;       + Consult（替代 counsel/swiper）+ 内置 project.el / which-key。
;;
;;; Code:

(eval-when-compile
  (require 'orderless)
  (require 'vertico)
  (require 'vertico-repeat)
  (require 'marginalia)
  (require 'consult))

;; ---------------------------------------------------------------------------
;; 完成基础设施
;; ---------------------------------------------------------------------------
(setq completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t
      completion-cycle-threshold 3
      tab-always-indent 'complete)

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package vertico
  :demand t
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word)
              ("C-w" . vertico-directory-up))
  :config
  (vertico-mode 1)
  ;; 竖直候选高度与 ivy 时代接近
  (setq vertico-count 12
        vertico-resize nil
        vertico-cycle t
        read-file-name-completion-ignore-case t))

(use-package vertico-repeat
  :after vertico
  :bind ("M-r" . vertico-repeat))

(use-package marginalia
  :demand t
  :custom
  (marginalia-annotators '(marginalia-annotators-heavy marginalia-annotators-light nil))
  :config
  (marginalia-mode 1))

;; ---------------------------------------------------------------------------
;; Consult：替代 counsel / swiper / browse-kill-ring / counsel-projectile
;; ---------------------------------------------------------------------------
(defun flywind/consult-search-dwim ()
  "`C-s'：文件 buffer 里 `consult-line'，其它 buffer 里 `consult-ripgrep'。"
  (interactive)
  (if (buffer-file-name)
      (call-interactively #'consult-line)
    (call-interactively #'consult-ripgrep)))

(use-package consult
  :bind (;; 沿用原配置的按键位置
         ("C-s"         . flywind/consult-search-dwim)
         ("C-S-s"       . consult-ripgrep)
         ("C-x C-r"     . consult-recent-file)
         ("C-x b"       . consult-buffer)
         ("C-x 4 b"     . consult-buffer-other-window)
         ("C-x 5 b"     . consult-buffer-other-frame)
         ("C-x r b"     . consult-bookmark)
         ("C-x C-o"     . consult-imenu)
         ("M-g g"       . consult-line)
         ("M-y"         . consult-yank-pop)
         ("M-s r"       . consult-ripgrep)
         ("M-s h l"     . consult-line)
         ("C-x p f"     . consult-project-buffer))
  :custom
  (consult-narrow-key "<")
  (consult-preview-key 'any)
  (xref-show-xrefs-function #'consult-xref)
  (xref-show-definitions-function #'consult-xref))

;; ---------------------------------------------------------------------------
;; 历史保存
;; ---------------------------------------------------------------------------
(use-package savehist
  :ensure nil
  :custom
  (history-length 500)
  (history-delete-duplicates t)
  (savehist-additional-variables '(search-ring regexp-search-ring vertico-repeat-history))
  (savehist-save-minibuffer-history t)
  :config
  (setq savehist-file (expand-file-name "savehist" flywind-etc-dir))
  (savehist-mode 1))

;; ---------------------------------------------------------------------------
;; which-key（Emacs 31 内置）
;; ---------------------------------------------------------------------------
(use-package which-key
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 0.8)
  (which-key-announce-inactive-period 8)
  :config
  (which-key-mode 1))

;; ---------------------------------------------------------------------------
;; 项目命令：Emacs 31 内置 project.el（不再引入 projectile）
;; ---------------------------------------------------------------------------
(provide 'flywind-completion)
;;; flywind-completion.el ends here
