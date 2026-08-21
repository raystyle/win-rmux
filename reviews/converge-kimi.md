# win-rmux 残留项收敛裁决（Kimi）

日期：2026-08-21。基线：HEAD `cff6826`（终审 FINAL_OK 之后）。对象：8 条非阻塞残留。
裁决规则：只有当残留不存在现实的正确性/损坏路径时才 ACCEPT。结论：**8 项全部 FIX，已落地并验证**。
改动未提交（git mutation 需用户确认），工作区 diff 含 `README.md`、`skills/win-rmux/SKILL.md`、
`skills/win-rmux/scripts/install-agent-hooks.ps1`。

| item | FIX/ACCEPT | reason | done |
| --- | --- | --- | --- |
| 1 Remove-KimiHookBlocks 吞单括号段 | FIX | 陈旧块后夹 `[features]`/`[model]` 会被连带删除 = 用户配置损坏路径，必须修 | ✅ 块收尾条件改为任意 TOML 表头 `^\s*\[`（install-agent-hooks.ps1:55）；已用合成 TOML 实测：陈旧块被删、`[features]`/`[model]`/当前路径块均保留（removed=1，四项断言全 True） |
| 2 stream-pane --lines 缺阻塞警告 | FIX | 照文档前台裸跑会永久阻塞（command-verification.md:143 实测 TIMEOUT），agent 会挂死 | ✅ SKILL.md:127 注释补「持续阻塞输出，勿前台裸跑——配超时或放后台/job」 |
| 3 Get-Content -Raw 无 -LiteralPath | FIX | 路径含 `[`/`]` 时按通配符解析，Test-Path 误判不存在 → 可能以 `{}` 起步覆盖既有配置 | ✅ 三处读取全部改 `Test-Path -LiteralPath` + `Get-Content -LiteralPath -Raw`（:71、:101、:131） |
| 4 污染 daemon 探针用裸 list-sessions | FIX | tiny CLI 误报空 → 误 `kill-server` 杀健康会话，正确性路径现实存在 | ✅ SKILL.md:44 守卫最前加 `$env:RMUX_DISABLE_TINY_CLI='1'`，探针与后续操作统一走 full helper |
| 5 PATH 重建丢进程独有条目 | FIX | 同会话新装/临时加入 PATH 的工具对 agent 不可见，正确性路径现实存在 | ✅ SKILL.md:50-51 改并集：Machine+User 优先，进程独有条目追加去重保留；已实测进程独有条目与 Machine 条目均在（测试里的 "machine entry False" 是大小写检查假象，`C:\WINDOWS\system32` 实际在列） |
| 6 轮询诊断硬编码 AGENT_STATE_kimi | FIX | 照抄示例驱动 codex/claude 时读到错误状态变量，诊断误导 | ✅ SKILL.md:140 引入 `$targetName`（须与 $p 对应），:148 诊断改 `"AGENT_STATE_$targetName"`；嵌套引号语法已实测可解析 |
| 7 无效 JSON 从 {} 重建覆盖用户文件 | FIX | 用户手误改坏 settings.json → 被 hooks-only 文件整个替换 = 配置损坏路径 | ✅ install-agent-hooks.ps1:74-78 改告警并 `return` 跳过（不动文件，提示手工修复后重跑） |
| 8 README 低估打包完整性 | FIX | gh api 回退只拉 SKILL.md → 守卫引用 scripts//hooks/ 直接失败，现实可用性路径 | ✅ README 安装节明确 `scripts/`、`hooks/`、`references/` 必须随 SKILL.md 完整发布；gh api 回退改 tarball 整目录解包 |

验证记录：

- `install-agent-hooks.ps1` 全文 AST 解析：PARSE OK。
- `Remove-KimiHookBlocks` 合成 TOML 功能测试：removed=1（预期 1），`[features]`、`[model]`、
  当前路径块保留，旧路径块删除。
- PATH 并集表达式在 pwsh 子进程实测：进程独有条目保留、Machine 条目保留。
- 全量 `git diff` 走查：无越界改动，行内注释同步更新。

结论：8/8 FIX 完成，无 ACCEPT 项。建议提交为一次 `fix: 收敛终审残留（hooks 块切分/LiteralPath/
守卫探针/PATH 并集/文档完整性）`。
