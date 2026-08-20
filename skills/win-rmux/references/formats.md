# rmux 格式变量（-F / format tokens）

rmux 兼容 tmux 的 `FORMATS`。以下变量来自 rmux 0.10.0 默认模板与实测 `-F` 输出，按命名空间整理。

用法：`rmux list-panes -F "#{pane_id} #{pane_current_command}"`；多数 `list-*`、`display-message` 支持。

## 会话 session

- `#{session_name}`（简写 `#S`）：会话名
- `#{session_id}`：会话 id
- `#{session_attached}`：是否已 attach
- `#{session_windows}`：窗口数
- `#{session_alerts}` / `#{session_alert}`：告警标记
- `#{session_created}`：创建时间

## 窗口 window

- `#{window_index}`（`#I`）：窗口编号
- `#{window_id}`：窗口 id
- `#{window_name}`（`#W`）：窗口名
- `#{window_panes}`：窗格数
- `#{window_layout}`：布局字符串
- `#{window_flags}`：窗口 flags
- `#{window_active}` / `#{window_last_flag}` / `#{window_bell_flag}` /
  `#{window_activity_flag}` / `#{window_silence_flag}`：状态标志
- `#{window_offset_x}` / `#{window_offset_y}` / `#{window_bigger}`：视图偏移

## 窗格 pane

- `#{pane_id}`：pane id（`%N` 寻址用）
- `#{pane_index}`：窗格在窗口内的编号
- `#{pane_pid}`：窗格进程 PID
- `#{pane_current_command}`：当前命令（判活/定位最常用）
- `#{pane_current_path}`：当前工作目录
- `#{pane_title}`（`#T`）：窗格标题
- `#{pane_width}` / `#{pane_height}`：宽高
- `#{pane_top}` / `#{pane_left}`：坐标
- `#{pane_active}` / `#{pane_in_mode}` / `#{pane_dead}` / `#{pane_marked}` /
  `#{pane_marked_set}`：状态
- `#{pane_dead_status}` / `#{pane_dead_signal}` / `#{pane_dead_time}`：退出信息
- `#{pane_mode}`：pane mode

## 客户端 client

- `#{client_name}` / `#{client_termname}` / `#{client_session}`：client 名 / term / 会话

## 其它

- `#{host_short}`：短主机名
- `#{history_size}` / `#{history_limit}`：回滚行数

## 条件与操作符

- `#{?cond,then,else}`：三元（如 `#{?pane_active,on,off}`）
- `#{==:a,b}` / `#{!=:a,b}`：比较（如 `#{?#{!=:#{pane_dead_status},},...}`）
- `#{E:option}` / `#{T:option}`：默认 status-format 模板里用于展开选项值 / 模板选项
- `#{P:}` / `#{S:}` / `#{R:}` / `#{n:}` / `#{q:}` / `#{t:}` / `#{=N:...}` 等也出现在默认模板

> 完整规范见 tmux man `FORMATS`；rmux 特有 token 以 `status-format` / `window-status-format` 默认值为准。
