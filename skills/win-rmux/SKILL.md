---
name: win-rmux
description: 在 Windows/pwsh 用 RMUX 新开终端窗口，把多个 agent（codex / kimi / claude code）放到同一终端的不同窗格里运行与驱动：新终端 + 多窗格布局（上 2 下 1）、send-keys/capture-pane、环境清理（NO_COLOR/TERM/PATH）、agent 状态判断原语、关闭退出。涉及 rmux/tmux 分屏或驱动调试 codex/kimi/claude 时使用。
compatibility: Windows 10/11 + PowerShell 7 + rmux（PATH 内）+ Windows Terminal（wt）
---

# win-rmux：新终端 + 同终端多窗格多 agent 操作

用途：作为 agent（Codex / Kimi / Claude Code）开一个新终端窗口，用 rmux 把多个 agent（如
codex、kimi、claude）放到同一个终端的不同窗格里，再通过 rmux 命令分别驱动。rmux 本体已在 PATH
（`rmux` 命令直接可用），wt 用 `Get-Command` 动态解析，**不要硬编码安装路径**。

## 核心流程：新开终端 + rmux 同终端多窗格

```powershell
# 0. 环境准备（关键，缺一不可）：
#    - 当前环境若带 NO_COLOR=1（Codex exec 沙箱必有），必须 Remove-Item，否则 agent 无色彩
#    - TERM=dumb 会让 rmux 客户端无色彩 → 设 xterm-256color
#    - PATH 按注册表重建（含 .local\bin），否则 claude /status 报 native 安装警告；
#      注意：重建会丢弃进程级临时 PATH 追加项，工具路径以注册表为准
# 0.1 旧 daemon 守卫：daemon 若由污染环境（含 NO_COLOR）启动，新窗格颜色仍会坏；
#     无保留会话时先 kill-server，让下面步骤用干净环境重启 daemon
if (Get-Process rmux -ErrorAction SilentlyContinue) {
    $left = rmux list-sessions 2>$null
    if (-not $left) { rmux kill-server }
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'
$env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 会话复用守卫：dev 已存在先杀掉，避免 new-session 报错后 split 追加出 dev:0.2，
#    破坏固定的 dev:0.0/dev:0.1 窗格索引
#    坑：不能写 `if (rmux has-session -t dev 2>$null)`，PowerShell 下 has-session 的
#    退出码判断不可靠（实测守卫未命中 → new-session duplicate → split 追加重复窗格）；
#    改用 list-sessions 输出做 -contains 判断
if (@(rmux list-sessions -F '#{session_name}' 2>$null) -contains 'dev') { rmux kill-session -t dev }

# 2. 建会话并分窗格：窗格 0 = codex，窗格 1 = claude（右侧；-d 新窗格不抢焦点）。
#    显式 -c：wt 新窗口默认 cwd 是 %USERPROFILE%，不继承调用方目录，必须指定工作目录
$wd = (Get-Location).Path
rmux new-session -d -s dev -c $wd 'codex'
rmux split-window -h -d -t dev -c $wd 'claude'

# 3. 弹新终端窗口 attach（-w new 强制新窗口；-d 指定目录；Minimized 最小化启动不抢主窗口焦点）
$wt = (Get-Command wt.exe).Source
$wtArgs = "-w new --title `"Codex + Claude`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -t dev`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 4. 等待窗口 attach（wt 启动 + pwsh + attach 约 1-2s），再检查/操作，避免竞态
Start-Sleep -Seconds 2
rmux list-clients          # [宽x高 term]：dumb=无色彩；detach-client -t <id> 重开
rmux send-keys -t dev:0.1 --wait quiet --stable-for 800ms --timeout 15s -- '/status' Enter
# codex/claude 是全屏 TUI（alternate screen），ConPTY 下 capture-pane 返回空——
# 验证改用 list-clients 的 term 标记、非 TUI 命令输出（claude -p）、stream-pane 或让用户目视
```

## 三席上 2 下 1 模板：codex + kimi + claude code

三席 = codex / kimi / claude code。上排 `codex | kimi`，下排 claude 全宽。关键在第三个
`split-window -f -v`（`-f` 全宽跨整窗），否则下排只落在半边。

```powershell
# 环境准备 + 会话复用守卫同上（略），然后：
$wd = (Get-Location).Path
rmux new-session -d -s dev -c $wd 'codex'
rmux split-window -h -d -t dev -c $wd 'kimi'
rmux split-window -f -v -d -t dev -c $wd 'claude'

