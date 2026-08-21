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
$env:RMUX_DISABLE_TINY_CLI = '1'   # 探针/操作统一走 full helper，规避 tiny CLI 误报（防止空报误触发 kill-server）
if (Get-Process rmux -ErrorAction SilentlyContinue) {
  if (-not (rmux list-sessions 2>$null)) { rmux kill-server }   # 污染 daemon 守卫
}
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
# PATH 以 Machine+User 为准（去宿主污染），进程独有条目（本会话新装/临时加的）追加保留不丢弃
$mu = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$env:Path = (($mu -split ';') + ($env:Path -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
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

> **默认从 wt 窗口内启动 daemon**（2026-08-21 修正）。CI/agent 宿主常把命令包进 job object，
> 会阻止独立 rmux daemon（`new-session -d` 报 `os error 5`）；wt 是 UWP，进程树脱离 job，
> 把整套 launch 放进 wt 内执行即稳定。launcher **不要**含 `attach-session`（否则 wt 卡前台），
> 建好后宿主 `locate` 复核，`Visible` 时单独 recover 弹 attach。

最简示意（完整 launcher 脚本见 `references/rmux-usage.md`）：

```powershell
# 1. 弹 wt（宿主在 job object 内必须走这步）跑 launcher：new-session + split-window -h + split-window -f -v
Start-Process (Get-Command wt.exe).Source -ArgumentList "-w new --title `"$unit-launch`" -d `"$wd`" pwsh -NoProfile -File `"<launcher.ps1绝对路径>`"" -WindowStyle Minimized
Start-Sleep -Seconds 10
rmux list-panes -t $unit -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command}"   # locate 复核
# 2. 布局：3 = 上 2 下 1；2 = -h 左右；1 = 单 pane；>3 前两个上排、其余 -f -v 全宽下堆
```

- `$wd`（宿主侧）与 launcher 内的 `$wd` 是两份独立副本——两处都要给 `(Get-Location).Path`。
- 宿主不在 job object 内（普通交互终端）时，可直接宿主 pwsh 跑 launcher body（更轻），失败
  报 `os error 5` 则回退 wt 启动。
- launcher body 只含环境守卫（PATH/NO_COLOR/TERM），**用户 env 同步与 hook 安装仍要先跑一次
  前置守卫**（否则 agent 缺 API key、judge 无 hook 状态）。

## locate：agent ↔ pane

```powershell
rmux list-panes -t $unit -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command} top=#{pane_top} left=#{pane_left} w=#{pane_width} h=#{pane_height}"
# 或：rmux find-panes --current-command codex
```

## drive：给指定 agent 发 prompt（严格流程）

> **必守**：drive 不是「发完就走」，必须做「提交确认」——发文本后**必须**验证它已真正进入
> agent 处理（否则 prompt 停在输入框，agent 没开始）。三 agent 均实测：文本+Enter 同发会被吞。
> 完整四步严格流程 + 出错排查见 `references/troubleshooting.md`（drive 相关坑的速查）。

```powershell
function Get-AgentPane([string]$name) {
  $i = [array]::IndexOf($agents.name, $name)
  if ($i -lt 0) { throw "unknown agent: $name" }
  "${unit}:0.$i"
}
$p = Get-AgentPane 'codex'
# 目标 pane 校验（display-message 按单一 pane 解析；list-panes -t <sess>:0.0 是 window 作用域会误报）
if ((rmux display-message -p -t $p -F '#{pane_current_command}' 2>$null) -notmatch 'codex') {
  Write-Warning "target pane $p cmd 非 codex，先 locate 确认再 drive（禁止盲发）"
}
# 发文本（-l 字面量防截断）→ 单独 Enter 提交 → 必须 capture 验证 prompt 已离开输入框：
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -l -- '<ascii-prompt>'
rmux send-keys -t $p -- Enter
rmux capture-pane -t $p -p   # 若见 `up to edit queued` / prompt 仍在输入框 → Enter 被吞，单独重发 Enter
```

- 回车只有 `Enter`；`C-m` 是字面量 `^M`。**Enter 必须单独一次 send-keys 发**（与文本同发实测不提交）。
- 中文乱码：prompt 用 ASCII（通篇英文），含空格用 `-l` 字面量或拆 token + `Space`。
- 等待：`--wait quiet|--wait-text|--wait-next-text|--wait-visible-text|--wait-pane-exit` + `--stable-for` + `--timeout`。
- **`--wait quiet` 超时 ≠ 未发送**（指令可能已入输入框待提交）——**此时严禁重发同一条 prompt**
  （会排队两次执行两遍）；按上面 capture 验证只补 Enter，若已排队多份先 `C-c` 清队列。详见
  `references/troubleshooting.md`。

## observe：读 agent 输出

```powershell
rmux capture-pane -t $p -p        # codex(--no-alt-screen) 或非 TUI 可读
rmux stream-pane -t $p --lines    # 流式；持续阻塞输出（实测不自行退出），勿前台裸跑——配超时或放后台/job
rmux pane-snapshot -t $p          # 快照
```

### TUI 备屏的文件产物获取（claude/kimi 等备屏 TUI）

claude/kimi 走 alternate screen，`capture-pane -a`/`-H`/`pane-snapshot` 均返回
空（实测 `no alternate screen`），终端的 scrollback 历史也无法从外部回读——长回复、
review 结论等**超过一屏的产物会永久丢**。可靠做法是让 agent 把结论**写进文件**再读文件
（2026-08-21 三 agent review 实测）：

```powershell
# 1. 指示 agent 把产物写到工作区某个路径（prompt 用 ASCII；文件用绝对路径）
$targetName = 'kimi'   # 目标 agent 名（须与 $p 对应；下面诊断按它读 AGENT_STATE_<name>）
$writePrompt = 'Write your full review to D:\win-rmux\reviews\review-kimi.md (markdown). Set-Content -Path D:\win-rmux\reviews\review-kimi.md -Value (content). Reply "WRITTEN" when done.'
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -l -- $writePrompt
rmux send-keys -t $p -- Enter
# 2. 轮询文件出现（judge 状态回 idle 或文件存在）；加超时上限防永久挂起
$deadline = (Get-Date).AddMinutes(3)
while (-not (Test-Path 'D:\win-rmux\reviews\review-kimi.md') -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 15 }
if (-not (Test-Path 'D:\win-rmux\reviews\review-kimi.md')) {
  Write-Warning "文件超时未出现：capture=$((rmux capture-pane -t $p -p 2>$null) -join ' ') state=$(rmux show-environment -t $unit "AGENT_STATE_$targetName" 2>$null)"
}
# 3. 直接读文件内容（不经 rmux，产物完整持久）
```

- agent 写入用 `Set-Content`（pwsh，符合环境约束）；写错时目录要先 `New-Item -ItemType Directory -Force`。
- 备屏 TUI 的当前帧 capture 仍可读到少量尾部（判定完成用 hook 状态 `idle` 或文件存在，更稳）。
- 发送指令时若 pane 仍 `working`，`--wait quiet` 会超时（send-keys 报 timed out）——
  **超时 ≠ 未发送**，处置见上文「drive：给指定 agent 发 prompt（严格流程）」步骤 4：先查
  queued messages，不要盲目补发（补发可能造成重复排队执行两遍）。

## judge：判断 agent 状态 / 是否已提交

首选读 hook 上报状态（需一次性安装 hook，见 `references/hooks.md`）：

```powershell
rmux show-environment -t $unit AGENT_STATE_codex   # idle | working | blocked（空=未上报）
```

回退（未装 hook 或旧 agent）：

- 就绪：`RMUX_DISABLE_TINY_CLI=1` + `list-panes` 确认 pane 在 + `Get-Process <cmd>` 进程活。
- 可 capture（如 codex `--no-alt-screen`）：`capture-pane -p` 看预期输出。
- TUI 备屏（claude/kimi）：优先看尾部状态（见 `references/troubleshooting.md`「TUI 备屏 / 判活」busy/ready 二值），再可辅以进程
  CPU 增长判提交——**注意 CPU 法对 claude 深度思考阶段不可靠**（统计的是累计 CPU，深度思考
  常驻低增量，会误报「未提交」→ 触发重发 → 重复排队），只作辅助：

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
$wd = (Get-Location).Path          # recover 常在同一会话继续，$wd 可能未定义；显式补上
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

> **踩坑/排障统一维护在 `references/troubleshooting.md`**（现象 + 排查 + 处理速查表），本文不
> 承载坑内容。操作原语遇错时（launch 失败、drive 不提交、agent 卡住、备屏捕获空、send-keys
> 异常等）去那查，别在其它文档找。命令/格式/环境/键位/选项全量见 `references/README.md`。
