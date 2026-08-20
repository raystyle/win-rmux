# rmux 环境变量 / 配置 / 进程模型

## 环境变量

- `RMUX_DISABLE_TINY_CLI=1`：强制走 full helper，规避 tiny CLI 误报（如 `can't find pane`）。
- `RMUX_DISABLE_TMUX_FALLBACK=1`：禁用 `tmux.conf` 回退解析。
- `CLAUDE_CODE_GIT_BASH_PATH`：`rmux claude` teammate pane 需要的 Git Bash 路径（Windows）。

## 配置

- `-f FILE`：指定配置文件。
- 无 rmux 配置时，尽力解析标准 `tmux.conf` 路径；不支持的插件行会报告但不会中止启动。
- 用 `RMUX_DISABLE_TMUX_FALLBACK=1` 关闭回退。

## socket / 命名管道

- 顶层：`-L socket-name`、`-S socket-path`。
- Windows 默认命名管道：`\\.\pipe\rmux-<...>`。
- 客户端与 daemon 通过该 socket 通信；`kill-server` 杀 daemon，最后一个会话销毁后 daemon 自动退出。

## tiny CLI / full helper / daemon 进程模型

- 公开入口 `rmux.exe` = tiny 分发器；完整实现 `libexec\rmux\rmux.exe`（full helper）；
  安装目录另含 `rmux-daemon.exe`（daemon）。
- tiny CLI 只处理热路径 detach 命令，某些情况会误报；`RMUX_DISABLE_TINY_CLI=1` 走 full helper 重试。
- 只复制 `rmux.exe` 是无效安装（README 明确说明）。

## 顶层 flags

```text
rmux [-2CDlNuVv] [-c shell-command] [-f file] [-L socket-name] [-S socket-path] [-T features] [command [flags]]
```
