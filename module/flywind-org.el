(setq org-agenda-files
	  (list "~/flywind-nas/gtd/work.org"))

;; (setq org-todo-keywords
;;       '((sequence "TODO(t!)" "NEXT(n)" "WAITTING(w)" "SOMEDAYS(s)" "已安排(e)" "|" "DONE(d@/!)" "ABORT(a@/!)")
;;		))


;; ui
(setq-default
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
 org-hide-leading-stars-before-indent-mode t
 org-image-actual-width nil
 org-indent-indentation-per-level 2
 org-indent-mode-turns-on-hiding-stars t
 org-pretty-entities nil
 org-pretty-entities-include-sub-superscripts t
 org-priority-faces
 `((?a . ,(face-foreground 'error))
   (?b . ,(face-foreground 'warning))
   (?c . ,(face-foreground 'success)))
 org-startup-folded t
 org-startup-indented t
 org-startup-with-inline-images nil
 org-tags-column 0
 org-todo-keywords
 '((sequence "TODO(t!)" "NEXT(n)" "WAITTING(w)" "SOMEDAYS(s)" "已安排(e)" "|" "DONE(d@/!)" "ABORT(a@/!)"))
 org-capture-templates
 '(("t" "Todo" entry (file+headline "~/flywind-nas/gtd/work.org" "Todo")
	"** TODO [#B] %?\n %i\n"
	:empty-line 1))
 ;; (setq org-columns-default-format "%70ITEM %TODO %3PRIORITY %6TAGS")

 org-agenda-custom-commands
 '(
   ("w" . "任务安排")
   ("wa" "任务安排" todo "TODO")
   ("wb" "已完成任务" todo "DONE")
   )

 ;; org-todo-keywords
 ;; '((sequence "[ ](t)" "[-](p)" "[?](m)" "|" "[X](d)")
 ;;   (sequence "TODO(T)" "|" "DONE(D)")
 ;;   (sequence "NEXT(n)" "ACTIVE(a)" "WAITING(w)" "LATER(l)" "|" "CANCELLED(c)"))
 org-use-sub-superscripts '{}
 outline-blank-line t

 ;; LaTeX previews are too small and usually render to light backgrounds, so
 ;; this enlargens them and ensures their background (and foreground) match
 ;; the current theme.
 ;; org-preview-latex-image-directory (concat doom-cache-dir "org-latex/")
 ;; org-format-latex-options (plist-put org-format-latex-options :scale 1.5)
 ;; org-format-latex-options
 ;; (plist-put org-format-latex-options
 ;;            :background (face-attribute (or (cadr (assq 'default face-remapping-alist))
 ;;                                            'default)
 ;;                                        :background nil t))
 )

(provide 'flywind-org)
