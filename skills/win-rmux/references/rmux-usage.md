# RMUX 正确用法研究（gh 调研 + 本机实测）

> 2026-08-19，来源：Helvesec/rmux v0.10.0（README、docs/integrations/claude-code.md、docs/man/rmux.1、resources/claude/skills/rmux/SKILL.md）+ 本机 Windows 10 实测。

## 结论

- RMUX 是 Rust 写的 tmux 兼容终端复用器（105 个命令），Windows 原生 ConPTY，无需 WSL
- 本机部署：`D:\ohmyenv\rmux`（ohmyenv 管理，已前置 PATH）。Windows 包 = `rmux.exe`（tiny CLI 分发器）+ `libexec\rmux\rmux.exe`（full helper），两者必须同目录保留
- 配置读取顺序：`%XDG_CONFIG_HOME%\rmux\rmux.conf` → `~/.rmux.conf` → `%APPDATA%\rmux\rmux.conf` → `%RMUX_CONFIG_FILE%`；无配置时按 best-effort 解析 `tmux.conf`（`RMUX_DISABLE_TMUX_FALLBACK=1` 关闭）
- 官方提供 Claude Code skill（`rmux claude install-skill` 装到 `%USERPROFILE%\.claude\skills\rmux`），项目级双端 skill 已在本仓库落地（`.claude/skills/rmux` + `.agents/skills/rmux`）

## 常用命令（实测可用）

```powershell
rmux new-session -d -s NAME -c D:\path
rmux split-window -h -t 1:0 -c D:\path 'cmd'   # 右分屏；-v 上下
rmux list-sessions / rmux find-panes
rmux capture-pane -t NAME -p
rmux pane-snapshot -t NAME
rmux kill-pane -t %N / kill-session -t NAME
```

## 会话 / 窗格 / 布局三组原语（2026-08-19 实测定稿）

### 会话（session）

```powershell
rmux new-session -d -s NAME -c <dir> 'cmd'   # 后台建会话（-c 显式工作目录）
rmux new-session -A -s NAME -c <dir> 'cmd'   # 存在则 attach，不存在则建（单 agent 变体）
rmux list-sessions                            # 会话列表
rmux has-session -t NAME                      # 存在性检查（复用守卫）
rmux attach-session -t NAME                   # 附加
rmux kill-session -t NAME                     # 关单个会话（daemon 与其他会话保留）
rmux kill-server                              # 杀 daemon + 全部会话/窗格
```

### 窗格（pane）

```powershell
rmux list-panes -t NAME -F "#{window_index}.#{pane_index} #{pane_id} top=#{pane_top} left=#{pane_left} w=#{pane_width} h=#{pane_height}"
rmux split-window -h -d -t NAME -c <dir> 'cmd'      # 右侧分割（-v 上下；-d 不抢焦点）
rmux split-window -f -v -d -t NAME -c <dir> 'cmd'   # -f 全宽/全高跨整窗分割
rmux kill-pane -t %N
rmux join-pane -s SRC -t TGT -h|-v|-f               # 把 SRC 合并到 TGT（重排）
rmux swap-pane -s SRC -t TGT                        # 交换两窗格
```

窗格寻址三种写法：会话名（`-t dev`）、`session:window.pane`（`-t dev:0.1`）、
pane id（`-t %3`）。

### 布局（layout）

查看当前布局字符串：`rmux list-windows -F "#{window_layout}"`

应用预设布局：`rmux select-layout LAYOUT -t NAME`（LAYOUT 取值按 tmux 约定，如
`even-horizontal` / `even-vertical` / `main-horizontal` / `tiled`）。

**上 2 下 1（本机实测验证）**：

```powershell
rmux new-session -d -s NAME 'cmd0'          # 窗格 0 全屏
rmux split-window -h -d -t NAME 'cmd1'      # 右侧分割 → 上排两个
rmux split-window -f -v -d -t NAME 'cmd2'   # -f 全宽下方分割 → 下排一个
```

