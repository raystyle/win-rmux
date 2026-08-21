# rmux 默认选项参考

来源：`rmux show-options -g` 与 `rmux show-window-options -g`（rmux 0.10.0 默认值）。

## 与 win-rmux 强相关的默认

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| prefix | C-b | 前缀键 |
| prefix2 | None | 无第二前缀 |
| default-shell | cmd.exe | 选项值；但实测无命令时新窗格实际跑 pwsh.exe（见 command-verification.md） |
| base-index | 0 | window 起始编号 |
| pane-base-index | 0 | pane 起始编号 |
| alternate-screen | on | 全屏 TUI 走备屏 -> capture-pane 常为空 |
| remain-on-exit | off | 命令退出即关窗格 |
| mouse | off | 默认关闭鼠标 |
| history-limit | 2000 | 回滚行数 |
| default-size | 80x24 | 初始尺寸 |
| renumber-windows | off | 不自动重排 window 编号 |
| destroy-unattached | off | 无人 attach 的会话保留 |
| detach-on-destroy | on | 会话销毁时 detach 客户端 |
| repeat-time | 500 | 重复键窗口（ms） |
| status | on / bottom | 状态栏开启、底部 |
| set-titles | off | 不设置终端标题 |

## 常用 window 选项

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| synchronize-panes | off | 关闭多窗格同步输入 |
| monitor-activity | off | 活动监控 |
| monitor-bell | on | 铃声监控 |
| monitor-silence | 0 | 静默监控（0=关） |
| mode-keys | emacs | 复制模式键风格 |
| xterm-keys | on | xterm 扩展键 |
| aggressive-resize | off | 不随客户端尺寸实时重排 |
| pane-border-status | off | 窗格边框不显示状态 |

改法示例：

```powershell
rmux set-option -g default-shell 'C:\Program Files\PowerShell\7\pwsh.exe'
rmux set-option -g mouse on
rmux set-window-option -g synchronize-panes off
```

skill 驱动时通常不改全局，只按窗格显式传 `-c` 与 shell-command。

## 全量默认 server 选项（show-options -g）

