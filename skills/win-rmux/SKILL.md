---
name: win-rmux
description: 在 Windows/pwsh 用 RMUX 把 codex/kimi/claude（可扩展 pi/grok）放进一个「执行单元」同一终端多窗格里前台/后台远程驱动：launch/locate/drive/observe/judge/recover-close 六原语，上2下1 布局，yolo 免交互启动，send-keys/capture-pane，环境守卫。
compatibility: Windows 10/11 + PowerShell 7 + rmux（PATH 内）+ Windows Terminal（wt）
---

# win-rmux：一个执行单元里的多 agent 远程驱动

核心模型：

- **执行单元（Execution Unit）** = 一个 rmux 会话，承载 N 个 agent 各占一个 pane；默认 3 个 codex/kimi/claude，上 2 下 1。
- **两种模式**：`Visible=$true`（默认，前台弹 wt 可见）；`Visible=$false`（后台 headless 纯 rmux 驱动）。
- **六原语**：launch / locate / drive / observe / judge / recover·close。
- 寻址按 agent 名，不硬编码 pane 索引；未来加 pi/grok 只改 `$agents`。

## Agent 注册表（当前 3，可扩展）

```powershell
$unit    = 'execution-unit'    # 执行单元（Execution Unit）名，可覆盖
$Visible = $true     # 前台；$false = 后台

$agents = @(
  @{ name = 'codex';  cmd = 'codex';  args = @('--dangerously-bypass-approvals-and-sandbox', '--dangerously-bypass-hook-trust', '--no-alt-screen') }
  @{ name = 'kimi';   cmd = 'kimi';   args = @('--auto') }
  @{ name = 'claude'; cmd = 'claude'; args = @('--dangerously-skip-permissions') }
  # 未来：@{ name='pi'; cmd='pi'; args=@(...) }、@{ name='grok'; cmd='grok'; args=@(...) }
)
```

默认 pane 映射（按注册表顺序，都在 window 0）：`0.0=codex`、`0.1=kimi`、`0.2=claude`。

## 前置守卫（每次先跑）

```powershell
if (Get-Process rmux -ErrorAction SilentlyContinue) {
  if (-not (rmux list-sessions 2>$null)) { rmux kill-server }   # 污染 daemon 守卫
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
# agent 状态 hook 检测/安装（幂等；首次会写 codex/kimi/claude 的 hook 配置）
pwsh -NoProfile -File "$PSScriptRoot/scripts/install-agent-hooks.ps1"
```

hook 状态通道见 `references/hooks.md`；安装后 agent 会在 `working/blocked/idle` 变化时回写
`AGENT_STATE_<name>`，`judge` 用 `show-environment` 读取。

## launch：建执行单元

```powershell
$wd = (Get-Location).Path
if (@(rmux list-sessions -F '#{session_name}' 2>$null) -contains $unit) { rmux kill-session -t $unit }

# 第 1 个 agent
$argv = @('new-session','-d','-s',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[0].name)",$agents[0].cmd) + $agents[0].args
& rmux @argv
# 第 2 个：右侧 -h
$argv = @('split-window','-h','-d','-t',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[1].name)",$agents[1].cmd) + $agents[1].args
& rmux @argv
# 第 3 个：下全宽 -f -v（上2下1 关键）
$argv = @('split-window','-f','-v','-d','-t',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[2].name)",$agents[2].cmd) + $agents[2].args
& rmux @argv

if ($Visible) {
  $wt = (Get-Command wt.exe).Source
  $wtArgs = "-w new --title `"$unit`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -d -t $unit`""
  Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized
  Start-Sleep -Seconds 2
}
```

布局按 N：1=单 pane；2=`-h` 左右；3=上2下1；>3 前两个上排、其余 `-f -v` 往下全宽堆（待定）。

## locate：agent ↔ pane

```powershell
rmux list-panes -t $unit -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command} top=#{pane_top} left=#{pane_left} w=#{pane_width} h=#{pane_height}"
# 或：rmux find-panes --current-command codex
```

## drive：给指定 agent 发 prompt

```powershell
function Get-AgentPane([string]$name) {
  $i = [array]::IndexOf($agents.name, $name)
  if ($i -lt 0) { throw "unknown agent: $name" }
  "${unit}:0.$i"
}
$p = Get-AgentPane 'codex'
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -- '<ascii-prompt>' Enter
```

- 回车只有 `Enter`；`C-m` 是字面量 `^M`。
- 中文乱码：prompt 用 ASCII；含空格用 `-l` 字面量或拆 token + `Space`。
- 等待：`--wait quiet|--wait-text|--wait-next-text|--wait-visible-text|--wait-pane-exit` + `--stable-for` + `--timeout`。

## observe：读 agent 输出

```powershell
rmux capture-pane -t $p -p        # codex(--no-alt-screen) 或非 TUI 可读
rmux stream-pane -t $p --lines    # 流式
rmux pane-snapshot -t $p          # 快照
```

## judge：判断 agent 状态 / 是否已提交

首选读 hook 上报状态（需一次性安装 hook，见 `references/hooks.md`）：

```powershell
rmux show-environment -t $unit AGENT_STATE_codex   # idle | working | blocked（空=未上报）
```

回退（未装 hook 或旧 agent）：

- 就绪：`RMUX_DISABLE_TINY_CLI=1` + `list-panes` 确认 pane 在 + `Get-Process <cmd>` 进程活。
- 可 capture（如 codex `--no-alt-screen`）：`capture-pane -p` 看预期输出。
- TUI 备屏（claude/kimi）：进程 CPU 增长判提交：

```powershell
$before = (Get-Process claude -ErrorAction SilentlyContinue).CPU
rmux send-keys -t (Get-AgentPane 'claude') -- 'prompt' Enter
Start-Sleep -Seconds 2
$after = (Get-Process claude -ErrorAction SilentlyContinue).CPU
if ($after - $before -gt 0.5) { 'submitted' }
```

- claude/kimi 的 capture 为空是 alternate screen 正常现象，不是错误。

## recover / close

```powershell
# recover：前台重新弹 wt attach（关 wt 只是 detach，daemon/会话仍在）
$wtArgs = "-w new --title `"$unit`" -d `"$wd`" pwsh -NoProfile -Command `"rmux attach-session -d -t $unit`""
Start-Process -FilePath (Get-Command wt.exe).Source -ArgumentList $wtArgs -WindowStyle Minimized
# 不 new-session -A、不 kill-server

# close
rmux kill-session -t $unit     # 关执行单元
rmux kill-server               # 全关（杀 daemon 及所有 agent）
```

## 三 agent yolo / 去交互（--help + gh 源码已印证）

| agent | yolo 启动 | 运行中切换 | 免备屏 |
| --- | --- | --- | --- |
| codex | `--dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust` | — | `--no-alt-screen` ✅ |
| claude | `--dangerously-skip-permissions` | — | ❌ |
| kimi | `--auto`（或 `-y`） | `/yolo on` | ❌ |

- 首选启动即免交互；若仍阻塞：kimi 发 `/yolo on` + `Enter`；codex/claude 审批键通常 `y`/`n`。
- one-shot 非交互：`codex exec '<p>'` / `claude -p '<p>'` / `kimi -p '<p>'`（kimi `-p` 不能与 `-y` 组合）。

## 关键踩坑

完整实测（daemon 进程模型、NO_COLOR 根源、ConPTY 备屏、关闭退出等）见
`references/rmux-usage.md`；命令/扩展/格式/环境/键位/选项全量见 `references/README.md`。
