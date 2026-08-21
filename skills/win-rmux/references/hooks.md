# rmux agent 状态 hook（借鉴 herdr）

目标：把 `judge` 从「CPU 轮询猜状态」升级为「agent 自己上报 idle/working/blocked」。

## 状态通道（rmux 原生，已实测）

rmux 没有 herdr 的 `pane report-agent`，但 `set-environment` / `show-environment` 可以当状态通道：

```powershell
rmux set-environment -t $unit AGENT_STATE_codex working
rmux show-environment -t $unit AGENT_STATE_codex   # -> AGENT_STATE_codex=working
```

注意：`show-environment` 一次只查一个变量。

## launch 注入身份 env（已实测）

`new-session` / `split-window` 的 `-e VAR=value` 把身份注入 pane，让 hook 脚本知道回写哪个会话 / agent：

```powershell
-e "WIN_RMUX_UNIT=$unit" -e "WIN_RMUX_AGENT=$($agent.name)"
```

## 三 agent hook 事件（与 install-agent-hooks.ps1 实际注册一致）

| agent | hook 配置 | 安装脚本注册事件 | 上报 |
| --- | --- | --- | --- |
| codex | `~/.codex/hooks.json` | `SessionStart`/`UserPromptSubmit`/`PreToolUse`/`PermissionRequest`/`Stop`/`SessionEnd` | SessionStart→idle；UserPromptSubmit/PreToolUse→working；PermissionRequest→blocked；SessionEnd→idle；Stop 实测不触发 |
| claude | `~/.claude/settings.json` | `SessionStart`/`UserPromptSubmit`/`PreToolUse`/`PermissionRequest`/`Stop`（未注册 `SubagentStop`） | SessionStart→idle；UserPromptSubmit/PreToolUse→working |
| kimi | `~/.kimi-code/config.toml` | `SessionStart`/`UserPromptSubmit`/`PreToolUse`/`PermissionRequest`/`Stop`/`Interrupt` | 同上（codex/claude 风格事件集） |

实测补充（重要）：

- codex hook 需要信任；headless 下必须加 `--dangerously-bypass-hook-trust`，否则静默跳过。
- claude 的 JSON hook 条目需要 `matcher`（`Stop`/`PreToolUse` 等用 `matcher: "*"`），否则可能不触发。注：`PermissionRequest` 并非 Claude Code 标准事件（标准集见 `claude -h`），claude 可能永不报 `blocked`。
- codex 的 `Stop` hook 实测不触发：`UserPromptSubmit→working` 正常、`Stop→idle` 不写
  （2026-08-21，kimi/claude 正常），模型调用失败/异常中断后状态会卡 `working`。
  judge codex 用进程 CPU 回退，或手动 `rmux set-environment -t $unit AGENT_STATE_codex idle` 清理。

## 一次性安装（每 agent）

1. 写 hook 脚本到 agent 的 hooks 目录（读 stdin JSON，取 `$Action` / `hook_event_name`）。
2. 注册进对应 hook 配置（kimi config / codex `hooks.json` / claude `settings.json`）。

## hook 脚本要点（win-rmux 版）

```powershell
param([string]$Action = "")
if (-not $env:WIN_RMUX_UNIT -or -not $env:WIN_RMUX_AGENT) { exit 0 }
$state = switch ($Action) {
  'working' { 'working' }
  'blocked' { 'blocked' }
  'idle'    { 'idle' }
  default   { exit 0 }
}
rmux set-environment -t $env:WIN_RMUX_UNIT ("AGENT_STATE_" + $env:WIN_RMUX_AGENT) $state 2>$null
```

## judge：读状态

```powershell
rmux show-environment -t $unit AGENT_STATE_codex
# 输出为空/不存在 = 未上报；否则为 `AGENT_STATE_codex=idle|working|blocked`（注意带 KEY= 前缀，解析需去掉）
```

## 内置脚本

- hook 脚本：`hooks/win-rmux-agent-state.ps1`（agent 触发时调用，读 stdin `hook_event_name`，回写状态）。
- 检测/安装：`scripts/install-agent-hooks.ps1`（幂等，自动写 codex `hooks.json`、claude `settings.json`、kimi `config.toml`）。

SKILL 的「前置守卫」会先跑 `install-agent-hooks.ps1`，保证 hook 就位。
