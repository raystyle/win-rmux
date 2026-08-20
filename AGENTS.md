# win-rmux 开发协作规则（Codex）

## 仓库结构

- `skills/win-rmux/SKILL.md`：skill 本体（agentskills 标准，frontmatter + 操作原语）
- `skills/win-rmux/references/rmux-usage.md`：详细实测研究（daemon 进程模型、三组原语、踩坑）
- `AGENTS.md` / `CLAUDE.md`：本文件，开发调试过程与测试回归验收方法
- `README.md`：gh 命令三端安装说明

## 调试开发过程

win-rmux 从 ohmypwsh 项目的 rmux skill 迁移独立而来。关键踩坑已当场沉淀（详见
`skills/win-rmux/references/rmux-usage.md`）：

- 回车键名只有 `Enter` 有效，`C-m` 被当字面量 `^M`
- TUI agent 提交判断用进程 CPU 增长（capture 因 alternate screen 为空）
- `has-session` 退出码在 PowerShell `if` 不可靠，改用 `list-sessions` + `-contains`
- tiny CLI 误报 `can't find pane`，设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper
- 中文 payload 经 send-keys 乱码，驱动 prompt 用 ASCII
- 上 2 下 1 布局关键在 `split-window -f -v`（全宽跨整窗）
- 恢复 attach 用 `attach-session -d`，不 `new-session -A` 不 `kill-server`

## 测试回归验收方法

1. gh 安装三端：codex（`~/.codex/skills`）、claude（`~/.claude/skills`）、kimi
   （`~/.kimi-code/skills`），重启对应 agent 后 skill 可见。
2. 新终端 + 三席上 2 下 1：`new-session` + `split-window -h` + `split-window -f -v`，
   验证 `0.0 codex / 0.1 kimi / 0.2 claude`，0.2 全宽在下。
3. send-keys 提交原语：发文本 + `Enter`，进程 CPU 增长判定已提交，不盲目补回车。
4. 恢复 attach：关 wt 再弹窗 `attach-session -d -t dev`，验证 term=xterm-256color。
5. 关闭退出：`kill-session` / `kill-server`，验证 daemon 生命周期。
6. 三端互相 review：让 codex / kimi / claude 各自 review SKILL.md，统一操作原语。

## 任务

- [x] skill 独立仓库 + gh 三端安装
- [ ] 三端 gh 安装回归
- [ ] 三席上 2 下 1 实测回归
- [ ] 三端互相 review
