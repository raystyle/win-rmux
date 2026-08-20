# rmux 概念模型与核心命令速查

## 定位

rmux 是 Windows 的 tmux 兼容多路复用器（Helvesec/rmux）。本仓库用它在 Windows Terminal
新窗口里并排运行多个 agent（codex / kimi / claude），再通过命令驱动各个窗格。

版本：0.10.0。安装路径：`D:\ohmyenv\rmux\rmux.exe`（PATH 内 `rmux` 可用）。

## daemon / client 模型

- 一个后台 **server（daemon）** 持有所有 session/window/pane，通过命名管道 socket 通信
  （`\\.\pipe\rmux-...`）。
- 每个 wt 窗格里的 `rmux attach-session` 是一个 **client**。关 wt 只是 detach，daemon 与会话仍存活。
- `rmux kill-server` 杀掉 daemon 与所有会话/窗格；daemon 在最后一个会话被杀后自动退出。
- 恢复会话用 `attach-session -d -t NAME`，不要 `new-session -A`（见 rmux-usage.md）。

## 层级与索引

session → window → pane。默认 `base-index 0`、`pane-base-index 0`，所以 `dev:0.0`
表示会话 `dev` 的 window 0、pane 0。

target 写法：

- 会话名：`-t dev`
- `session:window.pane`：`-t dev:0.1`
- pane id：`-t %3`
- window 编号：`-t :=2`（如 `select-window -t :=0`）
- 相对偏移：`-t :+1` / `-t :-1`（如 `swap-window -t :+1`）

更多 tmux target 语法（window id `@N`、`!` 上个窗格、`{last}`/`{next}` 等）未逐一实测，以 tmux man 为准。

## Windows / pwsh 关键默认（详见 options.md）

- 实测：无显式命令时新窗格实际跑 `pwsh.exe`（PowerShell 7），与 `default-shell` 选项显示的
  `cmd.exe` 不一致；`-c` 工作目录已实测生效。skill 始终显式传命令（codex/kimi/claude），不受影响。
- `alternate-screen = on`：pwsh/TUI 走备屏，capture-pane 常返回空（实测）。
- `remain-on-exit = off`：pane 内命令退出即关闭窗格。
- 前缀键 `C-b`，`prefix2` 未设置。

## 核心命令速查（win-rmux 相关）

| 目的 | 命令 |
| --- | --- |
| 建后台会话 | `rmux new-session -d -s NAME -c DIR 'cmd'` |
| 右/下/全宽分窗格 | `rmux split-window -h|-v|-f -d -t TARGET -c DIR 'cmd'` |
| 会话/窗格/窗口/客户端列表 | `rmux list-sessions` / `list-panes` / `list-windows` / `list-clients` |
| 会话是否存在 | `rmux has-session -t NAME`（PowerShell 下用 `list-sessions` + `-contains` 更稳） |
| 恢复 attach | `rmux attach-session -d -t NAME` |
| 发送按键 | `rmux send-keys -t TARGET -- 'text' Enter` |
| 读取输出 | `rmux capture-pane -t TARGET -p` |
| 关会话 / 关 daemon | `rmux kill-session -t NAME` / `rmux kill-server` |
| 等待窗格条件 | `rmux wait-pane -t TARGET --quiet --timeout 30s` |
| 按命令/文本找窗格 | `rmux find-panes --current-command codex` / `rmux expect-pane -t TARGET --get-by-text TEXT` |

格式输出：`list-*` 支持 `-F`（格式变量）与 `--json`；`list-panes -F
"#{window_index}.#{pane_index} ..."` 可输出精确坐标。
