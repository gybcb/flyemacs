;;; flywind-modeline.el --- 轻量 mode line：零外部依赖，颜色全交给主题 -*- lexical-binding: t; -*-

;;; Commentary:

;; 为什么不用 doom-modeline：本机（Apple Silicon + Ghostty tty）实测它启动 +60ms
;; （0.27s -> 0.33s），单次渲染 371us，而 Emacs 默认只要 194us —— 它比默认慢将近
;; 一倍。它比默认多做的事件就三件：少列一些东西、加图标、上颜色。这三件都能直接
;; 写进 `mode-line-format'，代价是每次渲染多两个 `:eval'，其余全走 Emacs C 侧的
;; % 转义与 `mode-line-modes'。
;;
;; 三条设计约束：
;;
;;   1. 颜色一律 `:inherit' 主题已经管好的 face（`mode-line-buffer-id' /
;;      `success' / `warning' / `font-lock-comment-face'），不写死前景色。主题会
;;      在浅色与深色之间自动切换（见 `flywind-theme--apply'），写死的颜色在那边
;;      一定翻车。
;;   2. 图标用 JetBrainsMono Nerd Font 的码位，不依赖 nerd-icons / all-the-icons
;;      包。码位不是猜的：名字取自 nerd-icons 的数据表，再用 `fc-query' 查过
;;      JetBrainsMonoNerdFont-Regular.ttf 的 cmap，下面用到的 24 个全覆盖。
;;      终端侧 Ghostty 的 font-family 也是这个 Nerd Font，所以 tty 与 GUI 同一套
;;      字形。探测不到字体就退回 ASCII（见 `flywind-modeline-icons'）。
;;   3. `mode-line-format' 是对所有 buffer 都 buffer-local 的变量，必须
;;      `setq-default'。在 `define-minor-mode' 体里用 `setq' 只会改到当时那个
;;      buffer（实测：模式显示已开，新开的 json buffer 仍是系统默认那条）。
;;   4. 渲染路径上不做任何 I/O：只读 `buffer-name' / `buffer-modified-p' /
;;      `buffer-read-only' / `vc-mode'。不调 `project-current'（那是 doom-modeline
;;      每次重绘去走目录的原因），也不 stat 文件 —— 只读状态取 `buffer-read-only'
;;      这个编辑器内部状态，不用 `file-writable-p'。
;;
;; `flywind-modeline-implementation' 留了 doom 档：设成 doom 就是回到原来那条
;; bar（包仍在清单里，按需 require），可以当场 A/B 两种长相。
;;
;; 自己这条不再显示的东西：滚动条占位、`mode-line-client'（server 客户端标记）、
;; `mode-line-remote'（远程文件标记）、`buffer-codepoint-for-data'。要哪个把对应
;; 变量加回 `flywind-modeline--format' 即可。

;;; Code:

(require 'cl-lib)

(declare-function flywind-font-available-p "flywind-ui" (&optional family))
(declare-function doom-modeline-mode "doom-modeline" (&optional arg))
;; `flywind-modeline-mode' 由下面的 define-minor-mode 定义，:set 里提前读到它。
(defvar flywind-modeline-mode)
(defgroup flywind-modeline nil
  "轻量 mode line。"
  :group 'flywind)

(defcustom flywind-modeline-implementation 'own
  "用哪条 mode line。
`own'  = 本模块这条，启动与渲染最便宜。
`doom' = doom-modeline（包得装着；切换时按需 require）。"
  :type '(choice (const :tag "本模块（快）" own)
                 (const :tag "doom-modeline" doom))
  :group 'flywind-modeline
  :set (lambda (sym val)
         (set-default sym val)
         ;; 已经启用时才重建；否则 customize 会顺手把模式打开。
         (when (and (fboundp 'flywind-modeline-mode) flywind-modeline-mode)
           (flywind-modeline-mode 1))))

(defcustom flywind-modeline-icons 'auto
  "是否用 Nerd Font 图标。
`auto' = GUI 下探测字体在不在（`flywind-font-available-p'）；tty 下开着 ——
         终端字体由终端自己决定，Emacs 问不到，而本机 Ghostty 是 Nerd Font。
t      = 强制开。nil = 用 ASCII 标记（终端不是 Nerd Font 时用这个，否则是豆腐）。"
  :type '(choice (const :tag "自动判定" auto)
                 (const :tag "强制开" t)
                 (const :tag "关闭（ASCII）" nil))
  :group 'flywind-modeline)

(defcustom flywind-modeline-show-vc t
  "是否显示版本控制分支。只从 `vc-mode' 抠，不起 git、不做 I/O。"
  :type 'boolean
  :group 'flywind-modeline)

(defcustom flywind-modeline-show-coding t
  "是否显示编码与行尾（`%z' 形如 [UTF-8 unix]）。"
  :type 'boolean
  :group 'flywind-modeline)

(defcustom flywind-modeline-show-position t
  "是否显示行列号与位置百分比。"
  :type 'boolean
  :group 'flywind-modeline)

(defcustom flywind-modeline-buffer-name-width 40
  "buffer 名宽过这个值就截断；0 = 不截断。"
  :type '(choice (const :tag "不截断" 0) (integer :tag "宽度" 40))
  :group 'flywind-modeline)

;;; Face：全部 inherit 主题已经管好的 face，一个硬编码颜色都没有。

(defface flywind-modeline-buffer
  '((t :inherit (mode-line mode-line-buffer-id)))
  "buffer 名。主题决定它在浅 / 深两套下长什么样。"
  :group 'faces)

(defface flywind-modeline-icon
  '((t :inherit (mode-line font-lock-comment-face)))
  "文件类型图标；用注释色，免得在整条 bar 里抢戏。"
  :group 'faces)

(defface flywind-modeline-branch
  '((t :inherit (mode-line success)))
  "版本控制分支。"
  :group 'faces)

(defface flywind-modeline-unsaved
  '((t :inherit (mode-line warning)))
  "未保存与只读状态。"
  :group 'faces)

;;; 图标码位（名字来自 nerd-icons 数据表，字形存在性用 fc-query 对 TTF 验过）。

(defconst flywind-modeline-glyph
  '((json . #xe60b) (yaml . #xe8eb) (toml . #xe615) (config . #xe615)
    (key . #xf084) (terminal . #xf120) (git . #xe702) (markdown . #xe73e)
    (code . #xf121) (docker . #xe7b0) (wrench . #xf0ad) (python . #xe73c)
    (ruby . #xe739) (go . #xe724) (rust . #xe7a8) (css . #xe749)
    (javascript . #xe781) (file-code . #xf1c9) (html . #xe736) (file . #xf15b)
    (folder . #xf07b) (branch . #xe0a0) (pencil . #xf040) (lock . #xf023))
  "图标名 -> 码位。放常量表，映射表只写图标名，读起来知道是什么。")

(defcustom flywind-modeline-name-icons
  '(("\\.gitconfig\\'" . git) ("\\.gitignore\\'" . git)
    ("\\.gitattributes\\'" . git) ("\\.gitmodules\\'" . git)
    ("\\.tmux\\.conf\\'" . terminal) ("\\.bashrc\\'" . terminal)
    ("\\.zshrc\\'" . terminal) ("\\.profile\\'" . terminal)
    ("\\.env\\'" . key) ("\\.env\\.[a-z]+\\'" . key)
    ("\\.editorconfig\\'" . config) ("\\.inputrc\\'" . config)
    ("authorized_keys\\'" . key) ("ssh_config\\'" . key)
    ("known_hosts\\'" . key)
    ("\\`[Mm]akefile" . wrench) ("Makefile\\.am\\'" . wrench)
    ("\\`Dockerfile" . docker) ("\\`Containerfile" . docker))
  "整文件名正则 -> `flywind-modeline-glyph' 里的图标名。
点文件没有扩展名，所以必须先按整名匹配。"
  :type '(alist :key-type regexp :value-type symbol)
  :group 'flywind-modeline)

(defcustom flywind-modeline-ext-icons
  '(("json" . json) ("jsonc" . json) ("jsonl" . json)
    ("yaml" . yaml) ("yml" . yaml)
    ("toml" . toml) ("ini" . config) ("conf" . config) ("cfg" . config)
    ("properties" . config) ("service" . config) ("desktop" . config)

    ("el" . code) ("sh" . terminal) ("bash" . terminal) ("zsh" . terminal)
    ("fish" . terminal) ("md" . markdown) ("markdown" . markdown)
    ("py" . python) ("rb" . ruby) ("go" . go) ("rs" . rust)
    ("css" . css) ("js" . javascript) ("mjs" . javascript)
    ("ts" . file-code) ("tsx" . file-code) ("jsx" . file-code)
    ("html" . html) ("htm" . html) ("xml" . file-code))
  "扩展名（小写，不含点）-> `flywind-modeline-glyph' 里的图标名。"
  :type '(alist :key-type string :value-type symbol)
  :group 'flywind-modeline)

(defconst flywind-modeline--empty-lighter '("")
  "抹 lighter 时写进去的形态：空串外面包一层列表。
裸空串在 tty 的 mode line 渲染路径里会被判成无效，打出 *invalid*（实测）。
mode line 认的是列表形式的 lighter，真 diminish 产出的也是这个形态。")

(defcustom flywind-modeline-hidden-minor-modes
  '(which-key-mode eldoc-mode hungry-delete-mode auto-revert-mode)
  "这些 minor mode 不在 mode line 上占位。
只列实测真的会出现在 mode line 里又不携带信息的：`WK'（which-key 一直开着）、
` h'（hungry-delete）、`ElDoc'（echo area 本来就在给文档）、`ARev'
（auto-revert-mode —— 它是 flywind-dired 里 global-auto-revert-mode 顺带开的，
每个 buffer 都挂一个，等于没有信息）。
空 lighter 的几个（volatile-highlights / whitespace / rainbow-delimiters）
本来就不渲染，不用列在这里，它们的 :diminish 留在各自模块里。"
  :type '(repeat symbol)
  :group 'flywind-modeline)

(defun flywind-modeline--hide-lighter (mode)
  "把 MODE 在 mode line 上的 lighter 抹成空串。
只改 `minor-mode-alist' 就够：老 Emacs（24 那代）另有个
`global-minor-mode-alist' 存全局 minor mode 的 lighter，Emacs 31 里它已经不存在
（实测 void-variable），which-key / auto-revert 这类全局 minor mode 的 lighter
实测就挂在 `minor-mode-alist' 上。

不用 `diminish' 包：它在 Emacs 31 里不是内建（emacs -Q 下 fboundp 为 nil），
而本模块要在 init 期间就跑 —— 调它等于在启动期顺带加载一个包，字节编译时还会
报 not known to be defined。对「条目已经在 alist 里」的 mode，diminish 做的事
就是换掉 cdr，这里等价。"
  ;; 抹成什么形态有讲究：裸空串 `""' 在 tty 的 C 渲染路径里判成无效，mode line
  ;; 上会打出 *invalid*（实测）。要包一层列表 —— `("\")' 这种形式才是 mode line
  ;; 认的 lighter 形态，真 diminish 产出的也是它。
  ;; 另有 (MODE MODE LIGHTER) 这种全局化 minor mode 的形状，直接把 cdr 换掉会破坏
  ;; 结构，按 diminish 的做法在 lighter 位前放一个 'ignore 保住形状。
  (when-let* ((cell (assq mode minor-mode-alist)))
    (setcdr cell (if (and (consp (cdr cell)) (eq (nth 1 cell) mode))
                     (cons 'ignore flywind-modeline--empty-lighter)
                   flywind-modeline--empty-lighter))))

(defun flywind-modeline--hide-noise-lighters ()
  "抹掉 `flywind-modeline-hidden-minor-modes' 里所有已加载的 lighter。
还没加载的由 `after-load-functions' 补：换掉 alist 只对该 mode 加载之后的
`minor-mode-alist' 生效，太早改是空转。"
  (interactive)
  (dolist (mode flywind-modeline-hidden-minor-modes)
    (flywind-modeline--hide-lighter mode)))

(add-hook 'after-load-functions
          (lambda (_file)
            (when flywind-modeline-mode
              (flywind-modeline--hide-noise-lighters))))

(defconst flywind-modeline-ascii-icon "?")
(defconst flywind-modeline-ascii-branch "@")
(defconst flywind-modeline-sep " │ ")

(defun flywind-modeline--icons-p ()
  "当前该不该出图标。
tty 判不了终端字体，按 Nerd Font 假定（Ghostty 用的是它自己的 font-family）。
GUI 下探测：只有「确定没装」才退回 ASCII；探测不了（batch、没有显示后端）按开
处理 —— macOS 会做字形回退，~/Library/Fonts 里就装着 Nerd Font，真缺字形是显式
方块，一眼看得见，比整条 bar 静默退回 ASCII 好发现。"
  ;; 写成 ('t t) 而不是裸 t：pcase 里裸 t 匹配「一切非 nil」，'auto 会被它吃掉。
  (pcase flywind-modeline-icons
    ('nil nil)
    ('t t)
    (_ (or (not (display-graphic-p))
           ;; memq 命中给的是尾串（(t unknown) 这种），谓词要的是 t/nil。
           (and (memq (flywind-font-available-p) '(t unknown)) t)))))

(defun flywind-modeline--glyph (name icons fallback)
  "取图标名 NAME 的字符串；ICONS 关时给 FALLBACK（ASCII）。"
  (if-let* ((icons icons)
            (cell (assq name flywind-modeline-glyph)))
      (string (cdr cell))
    fallback))

(defun flywind-modeline--icon-name (name)
  "按 buffer 名 NAME 找图标名（`flywind-modeline-glyph' 的键）；没匹配返回 nil。
整名正则优先，再看扩展名。码位由 `flywind-modeline--glyph' 再去查。"
  (catch 'hit
    (dolist (pair flywind-modeline-name-icons)
      (when (string-match-p (car pair) name)
        (throw 'hit (cdr pair))))
    (when-let* ((ext (file-name-extension name))
                ((not (string-empty-p ext)))
                (hit (assoc (downcase ext) flywind-modeline-ext-icons)))
      (throw 'hit (cdr hit)))))

(defun flywind-modeline--identity ()
  "图标 + buffer 名 + 状态标记。只读编辑器内部状态，零 I/O。"
  (let* ((icons (flywind-modeline--icons-p))
         (raw (buffer-name))
         (name (if (and (> flywind-modeline-buffer-name-width 0)
                        (> (length raw) flywind-modeline-buffer-name-width))
                   (truncate-string-to-width raw flywind-modeline-buffer-name-width
                                             0 nil t)
                 raw))
         ;; dired 目录 buffer 用文件夹图标；它是只读的，走不到扩展名那条。
         (icon-name (if (derived-mode-p 'dired-mode) 'folder
                      (or (flywind-modeline--icon-name raw) 'file)))
         (bad (or buffer-read-only (buffer-modified-p)))
         (icon-face (if bad 'flywind-modeline-unsaved 'flywind-modeline-icon)))
    (concat
     (propertize (flywind-modeline--glyph icon-name icons flywind-modeline-ascii-icon)
                 'face icon-face)
     " "
     (propertize name 'face 'flywind-modeline-buffer)
     (cond
      (buffer-read-only
       (propertize (concat " " (flywind-modeline--glyph 'lock icons "R"))
                   'face 'flywind-modeline-unsaved))
      ((buffer-modified-p)
       (propertize (concat " " (flywind-modeline--glyph 'pencil icons "*"))
                   'face 'flywind-modeline-unsaved))
      (t "")))))

(defun flywind-modeline--vc ()
  "从 `vc-mode' 抠分支名；它形如 \" Git-main\" / \" Git:main\" / \" SVN1.7:trunk\"。"
  (when (and flywind-modeline-show-vc vc-mode)
    (let* ((body (string-trim (substring-no-properties vc-mode)))
           ;; elisp 正则没有 PCRE 那套 \(?1: —— 用它只会静默拿不到分组，
           ;; 用普通 \(...\) 加 match-string 1。
           (branch (if (string-match "[:/-]\\(.+\\)\\'" body)
                       (match-string 1 body)
                     body))
           (icons (flywind-modeline--icons-p)))
      (propertize
       (concat flywind-modeline-sep
               (flywind-modeline--glyph 'branch icons flywind-modeline-ascii-branch)
               " " branch)
       'face 'flywind-modeline-branch))))

(defun flywind-modeline--coding ()
  "编码与行尾。配置文件里 LF / CRLF 是真问题，不像 `%z' 那样只能给出终端编码。
只读 `buffer-file-coding-system'，不碰磁盘。没访文件的 buffer 不显示。"
  (when-let* ((buffer-file-name)
              (cs buffer-file-coding-system)
              (base (coding-system-base cs)))
    (propertize
     (concat flywind-modeline-sep
             (upcase (symbol-name base))
             (pcase (coding-system-eol-type cs)
               (1 " CRLF") (2 " CR") (_ " LF")))
     'face 'flywind-modeline-icon)))

(defun flywind-modeline--format ()
  "拼 `mode-line-format'。除三个 :eval 外都交给 C 侧的 % 转义与内置变量。"
  `(;; 左：身份与状态
    "  "
    (:eval (flywind-modeline--identity))
    (:eval (flywind-modeline--vc))
    ,@(and flywind-modeline-show-coding '((:eval (flywind-modeline--coding))))
    ;; 行列与位置：用 % 转义，走 C 侧，不花 elisp 时间
    ,@(and flywind-modeline-show-position '("  %l:%c %P"))
    "  "
    mode-line-modes
    ;; 最右：eglot / flycheck / display-time 这些自己往 misc-info 里塞的东西
    mode-line-misc-info
    "  "))

(defvar flywind-modeline--stock-format (default-value 'mode-line-format)
  "Emacs 自带那条 `mode-line-format'，在加载时抓住。
必须在加载时就存：等到开启时才存，一旦先关掉本模式（或者先开 doom 档再
切回来），那时读到的已经是被改过的值了 —— 实测会把 mode line 设成 nil。")

;;;###autoload
(define-minor-mode flywind-modeline-mode
  "轻量 mode line。关掉回到 Emacs 默认那条。"
  :global t
  :lighter nil
  (if flywind-modeline-mode
      (if (eq flywind-modeline-implementation 'doom)
          (progn
            ;; 先拿默认值打底，别让它在我们这条之上做替换。
            (setq-default mode-line-format flywind-modeline--stock-format)
            (require 'doom-modeline)
            (doom-modeline-mode 1))
        (when (bound-and-true-p doom-modeline-mode)
          (doom-modeline-mode -1))
        (setq-default mode-line-format (flywind-modeline--format))
        (flywind-modeline--hide-noise-lighters))
    (when (bound-and-true-p doom-modeline-mode)
      (doom-modeline-mode -1))
    (setq-default mode-line-format flywind-modeline--stock-format))
  (force-mode-line-update t))

;;;###autoload
(defun flywind-modeline-report ()
  "报告当前 mode line 的来源与单次渲染代价。"
  (interactive)
  (let* ((fmt mode-line-format)
         (buf (generate-new-buffer " flywind-modeline-sample"))
         (sample "")
         (n 300)
         (us 0.0))
    (with-current-buffer buf
      (insert "{\n  \"a\": 1,\n  \"b\": [1, 2, 3]\n}\n")
      (rename-buffer "config.json")
      (setq sample (format-mode-line fmt))
      (let ((t0 (float-time)))
        (dotimes (_ n) (format-mode-line fmt))
        (setq us (/ (* 1000000.0 (- (float-time) t0)) n))))
    (kill-buffer buf)
    (with-current-buffer (get-buffer-create "*flywind-modeline-report*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert
         (format "实现：%s（图标：%s；`flywind-modeline-icons' = %S）\n"
                 (cond ((eq flywind-modeline-implementation 'doom) "doom-modeline")
                       (flywind-modeline-mode "本模块")
                       (t "Emacs 默认"))
                 (if (flywind-modeline--icons-p) "开" "关（ASCII）")
                 flywind-modeline-icons)
         (format "单次渲染：%.1f us（%d 次平均，样例是 6 行 JSON 的 config.json）\n" us n)
         (format "片段数：%d\n\n样例行（config.json）：\n%s\n\n可调：\n"
                 (if (listp fmt) (length fmt) -1)
                 (replace-regexp-in-string "[\n\t]+" " " sample))
         "  flywind-modeline-implementation   own / doom（当场换实现）\n"
         "  flywind-modeline-icons            auto / t / nil\n"
         "  flywind-modeline-show-coding      编码与行尾\n"
         "  flywind-modeline-show-position    行列与百分比\n"
         "  flywind-modeline-buffer-name-width  buffer 名截断宽度\n")
        (special-mode)
        (goto-char (point-min))))
    (display-buffer "*flywind-modeline-report*")))

;;; 开机就启用。设 `mode-line-format' 只是赋值，没有 hook 与加载代价；
;;; 想临时回默认条：M-x flywind-modeline-mode 传 -1。
(flywind-modeline-mode 1)

(provide 'flywind-modeline)
;;; flywind-modeline.el ends here
