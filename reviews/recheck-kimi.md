# win-rmux 修复复核（Kimi）

日期：2026-08-21。对象：上一轮 review（`reviews/review-kimi.md`）所提问题的修复核验。
方法：逐条对照 `SKILL.md`、`scripts/install-agent-hooks.ps1`、`scripts/refresh-user-env.ps1`、
`references/hooks.md` 当前内容，并标注仍存在的残留问题。

## 结论总览

| 检查项 | 状态 |
| --- | --- |
| 1. SKILL.md 守卫用 `$SkillDir` | ✅ 已修复 |
| 1. drive 用 `-l` + 单独 Enter | ✅ 已修复 |
| 1. judge 回退两段式 | ✅ 已修复 |
| 2. 空/非法 JSON 兜底 | ✅ 已修复 |
| 2. 自动建父目录 | ✅ 已修复 |
| 2. 逐 agent try/catch | ✅ 已修复 |
| 2. `[features]` 去重（表内插入） | ✅ 已修复（有一处残留边缘） |
| 3. 只补缺失 + 跳过 5 项 + 无 `$e` 泄漏 | ✅ 已修复 |
| 4. hooks.md 事件表对齐安装脚本 | ✅ 已修复 |

## 1) SKILL.md — 全部确认

- 守卫 `SKILL.md:41-43` 新增显式 `$SkillDir`（注释说明粘贴执行时 `$PSScriptRoot` 为空），
  `:52`/`:54` 两处脚本引用均改用 `$SkillDir`，`:57-58` 补了原因说明。正确。
- drive `SKILL.md:111-112`：文本用 `-l` 字面量 + 单独一次 `Enter`，注释解释了原因。正确。
- judge 回退 `SKILL.md:164-166`：同样两段式（`-l` 文本 → 单独 Enter），与 drive 规则一致。正确。
- 新增「TUI 备屏写文件取产物」一节（`SKILL.md:127-146`）方向正确（备屏读不出是实测结论）。

## 2) install-agent-hooks.ps1 — 四项确认，细节如下

- 空/非法 JSON：`:71` 空/空白文件兜底为 `'{}'`；`:72-78` try/catch 非法 JSON → 备份原文件
  并从 `@{}` 重建。正确。
- 父目录创建：JSON 路径 `:87-88`、kimi `:97-98`、codex config `:127-128` 三处都有
  `New-Item -ItemType Directory -Force`。正确。
- 逐 agent try/catch：`:165-172` 四个安装步骤各自 try/catch，`$fail` 计数汇总，
  单点失败不再拖垮整脚本。正确。
- `[features]` 去重：`:135-159` 已有 `[features]` 表时在表体末尾插入 `hooks = true`
  （到下一个表头或 EOF），不再追加重复表头。逻辑走查（表在中间/表在末尾两种情形）均正确。

## 3) refresh-user-env.ps1 — 全部确认

- 只补缺失：`:27` 先查 Process 是否已有同名非空值，有才跳过，不覆盖宿主有意设置的值。正确。
- 跳过清单：`:22` = `PATH, PSModulePath, TERM, COLORTERM, NO_COLOR`，与要求一致；
  头注释 `:12-14` 也更新了设计取舍说明（含 PSModulePath 并集理由）。正确。
- `$e` 泄漏：`:38` `Remove-Variable skip,user,n,e` 已含 `e`。正确。

## 4) references/hooks.md — 确认

- 事件表（`hooks.md:26-30`）与安装脚本逐一对齐：codex 6 事件（含 `SessionEnd`）、
  claude 5 事件（明确标注未注册 `SubagentStop`）、kimi 6 事件（含 `Interrupt`）。
- 新增 `:35` 关于 `PermissionRequest` 非 Claude Code 标准事件的提醒，属实且有价值。正确。

## 仍存在的残留问题（非阻塞，建议下轮处理）

1. **`SKILL.md:137` 新一节又忘了 `-l`**：文件产物获取示例
   `rmux send-keys -t $p --wait quiet ... -- $writePrompt` 未加 `-l`，而该 prompt 含空格、
   冒号、反斜杠——正是 drive 刚修复的同一类坑，两节自相矛盾。
2. **`install-agent-hooks.ps1:50-60` `Remove-KimiHookBlocks` 误删风险未修**：块仍只在下一个
   `[[hooks]]` 处收尾；陈旧 hook 块之后若夹 `[features]`/`[model]` 等单括号段，仍会被吞进
   块里一并删除。上一轮已指出，本轮未动。
3. **`install-agent-hooks.ps1:131` 边缘**：若 `[features]` 里已有 `hooks = false`，
   Contains 检查不命中，会在同一表内插入第二个 `hooks` 键 → TOML 重复键解析错误；
   且 `:131` 的全文 Contains 会被注释行（如 `# hooks = true`）误判为已启用。
4. **`install-agent-hooks.ps1:135` vs `:142` 不一致**：外层检测用 `^\[features\]`（列 0），
   内层用 `^\s*\[features\]`；带前导空白的合法 TOML 表头会走追加分支 → 重复表头（极小概率）。
5. **`install-agent-hooks.ps1:30` 去重仍只看 `hooks[0].command`**（上轮已提，未改）：
   claude 多命令 matcher 组场景下重复条目仍可能累积。
6. **refresh-user-env.ps1 仍未展开 REG_EXPAND_SZ**：含 `%USERPROFILE%` 等引用的 User 变量
   按字面量同步进 Process（对 API key 无碍，对路径类变量是坑）。上轮已提，未改。
7. **`SKILL.md:43` 默认值是 `C:\Users\ray\.claude\skills\win-rmux`**：三端安装的同一份 skill
   都指向 claude 路径，codex/kimi 安装处照抄会指错目录。注释已提示"按本机安装路径填"，
   可接受，但建议改成按安装端区分的示例或环境变量。

## 复核结论

四项检查清单全部修复到位且实现正确；上述 7 条为残留/新引入的次要问题，其中
第 1、2 条建议优先处理（一个是自相矛盾的示例，一个是可能误删用户配置的旧坑）。
