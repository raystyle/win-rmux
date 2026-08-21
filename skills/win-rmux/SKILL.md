---
name: win-rmux
description: 在 Windows/pwsh 用 RMUX 把 codex/kimi/claude（可扩展 pi/grok）放进一个「执行单元」同一终端多窗格里前台/后台远程驱动：launch/locate/drive/observe/judge/recover-close 六原语，上2下1 布局，yolo 免交互启动，send-keys/capture-pane，环境守卫。
compatibility: Windows 10/11 + PowerShell 7 + rmux（PATH 内）+ Windows Terminal（wt）
---

# win-rmux：一个执行单元里的多 agent 远程驱动

## 环境约束（全程）

- **仅使用 pwsh（PowerShell 7）**：所有命令、脚本、hook、wt 内启动一律用 `pwsh`；
  **禁用 `powershell.exe`（5.1）与 cmd**。rmux 会话默认 shell 设为
  `C:\Program Files\PowerShell\7\pwsh.exe`（见 `references/options.md`）。

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
# 指定本 skill 安装目录（脚本内联执行时 $PSScriptRoot 为空，必须显式给出）。
# 例：C:\Users\<user>\.claude\skills\win-rmux（Claude）、~\.codex\skills\win-rmux（Codex）等
$SkillDir = 'C:\Users\ray\.claude\skills\win-rmux'   # ← 按本机安装路径填
if (Get-Process rmux -ErrorAction SilentlyContinue) {
  if (-not (rmux list-sessions 2>$null)) { rmux kill-server }   # 污染 daemon 守卫
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
# User 环境变量同步（宿主常不加载 User env，agent 会缺 DEEPSEEK_API_KEY 等 API key；
# 必须 dot-source，子进程调用无效）
. "$SkillDir/scripts/refresh-user-env.ps1"
# agent 状态 hook 检测/安装（幂等 + 路径感知；首次会写 codex/kimi/claude 的 hook 配置）
pwsh -NoProfile -File "$SkillDir/scripts/install-agent-hooks.ps1"
```

> `$PSScriptRoot` 仅在 `.ps1` 文件内定义；守卫作为「粘贴运行」片段在交互 pwsh 执行时其为空，
> 必须改用显式 `$SkillDir`（2026-08-21 三 agent review 一致指出）。

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
# 目标 pane 校验：确认当前启动命令即该 agent（防 respawn 重排/崩溃后错位）
if ((rmux list-panes -t $p -F '#{pane_current_command}' 2>$null) -notmatch 'codex') {
  Write-Warning "target pane $p cmd 非 codex，先 locate 确认再 drive"
}
# 先发文本、再单独发 Enter（实测 Enter 与文本同发会被吞，不提交）；
# -l 走字面量，含空格/特殊字符的 prompt 才不被 token 化截断
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -l -- '<ascii-prompt>'
rmux send-keys -t $p -- Enter
```

- 回车只有 `Enter`；`C-m` 是字面量 `^M`。**Enter 必须单独一次 send-keys 发**（与文本同发实测不提交，codex/kimi 均踩到）。
- 中文乱码：prompt 用 ASCII；含空格用 `-l` 字面量或拆 token + `Space`。
- 等待：`--wait quiet|--wait-text|--wait-next-text|--wait-visible-text|--wait-pane-exit` + `--stable-for` + `--timeout`。

## observe：读 agent 输出

```powershell
rmux capture-pane -t $p -p        # codex(--no-alt-screen) 或非 TUI 可读
rmux stream-pane -t $p --lines    # 流式
rmux pane-snapshot -t $p          # 快照
```

### TUI 备屏的文件产物获取（claude/kimi 等备屏 TUI）

claude/kimi 走 alternate screen，`capture-pane -a`/`-H`/`pane-snapshot` 均返回
空（实测 `no alternate screen`），终端的 scrollback 历史也无法从外部回读——长回复、
review 结论等**超过一屏的产物会永久丢**。可靠做法是让 agent 把结论**写进文件**再读文件
（2026-08-21 三 agent review 实测）：

```powershell
# 1. 指示 agent 把产物写到工作区某个路径（prompt 用 ASCII；文件用绝对路径）
$writePrompt = 'Write your full review to D:\win-rmux\reviews\review-kimi.md (markdown). Set-Content -Path D:\win-rmux\reviews\review-kimi.md -Value (content). Reply "WRITTEN" when done.'
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -- $writePrompt
rmux send-keys -t $p -- Enter
# 2. 轮询文件出现（judge 状态回 idle 或文件存在）
while (-not (Test-Path 'D:\win-rmux\reviews\review-kimi.md')) { Start-Sleep -Seconds 15 }
# 3. 直接读文件内容（不经 rmux，产物完整持久）
```

- agent 写入用 `Set-Content`（pwsh，符合环境约束）；写错时目录要先 `New-Item -ItemType Directory -Force`。
- 备屏 TUI 的当前帧 capture 仍可读到少量尾部（判定完成用 hook 状态 `idle` 或文件存在，更稳）。
- 发送指令时若 pane 仍 `working`，`--wait quiet` 会超时（send-keys 报 timed out）——超时后补发一次 `Enter` 即可，指令已入缓冲区，agent 完成后会执行。

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
# 同样走两段式：先文本(-l)再单独 Enter，与 drive 规则一致
rmux send-keys -t (Get-AgentPane 'claude') -l -- 'prompt'
rmux send-keys -t (Get-AgentPane 'claude') -- Enter
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

2026-08-21 实测新增：

- **宿主 job object 阻止 rmux daemon**：CI/agent 宿主把命令包在 job object 里时，
  `new-session -d` 启动独立 daemon 报 `os error 5`（`Windows refused to launch an
  independent RMUX daemon`）。解法：把整套 launch 命令放进 **wt 窗口内执行**（wt 是
  UWP 应用，进程树脱离 job），daemon 由 wt 内的 pwsh 启动；之后 client 命令
  （send-keys / capture-pane / list-panes 等）在宿主侧照常可用。
- **首次进入新目录的信任提示**：codex/kimi 对新目录会弹「Do you trust this
  directory?」交互确认，yolo 参数不绕过。解法：capture 检测到提示后 send-keys 选信任
  （codex `1` + Enter；kimi 高亮项直接 Enter）；codex 可在 config.toml
  `[projects.'<path>'] trust_level = "trusted"` 预置永久信任。
- **codex 的 Stop hook 不上报 idle**：`UserPromptSubmit→working` 正常，`Stop→idle`
  实测不触发（kimi/claude 正常），异常中断后状态会卡 `working`。judge codex 用进程
  CPU 回退，或手动 `rmux set-environment -t $unit AGENT_STATE_codex idle` 清理。
- **respawn-pane 有崩溃风险**：`respawn-pane -k` 重启 codex 实测会崩溃退出，pane 被
  移除后布局自动重排（如 kimi 顶到全宽）。恢复：在现存 pane 左侧
  `split-window -h -b` 插回 agent 还原上 2 下 1。
