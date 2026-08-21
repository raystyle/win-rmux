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
会自动发现并把**整个 skill 目录**装到对应 agent 的用户级 skills 目录。注意：本 skill 不只是
`SKILL.md`：前置守卫会直接执行 `scripts/refresh-user-env.ps1`、`scripts/install-agent-hooks.ps1`，
hook 回写依赖 `hooks/win-rmux-agent-state.ps1`，因此 `scripts/`、`hooks/`、`references/`
必须随 SKILL.md 一起完整发布/安装，缺任何一个目录守卫都会失败。

```bash
# 推荐：装到最新 release 并锁定版本（后续 gh skill update 跳过，升级需显式解 pin）
# Codex
gh skill install raystyle/win-rmux win-rmux@v0.1.0 --pin --agent codex --scope user

# Claude Code
gh skill install raystyle/win-rmux win-rmux@v0.1.0 --pin --agent claude-code --scope user

# Kimi Code
gh skill install raystyle/win-rmux win-rmux@v0.1.0 --pin --agent kimi-cli --scope user
```

> 想跟动态 HEAD（不锁版本）可去掉 `@v0.1.0 --pin`（默认解析：最新 release tag，无则用默认分支 HEAD）。

安装后重启对应 agent 生效。三端统一从 `skills/win-rmux/SKILL.md` 安装，并带上
`references/rmux-usage.md`。

校验与升级：

```bash
gh skill list --agent codex      --scope user
gh skill list --agent claude-code --scope user
gh skill list --agent kimi-cli   --scope user
gh skill update --dry-run          # pinned 技能会显示 "pinned to <tag> (skipped)"
gh skill update --unpin win-rmux   # 解除锁版
gh skill update --all              # 解开后更新到最新
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

旧版 `gh`（< 2.97，无 `skill` 命令）仍可用 `gh api` 回退：必须拉取**完整目录**
（SKILL.md + scripts/ + hooks/ + references/，缺 scripts/ 或 hooks/ 守卫会失败）：

```bash
dest=~/.codex/skills/win-rmux   # claude / kimi 同理，替换目标目录
mkdir -p "$dest"
gh api repos/raystyle/win-rmux/tarball/HEAD -H "Accept: application/vnd.github+json" > /tmp/win-rmux.tar.gz
tar -xzf /tmp/win-rmux.tar.gz --strip-components=2 -C "$dest" --wildcards '*/skills/win-rmux/*'
```

## 版本发布（发布新版本）

版本由 git tag / release 管理（无独立 version 字段；`gh skill install <skill>@<tag>`
= @git tag，`--pin` 锁定后 `gh skill update` 跳过）。当前最新：`v0.1.0`。

```bash
# 校验合规（推荐：无 warning 再发）
gh skill publish --dry-run

# 打版本 + 建 GitHub release（semver tag；自动加 agent-skills topic）
gh skill publish --tag v0.2.0

# 发版后让下游锁新版本：install ...@v0.2.0 --pin
```

> tag `refs/tags/v*` 已被 tag protection ruleset 锁定（禁删除/禁 force-push），release 不可变。
> `gh skill` 无内置删除命令，卸载靠 `Remove-Item <agent-skills>/win-rmux -Recurse`。

## 说明

- skill 名 `win-rmux`，底层命令仍是 `rmux`（Windows/pwsh 的 tmux 兼容多路复用器）。
- 完整实测踩坑见 `AGENTS.md` / `CLAUDE.md`。