```text
activity-action other
assume-paste-time 1
base-index 0
bell-action any
default-command ''
default-shell C:\WINDOWS\system32\cmd.exe
default-size 80x24
destroy-unattached off
detach-on-destroy on
display-panes-active-colour red
display-panes-colour blue
display-panes-time 1000
display-time 750
history-limit 2000
key-table root
lock-after-time 0
lock-command "lock -np"
message-command-style bg=black,fg=yellow,fill=black
message-line 0
message-style bg=yellow,fg=black,fill=yellow
mouse off
prefix C-b
prefix2 None
renumber-windows off
repeat-time 500
set-titles off
set-titles-string "#S:#I:#W - \"#T\" #{session_alerts}"
silence-action other
status on
status-bg default
status-fg default
status-format[0] "#[align=left range=left #{E:status-left-style}]#[push-default]#{T;=/#{status-left-length}:status-left}#[pop-default]#[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-format}#[pop-default]#[norange default]#{?loop_last_flag,,#{E:window-status-separator}},#[range=window|#{window_index} list=focus #{?#{!=:#{E:window-status-current-style},default},#{E:window-status-current-style},#{E:window-status-style}}#{?#{&&:#{window_last_flag},#{!=:#{E:window-status-last-style},default}}, #{E:window-status-last-style},}#{?#{&&:#{window_bell_flag},#{!=:#{E:window-status-bell-style},default}}, #{E:window-status-bell-style},#{?#{&&:#{||:#{window_activity_flag},#{window_silence_flag}},#{!=:#{E:window-status-activity-style},default}}, #{E:window-status-activity-style},}}]#[push-default]#{T:window-status-current-format}#[pop-default]#[norange list=on default]#{?loop_last_flag,,#{E:window-status-separator}}}#[nolist align=right range=right #{E:status-right-style}]#[push-default]#{T;=/#{status-right-length}:status-right}#[pop-default]#[norange default]"
status-format[1] "#[align=left]#{R: ,#{n:#{session_name}}}P: #[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{P:#[range=pane|#{pane_id} #{E:pane-status-style}]#[push-default]#{T:window-pane-status-format}#[pop-default]#[norange list=on default]  ,#[range=pane|#{pane_id} list=focus #{?#{!=:#{E:pane-status-current-style},default},#{E:pane-status-current-style},#{E:pane-status-style}}]#[push-default]#{T:window-pane-current-status-format}#[pop-default]#[norange list=on default] }"
status-format[2] "#[align=left]#{R: ,#{n:#{session_name}}}S: #[norange default]#[list=on align=#{status-justify}]#[list=left-marker]<#[list=right-marker]>#[list=on]#{S:#[range=session|#{session_id} #{E:session-status-style}]#[push-default]#S#{session_alert}#[pop-default]#[norange list=on default]  ,#[range=session|#{session_id} list=focus #{?#{!=:#{E:session-status-current-style},default},#{E:session-status-current-style},#{E:session-status-style}}]#[push-default]#S*#{session_alert}#[pop-default]#[norange list=on default] }"
status-interval 15
status-justify left
status-keys emacs
status-left "[#{session_name}] "
status-left-length 10
status-left-style default
status-position bottom
status-right "#{?window_bigger,[#{window_offset_x}#,#{window_offset_y}] ,}\"#{=21:host_short}\" %H:%M %d-%b-%y"
status-right-length 40
status-right-style default
status-style bg=green,fg=black
update-environment[0] DISPLAY
update-environment[1] KRB5CCNAME
update-environment[2] MSYSTEM
update-environment[3] SSH_ASKPASS
update-environment[4] SSH_AUTH_SOCK
update-environment[5] SSH_AGENT_PID
update-environment[6] SSH_CONNECTION
update-environment[7] WAYLAND_DISPLAY
update-environment[8] WINDOWID
update-environment[9] XAUTHORITY
update-environment[10] XDG_CURRENT_DESKTOP
update-environment[11] XDG_SESSION_DESKTOP
update-environment[12] XDG_SESSION_TYPE
visual-activity off
visual-bell off
visual-silence off
word-separators "!\"#$%&'()*+,-./:;<=>?@[\\]^`{|}~"
``` 

## 全量默认 window 选项（show-window-options -g）

```text
cursor-colour none
cursor-style default
menu-style default
menu-selected-style bg=yellow,fg=black
menu-border-style default
menu-border-lines single
aggressive-resize off
allow-passthrough off
allow-rename off
alternate-screen on
automatic-rename on
automatic-rename-format "#{?pane_in_mode,[tmux],#{pane_current_command}}#{?pane_dead,[dead],}"
clock-mode-colour blue
clock-mode-style 24
copy-mode-match-style bg=cyan,fg=black
copy-mode-current-match-style bg=magenta,fg=black
copy-mode-mark-style bg=red,fg=black
copy-mode-line-numbers off
copy-mode-line-number-style fg=white,dim
copy-mode-current-line-number-style fg=yellow
fill-character ''
main-pane-height 24
main-pane-width 80
mode-keys emacs
mode-style noattr,bg=yellow,fg=black
monitor-activity off
monitor-bell on
monitor-silence 0
other-pane-height 0
other-pane-width 0
pane-active-border-style "#{?pane_in_mode,fg=yellow,#{?synchronize-panes,fg=red,fg=green}}"
pane-base-index 0
pane-border-format "#{?pane_active,#[reverse],}#{pane_index}#[default] \"#{pane_title}\""
pane-border-indicators colour
pane-border-lines single
pane-border-status off
pane-border-style default
pane-colours
popup-style default
popup-border-style default
popup-border-lines single
remain-on-exit off
remain-on-exit-format "Pane is dead (#{?#{!=:#{pane_dead_status},},status #{pane_dead_status},}#{?#{!=:#{pane_dead_signal},},signal #{pane_dead_signal},}, #{t:pane_dead_time})"
scroll-on-clear on
synchronize-panes off
window-active-style default
window-size latest
window-style default
window-status-activity-style reverse
window-status-bell-style reverse
window-status-current-format "#I:#W#{?window_flags,#{window_flags}, }"
window-status-current-style default
window-status-format "#I:#W#{?window_flags,#{window_flags}, }"
window-status-last-style default
window-status-separator " "
window-status-style default
wrap-search on
xterm-keys on
``` 
