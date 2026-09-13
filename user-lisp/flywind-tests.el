;;; flywind-tests.el --- 主题自动跟随的回归测试 -*- lexical-binding: t; -*-

;;; Commentary:

;; 这套用例守的是「主题按环境选浅色 / 深色」这条链路上的判定逻辑，包括几个
;; 静默失效过、或者一改就会复发的坑：
;;
;;   - Ghostty 不导出 COLORFGBG，而 `ghostty +show-config\' 又不跟随系统外观，
;;     两档主题（light:X,dark:Y）时必须看 macOS，静态配置时才看解析出的背景色。
;;   - 缓存按环境分格：浅色 Ghostty 与深色 iTerm 不能互相顶掉。
;;   - `after-focus-change-function\' 是单函数变量，只能 add-function；用
;;     add-hook 会把值 cons 成列表，启动期就报 Invalid function。
;;   - Emacs 31 的 `read\' 只接受一个参数，多传会被 ignore-errors 吞成「没缓存」。
;;
;; 跑法：
;;   M-x flywind-tests-run                       在正在用的 Emacs 里跑
;;   emacs --batch -l early-init.el -l init.el \
;;         --eval "(flywind-tests-run-batch)"    命令行跑，有失败则退出码 1
;;
;; 用例不碰真缓存：全程把 flywind-theme--cache-file 绑到临时文件；跑完把主题
;; 还原成跑之前的方向。

;;; Code:

(require 'cl-lib)
;; 测的就是这两个模块；不 require 进来的话编译期不认识它们的内部变量，会报一堆
;; "reference to free variable"，而且 let 绑定会被当成词法绑定。
(require 'flywind-ui)
(require 'flywind-modeline)
(require 'vc)
;; 本文件 lexical-binding 是 t：没被 defvar 标记成 special 的变量，let 只建词法
;; 绑定，被测函数读不到（实测分支解析因此静默返回 nil）。vc-mode 再 defvar 一次
;; 确保它是动态的。
(defvar vc-mode)

(defvar flywind-tests--pass 0 "本轮通过数。")
(defvar flywind-tests--fail 0 "本轮失败数。")

(defvar flywind-tests--skip 0 "本轮因环境不适而跳过的断言数。")

(defun flywind-tests--check (label want got)
  "断言 WANT 等于 GOT，不等就把差异打进结果缓冲。"
  (if (equal want got)
      (progn (cl-incf flywind-tests--pass) (princ (format "PASS %s\n" label)))
    (cl-incf flywind-tests--fail)
    (princ (format "FAIL %s\n     期望 %S\n     实得 %S\n" label want got))))

;; with-env 会把 getenv 整个换掉，所以先存下真函数，用例里要读真实环境值时走它。
(defvar flywind-tests--orig-getenv (symbol-function 'getenv)
  "在测试伪造 getenv 之前存下来的真函数。")

(defun flywind-tests--real-getenv (name)
  "绕过 with-env 的伪造，读一个真实环境变量的值。"
  (funcall flywind-tests--orig-getenv name))

(defmacro flywind-tests--with-env (env &rest body)
  "伪造一套环境信号。ENV 是 plist，例：:gui nil :term-program \"ghostty\"。
getenv 被整体换掉，其它名字转发给真的那个。"
  (declare (indent 1))
  (let* ((tp (plist-get env :term-program))
         (cf (plist-get env :colorfgbg))
         (tm (plist-get env :term))
         (gui (plist-get env :gui))
         (ghost (plist-get env :ghost)))
    `(cl-letf* (((symbol-function 'display-graphic-p)
                 (lambda (&rest _) ,gui))
                ((symbol-function 'getenv)
                 (lambda (name)
                   (cond ((equal name "TERM_PROGRAM") (and ,tp ,tp))
                         ((equal name "COLORFGBG") (and ,cf ,cf))
                         ((equal name "TERM") (or ,tm "xterm"))
                         ((equal name "GHOSTTY_BIN_DIR") nil)
                         (t (flywind-tests--real-getenv name)))))
                ((symbol-function 'flywind-theme--in-ghostty-p)
                 (lambda () ,(or ghost nil)))
                ((symbol-function 'flywind-theme--ghostty-binary)
                 (lambda () (and ,ghost "/fake/ghostty")))
                ((symbol-function 'flywind-theme--macos-appearance)
                 (lambda () 'dark)))
       ,@body)))


(defun flywind-tests--gout (theme bg iface)
  "拼一份 Ghostty 探测输出：配置段 + 分隔符 + AppleInterfaceStyle。"
  (concat (when theme (format "theme = %s\n" theme))
          (when bg (format "background = %s\n" bg))
          flywind-theme--iface-marker "\n" (or iface "")))
(defvar flywind-tests--ghostty-true nil
  "真环境（不伪造信号）下探测器该判成的方向，用于比对异步结果。")

(defun flywind-tests--probe-real ()
  "按真环境跑一次探测器，返回它该判成的方向。
用例里 with-env 会伪造 ghostty 路径，那条路只能验「起没起进程」，验不了判定。"
  (let* ((cmd (flywind-theme--probe-command))
         (out (and cmd (flywind-theme--run-probe-once))))
    (and cmd out (flywind-theme--parse-probe (car cmd) out))))

(defun flywind-tests-run ()
  "跑全套回归，返回 (通过数 . 失败数)；明细在 *flywind-tests*。"
  (interactive)
  (let* ((out (get-buffer-create "*flywind-tests*"))
         (orig-kind flywind-theme--current)
         (cache (make-temp-file "flywind-theme-cache" nil ""))
         (inhibit-read-only t))
    (setq flywind-tests--pass 0
          flywind-tests--fail 0
          flywind-tests--skip 0)
    (with-current-buffer out
      (erase-buffer)
      ;; 缓存指向临时文件：用例大量写缓存，绝不能污染 .local/cache 里真那份。
      (let ((flywind-theme--cache-file cache)
            (flywind-theme-force nil)
            (flywind-theme--probe nil))
        (unwind-protect
            (progn
  (princ "\n== A. 环境标识 ==\n")
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "GUI 是 gui" "gui" (flywind-theme--context-key)))
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app")
    (flywind-tests--check "终端带终端名" "tty:iTerm.app" (flywind-theme--context-key)))
  (flywind-tests--with-env (:gui nil :term-program nil :term "xterm-256color")
    (flywind-tests--check "没有 TERM_PROGRAM 用 TERM" "tty:xterm-256color"
               (flywind-theme--context-key)))

  (princ "\n== B. 缓存：分格、旧格式、往返 ==\n")
  (ignore-errors (delete-file flywind-theme--cache-file))
  (flywind-tests--with-env (:gui nil :term-program "ghostty")
    (flywind-theme--write-cache 'light)
    (flywind-tests--check "ghostty 格写 light 读回 light" 'light (flywind-theme--read-cache)))
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app")
    (flywind-tests--check "别的终端那格没被顶掉" nil (flywind-theme--read-cache))
    (flywind-theme--write-cache 'dark)
    (flywind-tests--check "iTerm 格写 dark"      'dark  (flywind-theme--read-cache)))
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "GUI 那格还是空的"     nil   (flywind-theme--read-cache))
    (flywind-theme--write-cache 'dark)
    (flywind-tests--check "GUI 格写 dark"        'dark  (flywind-theme--read-cache)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty")
    (flywind-tests--check "三格互不干扰（ghostty 仍 light）" 'light (flywind-theme--read-cache))
    (flywind-tests--check "表里三格齐全" 3 (length (flywind-theme--read-table)))
    (flywind-theme--forget-cache)
    (flywind-tests--check "forget 只抹本格" nil (flywind-theme--read-cache))
    (flywind-tests--check "另两格还在"     2 (length (flywind-theme--read-table))))
  ;; 旧格式：整文件一个 light/dark，按 gui 认。
  (with-temp-file flywind-theme--cache-file (insert "dark\n"))
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "旧格式按 gui 认" 'dark (flywind-theme--read-cache)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty")
    (flywind-tests--check "旧格式不会喂给终端格" nil (flywind-theme--read-cache)))
  (with-temp-file flywind-theme--cache-file (insert "不是一 Lisp 对象 {{{\n"))
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "内容不认识 -> nil，不报错" nil (flywind-theme--read-cache)))
  ;; 用一个同名普通文件挡住父目录：make-directory 会失败，写不进去也不该炸。
  (let* ((block (expand-file-name "fw2-blocked" temporary-file-directory)))
    (with-temp-file block (insert "我是个文件不是目录"))
    (let ((flywind-theme--cache-file (expand-file-name "theme" block)))
      (flywind-tests--check "读不了时返回 nil 而不是报错" nil (flywind-theme--read-cache))
      (flywind-tests--check "写不进去也只是没写成"       nil
                 (progn (flywind-theme--write-cache 'dark)
                        (flywind-theme--read-cache)))
      (ignore-errors (delete-file block))))

  (princ "\n== C. 背景色亮度 ==\n")
  (dolist (pair '(( "#eff1f5" . light)    ; Catppuccin Latte
                  ("#1e1e2e" . dark)      ; Catppuccin Mocha
                  ("#282c34" . dark)      ; Ghostty 默认
                  ("#ffffff" . light)
                  ("#000000" . dark)
                  ("#rgb"    . nil)       ; 非法十六进制
                  ("#12345"  . nil)       ; 位数不对
                  ("#abc"    . light)     ; 三位缩写（r=g=b -> 亮）
                  ("rgb:0000/0000/0000" . dark)
                  ("rgb:ffff/ffff/ffff" . light)
                  ("rgb:eff1/f5f5/f6ff" . light)
                  (""          . nil)
                  (nil         . nil)
                  ("黑色"      . nil)))
    (flywind-tests--check (format "背景 %S -> %S" (car pair) (cdr pair))
               (cdr pair) (flywind-theme--color-appearance (car pair))))

  (princ "\n== D. 探测输出解析 ==\n")
  ;; 两档主题：终端自己跟 macOS，所以看系统外观，不能信 +show-config 的背景色。
  (flywind-tests--check "light:/dark: + Dark -> dark" 'dark
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "light:Catppuccin Latte,dark:Catppuccin Mocha" "#eff1f5" "Dark")))
  (flywind-tests--check "light:/dark: + 浅色 -> light" 'light
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "light:Catppuccin Latte,dark:Catppuccin Mocha" "#eff1f5" "")))
  (flywind-tests--check "两档时配置里那个死背景色不参与判断" 'dark
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "dark:Mocha,light:Latte" "#eff1f5" "Dark")))
  ;; 静态配置：终端不跟系统，Emacs 必须跟终端，所以看背景色而不是 macOS。
  (flywind-tests--check "静态浅背景 + macOS 深色 -> 仍 light" 'light
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "Catppuccin Latte" "#eff1f5" "Dark")))
  (flywind-tests--check "静态深背景 -> dark"                'dark
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "Catppuccin Mocha" "#1e1e2e" "")))
  (flywind-tests--check "手写 background 覆盖也算静态"       'dark
             (flywind-theme--parse-probe 'ghostty (flywind-tests--gout nil "#1e1e2e" "")))
  ;; 只给一档不算「跟系统」：文档要求两档都给才自动切。
  (flywind-tests--check "只给 dark: 一档 -> 走静态背景色"    'light
             (flywind-theme--parse-probe 'ghostty
               (flywind-tests--gout "dark:Mocha" "#eff1f5" "Dark")))
  (flywind-tests--check "没有分隔符 -> 不猜"                nil
             (flywind-theme--parse-probe 'ghostty "background = #1e1e2e"))
  (flywind-tests--check "两段都空 -> 不猜"                  nil
             (flywind-theme--parse-probe 'ghostty
               (concat flywind-theme--iface-marker "\n")))
  (flywind-tests--check "config-value 取不到行返回 nil"     nil
             (flywind-theme--config-value "theme" "background = #000000\n"))
  (flywind-tests--check "config-value 去掉首尾空白"  "#eff1f5"
             (flywind-theme--config-value "background" "  background = #eff1f5  \n"))
  (flywind-tests--check "macos Dark -> dark" 'dark (flywind-theme--parse-probe 'macos "Dark"))
  (flywind-tests--check "macos 空输出 = 浅色" 'light (flywind-theme--parse-probe 'macos ""))
  (flywind-tests--check "macos nil = 浅色"   'light (flywind-theme--parse-probe 'macos nil))
  (flywind-tests--check "不认识的 source"    nil    (flywind-theme--parse-probe 'wat "Dark"))

  (flywind-tests--check "两档都给 -> 跟随系统"       t    (flywind-theme--ghostty-follows-system-p "light:a,dark:b"))
  (flywind-tests--check "顺序无关"                   t    (flywind-theme--ghostty-follows-system-p "dark:b,light:a"))
  (flywind-tests--check "只给一档 -> 静态"           nil  (flywind-theme--ghostty-follows-system-p "dark:Mocha"))
  (flywind-tests--check "只给 light: -> 静态"        nil  (flywind-theme--ghostty-follows-system-p "light:Latte"))
  (flywind-tests--check "单主题名 -> 静态"           nil  (flywind-theme--ghostty-follows-system-p "Catppuccin Mocha"))
  (flywind-tests--check "nil -> 静态"                nil  (flywind-theme--ghostty-follows-system-p nil))
  (flywind-tests--check "run-probe-once 无探测器时 nil" nil
             (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
               (flywind-theme--run-probe-once)))

  (princ "\n== E. COLORFGBG ==\n")
  (dolist (pair '(("12;8" . dark) ("0;7" . light) ("15" . light) ("7" . light)
                  ("9" . dark) ("0;15" . light) ("1;233" . dark) ("1;252" . light)
                  ("12" . dark) ("" . nil) ("a;b" . nil) ("12;" . nil)))
    (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg (car pair))
      (flywind-tests--check (format "COLORFGBG %S" (car pair))
                 (cdr pair) (flywind-theme--tty-appearance))))

  (princ "\n== F. 该用哪个探测器 ==\n")
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
    (flywind-tests--check "COLORFGBG 已给准数就不再探" nil (flywind-theme--probe-command)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :colorfgbg nil :ghost t)
    (flywind-tests--check "Ghostty 且没有 COLORFGBG -> 走合并探测（sh -c）"
               t (pcase-let ((`(,src ,exe . ,rest) (flywind-theme--probe-command)))
                   (and (eq src 'ghostty)
                        (stringp exe)
                        (equal (car rest) "-c")
                        (stringp (cadr rest))
                        (string-match-p "/fake/ghostty" (cadr rest))
                        (string-match-p "AppleInterfaceStyle" (cadr rest))
                        (and (string-match-p flywind-theme--iface-marker (cadr rest))
                             t)))))
  (flywind-tests--with-env (:gui t)
    (let ((r (flywind-theme--probe-command)))
      (flywind-tests--check "GUI -> macos" 'macos (car r))))

  (princ "\n== G. desired 的优先级 ==\n")
  (ignore-errors (delete-file flywind-theme--cache-file))
  (flywind-theme--write-cache 'dark "gui")
  (flywind-theme--write-cache 'light "tty:ghostty")
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "缓存说 dark" 'dark (flywind-theme--desired)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (flywind-tests--check "缓存说 light（没起进程）" 'light (flywind-theme--desired)))
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
    (flywind-theme--write-cache 'light "tty:iTerm.app")
    (flywind-tests--check "免费信号压过缓存" 'dark (flywind-theme--desired)))
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
    (let ((flywind-theme-force 'light))
      (flywind-tests--check "手动钉住压过一切" 'light (flywind-theme--desired))))
  (flywind-tests--with-env (:gui nil :term-program "weird-term" :colorfgbg nil)
    (ignore-errors (flywind-theme--forget-cache "tty:weird-term"))
    (let ((flywind-theme-probe-at-startup nil))
      (flywind-tests--check "没信号且不探 -> dark 兜底" 'dark (flywind-theme--desired))))

  (princ "\n== H. absorb-probe 的行为 ==\n")
  (ignore-errors (delete-file flywind-theme--cache-file))
  (flywind-theme--write-cache 'dark "tty:ghostty")
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (flywind-theme--apply 'dark)
    (flywind-theme--absorb-probe 'ghostty (flywind-tests--gout "Catppuccin Mocha" "#1e1e2e" ""))
    (flywind-tests--check "与缓存一致 -> 不写不换" 'dark (flywind-theme--read-cache))
    (flywind-theme--absorb-probe 'ghostty (flywind-tests--gout "Catppuccin Latte" "#eff1f5" ""))
    (flywind-tests--check "变了 -> 改写缓存"       'light (flywind-theme--read-cache))
    (flywind-tests--check "变了 -> 换主题" 'light flywind-theme--current)
    (flywind-theme--absorb-probe 'ghostty "没有那行")
    (flywind-tests--check "读不出方向 -> 什么都不动" 'light (flywind-theme--read-cache))
    (flywind-theme--absorb-probe 'unknown "Dark")
    (flywind-tests--check "来源不认识 -> 不动"       'light (flywind-theme--read-cache)))

  (princ "\n== I. 异步查证（真进程）==\n")
  ;; 真实 Ghostty 在当前配置下该判成哪个方向：跑同一条探测器命令、同一套解析规则。
  (setq flywind-tests--ghostty-true (flywind-tests--probe-real))
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
    (let ((flywind-theme--probe nil) (flywind-theme--last-check 0.0))
      (flywind-tests--check "有免费信号时不起进程" nil (flywind-theme--verify-async t))))
  ;; 真环境跑（这台机器就在 Ghostty 里）：不能用 with-env 伪造 binary，
  ;; 那样探测不到配置段，只能验证「起没起进程」，验不了方向。
  (if (not (flywind-theme--probe-command))
      (cl-incf flywind-tests--skip 3)
      (princ "SKIP 本环境有免费信号（COLORFGBG）或没有可用探测器，跳过真进程查证 3 条\n")
    (let ((flywind-theme--probe nil) (flywind-theme--last-check 0.0))
      (dolist (p (process-list))
        (when (equal (process-name p) "flywind-theme") (delete-process p)))
      (flywind-theme--verify-async t)
      (flywind-tests--check "真环境起了探测进程" t (processp flywind-theme--probe))
      (let ((n 0))
        (while (and flywind-theme--probe (< n 100))
          (accept-process-output nil 0.1) (cl-incf n)))
      (flywind-tests--check "哨兵会跑完并清掉句柄" nil flywind-theme--probe)
      (flywind-tests--check "哨兵把缓存写成真实方向" flywind-tests--ghostty-true (flywind-theme--read-cache))))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (let ((flywind-theme--probe nil) (flywind-theme--last-check (float-time)))
      (flywind-tests--check "限频：刚查过就跳过" nil (flywind-theme--verify-async))))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (let ((flywind-theme--probe nil) (flywind-theme--last-check 0.0)
          (flywind-theme-force 'dark))
      (flywind-tests--check "钉住时不起进程" nil (flywind-theme--verify-async t))))

  (princ "\n== J. start-watching 与焦点函数（回归：启动期 Invalid function）==\n")
  (flywind-tests--with-env (:gui nil :term-program "iTerm.app" :colorfgbg "12;8")
    (let ((flywind-theme--timer nil))
      (flywind-theme--start-watching)
      (flywind-tests--check "没有探测器就不装 timer" nil flywind-theme--timer)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (let ((flywind-theme--timer nil) (flywind-theme--last-check (float-time)))
      (flywind-theme--start-watching)
      (flywind-tests--check "Ghostty 里装 timer（它会随系统换配色）" t (timerp flywind-theme--timer))
      (when (timerp flywind-theme--timer) (cancel-timer flywind-theme--timer))
      ;; 启动立即核对：last-check 过期时才起进程，不等满一个轮询周期。
      (let ((flywind-theme--probe nil) (flywind-theme--last-check 0.0)
            (flywind-theme--focus-hooked t))
        (cl-letf (((symbol-function 'run-at-time) (lambda (&rest _) nil)))
          (flywind-theme--start-watching))
        (flywind-tests--check "缓存可能过期 -> 启动就异步核对一次" t (processp flywind-theme--probe))
        (when flywind-theme--probe
          (delete-process flywind-theme--probe)
          (setq flywind-theme--probe nil)))))
  (let ((flywind-theme--focus-hooked nil)
        (flywind-theme--timer nil)
        (before after-focus-change-function))
    (fset 'fw2-dummy-dm (lambda (&rest _) 'dm))
    (add-function :after after-focus-change-function (symbol-function 'fw2-dummy-dm))
    (flywind-tests--with-env (:gui t)
      (flywind-theme--start-watching)
      (flywind-tests--check "值仍是函数，没被 cons 成列表" t (functionp after-focus-change-function))
      (flywind-tests--check "调用它不报错" t (progn (funcall after-focus-change-function) t))
      (flywind-tests--check "已标记挂上"   t   flywind-theme--focus-hooked)
      (let ((n 0))
        (cl-letf (((symbol-function 'add-function)
                   (lambda (&rest _) (setq n (1+ n)))))
          (flywind-theme--start-watching))
        (flywind-tests--check "重复 start-watching 不再套一层" 0 n))
      (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
        (dolist (p (process-list))
          (when (equal (process-name p) "flywind-theme") (delete-process p)))
        (let ((flywind-theme--probe nil)
              (flywind-theme--last-check (float-time)))
          (cl-letf (((symbol-function 'frame-focus-state) (lambda (&rest _) nil)))
            (flywind-theme--on-focus))
          (flywind-tests--check "失焦不起进程" nil flywind-theme--probe))
        (let ((flywind-theme--last-check (float-time)))
          (cl-letf (((symbol-function 'frame-focus-state) (lambda (&rest _) t)))
            (flywind-theme--on-focus)
            (flywind-tests--check "聚焦但刚查过 -> 限频挡住" nil flywind-theme--probe)
            (setq flywind-theme--last-check 0.0)
            (flywind-theme--on-focus)
            (flywind-tests--check "聚焦且隔够了 -> 起进程" t (processp flywind-theme--probe)))
          (while flywind-theme--probe (accept-process-output nil 0.1)))))
    (remove-function after-focus-change-function (symbol-function 'fw2-dummy-dm))
    (remove-function after-focus-change-function (function flywind-theme--on-focus))
    (fmakunbound 'fw2-dummy-dm)
    (setq flywind-theme--focus-hooked nil)
    (flywind-tests--check "摘干净后仍是可调用函数" t (functionp after-focus-change-function))
    (flywind-tests--check "摘干净后调用仍不报错"   t (progn (funcall after-focus-change-function) t))
    (ignore-errors before))

  (princ "\n== K. 手动命令按环境分格 ==\n")
  (ignore-errors (delete-file flywind-theme--cache-file))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (flywind-theme--apply 'dark)
    (let ((flywind-theme--last-check (float-time)))
      (flywind-theme-toggle)
      (flywind-tests--check "toggle 换到 light" 'light flywind-theme--current)
      (flywind-tests--check "toggle 写进本格缓存" 'light (flywind-theme--read-cache))
      (flywind-tests--check "toggle 同时钉住"   'light flywind-theme-force)))
  (flywind-tests--with-env (:gui t)
    (flywind-tests--check "GUI 那格没被 Ghostty 的 toggle 污染" nil (flywind-theme--read-cache)))
  (flywind-tests--with-env (:gui nil :term-program "ghostty" :ghost t)
    (let ((flywind-theme--last-check 0.0) (flywind-theme--probe nil)
          ;; 这一段要看到「真的重新探了一次」，所以给一个跑得通的探测器，
          ;; 不用 with-env 里那个假 ghostty 路径（它必然失败）。
          (flywind-theme--probe-command-real
           (list 'macos (or (executable-find "defaults") "/nonexistent")
                 "read" "-g" "AppleInterfaceStyle")))
      (cl-letf (((symbol-function 'flywind-theme--probe-command)
                 (lambda () flywind-theme--probe-command-real)))
      (flywind-theme-follow-system)
      (let ((n 0))
        (while (and flywind-theme--probe (< n 60))
          (accept-process-output nil 0.1) (cl-incf n)))
      (flywind-tests--check "follow-system 丢掉钉住" nil flywind-theme-force)
      (flywind-tests--check "follow-system 抹掉本格缓存后重探出结果" t
                 (and (memq (flywind-theme--read-cache) '(light dark)) t)))))
  (princ "\n== L. mode line（flywind-modeline）==\n")
  (require 'flywind-modeline)
  (let ((orig-mode flywind-modeline-mode)
        (orig-impl flywind-modeline-implementation))
    (unwind-protect
        (progn
          ;; --- 图标映射：整名正则优先，扩展名其次 ---
          (dolist (pair '(("init.el" . code) (".gitignore" . git)
                          (".gitmodules" . git) (".gitconfig" . git)
                          ("config.json" . json) ("a.jsonc" . json)
                          ("a.yaml" . yaml) ("a.yml" . yaml)
                          ("x.toml" . toml) ("x.ini" . config) ("x.conf" . config)
                          (".editorconfig" . config) (".tmux.conf" . terminal)
                          (".bashrc" . terminal) (".env" . key) ("ssh_config" . key)
                          ("README.md" . markdown) ("a.py" . python) ("a.go" . go)))
            (flywind-tests--check (format "图标 %s -> %s" (car pair) (cdr pair))
              (cdr pair) (flywind-modeline--icon-name (car pair))))
          (dolist (n '("Brewfile" "*scratch*" "noextension"))
            (flywind-tests--check (format "无匹配 %s -> nil（走通用图标）" n)
              nil (flywind-modeline--icon-name n)))
          ;; 映射表里写错图标名是静默失效（码位查不到就不显示），拿码位表兜底查一遍。
          (flywind-tests--check "两张映射表的值都在码位表里" nil
            (let (miss)
              (dolist (p (append flywind-modeline-name-icons
                                 flywind-modeline-ext-icons))
                (unless (assq (cdr p) flywind-modeline-glyph)
                  (push (car p) miss)))
              miss))
          (flywind-tests--check "码位表全落在私用区（不是打错的 ASCII）" t
            (seq-every-p (lambda (p) (>= (cdr p) #xe000)) flywind-modeline-glyph))
          ;; --- 图标开关的退回 ---
          (flywind-tests--check "图标开着出单个码位" t
            (let ((g (flywind-modeline--glyph 'json t "?")))
              (and (stringp g) (= 1 (length g)) (= #xe60b (aref g 0)))))
          (dolist (case '((gui-font-t . t) (gui-font-unknown . t) (gui-font-nil . nil)))
            (flywind-tests--check
             (format "GUI 图标判定 %S -> %S（预期即 cdr=%S）" (car case) (cdr case) (cdr case))
             t
             (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                       ((symbol-function 'flywind-font-available-p)
                        (lambda (&optional _f)
                          (pcase (car case)
                            ('gui-font-t t)
                            ('gui-font-unknown 'unknown)
                            (_ nil)))))
               (let ((flywind-modeline-icons 'auto))
                 ;; 直接把判定值交给 check 比，别在这儿 eq 成布尔：
                 ;; want=nil 时 eq 出来的 t 反而对不上。
                 (let ((got (flywind-modeline--icons-p)))
                   (if (cdr case) (eq got t) (null got)))))))
          (flywind-tests--check "tty 下不看字体探测，直接开" t
            (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) nil))
                      ((symbol-function 'flywind-font-available-p)
                       (lambda (&optional _f) nil)))
              (let ((flywind-modeline-icons 'auto)) (flywind-modeline--icons-p))))
          (flywind-tests--check "图标关掉退回 ASCII 标记" "?"
            (flywind-modeline--glyph 'json nil "?"))
          (with-temp-buffer
            (rename-buffer "x.json")
            (let* ((flywind-modeline-icons nil)
                   (buffer-file-name "/tmp/x.json")
                   (s (flywind-modeline--identity)))
              (flywind-tests--check "ASCII 模式下不出私用区字符" nil
                (seq-some (lambda (c) (and (>= c #xe000) (<= c #xf8ff))) s))
              (flywind-tests--check "ASCII 模式仍带 buffer 名" t
                (and (string-match-p "x\\.json" s) t))))
          ;; --- 状态标记（未保存 / 只读）---
          (with-temp-buffer
            (rename-buffer "state.json")
            (let ((flywind-modeline-icons t)
                  (buffer-file-name "/tmp/state.json"))
              (flywind-tests--check "未修改时不带状态标记" nil
                (string-match-p "●\\|\\*\\|R" (flywind-modeline--identity)))
              (set-buffer-modified-p t)
              (flywind-tests--check "未保存出标记（● 或铅笔码位）" t
                (let ((id (flywind-modeline--identity)))
                  (or (and (string-match-p "●\\|\\*" id) t)
                      (seq-some (lambda (c) (= c #xf040)) id)))); 铅笔
              (set-buffer-modified-p nil)
              (setq buffer-read-only t)
              (flywind-tests--check "只读出标记（R 或 lock 码位）" t
                (let ((s (flywind-modeline--identity)))
                  (or (and (string-match-p "R" s) t)
                      (seq-some (lambda (c) (= c #xf023)) s))))))
          ;; --- buffer 名截断 ---
          (with-temp-buffer
            (rename-buffer (make-string 40 ?a))
            (let ((flywind-modeline-buffer-name-width 12)
                  (flywind-modeline-icons nil))
              (flywind-tests--check "buffer 名按宽度截断" t
                (<= (length (flywind-modeline--identity)) (+ 12 8)))))
          ;; --- 分支解析：不起 git，只剔 vc-mode 那根串 ---
          (flywind-tests--check "无 vc-mode 不出分支段" nil
            (let ((vc-mode nil)) (flywind-modeline--vc)))
          (dolist (case '((" Git-main" "main") (" Git:main" "main")
                          (" SVN1.7:trunk" "trunk") (" Git-main*" "main*")
                          (" Hg-default" "default")))
            (flywind-tests--check (format "分支 %S -> %s" (car case) (cadr case))
              t
              (let ((vc-mode (car case))
                    (flywind-modeline-show-vc t)
                    (flywind-modeline-icons nil))
                (and (stringp (flywind-modeline--vc))
                     (string-match-p (regexp-quote (cadr case))
                                     (flywind-modeline--vc))
                     t)))))
          (flywind-tests--check "关掉开关就不出分支段" nil
            (let ((vc-mode " Git-main") (flywind-modeline-show-vc nil))
              (flywind-modeline--vc)))
          ;; --- 编码与行尾：配置文件真正关心这个；%z 给出的是终端编码 ---
          (flywind-tests--check "没访文件不出编码段" nil
            (let ((buffer-file-name nil)) (flywind-modeline--coding)))
          (with-temp-buffer
            (setq-local buffer-file-name "/tmp/x.json")
            (dolist (case '((utf-8-unix "UTF-8" "LF")
                            (utf-8-dos "UTF-8" "CRLF")
                            (utf-8-mac "UTF-8" "CR")
                            (gb18030-unix "GB18030" "LF")))
              (flywind-tests--check
               (format "编码 %S -> %s / %s" (car case) (cadr case) (nth 2 case))
               t
               (let ((buffer-file-coding-system (car case)))
                 (setq buffer-file-coding-system (car case))
                 (let ((s (flywind-modeline--coding)))
                   (and (stringp s)
                        (string-match-p (cadr case) s)
                        (string-match-p (nth 2 case) s)
                        t)))))
          ;; --- 开关与还原：这里守 setq vs setq-default 那个坑 ---
          (flywind-tests--check "加载时抓住了 Emacs 默认那条" t
            (listp flywind-modeline--stock-format))
          (flywind-modeline-mode 1)
          (flywind-tests--check "开启后改的是全局默认值（不是当时那个 buffer）" t
            (let ((fmt (default-value 'mode-line-format)))
              (and (listp fmt)
                   (seq-some (lambda (e) (and (listp e) (eq (car e) :eval))) fmt)
                   (null (seq-position fmt "%e")))))
          (dolist (mode '(hungry-delete-mode which-key-mode eldoc-mode
                           auto-revert-mode))
            (flywind-tests--check
             (format "%s 的 lighter 已抹平" mode)
             t
             (let ((lighter (cdr (assq mode minor-mode-alist))))
               (and (member (if (stringp lighter) lighter (car-safe lighter))
                            '("" nil))
                    t))))
          ;; 格式里裸符号出现的意思是「取这个变量的值」，名字打错就静默少一段。
          (flywind-tests--check "格式里引用的内置变量都存在" nil
            (let (miss)
              (dolist (e (flywind-modeline--format))
                (when (and (symbolp e) (not (keywordp e)) (not (boundp e)))
                  (push e miss)))
              miss))
          (flywind-modeline-mode -1)
          (flywind-tests--check "关掉后回到 Emacs 默认那条" t
            (equal (default-value 'mode-line-format)
                   flywind-modeline--stock-format))
          ;; doom 档：包没装就算跳过，不算失败。
          (if (not (require 'doom-modeline nil t))
              (progn
                (cl-incf flywind-tests--skip 2)
                (princ "SKIP doom 档 2 条（本机没装 doom-modeline）\n"))
            (setq flywind-modeline-implementation 'doom)
            (flywind-modeline-mode 1)
            (flywind-tests--check "doom 档也给出非空 mode line" t
              (and (listp (default-value 'mode-line-format))
                   (bound-and-true-p doom-modeline-mode)))
            (flywind-modeline-mode -1)
            (flywind-tests--check "从 doom 档切回来不残留" t
              (equal (default-value 'mode-line-format)
                     flywind-modeline--stock-format))))
      (setq flywind-modeline-implementation orig-impl)
      (flywind-modeline-mode (if orig-mode 1 -1))))
            )
          (delete-file cache)
          ;; 用例里会 apply 主题，跑完还原成用户原本在看的方向。
          (when orig-kind (flywind-theme--apply orig-kind))))
      (princ (format "\n==== %d PASS / %d FAIL / %d SKIP ====\n"
                     flywind-tests--pass flywind-tests--fail
                     flywind-tests--skip))
      (when (> flywind-tests--skip 0)
        (princ "（SKIP 是环境不适而跳过的断言，不是失败；换到对应终端里跑就会执行）\n"))
      (special-mode)
      (goto-char (point-min)))
    (if (called-interactively-p 'interactive)
        (display-buffer out)
      (princ (with-current-buffer out (buffer-string))))
    (cons flywind-tests--pass flywind-tests--fail)))

(defun flywind-tests-run-batch ()
  "批处理入口：打印明细，有失败就以退出码 1 结束。"
  ;; 注意别拿 append 去接 flywind-tests-run 的返回值：它给的是 (通过数 . 失败数)
  ;; 这种非正规表，append 会直接 Wrong type argument: listp。
  (let* ((res (flywind-tests-run))
         (failed (cdr res)))
    (message "flywind-tests: %d PASS / %d FAIL / %d SKIP"
             (car res) failed flywind-tests--skip)
    (kill-emacs (if (> failed 0) 1 0))))

(provide 'flywind-tests)
;;; flywind-tests.el ends here
