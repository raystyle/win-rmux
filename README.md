# win-rmux

在 Windows/pwsh 用 RMUX 开新终端窗口，把多个 agent（Codex / Kimi / Claude Code）放到同一终端
的不同窗格里运行与驱动：新终端 + 多窗格布局（上 2 下 1）、send-keys / capture-pane、
环境清理（NO_COLOR / TERM / PATH）、agent 状态判断原语、关闭退出。

## 全局安装（三端）

前置：已安装 `gh` 并登录。

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/raystyle/win-rmux/main/install.ps1 | iex"
```

或本地安装：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1
# 覆盖: pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Force
```

安装到：

- Codex：`~/.codex/skills/win-rmux/SKILL.md`
- Claude Code：`~/.claude/skills/win-rmux/SKILL.md`
- Kimi Code：`~/.kimi-code/skills/win-rmux/SKILL.md`

## 说明

- skill 名 `win-rmux`，底层命令仍是 `rmux`（Windows/pwsh 的 tmux 兼容多路复用器）。
- 完整实测踩坑见 SKILL.md 与配套研究文档。
