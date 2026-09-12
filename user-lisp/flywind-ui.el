;;; flywind-ui.el --- 外观与显示 -*- lexical-binding: t; -*-

;;; Commentary:
;;
;; 帧装饰、行号、字体/主题、括号与空白可视化。
;; Emacs 31 相关修正：
;;   * 废弃的 `window-system' 函数 -> `display-graphic-p'
;;   * 默认字体改 JetBrainsMono Nerd Font Mono（见 `flywind-font-family'），
;;     字号由 `flywind-font-height' 控制（默认 nil = 不改）
;;   * 去掉 `:fontset' face 属性与 `create-fontset-from-fontset-spec'（现代 Emacs 无效且重复调用会 error）
;;   * `write-file-functions' -> 内置 `delete-trailing-whitespace-mode'
;;   * whitespace 不再 auto-cleanup（31 起会顺带补 EOF 换行）
;;
;;; Code:

(eval-when-compile
  (require 'volatile-highlights)
  (require 'rainbow-delimiters)
  (require 'doom-themes)
  (require 'doom-modeline))

;; ---------------------------------------------------------------------------
;; 帧装饰
;; ---------------------------------------------------------------------------
(dolist (fn '(tool-bar-mode scroll-bar-mode menu-bar-mode))
  (when (fboundp fn)
    (funcall fn -1)))

(when (display-graphic-p)
  (setq frame-title-format
        '("%S" (buffer-file-name "%f" (dired-directory dired-directory "%b")))))

;; Emacs 31 在兼容终端默认开启 xterm-mouse-mode，这里显式关闭以免干扰 iTerm/tmux 选择。
(when (and (not (display-graphic-p)) (fboundp 'xterm-mouse-mode))
  (xterm-mouse-mode -1))

;; ---------------------------------------------------------------------------
;; 行号 / 列宽
;; ---------------------------------------------------------------------------
(setq-default fill-column 80)
(setq column-number-mode nil)

(defvar flywind-line-numbers-excluded-modes
  '(term-mode shell-mode eshell-mode dired-mode
              special-mode help-mode Custom-mode
              package-menu-mode completion-list-mode bookmark-bmenu-mode
              tabulated-list-mode custom-theme-edit-mode)
  "不显示行号的 major mode。")

(defun flywind--disable-line-numbers ()
  "按 `flywind-line-numbers-excluded-modes' 关闭当前 buffer 的行号。"
  (when (memq major-mode flywind-line-numbers-excluded-modes)
    (display-line-numbers-mode -1)))

(use-package display-line-numbers
  :ensure nil
  :custom
  (display-line-numbers-width 3)
  (display-line-numbers-grow-starting-width t)
  :config
  (global-display-line-numbers-mode 1)
  (add-hook 'after-change-major-mode-hook #'flywind--disable-line-numbers))

(use-package display-fill-column-indicator
  :ensure nil
  :hook (prog-mode . display-fill-column-indicator-mode))

;; tab
(setq-default tab-width 4)

;; ---------------------------------------------------------------------------
;; 字体（仅 GUI）
;; ---------------------------------------------------------------------------
;; 用 Nerd Font 的 Mono 变体，不是全宽变体：Mono 把图标字形按单格宽渲染，
;; 否则 doom-modeline / nerd-icons 的图标会占两格，把行宽与对齐撑坏。
(defcustom flywind-font-family "JetBrainsMono Nerd Font Mono"
  "默认字体家族（Emacs 看到的 family 名，不是文件名前缀）。
可选值参考：~/Library/Fonts 里的 JetBrainsMonoNerdFontMono-*.ttf 对应
“JetBrainsMono Nerd Font Mono”；JetBrainsMonoNerdFont-*.ttf 对应
“JetBrainsMono Nerd Font”（图标全宽，不建议）。设为 nil 则不动字体。"
  :type '(choice (const :tag "不设置" nil) (string :tag "字体家族"))
  :group 'faces)

(defcustom flywind-font-height nil
  "默认字号，单位 1/10 pt（140 即 14pt）。
nil 表示不改字号，沿用 Emacs 当前值：换字体只换字形，不顺手改掉尺寸。"
  :type '(choice (const :tag "保持当前字号" nil) (integer :tag "高度" 140))
  :group 'faces)

(defun flywind-font-available-p (&optional family)
  "探测 FAMILY（默认 `flywind-font-family'）是否存在。
返回 t（存在）/ nil（确定不存在）/ unknown（无法判定）。
字体探测在没显示后端时（batch、或 TUI 构建）会直接报错，而字体没装
时 font-info 只是返回 nil：两者必须分开，否则会把「无法探测」当成
「字体缺失」。"
  (and-let* ((fam (or family flywind-font-family)))
    (condition-case nil
        (cond
         ((fboundp 'font-available-family-p)
          (if (font-available-family-p fam 12.0) t nil))
         ((fboundp 'font-info)
          (let ((info (font-info (font-spec :family fam))))
            (if (and info (aref info 0)) t nil)))
         (t 'unknown))
      (error 'unknown))))

(defun flywind--apply-font (&optional frame)
  "把 `flywind-font-family' / `flywind-font-height' 作用到 FRAME（默认现有所有帧）。
只在探测到「确定没装」时才提示并保留默认字体；探测不了（无显示后端）
则照用户配置应用，不把「无法探测」当成「没装」。"
  (cond
   ((not (display-graphic-p frame)) nil)
   ((not flywind-font-family) nil)
   ((eq (flywind-font-available-p) nil)
    (warn "字体 %s 未安装，已沿用 Emacs 默认字体" flywind-font-family))
   (t
    ;; FRAME 为 nil 时 set-face-attribute 作用于所有帧。
    (set-face-attribute 'default frame :family flywind-font-family)
    (when flywind-font-height
      (set-face-attribute 'default frame :height flywind-font-height)))))

;; 启动时已经存在的那一帧直接改；之后创建的帧（包括 -nw 下后开的 GUI 帧）走 hook。
;; 不用 `after-init-hook'：它早于帧创建时改不到真正的那一帧。
(when (display-graphic-p)
  (flywind--apply-font))
(add-hook 'after-make-frame-functions #'flywind--apply-font t)

;; ---------------------------------------------------------------------------
;; org 表格字体（仅 GUI）
;; ---------------------------------------------------------------------------
(defcustom flywind-org-table-font-family nil
  "org 表格的等宽字体家族；nil 表示跟随 `flywind-font-family'。
中英混排的表格要列对齐，需要一款拉丁与 CJK 都按双宽等宽排布的字体
（Sarasa Fixed / Source Han Mono / Noto Sans Mono CJK SC）。本机目前
没装这类字体（Sarasa Fixed SC 已不存在，设上会在 org 加载时报
“Font not available”），故默认跟随默认字体。装好后把本变量改成它的
family 名就会自动生效。"
  :type '(choice (const :tag "跟随默认字体" nil) (string :tag "字体家族"))
  :group 'faces)

(defun flywind--apply-org-table-font ()
  "按 `flywind-org-table-font-family' 设 org-table 字体；字体缺失则不动并提示。
旧配置硬编码的是 “Sarasa Fixed SC 18”，该字体已不在这台机器上：
org 一加载就报 Font not available。这里改成先探测再设。"
  (let ((fam (or flywind-org-table-font-family flywind-font-family)))
    (if (flywind-font-available-p fam)
        (set-face-attribute 'org-table nil :family fam)
      (warn "org 表格字体 %s 未安装，org-table 沿用默认字体" fam))))

;; ---------------------------------------------------------------------------
;; 主题：跟随系统浅色 / 深色
;; ---------------------------------------------------------------------------
;; 为什么要自己写：Emacs 31 确实有个会「随系统主题变化自动更新」的变量
;; `toolkit-theme'，但它的 docstring 明写只在 PGTK / Android / MS-Windows 构建里
;; 赋值 —— macOS 的 ns 构建不在其列，ns-win.el 里也找不到任何读 NSAppearance 的
;; 代码。所以 Mac 上只能自己查：`defaults read -g AppleInterfaceStyle'，
;; 这个 key 只在深色模式下存在，取不到值就是浅色。
;;
;; 启动成本（预算 0.6s，本配置之前 0.16s）：启动路径上仍然一个子进程都不起。
;;   * GUI：先读上次结果（`.local/cache/theme-appearance'，纯文件读）立刻载主题，
;;     稳态下零子进程、也不会「先深后浅」闪一下；随后异步查证，
;;     真变了才重载并改写缓存。只有首次（无缓存）会同步查一次。
;;   * 终端：用 `COLORFGBG'（环境变量，零成本）。终端里 Emacs 管不到终端自己的
;;     配色板，所以只看它、不看 macOS：终端是浅色调色板时载深色主题很难看。
;;
;; `ns-appearance' 故意不设：不设时 macOS 自己管窗口边框和标题栏、跟着系统走；
;; 显式设成 dark / light 反而把边框钉死，从此与系统脱钩。

(defgroup flywind-ui nil
  "外观与主题。"
  :group 'convenience)

(defcustom flywind-theme-light 'doom-solarized-light
  "系统为浅色时加载的主题。doom-themes 里随便换个 -light 结尾的就行。"
  :type 'symbol
  :group 'flywind-ui)

(defcustom flywind-theme-dark 'doom-solarized-dark
  "系统为深色时加载的主题。"
  :type 'symbol
  :group 'flywind-ui)

(defcustom flywind-theme-force nil
  "手工指定方向：nil = 跟随环境（GUI 看 macOS，终端看 COLORFGBG）。\nlight / dark = 钉住不跟随；`flywind-theme-toggle' 写的就是这里。"
  :type '(choice (const :tag "跟随系统" nil) (const light) (const dark))
  :group 'flywind-ui)

(defcustom flywind-theme-check-interval 60
  "重新查证环境外观的秒数；0 = 不定时轮询，只在启动和焦点回来时查。\n终端也要查：Ghostty 用「theme = light:X,dark:Y」会随 macOS 实时换配色。"
  :type 'number
  :group 'flywind-ui)

(defcustom flywind-theme-probe-at-startup t
  "没有缓存时，允许在启动时同步查一次环境外观。
设成 nil 则第一次启动先按深色兜底，等后台查到再切（会看到一次主题跳变），
换来的是启动期绝不起子进程。有缓存之后两种设置都不起进程。"
  :type 'boolean
  :group 'flywind-ui)

(defcustom flywind-theme-light-luminance 128
  "终端背景亮度大于等于这个值就算浅色（0-255）。"
  :type 'integer
  :group 'flywind-ui)

(defvar flywind-theme--cache-file
  (expand-file-name "theme-appearance" flywind-cache-dir)
  "深浅判定的缓存，内容是按环境分格的 alist。
分格是因为同一个人可能一边开浅色 Ghostty、一边开深色 iTerm。
用 defvar 不用 defconst：一是路径得能让用户改，二是 defconst 会被编译期
当常量内联进去，测试就没法把它绑到临时文件上。")

(defvar flywind-theme--current nil
  "当前已加载的主题方向：light 或 dark。")

(defvar flywind-theme--probe nil
  "正在跑的查证进程；不为 nil 就不再开新的。")

(defvar flywind-theme--last-check 0.0
  "上次查证的时间戳，用来限频（焦点事件很密）。")

;; ---------------------------------------------------------------------------
;; 缓存：按环境分格，GUI 与每个终端各占一格
;; ---------------------------------------------------------------------------
(defun flywind-theme--context-key ()
  "当前环境的标识：GUI 是 gui，终端带上终端名。
共用一格会互相顶掉，所以浅色 Ghostty 和深色 iTerm 各记各的。"
  (if (display-graphic-p)
      "gui"
    (format "tty:%s" (or (getenv "TERM_PROGRAM") (getenv "TERM") "?"))))

(defun flywind-theme--read-table ()
  "读缓存文件，返回 ((KEY . KIND) ...)；文件没有或格式不认识返回 nil。"
  (when (file-readable-p flywind-theme--cache-file)
    (ignore-errors
      (with-temp-buffer
        (insert-file-contents flywind-theme--cache-file)
        (goto-char (point-min))
        ;; 只能一个参数：Emacs 31 的 read 不接受 EOF-ERROR 那一位，多传会直接
        ;; wrong-number-of-arguments，被外层 ignore-errors 吞掉就成了「没缓存」。
        (let ((form (condition-case nil (read (current-buffer))
                      (end-of-file nil))))
          (cond
           ((listp form) form)
           ;; 旧格式：整文件就一个 light/dark，那时候只有 GUI 用它，按 gui 认。
           ((memq form '(light dark)) (list (cons "gui" form)))
           (t nil)))))))

(defun flywind-theme--read-cache (&optional key)
  "读 KEY 这一格的缓存；没有返回 nil。"
  (cdr (assoc (or key (flywind-theme--context-key))
              (flywind-theme--read-table))))

(defun flywind-theme--write-cache (kind &optional key)
  "只更新 KEY 这一格，别的终端 / GUI 的判定保持原样。"
  (let* ((key (or key (flywind-theme--context-key)))
         (table (flywind-theme--read-table))
         (cell (assoc key table)))
    (if cell
        (setcdr cell kind)
      (setq table (cons (cons key kind) table)))
    (ignore-errors
      (make-directory (file-name-directory flywind-theme--cache-file) t)
      (with-temp-file flywind-theme--cache-file
        (insert (prin1-to-string table) "\n")))))

(defun flywind-theme--forget-cache (&optional key)
  "抹掉 KEY 这一格缓存，让下次启动重新探。"
  (let* ((key (or key (flywind-theme--context-key)))
         (table (flywind-theme--read-table))
         (cell (assoc key table)))
    (when cell
      (ignore-errors
        (with-temp-file flywind-theme--cache-file
          (insert (prin1-to-string (delq cell table)) "\n"))))))

;; ---------------------------------------------------------------------------
;; 信号源：GUI 看 macOS，Ghostty 读它当前生效的背景色，其它终端看 COLORFGBG
;; ---------------------------------------------------------------------------
(defun flywind-theme--tty-appearance ()
  "按 COLORFGBG 判断终端背景深浅，返回 dark 或 light；看不出来返回 nil。
格式是 fg;bg 或 fg;中间色;bg，取最后一段。色号含义：0-6 深色，7 浅灰，
8 深灰，9-14 饱和亮色（拿来做背景仍偏深），15 亮白；232+ 是灰阶，250 以上才算浅。
注意 Ghostty 压根不导出这个变量，只认它会在 Ghostty 里永远判成深色。
尾部分号（像 \"12;\"）认不出：不卡死尾字就会把前景色当背景用。"
  (when-let* ((cfbg (getenv "COLORFGBG"))
              ((string-match-p "[0-9]\\'" cfbg))
              (field (car (last (split-string cfbg ";" t))))
              ((string-match-p "\\`[0-9]+\\'" (or field ""))))
    (let ((bg (string-to-number field)))
      (cond
       ((>= bg 232) (if (>= bg 250) 'light 'dark))
       ((memq bg '(7 15)) 'light)
       (t 'dark)))))

(defun flywind-theme--component (group)
  "把一段十六进制折算成 0-255。2 位直读，1 位乘 17，3 位按 12 位色、
4 位按 16 位色折算（OSC 色彩应答用 4 位）。认不出返回 nil。"
  (when (and (stringp group) (string-match-p "\\`[0-9a-fA-F]+\\'" group))
    (let ((v (string-to-number group 16)))
      (pcase (length group)
        (1 (* v 17))
        (2 v)
        (3 (/ v 16))
        (4 (/ v 257))
        (_ nil)))))

(defun flywind-theme--color-appearance (spec)
  "按背景色 SPEC 判深浅，返回 light 或 dark；认不出来返回 nil。
吃 #rgb、#rrggbb 和 rgb:rrrr/gggg/bbbb 三种写法。"
  (let ((parts (cond
                ((and (stringp spec)
                      (string-match "rgb:\\([0-9a-fA-F]+\\)/\\([0-9a-fA-F]+\\)/\\([0-9a-fA-F]+\\)"
                                    spec))
                 (list (match-string 1 spec) (match-string 2 spec) (match-string 3 spec)))
                ((and (stringp spec) (string-match "#\\([0-9a-fA-F]\\{6\\}\\)\\'" spec))
                 (let ((h (match-string 1 spec)))
                   (list (substring h 0 2) (substring h 2 4) (substring h 4 6))))
                ((and (stringp spec) (string-match "#\\([0-9a-fA-F]\\{3\\}\\)\\'" spec))
                 (let ((h (match-string 1 spec)))
                   (list (substring h 0 1) (substring h 1 2) (substring h 2 3))))
                (t nil))))
    (when-let* ((vals (and parts (mapcar #'flywind-theme--component parts)))
                ((null (memq nil vals))))
      (if (>= (+ (* 0.299 (nth 0 vals)) (* 0.587 (nth 1 vals)) (* 0.114 (nth 2 vals)))
              flywind-theme-light-luminance)
          'light 'dark))))

(defun flywind-theme--in-ghostty-p ()
  "是否在 Ghostty 里跑。"
  (or (equal (getenv "TERM_PROGRAM") "ghostty")
      (string-match-p "ghostty" (or (getenv "TERM") ""))))

(defun flywind-theme--ghostty-binary ()
  "Ghostty 可执行文件路径；找不到返回 nil。
Ghostty 的 shell integration 会把自己那串目录塞进 PATH，但 Emacs 的 exec-path
是静态设的，未必看得到，所以按 环境变量 -> PATH -> 固定路径 依次兜底。"
  (let ((hint (getenv "GHOSTTY_BIN_DIR")))
    (or (when hint
          (let ((cand (expand-file-name "ghostty" hint)))
            (and (file-executable-p cand) cand)))
        (executable-find "ghostty")
        (let ((cand "/Applications/Ghostty.app/Contents/MacOS/ghostty"))
          (and (file-executable-p cand) cand)))))

(defun flywind-theme--macos-appearance ()
  "查 macOS 系统外观，返回 dark 或 light。
AppleInterfaceStyle 这个 key 只在深色模式下存在，所以读不到值就是浅色。"
  (when-let* ((exe (executable-find "defaults")))
    (with-temp-buffer
      (let ((inhibit-message t)
            (message-log-max nil))
        (process-file exe nil (current-buffer) nil "read" "-g" "AppleInterfaceStyle"))
      (if (string-match-p "Dark" (buffer-string)) 'dark 'light))))

(defconst flywind-theme--iface-marker "---FLYWIND-APPLE-INTERFACE---"
  "Ghostty 探测脚本里分隔两段输出的标记。")

(defun flywind-theme--shell-single-quote (s)
  "把字符串安全地塞进 shell 单引号里。" 
  (concat "'" (string-replace "'" "'\\''" s) "'"))

(defun flywind-theme--ghostty-probe-script (exe)
  "一条 shell：先给 Ghostty 生效配置里的 theme / background，再给分隔符，
最后给 AppleInterfaceStyle。为什么要带两段 —— 见 `flywind-theme--parse-ghostty'。"
  (format "%s +show-config 2>/dev/null | grep -E '^(theme|background)[[:space:]]*=' ; printf '%%s\\n' %s ; defaults read -g AppleInterfaceStyle 2>/dev/null ; true"
          (flywind-theme--shell-single-quote exe)
          (flywind-theme--shell-single-quote flywind-theme--iface-marker)))

(defun flywind-theme--probe-command ()
  "当前环境该用哪个探测器，返回 (SOURCE EXE ARGS...)；没得探返回 nil。
SOURCE 决定输出怎么读：macos 只看 AppleInterfaceStyle，ghostty 看配置结构。"
  (cond
   ((and (not (display-graphic-p)) (flywind-theme--tty-appearance)) nil)
   ((and (not (display-graphic-p)) (flywind-theme--in-ghostty-p))
    ;; 需要同时拿 Ghostty 配置和 macOS 外观，靠一个 shell 一次性输出，
    ;; 避免为了一次复查串两个子进程。
    (when-let* ((exe (flywind-theme--ghostty-binary))
                (sh (executable-find "sh")))
      (list 'ghostty sh "-c" (flywind-theme--ghostty-probe-script exe))))
   (t (when-let* ((exe (executable-find "defaults")))
        (list 'macos exe "read" "-g" "AppleInterfaceStyle")))))

;; ---------------------------------------------------------------------------
;; Ghostty 要分两种情形读，这是本题最容易踩的坑：
;;   theme = light:X,dark:Y   -> Ghostty 自己跟 macOS 换配色。此时
;;                               +show-config 的输出是死的：实测系统浅色、
;;                               深色两种情况下它都输出 light 那档的
;;                               #eff1f5。所以要看 macOS 外观，不能信它。
;;   只给一档 / 手写 background -> 配置是静态的，+show-config 的 background
;;                               就是终端真正的背景色，拿它算亮度。
;; 探测输出一律是「配置段 + 分隔符 + AppleInterfaceStyle」，见 probe-script。
;; ---------------------------------------------------------------------------
(defun flywind-theme--config-value (key text)
  "从 TEXT 里每行 KEY = VALUE 取 VALUE；没这行返回 nil。
逐行匹配是因为 Emacs 正则里 ^ 和 $ 不保证按行锚定。"
  (let ((found nil))
    (dolist (ln (split-string (or text "") "\n" t))
      ;; 匹配和取值必须用同一个串：拿修剪后的串匹配、却从原行取
      ;; match-string，遇到带缩进的配置偏移就会错位（读出来是 "= #eff1"）。
      (let ((line (string-trim ln)))
        (when (and (null found)
                   (string-match (format "\\`%s[ \t]*=[ \t]*\\(.*\\)\\'"
                                         (regexp-quote key))
                                 line))
          (setq found (string-trim (match-string 1 line))))))
    found))

(defun flywind-theme--ghostty-follows-system-p (theme)
  "theme 同时给了 light: 和 dark: 两档时，Ghostty 自己跟 macOS 换配色。
官方文档要求两档都给才会自动切；只给一档（如 dark:Mocha）属于静态配置。"
  (and (stringp theme)
       (string-match-p "light:" theme)
       (string-match-p "dark:" theme)
       t))

(defun flywind-theme--parse-ghostty (out)
  "把 Ghostty 探测输出 OUT 翻成方向；认不出返回 nil。
两段以 flywind-theme--iface-marker 分隔：前面是生效配置，后面是
AppleInterfaceStyle（键不存在 = 浅色）。"
  (when (and (stringp out)
             (string-match (regexp-quote flywind-theme--iface-marker) out))
    (let* ((conf (substring out 0 (match-beginning 0)))
           (iface (string-trim (substring out (match-end 0))))
           (theme (flywind-theme--config-value "theme" conf))
           (bg (flywind-theme--config-value "background" conf)))
      ;; 两档都给 = 终端自己跟系统；否则配置是死的，信它解析出的背景色。
      (if (flywind-theme--ghostty-follows-system-p theme)
          (if (string-match-p "Dark" iface) 'dark 'light)
        (flywind-theme--color-appearance bg)))))

(defun flywind-theme--parse-probe (source out)
  "按 SOURCE 把探测输出 OUT 翻成方向；认不出返回 nil。
macos 那条：进程跑成功但没输出 = AppleInterfaceStyle 不存在 = 浅色，
与 flywind-theme--macos-appearance 口径一致。ghostty 那条认不出返回 nil
——绝不把「没读到」当成某个方向。"
  (pcase source
    ('ghostty (flywind-theme--parse-ghostty out))
    ('macos (if (and out (string-match-p "Dark" out)) 'dark 'light))
    (_ nil)))

(defun flywind-theme--run-probe-once ()
  "同步跑一次当前环境的探测器，返回原始输出；没探测器或跑失败返回 nil。"
  (when-let* ((cmd (flywind-theme--probe-command))
              (exe (cadr cmd))
              (args (cddr cmd)))
    (let ((inhibit-message t)
          (message-log-max nil))
      (ignore-errors
        (with-temp-buffer
          (apply #'process-file exe nil (current-buffer) nil args)
          (buffer-string))))))

(defun flywind-theme--sync-probe ()
  "同步探一次并写回缓存，返回方向。只在没缓存时用一次，
拿一次子进程换掉一次主题跳变。"
  (let* ((cmd (flywind-theme--probe-command))
         (out (and cmd (flywind-theme--run-probe-once))))
    (when cmd
      (let ((kind (and out (flywind-theme--parse-probe (car cmd) out))))
        (when kind
          (flywind-theme--write-cache kind)
          kind)))))


(defun flywind-theme--instant-appearance ()
  "不花代价就能拿到的方向：终端看 COLORFGBG，GUI 没有这种免费信号。"
  (unless (display-graphic-p)
    (flywind-theme--tty-appearance)))

(defun flywind-theme--desired ()
  "该用哪个方向：手动钉住 > 免费信号 > 本格缓存 > 启动同步探一次 > 深色兜底。
链条前面几项都不起进程；只有第三项在第一次没缓存时才花一个进程。"
  (or flywind-theme-force
      (flywind-theme--instant-appearance)
      (flywind-theme--read-cache)
      (and flywind-theme-probe-at-startup (flywind-theme--sync-probe))
      'dark))

(defun flywind-theme--apply (kind)
  "把主题切到 KIND（light 或 dark）；已经是它就不动，免得白闪一下。"
  (let ((theme (if (eq kind 'light) flywind-theme-light flywind-theme-dark)))
    (unless (and (eq flywind-theme--current kind)
                 (memq theme custom-enabled-themes))
      ;; 先定行背景深浅，再选主题：内置 face 靠 background-mode 选配色。
      (setq frame-background-mode kind)
      (mapc #'frame-set-background-mode (frame-list))
      (dolist (th custom-enabled-themes)
        (disable-theme th))
      (load-theme theme t)
      (setq flywind-theme--current kind))))

(defun flywind-theme--source-label ()
  "当前这个深浅是谁定的，给人看的字符串。"
  (cond
   (flywind-theme-force "手动钉住")
   ((display-graphic-p) "macOS 系统外观")
   ((flywind-theme--tty-appearance) "COLORFGBG")
   (t (pcase (car (flywind-theme--probe-command))
        ('ghostty "Ghostty 配置（两档主题时看 macOS）")
        ('macos "macOS 系统外观")
        (_ "无可用信号（兜底深色）")))))

(defun flywind-theme--verify-async (&optional ignore-rate-limit)
  "异步探一次环境深浅；与缓存不一致才换主题。
被 flywind-theme-force 钉住、或当前环境没探测器时什么都不做。
焦点事件很密，所以靠 flywind-theme-check-interval 的十分之一限频。"
  (interactive)
  (when (and (null flywind-theme-force)
             (null flywind-theme--probe)
             (ignore-errors
               (or ignore-rate-limit
                   (> (- (float-time) flywind-theme--last-check)
                      (max 5 (/ flywind-theme-check-interval 10))))))
    (when-let* ((cmd (flywind-theme--probe-command))
                (source (car cmd))
                (exe (cadr cmd))
                (args (cddr cmd))
                (buf (get-buffer-create " *flywind-theme-probe*")))
      (setq flywind-theme--last-check (float-time))
      ;; 不能先 kill-buffer 再把那个对象传给 start-process：死 buffer 会让
      ;; sentinel 里的 (process-buffer proc) 取值报错，输出永远是 nil，
      ;; 于是每次查证都被误判。要清掉旧输出就 erase-buffer。
      (with-current-buffer buf (erase-buffer))
      (setq flywind-theme--probe
            (apply #'start-process "flywind-theme" buf exe args))
      (set-process-sentinel
       flywind-theme--probe
       (lambda (proc _event)
         ;; set-process-sentinel 不只结束时回调：启动时先来一个 run/open 事件，
         ;; 那时 buffer 是空的，直接读会把「输出为空」误判成浅色。所以只处理终态。
         (let ((status (process-status proc)))
           (when (memq status '(exit signal failed killed deleted))
             (setq flywind-theme--probe nil)
             (let* ((pbuf (process-buffer proc))
                    (out (and (memq status '(exit signal))
                              (buffer-live-p pbuf)
                              (ignore-errors
                                (with-current-buffer pbuf
                                  (string-trim (buffer-string)))))))
               (when (buffer-live-p pbuf) (kill-buffer pbuf))
               (cond
                ((eq status 'failed)
                 (message "flywind：探测环境外观失败（%s 起不来），保持原主题" exe))
                (t (flywind-theme--absorb-probe source out)))))))))))

(defun flywind-theme--absorb-probe (source out)
  "把探测器输出翻成方向并应用；与缓存一致就什么都不做。
翻不出方向（比如 Ghostty 输出里没有 background）就什么都不做，
绝不把「没读到」当成一个方向。"
  (let ((kind (flywind-theme--parse-probe source out)))
    (when kind
      (unless (eq kind (flywind-theme--read-cache))
        (flywind-theme--write-cache kind)
        (flywind-theme--apply kind)))))

(defvar flywind-theme--timer nil "定时查证的 timer。")

(defvar flywind-theme--focus-hooked nil
  "是否已经把复查挂上焦点函数。`add-function' 不会去重，靠这个变量防重复套。")

(defun flywind-theme--on-focus (&rest _)
  "焦点变化时顺手复查一次外观。
注意 `after-focus-change-function' 可能在 read-event 之类的任意上下文里被调，
Emacs 文档要求这里写得像 process filter 一样小心：只做一次带限频的判断，
真正的活交给异步进程。"
  (when (eq (ignore-errors (frame-focus-state)) t)
    (flywind-theme--verify-async)))

(defun flywind-theme--start-watching ()
  "启动后的跟踪：定时 + 焦点变化就复查。
终端也要跟：Ghostty 配了 light:/dark: 主题会随 macOS 实时换配色，只在看
启动快照的话就会一直停在错的底色上。没有可用探测器的环境（比如 COLORFGBG
已经给了准数的终端）就什么都不装，不白忙。
焦点这块必须用 `add-function'：`after-focus-change-function' 是单函数变量
（doom-modeline 也用 add-function 挂在上面），拿 add-hook 去加会把值 cons 成
列表，Emacs 再把它当函数调用 —— 结果是 (flywind-theme--verify-async #<...>)
这种 Invalid function，而且连 doom-modeline 的焦点刷新一起弄坏。"
  (when (flywind-theme--probe-command)
    (when (and (> flywind-theme-check-interval 0) (null flywind-theme--timer))
      (setq flywind-theme--timer
            (run-at-time flywind-theme-check-interval
                         flywind-theme-check-interval
                         #'flywind-theme--verify-async)))
    (when (and (null flywind-theme--focus-hooked)
               (fboundp (quote frame-focus-state)))
      (add-function :after after-focus-change-function
                    (function flywind-theme--on-focus))
      (setq flywind-theme--focus-hooked t)))
    ;; 启动后马上异步核对一次：缓存可能是上一个外观下留下的，等满一个轮询
    ;; 周期才纠正的话，中间这段时间主题就是错的。异步 = 不占启动时间。
    (flywind-theme--verify-async))

(defun flywind-theme-toggle ()
  "在浅色 / 深色之间手动切换，并钉住不再跟随环境。
钉住同时写进本格缓存，下次启动沿用；只影响当前这个环境（GUI 与每个终端
各算一格）。要恢复自动跟随：M-x flywind-theme-follow-system。"
  (interactive)
  (setq flywind-theme-force
        (if (eq (or flywind-theme--current (flywind-theme--desired)) 'dark)
            'light
          'dark))
  (flywind-theme--write-cache flywind-theme-force)
  (flywind-theme--apply flywind-theme-force)
  (message "主题钉在 %s（环境 %s；M-x flywind-theme-follow-system 恢复跟随）"
           flywind-theme-force (flywind-theme--context-key)))

(defun flywind-theme-follow-system ()
  "丢掉钉住和本格缓存，重新跟随环境。"
  (interactive)
  (setq flywind-theme-force nil)
  (flywind-theme--forget-cache)
  (flywind-theme--apply (flywind-theme--desired))
  (flywind-theme--verify-async t)
  (message "主题：%s（来源：%s）"
           (or flywind-theme--current "未定")
           (flywind-theme--source-label)))

(use-package doom-themes
  :demand t
  :config
  ;; 终端也载真主题（实测 18ms）：之前只有 GUI 有主题，emacs -nw 是裸 face。
  (flywind-theme--apply (flywind-theme--desired)))

(add-hook 'after-init-hook #'flywind-theme--start-watching)

;; ---------------------------------------------------------------------------
;; modeline 与 org 表格字体（保持只在 GUI）
;; ---------------------------------------------------------------------------
(when (display-graphic-p)
  ;; org 表格字体：见 `flywind-org-table-font-family'；只设一次，不动态改 fontset。
  (with-eval-after-load 'org
    (flywind--apply-org-table-font))

  (use-package doom-modeline
    :hook (after-init . doom-modeline-mode)
    :custom
    (doom-modeline-buffer-file-name-style 'relative-from-project)))

;; TTY 下的时间显示
(use-package time
  :ensure nil
  :unless (display-graphic-p)
  :custom
  (display-time-24hr-format t)
  (display-time-day-and-date t)
  :config
  (display-time-mode 1))

;; ---------------------------------------------------------------------------
;; 括号 / 高亮
;; ---------------------------------------------------------------------------
(use-package paren
  :ensure nil
  :custom
  (show-paren-delay 0.1)
  (show-paren-highlight-openparen t)
  (show-paren-when-point-inside-paren t)
  (show-paren-when-point-in-periphery t)
  :config
  (show-paren-mode 1))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package volatile-highlights
  :diminish volatile-highlights-mode
  :config
  (volatile-highlights-mode 1))

(use-package rainbow-mode
  :diminish rainbow-mode
  :hook ((emacs-lisp-mode . rainbow-mode)
         (css-mode . rainbow-mode)))

;; ---------------------------------------------------------------------------
;; 空白可视化（只提示，不改文件）
;; ---------------------------------------------------------------------------
(use-package whitespace
  :ensure nil
  :diminish whitespace-mode
  :hook ((prog-mode conf-mode) . whitespace-mode)
  :config
  ;; 31 起 whitespace-cleanup 会补 EOF 换行，配合 auto-cleanup 会静默改文件，
  ;; 故只做可视化；清理交给 delete-trailing-whitespace-mode。
  (setq whitespace-action nil
        whitespace-line-column fill-column
        whitespace-style '(face trailing space-before-tab
                              indentation empty space-after-tab)))

;; 保存时只删行尾空白（Emacs 31 内置，取代废弃的 write-file-functions）
(use-package simple
  :ensure nil
  :hook (prog-mode . delete-trailing-whitespace-mode))

;; ---------------------------------------------------------------------------
;; 杂项
;; ---------------------------------------------------------------------------
(fset 'yes-or-no-p 'y-or-n-p)
(setq inhibit-startup-screen t)

(defun flywind-theme-report ()
  "看一眼当前主题是按什么定的。
GUI 那条分支要在真的 Emacs.app 里跑才准；结果写进 *flywind-theme-report*。"
  (interactive)
  (require 'doom-themes nil t)
  (let* ((cmd (flywind-theme--probe-command))
         (gout (flywind-theme--run-probe-once))
         (gconf (and gout
                     (string-match (regexp-quote flywind-theme--iface-marker) gout)
                     (substring gout 0 (match-beginning 0))))
         (gtheme (and gconf (flywind-theme--config-value "theme" gconf)))
         (gbg (and gconf (flywind-theme--config-value "background" gconf)))
         (rows (list
                (format "环境：%s（缓存分格：%s）"
                        (if (display-graphic-p)
                            (format "GUI（%s）" window-system)
                          (format "终端 TERM=%s / TERM_PROGRAM=%s"
                                  (or (getenv "TERM") "?")
                                  (or (getenv "TERM_PROGRAM") "?")))
                        (flywind-theme--context-key))
                (format "钉住：%s" (or flywind-theme-force "无（跟随环境）"))
                (format "免费信号 COLORFGBG：%s -> %s"
                        (or (getenv "COLORFGBG") "（未设置）")
                        (or (flywind-theme--tty-appearance) "看不出来"))
                (format "macOS 外观：%s"
                        (or (flywind-theme--macos-appearance)
                            "查不到（非 macOS 或 defaults 不可用）"))
                (format "Ghostty theme：%s"
                        (or gtheme "不适用（不在 Ghostty 里 / 探测失败）"))
                (format "  两档都给（终端自己跟 macOS）：%s"
                        (if (flywind-theme--ghostty-follows-system-p gtheme)
                            "是 -> 看 macOS 外观，CLI 解析出的背景色不参与判断"
                          "否 -> 配置是静态的，用下面这个背景色算亮度"))
                (format "  配置里的 background：%s -> %s"
                        (or gbg "无")
                        (or (flywind-theme--color-appearance gbg) "不参与判断"))
                (format "可用探测器：%s"
                        ;; 探测命令第一项是符号（macos / ghostty），mapconcat 直接吃
                        ;; 会 wrong-type-argument，先统一转成字符串。
                        (if cmd
                            (mapconcat (lambda (x)
                                         (if (symbolp x) (symbol-name x) (format "%s" x)))
                                       cmd " ")
                          "无（只能靠免费信号或兜底）"))
                (format "缓存：%s\n  本格：%s\n  全部：%S"
                        flywind-theme--cache-file
                        (or (flywind-theme--read-cache) "无")
                        (or (flywind-theme--read-table) "空"))
                (format "本次应该用：%s（来源：%s）"
                        (flywind-theme--desired)
                        (flywind-theme--source-label))
                (format "当前已加载：%s（调色板 bg=%s，frame-background-mode=%S）"
                        (or custom-enabled-themes "无")
                        (ignore-errors (doom-color 'bg))
                        frame-background-mode)
                (format "跟踪：timer=%s，%s"
                        (if (timerp flywind-theme--timer) "已装" "未装")
                        (if (> flywind-theme-check-interval 0)
                            (format "轮询间隔 %d 秒" flywind-theme-check-interval)
                          "不轮询（只焦点复查）")))))
    (with-current-buffer (get-buffer-create "*flywind-theme-report*")
      (let ((inhibit-read-only t)
            (buffer-read-only nil))
        (erase-buffer)
        (dolist (row rows)
          (insert row "\n"))
        (special-mode)
        (goto-char (point-min)))
      (display-buffer (current-buffer)))))

(provide 'flywind-ui)
;;; flywind-ui.el ends here
