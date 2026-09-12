;;; flywind-org.el --- Org 配置 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; Emacs 31 内置 Org 9.8：不再配置 org ELPA 源。
;; 原配置用 `setq-default' 在启动期裸设 org 变量，这里改为
;; `with-eval-after-load 'org' + `setq'，避免在 org 加载前写入被覆盖。
;;
;;; Code:

(eval-when-compile
  (require 'org)          ; 让编译器知道下面 setq 的 org 变量
  (require 'org-indent))

(with-eval-after-load 'org
  ;; 文件与 agenda
  (setq org-agenda-files (list "~/gtd/work.org")
        org-directory "~/gtd")

  ;; 编辑体验
  (setq org-src-preserve-indentation t
        org-edit-src-content-indentation 0
        org-log-done nil
        org-adapt-indentation nil
        org-cycle-include-plain-lists t
        org-cycle-separator-lines 1
        org-entities-user
        '(("flat"  "\\flat" nil "" "" "266D" "♭")
          ("sharp" "\\sharp" nil "" "" "266F" "♯"))
        org-fontify-done-headline t
        org-fontify-quote-and-verse-blocks t
        org-fontify-whole-heading-line t
        org-footnote-auto-label 'plain
        org-hidden-keywords nil
        org-hide-emphasis-markers nil
        org-hide-leading-stars t
        org-indent-indentation-per-level 2
        org-indent-mode-turns-on-hiding-stars t
        org-priority-faces
        `((?a . ,(face-foreground 'error))
          (?b . ,(face-foreground 'warning))
          (?c . ,(face-foreground 'success)))
        org-startup-folded t
        org-startup-indented t
        org-tags-column 0
        org-todo-keywords
        '((sequence "TODO(t!)" "NEXT(n)" "WAITTING(w)" "SOMEDAYS(s)" "已安排(e)"
                    "|" "DONE(d@/!)" "ABORT(a@/!)"))
        org-capture-templates
        '(("t" "Todo" entry (file "~/gtd/work.org")
           "* TODO [#B] %?\n %i\n"
           :empty-line 1))
        org-agenda-custom-commands
        '(("w" . "任务安排")
          ("wa" "任务安排" todo "TODO")
          ("wb" "已完成任务" todo "DONE"))
        org-use-sub-superscripts '{}
        outline-blank-line t))

(provide 'flywind-org)
;;; flywind-org.el ends here
