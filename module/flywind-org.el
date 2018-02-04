(setq org-agenda-files
      (list "~/flywind-nas/gtd/work.org"))

(setq org-todo-keywords
      '((sequence "TODO(t!)" "NEXT(n)" "WAITTING(w)" "SOMEDAYS(s)" "已安排(e)" "|" "DONE(d@/!)" "ABORT(a@/!)")
		))


(provide 'flywind-org)
