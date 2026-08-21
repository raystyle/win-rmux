# win-rmux

在 Windows/pwsh 用 RMUX 开新终端窗口，把多个 agent（Codex / Kimi / Claude Code）放到同一终端
的不同窗格里运行与驱动：新终端 + 多窗格布局（上 2 下 1）、send-keys / capture-pane、
环境清理（NO_COLOR / TERM / PATH）、agent 状态判断原语、关闭退出。

仓库源文件（目录结构 + 各文件作用）：

```text
win-rmux/
  AGENTS.md         开发协作规则（面向 Codex / Kimi 使用者：环境约束、调试、测试回归验收）
  CLAUDE.md         一行 `@AGENTS.md` 桥接（权威源为 AGENTS.md，不重复维护）
  LICENSE           MIT 许可证
  README.md         本文件：skill 简介 + 三端(gh skill)安装 / 更新 / 版本发布说明
  skills/
    win-rmux/       skill 本体（agentskills 标准：SKILL.md frontmatter + 操作原语；由
                    gh skill install 整目录安装，缺任一子目录守卫都会失败）
      SKILL.md      skill 入口：六原语(launch/locate/drive/observe/judge/recover.close)
                    + 四任务原语(research / 快速 research / review-cycle / 快速 review) + 前置守卫 + yolo 免交互表
      hooks/
        win-rmux-agent-state.ps1  agent 状态上报 hook（working/blocked/idle 回写
                                  AGENT_STATE_<name>，供 judge 读取；由 scripts/
                                  install-agent-hooks.ps1 安装到三端 agent 配置）
      references/   参考文档（供 skill 与 debug 引用，不直接执行）
        overview.md              概念模型与核心命令速查
        commands.md              全量命令参考（tmux 兼容面，rmux list-commands）
        extensions.md            RMUX 扩展命令（capabilities / diagnose / wait-pane / web-share 等）
        formats.md               -F 格式变量（session/window/pane/client 的格式占位符）
        environment.md           环境变量 / 配置 / tiny<->full helper / socket
        hooks.md                 agent 状态 hook 机制与配置（idle/working/blocked 通道）
        keybindings.md           默认键位（prefix 表、root 表）
        options.md               默认 server / window 选项与关键默认值
        web-share.md             浏览器远程共享与隧道（含「远程 SSH」结论）
        command-verification.md  全量命令在真实 server 上的实测执行结果
        rmux-usage.md            操作原语研究 / 完整实现（launcher、drive 流程、
                                 daemon 模型、ConPTY 备屏、恢复/关闭退出）
        task-workflows.md        任务原语详细实现（research 研究->报告+POC、
                                 review-cycle 评审->修改->复核循环到一致：prompt 模板/循环条件）
        troubleshooting.md       **唯一踩坑/排障维护点**（现象 + 原因 + 排查/处理速查表）
      scripts/
        install-agent-hooks.ps1  把 agent 状态 hook 写进三端 agent 配置（幂等 + 路径感知）
        refresh-user-env.ps1     把 User 环境变量补齐到当前会话（agent 缺 API key 时用）
```

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
gh skill install raystyle/win-rmux win-rmux@v0.1.5 --pin --agent codex --scope user

# Claude Code
gh skill install raystyle/win-rmux win-rmux@v0.1.5 --pin --agent claude-code --scope user

# Kimi Code
gh skill install raystyle/win-rmux win-rmux@v0.1.5 --pin --agent kimi-cli --scope user
```

> 想跟动态 HEAD（不锁版本）可去掉 `@v0.1.5 --pin`（默认解析：最新 release tag，无则用默认分支 HEAD）。

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
= @git tag，`--pin` 锁定后 `gh skill update` 跳过）。当前最新：`v0.1.5`。

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
- 完整实测踩坑见 `AGENTS.md`（权威源；`CLAUDE.md` 仅一行 `@AGENTS.md` 桥接）。
