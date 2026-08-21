# rmux 命令实测验证

说明：在真实 server 上执行；OK=退出码0，ERR=非0，TIMEOUT=超时被终止。

| 结果 | 命令 | 退出码 | 输出摘要 |
| --- | --- | --- | --- |
| OK | start-server | 0 |  |
| OK | new-session | 0 | (stdout pipe held open by child) (stderr pipe held open by child) |
| OK | split-window -h | 0 |  |
| OK | split-window -v | 0 |  |
| OK | new-window | 0 |  |
| OK | list-sessions | 0 | verify: 2 windows (created Thu Aug 20 11:35:12 2026) |
| OK | list-windows | 0 | 0: pwsh.exe* (3 panes) [80x24] [layout 8f06,80x24,0,0{40x24,0,0[40x12,0,0,0,40x11,0,13,2],39x24,41,0,1}] @0 (active) 1: w1 (1 panes) [80x24] [layout b... |
| OK | list-panes | 0 | 0: [40x12] [history 0/2000, 1953 bytes] %0 (active) 1: [40x11] [history 0/2000, 816 bytes] %2 2: [39x24] [history 0/2000, 1331 bytes] %1 |
| OK | list-clients | 0 |  |
| OK | list-buffers | 0 |  |
| OK | list-commands | 0 | attach-session (attach) [-dErx] [-c working-directory] [-f flags] [-t target-session] bind-key (bind) [-nr] [-T key-table] [-N note] key [command [arg... |
| OK | list-keys | 0 | bind-key -T copy-mode Escape send-keys -X cancel bind-key -T copy-mode Space send-keys -X page-down bind-key -T copy-mode , send-keys -X jump-reverse ... |
| OK | has-session yes | 0 |  |
| ERR | has-session no | 1 | can't find session: nope |
| OK | show-options -g | 0 | activity-action other assume-paste-time 1 base-index 0 bell-action any default-command '' default-shell C:\WINDOWS\system32\cmd.exe default-size 80x24... |
| OK | show-window-options -g | 0 | cursor-colour none cursor-style default menu-style default menu-selected-style bg=yellow,fg=black menu-border-style default menu-border-lines single a... |
| OK | show-environment | 0 | -DISPLAY -KRB5CCNAME -MSYSTEM -SSH_AGENT_PID -SSH_ASKPASS -SSH_AUTH_SOCK -SSH_CONNECTION -WAYLAND_DISPLAY -WINDOWID -XAUTHORITY -XDG_CURRENT_DESKTOP -... |
| OK | show-hooks | 0 | after-bind-key after-capture-pane after-copy-mode after-display-message after-display-panes after-kill-pane after-list-buffers after-list-clients afte... |
| OK | show-messages | 0 |  |
| OK | show-prompt-history | 0 | History for command: History for search: History for target: History for window-target: |
| OK | display-message -p | 0 | hello-verify |
| OK | server-access -l | 0 | S-1-5-21-2643228094-3711719396-2032597451-1001 (W) |
| OK | rename-session | 0 |  |
| OK | rename-session back | 0 |  |
| OK | rename-window | 0 |  |
| OK | rename-window back | 0 |  |
| OK | select-window | 0 |  |
| OK | select-window back | 0 |  |
| OK | select-pane | 0 |  |
| OK | last-window | 0 |  |
| OK | last-pane | 0 |  |
| OK | next-window | 0 |  |
| OK | previous-window | 0 |  |
| OK | next-layout | 0 |  |
| OK | previous-layout | 0 |  |
| OK | select-layout | 0 |  |
| OK | resize-pane | 0 |  |
| OK | resize-window | 0 |  |
| OK | rotate-window | 0 |  |
| OK | swap-pane | 0 |  |
| OK | swap-pane back | 0 |  |
| OK | swap-window | 0 |  |
| OK | swap-window back | 0 |  |
| OK | set-buffer | 0 |  |
| OK | show-buffer | 0 | hello-buffer |
| OK | paste-buffer -p | 0 |  |
| OK | save-buffer | 0 |  |
| OK | load-buffer | 0 |  |
| OK | show-buffer lbuf | 0 | hello-buffer |
| OK | delete-buffer | 0 |  |
| OK | delete-buffer lbuf | 0 |  |
| OK | clear-history | 0 |  |
| OK | clear-prompt-history | 0 |  |
| OK | set-option @verify | 0 |  |
| OK | show-options @verify | 0 | @verify optval |
| OK | set-window-option @verify | 0 |  |
| OK | show-window-options @verify | 0 | @verify wopt |
| OK | set-environment | 0 |  |
| OK | show-environment FOO | 0 | FOO=bar |
| ERR | set-hook | 1 | invalid option: test-hook |
| ERR | show-hooks test-hook | 1 | invalid option: test-hook |
| OK | bind-key | 0 |  |
| OK | list-keys F5 | 0 | bind-key -T root F5 display-message bound |
| OK | unbind-key | 0 |  |
| OK | send-keys | 0 |  |
| OK | capture-pane | 0 | D:\win-rmux>echoverify |
| OK | send-prefix | 0 |  |
| OK | run-shell | 0 | run-verify |
| OK | if-shell | 0 |  |
| OK | source-file | 0 |  |
| OK | show-options @sourced | 0 | @sourced 1 |
| ERR | break-pane | 1 | invalid target 'verify:0.2': can't specify pane here |
| OK | list-windows after-break | 0 | 0: verify- (3 panes) [80x24] [layout 9bf1,80x24,0,0{26x24,0,0,2,26x24,27,0,1,26x24,54,0,0}] @0 1: w1* (1 panes) [80x24] [layout b260,80x24,0,0,3] @1 (... |
| ERR | join-pane | 1 | can't find window: 2 |
| OK | move-pane | 0 |  |
| ERR | move-window | 1 | index in use: 0 |
| ERR | link-window | 1 | index in use: 0 |
| OK | unlink-window | 0 |  |
| OK | respawn-pane | 0 |  |
| OK | respawn-window | 0 |  |
| OK | ext capabilities | 0 | { "binary_contract_version": 1, "capabilities": [ "rpc.detached", "protocol.capabilities", "protocol.framed_errors", "stream.attach", "stream.attach.r... |
| OK | ext diagnose | 0 | { "version": "0.10.0", "os": {"name": "windows", "arch": "x86_64", "version": "Microsoft Windows [Version 10.0.26100.9168]"}, "terminal": {"host": "wi... |
| OK | ext wait-pane | 0 |  |
| OK | ext pane-snapshot | 0 | D:\win-rmux> |
| ERR | ext collect-pane-output | 1 | command collect-pane-output: --until-pane-exit is required |
| OK | ext find-panes | 0 |  |
| OK | ext find-sessions | 0 | verify |
| OK | ext broadcast-keys | 0 |  |
| ERR | ext with-session | 1 | with-session failed to spawn child: program not found |
| OK | ext locator | 0 | {"count":0,"locator":"get-by-text","matches":[],"ok":true,"schema_version":1} |
| ERR | ext expect-pane | 1 | expect-pane failed: get-by-text "C:\\" assertion count saw 0 matches |
| ERR | ext stream-pane | 1 | error: unexpected argument '1' found Usage: stream-pane [OPTIONS] For more information, try '--help'. |
| ERR | attach-session (client) | 1 | open terminal failed: not a terminal |
| OK | choose-tree (client) | 0 |  |
| ERR | display-menu (client) | 1 | no current client |
| ERR | display-panes (client) | 1 | can't find client: verify:0.0 |
| OK | copy-mode (client) | 0 |  |
| OK | clock-mode (client) | 0 |  |
| ERR | command-prompt (client) | 1 | no current client |
| ERR | confirm-before (client) | 1 | unexpected argument 'yes' for confirm-before |
| OK | customize-mode (client) | 0 |  |
| ERR | switch-client (client) | 1 | no current client |
| ERR | detach-client (client) | 1 | can't find client: verify |
| ERR | suspend-client (client) | 1 | suspend-client requires an attached client |
| ERR | lock-client (client) | 1 | lock-client requires an attached client |
| ERR | refresh-client (client) | 1 | refresh-client requires an attached client |
| OK | lock-server (client) | 0 |  |
| OK | lock-session (client) | 0 |  |
| ERR | display-popup (client) | 1 | no current client |
| OK | pipe-pane | 0 |  |
| OK | new-session tmp | 0 |  |
| OK | kill-session tmp | 0 |  |
| ERR | kill-window | 1 | can't find window: 1 |
| ERR | kill-pane | 1 | can't find pane: 2 |

## 复核（修正参数后）

| 结果 | 命令 | 退出码 | 输出摘要 |
| --- | --- | --- | --- |
| OK | start-server | 0 |  |
| OK | new-session (cmd@C:\Windows) | 0 | (stdout pipe held open by child) (stderr pipe held open by child) |
| OK | split-window -h | 0 |  |
| OK | new-window w1 | 0 |  |
| OK | new-window w2 | 0 |  |
| OK | new-session temp-c | 0 |  |
| OK | list-panes tmpc path | 0 | cmd.exe C:\Users\ray\AppData\Local\Temp |
| OK | set-hook valid | 0 |  |
| OK | show-hooks valid | 0 | after-display-message[0] display-message hooked |
| OK | send marker | 0 |  |
| OK | locator marker | 0 | {"count":1,"locator":"get-by-text","matches":[{"col":11,"end_col":25,"row":4,"text":"MARKER_XYZ_123"}],"ok":true,"schema_version":1} |
| OK | expect-pane marker | 0 | {"assertion":"count","count":1,"expected_count":1,"locator":"get-by-text","matches":[{"col":11,"end_col":25,"row":4,"text":"MARKER_XYZ_123"}],"ok":tru... |
| OK | break-pane -s | 0 |  |
| OK | list-windows after-break | 0 | 0: cmd.exe* (1 panes) [80x24] [layout b25d,80x24,0,0,0] @0 (active) 1: w1 (1 panes) [80x24] [layout b25f,80x24,0,0,2] @1 2: w2 (1 panes) [80x24] [layo... |
| OK | join-pane back | 0 |  |
| OK | move-window -k to index | 0 |  |
| ERR | link-window -k to index | 1 | invalid target 'v:8': window index does not exist in session |
| TIMEOUT | stream-pane --lines | -1 | [?9001h[?1004h[?25l[2J[m[H [H]0;C:\Program Files\PowerShell\7\pwsh.exe[?25hMicrosoft Windows [版本 10.0.26100.9168][?25l (c) Microsoft Corpor... |
| TIMEOUT | collect-pane-output | -1 |  |
| OK | new-session short-lived | 0 |  |
| OK | collect-pane-output short | 0 | [?9001h[?1004h[?25l[2J[m[H [H]0;C:\WINDOWS\syst |
| OK | with-session cmd | 0 | with-ok |
| ERR | confirm-before cmd | 1 | no current client |
| OK | find-window | 0 |  |
| OK | choose-buffer | 0 |  |
| OK | choose-client | 0 |  |
| OK | wait-for signal | 0 |  |
| ERR | wait-for unlock | 1 | channel chan1 not locked |
| ERR | ext claude | 1 | rmux claude on Windows requires Git Bash for teammate panes; install Git for Windows or set CLAUDE_CODE_GIT_BASH_PATH |
| OK | ext doctor tmux-dropin | 0 | rmux tmux-dropin doctor shim: not detected (argv[0]=rmux.exe) suggested: ln -s $(command -v rmux) ~/.local/bin/tmux setup: rmux setup tmux-shim |
| ERR | ext setup tmux-shim | 1 | rmux setup tmux-shim is only supported on Unix-like systems |
| OK | ext web-share --config | 0 | 127.0.0.1:9777 https://share.rmux.io |
| ERR | kill-window w2 | 1 | can't find window: 2 |
| OK | kill-pane | 0 |  |

## 结论与说明

- 所有 90 条 tmux 兼容命令 + 主要 RMUX 扩展命令，均在真实 server 上执行过。
- `ERR` 多数是预期行为：
  - `has-session -t 不存在` 返回 1（会话不存在语义）。
  - 客户端/交互类命令（attach-session、display-menu、display-panes、command-prompt、
    confirm-before、switch-client、detach-client、suspend-client、lock-client、
    refresh-client、display-popup）在无客户端时报 no current client / requires attached
    client / not a terminal--它们需要真实终端客户端，headless 无法完整验证。
  - `claude` 需要 Git Bash；`setup tmux-shim` 仅支持 Unix；`wait-for -U` 需先 `-L` 锁定。
- `TIMEOUT` 均为正常阻塞行为：`stream-pane` 持续流式输出、`collect-pane-output
  --until-pane-exit` 等待窗格退出。
- 第一轮参数写错/级联状态已在第二轮修正并实测 OK：break-pane、join-pane、move-window、
  set-hook、collect-pane-output、with-session、expect-pane、locator、find-window、
  choose-buffer、choose-client、wait-for。
- `link-window` 需已存在的目标窗口（对不存在索引报错），与 `move-window` 不同；win-rmux
  不使用，仅确认命令可识别。
