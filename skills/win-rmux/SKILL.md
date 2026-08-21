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

> **默认从 wt 窗口内启动 daemon**（2026-08-21 修正）。首次 launch 不要在宿主侧直接
> `new-session`：CI/agent 宿主常把命令包进 job object，独立 rmux daemon 会因无法脱离
> job 而启动失败，报 `os error 5`（`Windows refused to launch an independent RMUX
> daemon`）。wt 是 UWP 应用，进程树脱离 job，把整套 launch 放进 wt 内执行即稳定。
> launcher 脚本本身只负责建会话+切 pane，**不要**含 `attach-session`（否则 wt 卡前台）；
> 建好后宿主侧先用 `locate` 复核 pane，`Visible` 时再单独 recover 弹 attach 窗口。
> 何时可退化到宿主侧直连：宿主不在 job object 内（如普通交互终端、非 CI/agent 宿主）时，
> 下面的 wt 启动可作为统一入口，宿主 `find-panes` 照常可用。（`$Visible` 只决定是否弹可见
> 看板，与宿主是否在 job object 内是两个独立维度。）

launcher 脚本（写成本地 `launch-unit.ps1`，当前目录为 `$wd`）：

```powershell
# launch-unit.ps1 —— 在宿主 job object 外（wt 内）启动独立 rmux daemon + N 个 agent pane
$ErrorActionPreference = 'Continue'
$env:RMUX_DISABLE_TINY_CLI = '1'
Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
$env:TERM = 'xterm-256color'; $env:COLORTERM = 'truecolor'
$mu = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$env:Path = (($mu -split ';') + ($env:Path -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'

$unit = 'execution-unit'   # 覆盖点：与调用方保持一致
$wd   = (Get-Location).Path
$agents = @(
  @{ name = 'codex';  cmd = 'codex';  args = @('--dangerously-bypass-approvals-and-sandbox', '--dangerously-bypass-hook-trust', '--no-alt-screen') }
  @{ name = 'kimi';   cmd = 'kimi';   args = @('--auto') }
  @{ name = 'claude'; cmd = 'claude'; args = @('--dangerously-skip-permissions') }
)
if (@(rmux list-sessions -F '#{session_name}' 2>$null) -contains $unit) { rmux kill-session -t $unit }

$argv = @('new-session','-d','-s',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[0].name)",$agents[0].cmd) + $agents[0].args
& rmux @argv
$argv = @('split-window','-h','-d','-t',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[1].name)",$agents[1].cmd) + $agents[1].args
& rmux @argv
$argv = @('split-window','-f','-v','-d','-t',$unit,'-c',$wd,'-e',"WIN_RMUX_UNIT=$unit",'-e',"WIN_RMUX_AGENT=$($agents[2].name)",$agents[2].cmd) + $agents[2].args
& rmux @argv
# 脚本结束即退出，wt 标签关闭，daemon 由 wt 内 pwsh 与宿主解耦存活
```

宿主侧入口（弹 wt 跑 launcher，然后宿主等待/复核）：

```powershell
$wd = (Get-Location).Path          # 宿主侧须显式定义 $wd（launcher 内另有同名的独立副本）；wt -d 与 pane -c 都以它为工作目录
$wt = (Get-Command wt.exe).Source
$wtArgs = "-w new --title `"$unit-launch`" -d `"$wd`" pwsh -NoProfile -ExecutionPolicy Bypass -File `"<launch-unit绝对路径>`""
Start-Process -FilePath $wt -ArgumentList $wtArgs -WindowStyle Minimized
# 等待 daemon 起来（视 agent 数量，5-15s），再 locate 复核 pane
Start-Sleep -Seconds 10
rmux list-panes -t $unit -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command}"
```

- 复核 OK 后，`$Visible` 时 recover/弹 attach 看板（见 recover 段）；`$Visible=$false` 直接宿主驱动。
- 若 host 确实不在 job object 内、且想要更轻的纯后台启动，可把同一份 `launch-unit.ps1`
  的 body 直接用宿主 pwsh 执行（内含环境守卫 PATH/NO_COLOR/TERM），失败 `os error 5` 时回退
  到 wt 启动。**注意**：launcher body 不含「用户 env 同步」与「hook 安装」，这两项仍须先跑
  一次前置守卫（见上文）；否则 agent 可能缺 DEEPSEEK_API_KEY 等、judge 无 hook 状态通道。

