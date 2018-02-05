;; Directional window-selection routines
(use-package windmove
  :ensure nil
  :init (add-hook 'after-init-hook 'windmove-default-keybindings))
;; Quickly switch windows
(use-package ace-window
  :bind ("C-x o" . ace-window))

;; Numbered window shortcuts
(use-package window-numbering
  :init (add-hook 'after-init-hook 'window-numbering-mode))

;; Zoom window like tmux
(use-package zoom-window
  :bind ("C-x C-z" . zoom-window-zoom)
  :init (setq zoom-window-mode-line-color "DarkGreen"))

;; Popup Window Manager
(use-package popwin
  :commands popwin-mode
  :init (add-hook 'after-init-hook 'popwin-mode)
  :config
  (bind-key "C-z" popwin:keymap)

  ;; don't use default value but manage it ourselves
  (setq popwin:special-display-config
		'(("*Help*" :dedicated t :position bottom :stick nil :noselect nil)
		  ("*compilation*" :dedicated t :position bottom :stick t :noselect t :height 0.4)
		  ("*Compile-Log*" :dedicated t :position bottom :stick t :noselect t :height 0.4)
		  ("*Warnings*" :dedicated t :position bottom :stick t :noselect t)
		  ("*Completions*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*Shell Command Output*" :dedicated t :position bottom :stick t :noselect nil)
		  ("\*Async Shell Command\*.+" :regexp t :position bottom :stick t :noselect t)
		  ("^*WoMan.+*$" :regexp t :position bottom)
		  ("*Youdao Dictionary*" :dedicated t :position bottom)

		  (" *undo-tree*" :dedicated t :position right :stick t :noselect nil :width 0.3)
		  ("*undo-tree Diff*" :dedicated nil :stick nil :noselect nil)

		  ("*grep*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*ag search*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*rg*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*Occur*" :dedicated t :position bottom :stick t :noselect nil)
		  ("\*ivy-occur.+*$" :regexp t :position bottom :stick t :noselect nil)
		  ("*xref*" :dedicated t :position bottom :stick nil :noselect nil)

		  ("*vc-diff*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*vc-change-log*" :dedicated t :position bottom :stick t :noselect nil)

		  ("*shell*" :dedicated t :position bottom :stick t :noselect nil :height 0.3)
		  ("*Python*" :dedicated t :position bottom :stick t :noselect t :height 0.3)

		  ("*ert*" :dedicated t :position bottom :stick t :noselect nil)
		  ("*nosetests*" :dedicated t :position bottom :stick t :noselect nil))))

;; Easy window config switching
(use-package eyebrowse
  :init (add-hook 'after-init-hook 'eyebrowse-mode))


(provide 'flywind-window)