# 验证：应为 0.0 codex / 0.1 kimi / 0.2 claude，且 0.2 的 top>0、left=0（下方全宽）
rmux list-panes -t dev -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command} top=#{pane_top} left=#{pane_left} w=#{pane_width} h=#{pane_height}"
# 弹窗 attach（同上）
```

实测窗格坐标：0.0 codex(top=0 left=0)、0.1 kimi(top=0 left=41)、0.2 claude(top=13 left=0 全宽)。

## 单 agent 变体：新窗口只开 claude（或 codex）

同构，仅命令与会话名不同；`new-session -A` 在会话已存在时直接 attach：

```powershell
if (Get-Process rmux -ErrorAction SilentlyContinue) {
    $left = rmux list-sessions 2>$null
    if (-not $left) { rmux kill-server }
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$wd = (Get-Location).Path
$wt = (Get-Command wt.exe).Source
$wtArgs = "-w new --title `"Claude Code`" -d `"$wd`" pwsh -NoProfile -Command `"rmux new-session -A -s claude -c `"$wd`" claude`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized
Start-Sleep -Seconds 2
rmux list-clients
```

## 恢复：wt 窗口关了，重新弹窗 attach 后台会话

关 wt 只是 detach，会话仍在后台 daemon。恢复 = 新 wt 窗口纯 attach，**不要用
`new-session -A`**（避免会话名拼错时误建新会话）；daemon 已在跑，**禁止 kill-server**
（会杀后台 agent）。

```powershell
# 0. 客户端环境清理（daemon 已在跑，不能 kill-server）
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

# 1. 确认会话状态：attached=0 表示已 detach，可安全 attach
rmux list-sessions -F "#{session_name} attached=#{session_attached}"

# 2. 弹新 wt 窗口 attach（-d 强制 detach 残留客户端，幂等；不抢主窗口焦点）
$wt = (Get-Command wt.exe).Source
$wd = (Get-Location).Path
$wtArgs = "-w new --title `"dev`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -d -t dev`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized

# 3. 等待后验证：term=xterm-256color 表示有色彩，attached=dev 表示已挂上
Start-Sleep -Seconds 2
rmux list-clients -F "#{client_name} term=#{client_termname} attached=#{client_session}"
```

区分：**恢复**用 `attach-session -d -t NAME`；**创建/恢复一体**（会话可能不存在）才用
`new-session -A -s NAME ...`。

## 会话 / 窗格基础（tmux 兼容）

```powershell
rmux new-session -d -s NAME -c <dir> 'cmd'   # 后台新会话（-c 显式指定工作目录）
rmux list-sessions                            # 会话列表
rmux has-session -t NAME                      # 会话是否存在（仅查询；复用守卫用 list-sessions -contains）
rmux attach-session -t NAME                   # 附加
rmux split-window -h -d -t NAME -c <dir> 'cmd' # 右侧分割（-v 上下；-d 不抢焦点）
rmux split-window -f -v -d -t NAME -c <dir> 'cmd' # -f 全宽/全高跨整窗分割（上2下1关键）
rmux list-panes -t NAME                       # 窗格列表
rmux list-windows -F "#{window_layout}"       # 当前布局字符串
rmux select-layout LAYOUT -t NAME             # 应用预设布局（even-horizontal/tiled 等）
rmux kill-session -t NAME                     # 关闭会话
rmux kill-pane -t %N                          # 关窗格（pane id 寻址）
rmux join-pane -s SRC -t TGT -h|-v|-f         # 重排：SRC 合并到 TGT
rmux swap-pane -s SRC -t TGT                  # 交换两窗格
rmux find-sessions / rmux find-panes          # 查找（含 pane id）
```

## send-keys：目标、`--` 分隔与提交原语

- `-t` 三种写法：会话名（`-t dev`）、`session:window.pane`（`-t dev:0.1`）、pane id（`-t %3`）
- 内容放 `--` 之后；回车键名 **只有 `Enter` 有效**（`C-m` 会被当字面量 `^M` 污染输入框，实测）
- **提交原语：发送后必须验证已提交**，不要盲目连发 Enter/C-m
- **中文 payload 会丢失/乱码**（实测产生 `server closed connection`）：驱动 prompt 用 ASCII/英文，或走 `claude -p` 管道传中文
- **tiny CLI 误报「can't find pane」**：Windows 包 = `rmux.exe`（tiny 分发器）+
  `libexec\rmux\rmux.exe`（full helper），设 `RMUX_DISABLE_TINY_CLI=1` 强制走 full helper 重试
- `--wait` 本版本只支持 `quiet`；`--wait-next-text` / `--wait-text` / `--wait-visible-text` 是独立参数

### Agent 状态判断原语（避免「没回车」反复踩坑）

1. **发送前就绪**：`RMUX_DISABLE_TINY_CLI=1` + `list-panes` 确认目标窗格存在（tiny CLI 会误报
   `can't find session/pane`），再 `Get-Process <agent>` 确认进程活着。
2. **非 TUI 提交判断**：`capture-pane -p` 看命令是否已执行（出现预期输出 = Enter 已提交）。
3. **TUI 提交判断**：codex/claude/kimi 全屏 TUI 的 capture 为空（alternate screen），改用
   **进程 CPU 增长**：发送前记 `$before=(Get-Process <agent>).CPU`，发送后 2-3s 记 `$after`，
   `$after - $before > 0.5` 表示已提交并开始处理；否则才补一次 `Enter`（只补 Enter，不补 C-m）。
4. **长 prompt 分步**：「发文本 → 判断 CPU/输入 → Enter」三步，避免一次连发吞键。

```powershell
rmux send-keys -t dev -- 'echo hi' Enter
rmux send-keys -t dev --wait quiet --stable-for 500ms --timeout 2m -- 'cargo test' Enter
```

等待语义（**避免盲 sleep，必配 `--timeout`**）：

- `--wait quiet`：等输出静默（构建/测试/未知结束文本的默认选择）
- `--wait-next-text TEXT` / `--wait-text TEXT`：等指定文本出现
- `--wait-visible-text TEXT`：等渲染可见文本
- `--wait-pane-exit`：一次性进程（预期退出）

## 读取输出

```powershell
rmux capture-pane -t dev -p              # 全量文本
rmux pane-snapshot -t dev                # 快照
rmux stream-pane -t dev --lines          # 增量输出
rmux wait-pane -t dev --quiet --timeout 30s
```

**TUI 限制（重要）**：codex/claude 等全屏 TUI 走 alternate screen，Windows ConPTY 下
`capture-pane` / `pane-snapshot` 返回空。验证改用：`list-clients` 的 term 标记、
非 TUI 命令输出（`claude -p`、普通命令）、`stream-pane`，或让用户目视窗格。

## 关闭 / 退出（前缀键 Ctrl+B，与 tmux 一致）

- 只离开不杀会话：`Ctrl+B d`（detach），会话保留可再 attach
- 关当前会话/窗格：窗格内 `exit`；`Ctrl+B x` 杀窗格（y 确认）、`Ctrl+B &` 杀窗口、`Ctrl+B :` 命令模式 `kill-session`
- 彻底关闭：`rmux kill-server`（杀 daemon 及全部会话/窗格）；验证 `Get-Process rmux` 为空
- daemon 在最后一个会话被杀后自动退出（实测）；kill-server 会终止所有窗格里的 agent

## 详细踩坑

完整实测记录（daemon 进程模型、NO_COLOR 根源、ConPTY 备屏限制、三组原语、关闭退出验证等）见
`references/rmux-usage.md`，三端（codex / kimi / claude）skill 与该文档同步维护。
