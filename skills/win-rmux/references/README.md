# rmux 参考知识体系

本目录是 rmux 0.10.0 在 Windows/pwsh 环境下的完整参考资料，按「概念 → 命令 → 扩展 →
键位 → 选项 → 实测踩坑」分层，供 skill 与后续调试统一引用。

- [overview.md](overview.md) — 概念模型与核心命令速查
- [commands.md](commands.md) — 全量命令参考（tmux 兼容面，`rmux list-commands`）
- [extensions.md](extensions.md) — RMUX 扩展命令（capabilities / diagnose / wait-pane / web-share 等）
- [formats.md](formats.md) — `-F` 格式变量（session/window/pane/client）
- [environment.md](environment.md) — 环境变量 / 配置 / tiny↔full helper / socket
- [hooks.md](hooks.md) — agent 状态 hook（idle/working/blocked 上报通道）
- [keybindings.md](keybindings.md) — 默认键位（prefix 表、root 表）
- [options.md](options.md) — 默认 server / window 选项与关键默认值
- [web-share.md](web-share.md) — 浏览器远程共享与隧道（含「远程 SSH」结论）
- [command-verification.md](command-verification.md) — 全量命令在真实 server 上的实测执行结果
- [rmux-usage.md](rmux-usage.md) — 实测踩坑与操作原语研究（daemon 模型、ConPTY 备屏、关闭退出）

快速入口：

- 查某条命令的语法与别名 → `commands.md`，或直接 `rmux <command> --help`
- 查 RMUX 独有能力（等待 / 查找 / 广播 / web 分享） → `extensions.md`
- 驱动 agent、判断提交、处理 TUI 限制 → `rmux-usage.md`