布局按 N：1=单 pane；2=`-h` 左右；3=上2下1；>3 前两个上排、其余 `-f -v` 往下全宽堆（待定）。

## locate：agent ↔ pane

```powershell
rmux list-panes -t $unit -F "#{window_index}.#{pane_index} #{pane_id} cmd=#{pane_current_command} top=#{pane_top} left=#{pane_left} w=#{pane_width} h=#{pane_height}"
# 或：rmux find-panes --current-command codex
```

## drive：给指定 agent 发 prompt（严格流程）

> **必守**：drive 不是「发完就走」，必须做「提交确认」——发文本后**必须**验证它已真正进入
> agent 处理（否则 prompt 停在输入框，agent 没开始）。三 agent 均实测：文本+Enter 同发会被吞，
> Enter 单独发也可能因时序被忽略（codex/kimi 反复踩）。以下每一步都是确认过的严格操作。

```powershell
function Get-AgentPane([string]$name) {
  $i = [array]::IndexOf($agents.name, $name)
  if ($i -lt 0) { throw "unknown agent: $name" }
  "${unit}:0.$i"
}
$p = Get-AgentPane 'codex'

# ── 步骤 0：目标 pane 校验（display-message 按单一 pane 解析，list-panes -t <sess>:0.0 是 window 作用域会误报）──
if ((rmux display-message -p -t $p -F '#{pane_current_command}' 2>$null) -notmatch 'codex') {
  Write-Warning "target pane $p cmd 非 codex，先 locate 确认再 drive（禁止盲发）"
}

# ── 步骤 1（预发）：确认输入框为空（避免排队叠加）──
# 若 capture 见 `❯ Press up to edit queued messages` 或非空输入行 = 有排队，先清再发
$pre = rmux capture-pane -t $p -p
if ($pre -match 'up to edit queued|❯\s+\S') {
  Write-Host '[!] 有排队消息，先清空输入队列（只清未提交输入，不打断进行中的思考）' -ForegroundColor Yellow
  rmux send-keys -t $p -- C-c
  Start-Sleep -Milliseconds 500
}

# ── 步骤 2：发文本（-l 字面量保空格/特殊字符、含空格不截断）──
rmux send-keys -t $p --wait quiet --stable-for 800ms --timeout 15s -l -- '<ascii-prompt>'

# ── 步骤 3：单独 Enter 提交（文本与 Enter 同发会被吞；Enter 单独发但可能因时序被忽略，故必走步骤 4 校验）──
rmux send-keys -t $p -- Enter

# ── 步骤 4（提交确认）：验证 prompt 已离开输入框进入 agent 处理 ──
Start-Sleep -Milliseconds 800
$post = rmux capture-pane -t $p -p
if ($post -match 'queued|❯\s+<ascii-prompt>|❯\s+R') {
  # 输入框仍留着 prompt / 排队未提交 → Enter 被吞，单独重发 Enter
  Write-Host '[!] prompt 仍在输入框未提交，重发 Enter' -ForegroundColor Yellow
  rmux send-keys -t $p -- Enter
}
# 可选：hook 状态从 idle 转 working / 进程 CPU 增长，确认 agent 已开始处理
```

- 回车只有 `Enter`；`C-m` 是字面量 `^M`。**Enter 必须单独一次 send-keys 发**（与文本同发实测不提交）。
- 中文乱码：prompt 用 ASCII（通篇英文），含空格用 `-l` 字面量或拆 token + `Space`。
- 等待：`--wait quiet|--wait-text|--wait-next-text|--wait-visible-text|--wait-pane-exit` + `--stable-for` + `--timeout`。
- **`--wait quiet` 超时 ≠ 未发送**：pane 仍 `working`（agent 未上报 idle、TUI 实际已就绪）时 `--wait quiet` 会
  timed out，但指令可能已入缓冲区。**此时严禁重发同一条 prompt**（会排队两次，agent 执行两遍）——按
  步骤 4 只补 `Enter`；若已排队多份，`C-c` 清队列再只发一次。

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
- TUI 备屏（claude/kimi）：优先看尾部状态（见「关键踩坑」busy/ready 二值），再可辅以进程
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

