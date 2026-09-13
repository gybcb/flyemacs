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
;;      包。码位不是猜的：名字取自 nerd-icons 的数据表，再直读
;;      JetBrainsMonoNerdFont-Regular.ttf 的 cmap 表逐个验过全覆盖（别用 fc-query
;;      的 %{charset}，它只报 99 段、连确在用的码位都判成没有）。终端侧 Ghostty 的
;;      font-family 也是这个 Nerd Font，所以 tty 与 GUI 同一套字形。探测不到字体就
;;      退回 ASCII（见 `flywind-modeline-icons'）。
;;   3. `mode-line-format' 是对所有 buffer 都 buffer-local 的变量，必须
;;      `setq-default'。在 `define-minor-mode' 体里用 `setq' 只会改到当时那个
;;      buffer（实测：模式显示已开，新开的 json buffer 仍是系统默认那条）。
;;   4. 渲染路径上不做任何 I/O：只读 `buffer-name' / `buffer-modified-p' /
;;      `buffer-read-only' / `vc-mode' / `default-directory'。不调
;;      `project-current'（那是 doom-modeline 每次重绘去走目录的原因），也不 stat
;;      文件 —— 只读状态取 `buffer-read-only' 这个编辑器内部状态，不用
;;      `file-writable-p'。远端标记走 `file-remote-p'：它对本地路径是纯字符串判断，
;;      实测本地 buffer 里调用之后 (featurep 'tramp) 仍是 nil，不会把 tramp 拉进
;;      启动路径（路径本身是远端语法时才加载，而那种 buffer 里 tramp 早就在了）。
;;
;; doom-modeline 与它的依赖 nerd-icons 都已从清单删除（卸载），本模块零外部依赖。
;; 上面那串测量就是删它的依据；`M-x flywind-modeline-mode -1' 随时回到 Emacs 默认
;; 那条，A/B 不必留第二个实现。
;;
;; 自己这条不再显示的东西：滚动条占位、`mode-line-client'（server 客户端标记）、
;; `buffer-codepoint-for-data'。要哪个把对应变量加回 `flywind-modeline--format'。
;; 远程标记（`mode-line-remote'）本模块自己实现（`flywind-modeline--remote'）：
;; stock 那个构造对本地文件渲染成一个常驻的 `-`（就是默认那条 `-UUU:**-` 末尾的
;; dash），而它内部靠 `%[...%]' 做远端条件，`format-mode-line' 里连本地 buffer 都
;; 渲染出条件内的文字，离线根本验不了 —— 所以不借用，直接读 `file-remote-p'。

;;; Code:

(require 'cl-lib)

(declare-function flywind-font-available-p "flywind-ui" (&optional family))
;; 本模块调用 flywind-basic.el 里的抹 lighter 函数：显式 require，别只靠 init.el
;; 的顺序。启动期那次自动字节编译会提前载入本模块，那时函数还不存在。
(require 'flywind-basic)
;; `flywind-modeline-mode' 由下面的 define-minor-mode 定义，:set 里提前读到它。
(defvar flywind-modeline-mode)
(defgroup flywind-modeline nil
  "轻量 mode line。"
  :group 'flywind)

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

(defcustom flywind-modeline-show-remote t
  "是否在 mode line 上标出远端来源（TRAMP / sudoedit）。
标记取 `default-directory' 的 method:user@host；本地 buffer 完全不出现。"
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

(defface flywind-modeline-remote
  '((t :inherit (mode-line font-lock-string-face)))
  "远端来源标记（TRAMP / sudoedit）。"
  :group 'faces)

(defface flywind-modeline-unsaved
  '((t :inherit (mode-line warning)))
  "未保存与只读状态。"
  :group 'faces)

;;; 图标码位（名字来自 nerd-icons 的数据表）。字形存在性是直读 TTF 的 cmap 表验的，
;;; 不用 fc-query：它的 %{charset} 只报出 99 段、连这里确在用的 e0a0 / f023 都判成
;;; 没有，拿来当覆盖探针会一路误判。remote 选 BMP 内的 nf-fa-globe（f0ac）而不是
;;; Plane 15 的 nf-md-remote（f04b1）：后者要靠终端自己做字体回退，Ghostty 未必接。

(defconst flywind-modeline-glyph
  '((json . #xe60b) (yaml . #xe8eb) (toml . #xe615) (config . #xe615)
    (key . #xf084) (terminal . #xf120) (git . #xe702) (markdown . #xe73e)
    (code . #xf121) (docker . #xe7b0) (wrench . #xf0ad) (python . #xe73c)
    (ruby . #xe739) (go . #xe724) (rust . #xe7a8) (css . #xe749)
    (javascript . #xe781) (file-code . #xf1c9) (html . #xe736) (file . #xf15b)
    (folder . #xf07b) (branch . #xe0a0) (pencil . #xf040) (lock . #xf023)
    (remote . #xf0ac))
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

(defcustom flywind-modeline-hidden-minor-modes
  '(which-key-mode eldoc-mode hungry-delete-mode auto-revert-mode)
  "这些 minor mode 不在 mode line 上占位。
只列实测真的会出现在 mode line 里又不携带信息的：`WK'（which-key 一直开着）、
` h'（hungry-delete）、`ElDoc'（echo area 本来就在给文档）、`ARev'
（auto-revert-mode —— 它是 flywind-dired 里 global-auto-revert-mode 顺带开的，
每个 buffer 都挂一个，等于没有信息）。
volatile-highlights / whitespace / rainbow-mode 的 lighter 是可见文字（实测
` VHl' / ` ws' / ` Rbow'），归 flywind-ui.el 自己抹；rainbow-delimiters-mode 的
lighter 真的是空串，本来就不渲染，不用列在这里。"
  :type '(repeat symbol)
  :group 'flywind-modeline)

(defun flywind-modeline--hide-noise-lighters ()
  "抹掉 `flywind-modeline-hidden-minor-modes' 里所有已加载的 lighter。
动作本身在 flywind-basic.el 的 `flywind-hide-minor-mode-lighter'。
还没加载的由 `after-load-functions' 补：换掉 alist 只对该 mode 加载之后的
`minor-mode-alist' 生效，太早改是空转。"
  (interactive)
  (dolist (mode flywind-modeline-hidden-minor-modes)
    (flywind-hide-minor-mode-lighter mode)))

;; 用 bound-and-true-p 而不是裸 when：本 hook 在文件里就装上了，`flywind-modeline-mode'
;; 那个 symbol 要到文件后面的 define-minor-mode 才存在。启动期自动字节编译时，编译
;; 过程会加载别的 feature 并触发这个 hook —— 那时 symbol 还是 void，裸 when 直接报
;; “Symbol’s value as variable is void”，实测连带 8 个文件编译失败。
(add-hook 'after-load-functions
          (lambda (_file)
            (when (bound-and-true-p flywind-modeline-mode)
              (flywind-modeline--hide-noise-lighters))))

(defconst flywind-modeline-ascii-icon "?")
(defconst flywind-modeline-ascii-branch "@")
(defconst flywind-modeline-ascii-remote "~")
(defconst flywind-modeline-remote-max-width 28
  "远端标记里 method:user@host 的长度上限，超了截断加省略号。
/sudo::/etc/ 这类写法会由 tramp 补全本机主机名（实测补出来是
`root@shaogaoyangdeMac-mini-2.local' 这种四十来个字符的串），不设上限会把
mode line 挤没。")
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
     ;; 远端标记放最前：TRAMP / sudo 文件要先看见“改的是哪台机器”，再看文件名。
     (or (flywind-modeline--remote icons) "")
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

(defun flywind-modeline--remote (icons)
  "远端（TRAMP / sudoedit）buffer 的标记；本地 buffer 返回 nil。
标签是远端前缀去掉首尾冒号，形如 ssh:root@example.host，sudo 与 ssh 一眼分得开。
三处细节：
1. `file-remote-p' 对本地路径是纯字符串判断，实测调用之后 tramp 仍未被加载，
   所以这条不进启动路径；只有路径本身是远端语法时才加载它。
2. `/sudo::/etc/' 这种省略写法由 tramp 补全本机主机名，补出来的串带 text
   property（实测带 `tramp-default'），先抹 property 再用。
3. 补全出来的主机名实测四十来个字符，不设上限会把 mode line 挤没。"
  (when (and flywind-modeline-show-remote
             default-directory
             (file-remote-p default-directory))
    (let* ((remote (file-remote-p default-directory))
           ;; 整段前缀形如 /ssh:root@example.host: —— 去掉首尾的 / 与 : 就是标签。
           ;; 不取 method / user / host 三个分量：那两个要靠 tramp-methods 里的
           ;; 方法表，而表在 tramp-sh.el 里，没加载时 ssh: 这种写法只能拿到
           ;; method，标出来是「ssh:」这种没头没尾的东西（实测）。整段前缀不查表。
           (label (substring-no-properties
                   remote 1 (1- (length remote)))))
      (when (> (length label) flywind-modeline-remote-max-width)
        (setq label
              (concat (substring label 0 flywind-modeline-remote-max-width) "…")))
      (propertize
       (concat (flywind-modeline--glyph 'remote icons
                                        flywind-modeline-ascii-remote)
               " " label flywind-modeline-sep)
       'face 'flywind-modeline-remote))))

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
必须在加载时就存：等到开启时才存，一旦先关掉本模式，那时读到的已经是被本模块
改过的值了 —— 实测会把 mode line 设成 nil。")

;;;###autoload
(define-minor-mode flywind-modeline-mode
  "轻量 mode line。关掉回到 Emacs 默认那条。"
  :global t
  :lighter nil
  (if flywind-modeline-mode
      (progn
        (setq-default mode-line-format (flywind-modeline--format))
        (flywind-modeline--hide-noise-lighters))
    ;; 回到 Emacs 默认那条。
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
                 (cond
                  (flywind-modeline-mode "本模块")
                  (t "Emacs 默认"))
                 (if (flywind-modeline--icons-p) "开" "关（ASCII）")
                 flywind-modeline-icons)
         (format "单次渲染：%.1f us（%d 次平均，样例是 6 行 JSON 的 config.json）\n" us n)
         (format "片段数：%d\n\n样例行（config.json）：\n%s\n\n可调：\n"
                 (if (listp fmt) (length fmt) -1)
                 (replace-regexp-in-string "[\n\t]+" " " sample))
         "  flywind-modeline-icons            auto / t / nil\n"
         "  flywind-modeline-show-remote      远端来源（TRAMP / sudo）标记\n"
         "  flywind-modeline-show-vc          版本控制分支\n"
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
