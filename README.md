# win-rmux

在 Windows/pwsh 用 RMUX 开新终端窗口，把多个 agent（Codex / Kimi / Claude Code）放到同一终端
的不同窗格里运行与驱动：新终端 + 多窗格布局（上 2 下 1）、send-keys / capture-pane、
环境清理（NO_COLOR / TERM / PATH）、agent 状态判断原语、关闭退出。

仓库源文件：

- `skills/win-rmux/SKILL.md`：skill 本体（三端通用 SKILL.md 格式）
- `AGENTS.md`：Codex / Kimi 的 skill 内容（与本体同源）
- `CLAUDE.md`：Claude Code 的 skill 内容（与本体同源）

## 全局安装（gh 命令，三端）

前置：已安装 `gh` 并登录。

### Codex

```bash
mkdir -p ~/.codex/skills/win-rmux
gh api repos/raystyle/win-rmux/contents/skills/win-rmux/SKILL.md -H "Accept: application/vnd.github.raw" > ~/.codex/skills/win-rmux/SKILL.md
```

### Claude Code

```bash
mkdir -p ~/.claude/skills/win-rmux
gh api repos/raystyle/win-rmux/contents/skills/win-rmux/SKILL.md -H "Accept: application/vnd.github.raw" > ~/.claude/skills/win-rmux/SKILL.md
```

### Kimi Code

```bash
mkdir -p ~/.kimi-code/skills/win-rmux
gh api repos/raystyle/win-rmux/contents/skills/win-rmux/SKILL.md -H "Accept: application/vnd.github.raw" > ~/.kimi-code/skills/win-rmux/SKILL.md
```

安装后重启对应 agent 生效。三端统一从 `skills/win-rmux/SKILL.md` 安装（同为 SKILL.md 格式）。

## 说明

- skill 名 `win-rmux`，底层命令仍是 `rmux`（Windows/pwsh 的 tmux 兼容多路复用器）。
- 完整实测踩坑见 `AGENTS.md` / `CLAUDE.md`。