完整实测（daemon 进程模型、NO_COLOR 根源、ConPTY 备屏、关闭退出等）见
`references/rmux-usage.md`；命令/扩展/格式/环境/键位/选项全量见 `references/README.md`。

2026-08-21 实测新增：

- **宿主 job object 阻止 rmux daemon**：CI/agent 宿主把命令包在 job object 里时，
  `new-session -d` 启动独立 daemon 报 `os error 5`（`Windows refused to launch an
  independent RMUX daemon`）。**已内置进 launch 默认流程**（见上文「launch：建执行单元」）：
  整套 launch 命令放进 **wt 窗口内执行**（wt 是 UWP 应用，进程树脱离 job），daemon 由
  wt 内的 pwsh 启动；之后 client 命令（send-keys / capture-pane / list-panes 等）在宿主侧
  照常可用。宿主侧直接 launch 失败（报 os error 5）时，一律回退到 wt 启动。
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
- **drive 相关坑已固化为「严格流程」**（见上文「drive：给指定 agent 发 prompt（严格流程）」）：
  `--wait quiet` 超时 ≠ 未发送（指令可能已入输入缓冲区）、Enter 单独发仍可能被吞、排队会造成
  重复执行——均按 drive 流程的「预发清排队 → 发文本 → Enter → 提交确认」四步执行，不再重复叙述。
- **备屏 TUI 判活用「busy/ready 二值」，不按 spinner 动词断义**（claude/kimi 备屏 capture
  拿不到完整帧，但尾部状态行可见；busy/ready 判定两 agent 通用）：spinner 行非空（如
  `… (N s · ↓Nk tokens)`，`Nk tokens` 计数在涨）= busy（活，别打扰）；空 `❯` + 底部
  statusline = ready（可安全 drive）。
  **不要**把 `Cogitating…`/`Skedaddling…`/`Frolicking…` 等动词映射成特定阶段——这些是
  **Claude TUI 专属**的随机轮换趣味词，不编码「深度思考 vs 被安全策略中断」；按动词判活会
  误判（2026-08-21 三 agent review 指出）。kimi 的 statusline/文案不同，但「busy/ready +
  token 计数在涨」判活思路相同。「是否被安全策略中断」靠显式 review prompt 规避（见下条），
  不靠 spinner 词。另：深度思考阶段 judge 的进程 CPU 增长法对 claude 不敏感，判 busy 以
  token 计数在涨为准。
- **review 类 prompt 应内置「跳过凭据/密钥文件」**：claude 在 review 时会去读
  `*.key.ps1`/`.secrets` 等，被它自身安全策略拦（`Action blocked to prevent credential
  exposure`）放弃任务。**若宿主项目装有 secret-guard 类内容拦截 hook**（如 ohmypwsh），
  还会反拦含 `mysql://`、`AKIA`、`api_key` 模式字面量的内容（guard 自身源码/研究文档/测试
  样例），agent 读这些会被误拦。故 review/审查 prompt 显式附：`do NOT read/open secret/
  credential files (nothing under .secrets, no *key*.ps1, no API-key/token files)`，并 focus
  只留 code structure/logic/consistency（2026-08-21 实测，claude 是唯一会被自家策略硬拦的，
  codex/kimi 只是不该看）。
- **`C-c` 只发一次，勿连发**：Claude Code 的 `C-c` 连按两次会退出会话（杀掉 pane 里的
  claude）。清输入队列用单次 `C-c`；若不生效先 `capture` 确认再决定，不要连按。注意：
  「`C-c` 只清未提交输入、不打断进行中的思考」是 **claude TUI 的实测行为**，其他 TUI/agent
  （尤其 kimi）的 Ctrl+C 可能中断当前运行——发 `C-c` 前先确认不会打断当前思考。
