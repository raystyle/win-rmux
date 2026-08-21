# win-rmux 代码评审（Kimi）

日期：2026-08-21。范围：`skills/win-rmux/SKILL.md`（守卫 + drive 两段式 send-keys）、
`scripts/install-agent-hooks.ps1`、`scripts/refresh-user-env.ps1`、`references/` 与实际命令一致性。
已对本机 rmux 二进制核实：`send-keys --wait/--stable-for/--timeout`、`split-window -f`、
`stream-pane`、`pane-snapshot`、`find-panes` 均真实存在且与文档一致。

## 1) SKILL.md

- **`$PSScriptRoot` 在守卫中无定义**（`SKILL.md:43,45`）。skill 片段由 agent 在交互/粘贴 shell
  中执行，`$PSScriptRoot` 为空 → `. "/scripts/refresh-user-env.ps1"` 直接失败。守卫需要
  具体的 skill 安装目录（如显式解析 `WIN_RMUX_HOME` 或写死安装路径），不能用 `$PSScriptRoot`。
- **两段式 Enter 规则自相矛盾**：`SKILL.md:93-98` 明确 Enter 必须单独一次 send-keys
  （"与文本同发实测不提交"），但 judge 回退示例 `SKILL.md:126` 恰恰同发：
  `rmux send-keys -t ... -- 'prompt' Enter`。应拆成两次调用。
- **含空格 prompt**：`SKILL.md:99` 说含空格要用 `-l` 字面量，但 drive 示例（`SKILL.md:94`）
  没用 `-l`——照抄示例发真实 prompt 会踩 token 化坑。示例应加 `-l`。
- 次要：守卫 `SKILL.md:40` 用 Machine+User 重建 PATH，会丢当前会话进程级 PATH 新增
  （rmux-usage.md 已记录该副作用，但守卫处建议加行内注释）。

## 2) scripts/install-agent-hooks.ps1

- **`Remove-KimiHookBlocks` 可能误删无关 TOML**（`install-agent-hooks.ps1:50-58`）：
  `[[hooks]]` 块只在遇到下一个 `[[hooks]]` 时收尾。陈旧 hook 块之后若夹着单括号段
  （`[features]`、`[model]`、裸键值），会被吞进该块一并删除。块收集应在任何
  `^\s*\[` 头处停止。
- **`Enable-CodexHooksFeature` 可能搞坏 config.toml**（`:120-121`）：无条件在 EOF 追加
  `[features]\nhooks = true`。若文件已有 `[features]` 表，就是 TOML 重复表解析错误，
  codex 直接起不来。应先检测已有 `[features]` 段并把 `hooks = true` 插进去。
- **既有 JSON 非法/空文件即整脚本崩溃**（`:71`）：`$ErrorActionPreference='Stop'` 下，
  畸形或零字节 `hooks.json`/`settings.json` 让 `ConvertFrom-Json` 抛错，整个脚本挂掉，
  其余 agent 的 hook 都装不上。应逐文件 try/catch + 备份后从 `{}` 重建。
- **去重只看 `hooks[0].command`**（`:30`）：claude 一个 matcher 组挂多条 hook 命令、且
  win-rmux 的不是第一条时，无法去重 → 多次运行累积重复条目。应扫描组内所有子 hook。
- 次要：kimi 幂等判断（`:98`）是"包含当前命令即视为已装"——未来事件清单变化时老安装
  永远不会被更新。备份时间戳（`:15`）为秒级，同秒两次备份同名（有 `-Force`，无害）。

## 3) scripts/refresh-user-env.ps1

- **REG_EXPAND_SZ 值不展开**（`:16,21`）：`GetEnvironmentVariables('User')` 返回注册表原始值，
  如 `FOO=%USERPROFILE%\x` 会按字面量同步进 Process 环境，子进程看到的是未展开的 `%...%`。
  对 API key 无碍，对路径类变量是坑。建议对含 `%` 的值过一遍
  `[Environment]::ExpandEnvironmentVariables`。
- **会覆盖宿主有意设置的进程级值**：除 4 个跳过项外，所有 User 变量都写进 Process——
  宿主为本会话特意改的值被冲掉。可算设计取舍，但文件头注释应写明这一点。
- 琐碎：dot-source 时循环变量 `$e` 泄漏到调用方作用域（`:29` 只清了 skip/user/n）；
  头注释（`:8`）说守卫"显式设置 … NO_COLOR"，实际守卫是**删除**它。

## 4) references/ 一致性

- **hooks.md 事件表与安装脚本漂移**（`hooks.md:28-30`）：文档写 codex 装
  `SessionStart`/`PermissionRequest`、claude 装 `SessionStart`/tool-use/`SubagentStop`；
  而 `install-agent-hooks.ps1:127-129` 实际装 6 个 codex 事件、5 个 claude 事件
  （无 `SubagentStop`）、6 个 kimi 事件（含 `Interrupt`）。
- **同发 Enter 的示例与 SKILL.md 规则冲突**：`extensions.md:85` 和 `rmux-usage.md:163`
  都用 `-- '/status' Enter` 一次同发，SKILL.md 却要求两段式。要么限定语境（"短斜杠命令
  可同发，长 prompt 必须拆"），要么对齐。
- `commands.md` 与 `command-verification.md` 行尾 CRLF/LF 混用（外观问题）。
- 根 `README.md:10-11` 说 AGENTS.md/CLAUDE.md 是"skill 内容（与本体同源）"，实际二者是
  协作规则——描述过时。
- 已核实一致：drive/observe/judge 的命令与 flag 全部对得上真实二进制；hooks.md 的 codex
  Stop-hook 注意事项与 `SKILL.md:174-176` 一致；kimi 安装目录说明在 README/AGENTS.md 间一致。