关键在第三个 `-f`（full）：让垂直分割跨整个 window 宽度；不加 `-f` 只会在当前 pane
下方半边再分，得到「左上 + 右上 + 右下」而非全宽下排。

实测 layout 字符串：

```text
eb8e,80x24,0,0[80x12,0,0{40x12,0,0,6,39x12,41,0,7},80x11,0,13,8]
```

对应 pane 坐标：

```text
0.0 top=0 left=0  w=40 h=12   # 左上
0.1 top=0 left=41 w=39 h=12   # 右上
0.2 top=13 left=0 w=80 h=11   # 下方全宽
```

即「上 2 下 1」。三窗格并排（错误做法）的 layout 是横向三列，可用上面模板重建修正。

## 恢复 attach（wt 窗口关闭后，实测）

关 wt 只是 detach：attached client 退出，daemon + 会话保留，`list-sessions` 显示
`attached=0`、`list-clients` 为空。恢复 = 新 wt 窗口纯 `attach-session`，不要
`new-session -A`（避免会话名拼错时误建新会话），也绝不能 `kill-server`（会杀后台 agent）。

```powershell
# 0. 客户端环境清理（daemon 已在跑，不可 kill-server）
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 确认已 detach（attached=0、无 client）
rmux list-sessions -F "#{session_name} attached=#{session_attached}"
rmux list-clients

# 2. 弹新 wt 窗口 attach（-d 强制 detach 残留客户端，幂等；Minimized 不抢主窗口焦点）
$wt = (Get-Command wt.exe).Source
$wd = (Get-Location).Path
$wtArgs = "-w new --title `"dev`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -d -t dev`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 3. 验证：attached=dev、term=xterm-256color（有色彩）
Start-Sleep -Seconds 2
rmux list-clients -F "#{client_name} term=#{client_termname} attached=#{client_session}"
```

`attach-session -d` 的 `-d` = detach other clients before attaching，即使会话还挂着
残留客户端也能强制抢回，避免「session already attached」报错。

## 关闭 / 退出 rmux（实测）

进程模型（`Get-CimInstance Win32_Process` 实测）：真正的 daemon 是
`libexec\rmux\rmux.exe --__internal-daemon <管道>`（本机 PID 21912），
所有会话/窗格/PTY/滚动缓冲都在 daemon 内；用户终端是 attached client
（`libexec\rmux\rmux.exe` 无参，PID 15896）；外层还有 tiny CLI `rmux.exe`（PID 14900）。
命名管道 `\\.\pipe\rmux-...` 是客户端与 daemon 的 IPC 通道。

三个退出层级（前缀键默认 `Ctrl+B`，与 tmux 一致）：

1. **只离开不杀会话（detach）**：`Ctrl+B d`（或 `Ctrl+B D` 选客户端）→ 回到外层终端，
   daemon 与会话全部保留，之后 `rmux attach-session -t 0` 回来。外部命令行可用
   `rmux detach-client -a`（注意：会断开所有客户端）。
2. **关掉当前会话/窗格**：窗格内 shell 输入 `exit`（或 `Ctrl+D`），最后一个窗格关闭后
   会话结束；快捷键 `Ctrl+B x`（杀窗格，y 确认）、`Ctrl+B &`（杀窗口）、
   `Ctrl+B :` 后输入 `kill-session`。外部 `rmux kill-session -t NAME` 实测只影响目标会话，
   daemon 与其他会话原样存活。
3. **彻底关闭 rmux**：`rmux kill-server`（无参数）→ 杀 daemon 及全部会话/窗格/PTY。
   也可在 `Ctrl+B :` 命令模式输入 `kill-server`。验证：`Get-Process rmux` 无残留、
   命名管道消失。兜底：`Stop-Process -Name rmux -Force`（或 `rmux-daemon.exe`）。

注意：本项目 Codex（左窗格）与 claude（右窗格）都跑在会话 0 内，kill-server 或关闭最后
一个会话会同时终止两侧进程；detach 不会。

## 独立终端窗口运行 claude（不开窗格，实测）

适用：不想在 Codex 主窗口分屏，弹一个独立 Windows Terminal 窗口给 claude，从这边用
rmux 命令驱动。正确链路是 **wt 窗口 → rmux → claude**：窗口自己跑 `rmux new-session -A`
（会话存在则 attach，不存在则创建并运行 claude），daemon 由窗口环境启动。

```powershell
# 0. 关键：清掉 Codex 沙箱环境注入的污染
#    - NO_COLOR=1 会一路传给 daemon→窗格→claude，把颜色全禁掉（必须 Remove-Item，置空无效）
#    - TERM=dumb 会让 rmux 客户端无色彩 → 设为 xterm-256color
#    - 重建 PATH（含 .local\bin），否则 claude /status 会报 native PATH 警告
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'
$env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 弹独立 wt 窗口（-w new 强制新窗口；-WindowStyle Minimized 最小化启动不抢 Codex 焦点；
#    wt 路径动态解析，勿硬编码 WindowsApps）
$wt = (Get-Command wt.exe).Source
$wtArgs = '-w new --title "Claude Code" -d D:\ohmypwsh pwsh -NoProfile -Command "rmux new-session -A -s claude -c D:\ohmypwsh claude"'
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 2. 从这边操作（同窗格套路）
rmux list-clients                          # 检查 [宽x高 term] 标记：dumb=无色彩
rmux send-keys -t claude --wait quiet --stable-for 800ms --timeout 15s -l -- '/status'
rmux send-keys -t claude -- Enter          # Enter 单独发（与文本同发会被吞）
rmux capture-pane -t claude -p
```

补充：
- **wt 新窗口默认 cwd 是 `%USERPROFILE%`，不继承调用方 cwd**：弹窗命令必须显式
  `wt ... -d <目录>`，rmux 建会话/分窗格要显式 `-c <目录>`（Claude Code review 实测确认）。
- **会话复用守卫**：`rmux has-session -t dev` 存在时先 `kill-session -t dev`，否则
  `new-session`（无 -A）报错后 `split-window` 会静默追加 dev:0.2，破坏固定窗格索引。
- **旧 daemon 污染守卫**：daemon 若由含 NO_COLOR 的环境启动，新窗格颜色仍会坏——
  `Get-Process rmux` 有进程且 `list-sessions` 无保留会话时先 `kill-server` 再走干净环境。
- **send-keys 提交原语**：发送后 capture 验证输入行已清空/出现处理指示，未提交补发 `Enter`；
  长 prompt 分「发文本 → 检查 → Enter」避免吞键（Claude Code review 时实测踩到）。
- **无色彩的真正根因是 NO_COLOR=1**（Codex 沙箱注入），不是客户端 TERM：早期流程
  「Codex 侧 `new-session -d` 预建会话 + wt 再 attach」会把 NO_COLOR 带进 daemon → claude 单色；
  改为窗口直接 `new-session -A` 并 `Remove-Item Env:NO_COLOR` 后恢复彩色（实测确认）。
- **NO_COLOR/TERM 无法靠 Codex 配置关闭**：Codex unified exec 把 `UNIFIED_EXEC_ENV` 常量表
  （`NO_COLOR=1`、`TERM=dumb`、`LANG/LC_*=C.UTF-8`、`PAGER=cat`、`CODEX_CI=1` 等）硬编码注入每个
  exec 子进程，且在该进程 `shell_environment_policy`（exclude/set/filters）构建之后才覆写
  （源码 `codex-rs/core/src/unified_exec/process_manager.rs`）；`sandbox_mode=danger-full-access`
  只关隔离，不影响这套环境注入。因此只能在工作流层清理（启动命令里 `Remove-Item Env:NO_COLOR` + 设 TERM）。
- daemon 生命周期：最后一个会话被 kill 后 daemon 自动退出（实测 `kill-session` 末会话后
  `list-sessions` 报 no server running）。
- 旧窗口需要重开时，`rmux detach-client -t <client-id>` 断开后 wt 标签页自动关闭
  （attach 进程退出 → 默认 closeOnExit graceful）。
- 实测 /status 零警告：重建 PATH（含 `.local\bin`）后 claude 读到正确 PATH。

## Claude Code review 结论（2026-08-19，双端 skill 互相校验）

让 Claude Code（rmux 窗格内）review 双端 rmux skill：确认双文件字节一致、核心语法全部
对二进制实测通过（`new-session -A/-d/-s`、`split-window -h -d -t`、`send-keys -t dev:0.1
--wait quiet`（quiet 是本版唯一 wait 模式）、`--stable-for`/`--timeout`、窗格寻址
`dev:0.0/dev:0.1` 实测往返成功、`find-sessions`/`find-panes`/`pane-snapshot`/`stream-pane`/
`wait-pane` 不在 list-commands 但均可用）。已按 review 修复：单 agent 变体补回 `-c`/`-d`
（cwd 错误）、TUI 窗格 capture-pane 返回空的内联提示、会话复用守卫、旧 daemon 守卫、
list-clients 竞态等待、`--wait-text` 补齐、tiny CLI 结构说明、PATH 重建副作用注释。

## 踩坑（实测沉淀）

1. **send-keys 目标**：`-t` 接受会话名 / `session:window.pane` / pane id（`%N`），payload 必须放在 `--` 之后，键名 `Enter`/`Down`/`Up`/`C-c`。
2. **tiny CLI 误报「can't find pane」**：默认 `rmux.exe`（tiny 分发器）对部分目标解析失败；设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper 可解（本次实测 `-t 1` 在 tiny 下报错、full helper 下 exit 0）。
3. **`--wait` 本版本只支持 `quiet`**（`--wait-next-text`/`--wait-visible-text` 是独立参数，不是 `--wait` 的值）；等待必须配 `--timeout`，避免盲 sleep。
4. **Windows ConPTY 备屏捕获限制**：Claude Code 等全屏 TUI 走 alternate screen，rmux 0.10 `capture-pane`/`pane-snapshot` 返回空（`capture-pane -a` 报 no alternate screen），无法从外部读取 TUI 渲染内容；键可发（`broadcast-keys`/`send-keys`），但输入通道对 TUI 窗格不稳定（偶发 `server closed connection before a complete response frame arrived`）。
5. **`rmux claude`（teammate 模式）**：自动传 `--teammate-mode tmux` 并注入私有 tmux shim；内层会话 socket 每实例随机（`-L` 无法预知），外层命令看不到内层会话；TUI 内容同样不可捕获。调试建议改用 `claude -p`（纯文本可捕获）或让用户目视窗格。
6. **发送键到未知窗格有副作用**：`send-keys` 目标错误会把键注入错误的 pane（实测曾把 echo 打进其他 agent 会话输入框）。发送前先 `find-panes` 确认目标。
7. **中文输入经 send-keys 丢失/乱码**：对 Claude Code 窗格发中文 payload（如 `-- '只回复"连接正常"' Enter`）时输入框不显示内容，且产生 `server closed connection before a complete response frame arrived`（乱码字节打到 API）；同一窗格英文 payload 立即正常。驱动 claude 的 prompt 先用 ASCII/英文，或先 `claude -p` 走管道传中文。
8. **回车键名只有 `Enter` 有效**：`C-m` 会被当字面量 `^M` 发送（实测 pwsh 输入框出现 `echo B^M` 未执行，而 `Enter` 正常提交输出）；发送后不要盲目连发 Enter/C-m。TUI agent（codex/claude/kimi）的完整帧 capture 为空（仅尾部少量状态行可读），提交判断优先用**尾部状态 busy/ready**（见 SKILL「关键踩坑」），进程 CPU 增长只作辅助——CPU 对 claude 深度思考阶段不可靠，会误报未提交进而触发重发/排队。

## 与本项目的关系

- 双端 skill：`.claude/skills/rmux/SKILL.md`（Claude Code 项目级）与 `.agents/skills/rmux/SKILL.md`（Codex 项目级，仓库根向上扫描）内容同源
- Claude Code 的 statusline 命令经 `pwsh` 运行，与 rmux 无直接依赖；rmux 用于分屏调试
