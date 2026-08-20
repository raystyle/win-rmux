# win-rmux

在 Windows/pwsh 用 RMUX 开新终端窗口，把多个 agent（Codex / Kimi / Claude Code）放到同一终端
的不同窗格里运行与驱动：新终端 + 多窗格布局（上 2 下 1）、send-keys / capture-pane、
环境清理（NO_COLOR / TERM / PATH）、agent 状态判断原语、关闭退出。

仓库源文件：

- `skills/win-rmux/SKILL.md`：skill 本体（三端通用 SKILL.md 格式）
- `AGENTS.md`：Codex / Kimi 的 skill 内容（与本体同源）
- `CLAUDE.md`：Claude Code 的 skill 内容（与本体同源）

## 全局安装（gh skill，三端）

前置：`gh` 2.97+ 并已登录（`gh auth status`）。win-rmux 调试稳定后再正式安装；开发自测用
`--from-local`（见下）。

skill 名 `win-rmux`，仓库结构符合 agentskills 的 `skills/*/SKILL.md` 约定，`gh skill install`
会自动发现并连同 `references/` 一起装到对应 agent 的用户级 skills 目录。

```bash
# Codex
gh skill install raystyle/win-rmux win-rmux --agent codex --scope user

# Claude Code
gh skill install raystyle/win-rmux win-rmux --agent claude-code --scope user

# Kimi Code
gh skill install raystyle/win-rmux win-rmux --agent kimi-cli --scope user
```

安装后重启对应 agent 生效。三端统一从 `skills/win-rmux/SKILL.md` 安装，并带上
`references/rmux-usage.md`。

校验与升级：

```bash
gh skill list --agent codex      --scope user
gh skill list --agent claude-code --scope user
gh skill list --agent kimi-cli   --scope user
gh skill update --dry-run
gh skill update --all
```

注意：`gh skill` 对 `kimi-cli` 的用户级默认目录是 `~/.config/agents/skills`（与 amp/replit
共用），不是旧方案手写的 `~/.kimi-code/skills`。如需精确落到指定目录，用 `--dir` 覆盖：

```bash
gh skill install raystyle/win-rmux win-rmux --dir ~/.codex/skills
gh skill install raystyle/win-rmux win-rmux --dir ~/.claude/skills
gh skill install raystyle/win-rmux win-rmux --dir ~/.kimi-code/skills
```

本地开发自测（无需发布）：

```bash
gh skill install D:\win-rmux win-rmux --from-local --agent codex --scope user
```

旧版 `gh`（< 2.97，无 `skill` 命令）仍可用 `gh api` 回退：

```bash
mkdir -p ~/.codex/skills/win-rmux
gh api repos/raystyle/win-rmux/contents/skills/win-rmux/SKILL.md -H "Accept: application/vnd.github.raw" > ~/.codex/skills/win-rmux/SKILL.md
# claude / kimi 同理，替换目标目录
```

## 说明

- skill 名 `win-rmux`，底层命令仍是 `rmux`（Windows/pwsh 的 tmux 兼容多路复用器）。
- 完整实测踩坑见 `AGENTS.md` / `CLAUDE.md`。
