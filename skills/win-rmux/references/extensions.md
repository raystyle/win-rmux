# RMUX 扩展命令

rmux 在 tmux 兼容面之外提供的扩展。均可用 `rmux <ext> --help` 查看。

## 能力与诊断

- `rmux capabilities [--human|--json]`
- `rmux diagnose [--human|--json]`
- `rmux doctor tmux-dropin`：检查 tmux shim 是否就位（实测 `not detected (argv[0]=rmux.exe)`，并提示 `rmux setup tmux-shim`）。
- `rmux setup tmux-shim`：创建 tmux shim 软链（仅 Unix；Windows 实测报 `only supported on Unix-like systems`）。

## claude

- `rmux claude ...`：claude 协作窗格需要 Git Bash（安装 Git for Windows 或设 `CLAUDE_CODE_GIT_BASH_PATH`）。
- `rmux claude install-skill`：安装 rmux 自带的 Claude Code skill。

## 等待 / 读取 / 定位（驱动 agent 的核心）

### wait-pane

`rmux wait-pane [OPTIONS]`

- `-t, --target <TARGET>`
- `--text <TEXT>` / `--next-text <TEXT>` / `--visible-text <TEXT>`：等待指定文本
- `--quiet`：等待输出静默
- `--stable-for <DURATION>`：输出稳定时长（如 `500ms`、`8s`、`2m`）
- `--pane-exit`：等待窗格退出
- `--timeout <DURATION>`：超时（`ms/s/m`）
- `--json`
- `--get-by-text <TEXT>`

### pane-snapshot / stream-pane

- `rmux pane-snapshot [-t TARGET] [--json] [--style] [--region REGION]`
- `rmux stream-pane [-t TARGET] [--raw] [--lines]`

### collect-pane-output

`rmux collect-pane-output [OPTIONS] --max-bytes BYTES`

- `-t, --target <TARGET>` / `--until-pane-exit` / `--json`

### locator / expect-pane

- `rmux locator [-t TARGET] --get-by-text TEXT [--json]`
- `rmux expect-pane [-t TARGET] --get-by-text TEXT [--visible] [--hidden] [--count N] [--json]`

### find-panes / find-sessions

- `rmux find-panes [--title TITLE] [--title-prefix P] [--current-command CMD] [--cwd DIR] [--json]`
- `rmux find-sessions [--name NAME] [--name-prefix P] [--json]`

## 广播与包装

- `rmux broadcast-keys -t TARGETS... [-l] -- KEY...`：向多个目标同时发键。
- `rmux with-session SESSION_NAME [COMMAND...] [--kill-on-owner-exit] [--ttl DURATION]`（默认 ttl 30s）。

## web-share

完整说明见 [web-share.md](web-share.md)。要点：

`rmux web-share [OPTIONS]`，模式：`list` / `lookup <id>` / `stop <id>` / `disconnect <id>` / `off` / `config`。

关键 flags：

- `-t <TARGET>`：pane target 暴露单窗格；session target 暴露整个会话视图
- `--operator-only` / `--spectator-only`
- `--pin-operator PIN` / `--pin-spectator PIN` / `--no-pin`
- `--ttl <seconds>` / `--expires-at <RFC3339>` / `--kill-session-on-expire`
- `--max-spectators` / `--max-operators`
- `--frontend-url` / `--tunnel-url` / `--tunnel-provider`
- 隧道 provider：`localhost-run` / `sandhole` / `serveo` / `srv-us` / `tailscale-funnel` / `tailscale-serve`
- 界面：`--no-navbar` / `--no-disclaimer` / `--hide-viewers` / `--theme user|light|dark`

默认生成 operator 私有 URL + spectator URL；默认要求 6 位配对 PIN（`--no-pin` 可关）。

## send-keys 扩展等待参数

tmux 兼容的 `send-keys` 在 rmux 里额外支持（与 wait-pane 同语义）：

- `--wait`（本版本仅 `quiet`）/ `--wait-text` / `--wait-visible-text` / `--wait-next-text`
- `--wait-pane-exit`
- `--stable-for <DURATION>` / `--timeout <DURATION>`

示例：`rmux send-keys -t dev --wait quiet --stable-for 800ms --timeout 15s -- '/status' Enter`

## 脚本化 / SDK / control-mode

- `rmux capabilities` 列出 `public_contract`：`cli` / `json-output` / `format-tokens` / `control-mode`。
- 支持 `--json` 的命令：`capabilities` / `display-message` / `list-clients` / `list-panes` /
  `list-sessions` / `list-windows`。
- 官方 SDK：Rust `rmux-sdk`、Python `librmux`、TypeScript `@rmux/sdk`，连接本地 daemon，
  暴露 session/pane/stream/wait/snapshot 等能力。
