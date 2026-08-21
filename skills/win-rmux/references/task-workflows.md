# win-rmux 任务原语详细实现（research / 快速 research / review-cycle / 快速 review）

> 主 SKILL「任务原语」段只有概览；本文件是四类任务工作流的**完整实现**（research 完整 +
> 快速 research 单 agent 变体 + review-cycle 完整 + 快速 review 单 agent 变体）：驱动步骤、
> prompt 模板、产物规范、循环退出条件、踩坑。踩坑的"排查"统一见 `troubleshooting.md`
> （唯一坑维护点），本文只给"怎么把任务跑起来"的标准步骤 + 必要提示。异常排查去 troubleshooting。

## 0. 前置

四类任务都先走六原语：`launch`（建执行单元，上 2 下 1：codex/kimi/claude）-> `locate`
复核 pane -> 需要时 `recover` 弹前台看板。产物走**写文件**（备屏 TUI 完整帧不可从外部
读，长产物永久丢，见 troubleshooting「TUI 备屏」）。

## 0.1 执行单元命名分类（标准，一眼看出"是执行单元 + 跑什么任务"）

每个执行单元（rmux session 名 + wt 窗口标题）必须体现：**(1) 是执行单元；(2) 哪类任务；
(3) 哪个具体任务（task-id）**。统一格式，避免多单元并存时分不清。

```text
session 名 : <type>-<task-id或短名>        例：rs-20260821-wsl（研究）/ rv-20260821-features（评审复核）
wt 窗口标题: [<type>] <短主题> - <task-id>  例：[research] WSL 镜像 - r-20260821-wsl
pane 内   : WIN_RMUX_AGENT=<agent>（codex/kimi/claude）不重复，unit 用 session 名
```

- `type`（任务类型）：`research` / `review`（评审复核）。前缀建议：`rs-` 研究、`rv-` 评审。
- session 名用 `rs-`/`rv-` + task-id（.rmux_tasks 的第 1 段工具缩写一致）；task-id 见
  `.rmux_tasks/<task-id>`。
- wt 标题带 `[research]`/`[review]` 标签 + 短主题，attach 时一眼可辨。
- pane 不需编码单元：unit 即 session 名，`Get-AgentPane` 按 `WIN_RMUX_AGENT` 寻址即可。
- **撞名/复用**：目标 session 名已存在时，**绝不往它上面叠窗格、绝不静默 kill**；默认中止并提示
  手动处理，或用 `kill-session -t <冲突名>` 显式清理后再建（见 SKILL.md「环境探针」）。

## 1. research：研究任务

### 1.1 目标与产物

面向"根据需求去查清一件事并给出可用结论 + 可跑原型"。**核心方式 = 两个维度并行研究、交叉验证**：

- **代码维度（gh）**：用 `gh search code "<kw>" --repo <owner/repo>` / `gh api repos/<owner>/<repo>/...`
  查 GitHub 真实代码、仓库结构、版本、release、issues：得到"代码里到底怎么写的"。
- **信息维度（web）**：搜官方文档、公告、教程、讨论/issue 结论：得到"为什么这样、还有哪些方案/坑"。
- 两个维度**都要做**（不是二选一）：信息维度先定位方向和候选方案，代码维度再用真实仓库/代码验证；结论须能指出证据来自哪条 gh 命中或哪个来源。
- 产物二件套（让 agent 写到指定路径，绝对路径）：
  - 研究报告：`.rmux_tasks/<task-id>/research/research-<topic>.md`（结论 + 依据 + 可行方案 + 取舍）
  - 最小原型 POC：`.rmux_tasks/<task-id>/research/poc-<topic>/`（可独立运行的最小编译/执行，验证方案）

### 1.2 步骤

```text
1. launch（建单元）-> locate（复核 pane）
2. drive 研究 prompt（见下方模板）给一个 agent（深度研究）或按需分给多个（分工不同子题）
3. observe/judge：轮询产物文件出现（加超时上限，防永久挂起）
4. 读 .rmux_tasks/<task-id>/research/research-<topic>.md 与 poc-*/（不经 rmux，产物完整）
5. 主窗口审阅报告 + 跑 POC 验证（在宿主侧执行，或再 drive 给 agent 跑通）
6. 需要迭代：drive 追问/修订 -> 回第 3 步；否则 close
```

### 1.3 research prompt 模板（ASCII，避免 send-keys 乱码；长则写文件让 agent Read）

调研需求的完整 prompt 模板（写进 `.rmux_tasks/<task-id>/prompt.md` 或直接 send 短版）：

```text
RESEARCH task (read-only; do not modify project files).
Objective: <一句话需求>
Research method (two dimensions, do BOTH and cross-check):
  A. Code dimension (gh): gh search code "<kw>" --repo <owner/repo> / gh api repos/<owner>/<repo>/...
     -> find how real code/repos do it (versions, releases, issues).
  B. Info dimension (web): search official docs, announcements, tutorials, issue discussions
     -> find why, alternatives, known pitfalls.
  Evidence: cite which gh hit / which source each conclusion came from.
Deliver, to these exact paths:
  1. report : D:\<proj>\reports\research-<主题>.md   (markdown: 结论/依据/可行方案/取舍)
  2. poc    : D:\<proj>\reports\poc-<主题>\            (最小可运行原型 + 一句怎么跑)
Reply DONE <你名> when written.
```

- **两维度研究是硬要求**：模板里 A（代码维度）/ B（信息维度）都要做。**前置守卫不检查 gh**：
  研究开始前先自检 `Get-Command gh`（缺则提示装 gh 或明确告知只能做信息维度、代码维度结论降级），
  否则 gh 子任务直接失败。
- 长 prompt：不要 send-keys 一条超长：写入 `.rmux_tasks/<task-id>/prompt.md`（或研究专属
  路径），`drive` 一个短指令让它 Read 该文件（见 troubleshooting「drive 相关」长 prompt 截断）。
- 单 agent 研究类只看一个 pane 产物即够；多子题分工时按 pane 索引对应产物。

### 1.4 快速 research（单 agent 轻量变体）

> 何时用：只想快速查清一件事、拿一份结论即可，不需要最小原型 POC、也不想开满多个 pane 或
> 多轮追问。用 **1 个 agent、单轮、无迭代**；结论由主窗口自行判断采用。

```text
1. guard（前置守卫，同 research）+ launch 单 pane：会话名 rs-<task-id>（research 任务用
   rs- 前缀，见 0.1 命名分类），只建 1 个 pane（默认 codex，--no-alt-screen 便于
   capture/observe；可按需换 kimi/claude）
2. 写好研究指令文件 .rmux_tasks/<task-id>/research/prompt.md（同 1.3 模板；去掉 POC
   那节，或把 POC 标成可选）
3. drive 一条短指令（带 agent 名 resolver，勿让 agent 自己猜产物名）：
   "You are <agent>. Read .rmux_tasks/<task-id>/research/prompt.md and write your report
   to .rmux_tasks/<task-id>/research/research-<topic>.md"
4. observe/judge 轮询单一报告文件出现（固定 research-<topic>.md）-> 读文件（不经 rmux，
   备屏完整）
5. 主窗口读结论 -> 自行判断是否足够 -> close（不 drive 追问、不跑 POC 验证循环）
```

- 与完整 research 的区别：**单一 agent、单一轮次、默认无 POC（或 POC 可选）、无迭代追问**；
  只在"拿一份结论即可、是否展开由主窗口自己定"的场景用。
- 产物仍落 `.rmux_tasks/<task-id>/research/`，命名 research-<topic>.md（单文件）。
- 单 pane 启动时 launcher 只跑 `new-session -d`（不带 `-A`，避免静默附加残留会话）；不
  `split-window`。

## 2. review-cycle：评审->修改->复核循环

### 2.1 目标产物与循环

审一批代码改动，收敛到"三方一致、无 must-fix"：
- 每轮产物：`.rmux_tasks/<task-id>/review/review-<agent>.md`（首轮独立评审）、`.rmux_tasks/<task-id>/recheck/<round>/recheck-<agent>.md`
  （复核上轮修复）、`.rmux_tasks/<task-id>/review/prompt.md`（指令文件，长 prompt 用）。
- 循环：评审 -> 主窗口按报告改代码 -> 复核 -> 直到三方都"无 must-fix"。
- **不关闭执行单元**：循环全程保留单元（会话上下文不断，避免每轮重开）。终态达成后才
  `close`（或 `recover` 供主窗口继续）。

### 2.2 步骤

```text
1. launch（建单元，会话名 task-<id>、wt 标题 <task-type>-<topic>；见「执行单元命名」）-> locate
2. 首轮评审：
   - 写好 review 指令文件 .rmux_tasks/<task-id>/review/prompt.md（指定审哪个 diff / 哪些文件 / 产物路径）
   - drive 给 codex/kimi/claude 各一条短指令（带 agent 名）："You are <agent>. Read
     .rmux_tasks/<task-id>/review/prompt.md and write your verdict to
     .rmux_tasks/<task-id>/review/review-<agent>.md"
   - 轮询 review-codex|kimi|claude.md 三份齐全（文件出现；若上轮同名，先清 or r<N> 前缀）
3. 主窗口综合三份 review：归纳 must-fix（三方共同的必改、单方的参考/标注），按要求改代码
4. 复核（不关单元，round 递增到 recheck/2、recheck/3…）：
   - 更新指令文件 .rmux_tasks/<task-id>/recheck/<round>/r<N>-prompt.md："上轮修复后复核，
     只报还存在的 must-fix"（给上轮修复的 diff 或提交号，逐项对照）
   - drive 给三 agent 各"Read <r<N>-prompt.md> and write r<N>-recheck-<agent>.md"
   - 轮询三份 r<N>-recheck-<agent>.md 齐全
5. 判断：三份复核是否都以 `AGREE:` 开头（= 无 must-fix）？
   - 否 -> 主窗口按剩余意见再改 -> 回第 4 步（round+1）
   - 是 -> 一致达成，close（或 recover 继续）
   - 保护：设最大轮数（如 5），超限转人工判断，防"不关单元直到一致"死循环
```

### 2.3 review prompt 模板（指令文件，agent Read）

> 指令文件供三 agent 共享；占位 `<agent>` 由短 drive 指令带上 agent 名解析，勿让 agent 自己
> 猜（否则三 agent 写同一文件互相覆盖）。模板尽量 ASCII（占位用 `<topic>/<agent>/<issue>`），
> send-keys 的短指令必须纯 ASCII--中长模板本身写文件让 agent Read。

首轮（指向给定 diff/文件）：写到 `.rmux_tasks/<task-id>/review/prompt.md`：

```text
REVIEW <scope> (read-only; do NOT modify files).
Scope: <e.g. git show HEAD~N..HEAD, or list of files>; cross-check <references docs>.
Report ONLY bugs/regressions/edge cases (not style). Skip already-accepted items.
Write verdict to : <proj>/.rmux_tasks/<task-id>/review/review-<agent>.md
  - start with "AGREE:"  if no must-fix
  - start with "REGRESSION:" if must-fix (list file/line + why)
Do NOT read/open secret/credential files (.secrets, *key*.ps1, API-key/token);
focus code structure/logic/consistency.
```

复核（上轮修复后）：写到 `.rmux_tasks/<task-id>/recheck/<round>/r<N>-prompt.md`：

```text
RECHeck <scope> after apply of my fixes (read-only).
Fix reference: <git show <hash> | git diff <base>..<head> | 未提交: git diff> - 对照上轮 review
  的 must-fix 逐项验证；若修复已提交给提交号，未提交给工作区 diff。
Report ONLY: must-fix the fixes did NOT address + new regressions introduced by the fixes.
If all good, start with "AGREE:" else "REGRESSION:".
Write to : <proj>/.rmux_tasks/<task-id>/recheck/<round>/r<N>-recheck-<agent>.md
Skip secret/credential files. 
```

> 占位解析：短 drive 指令带 agent 名，如 `You are claude. Read
> <proj>/.rmux_tasks/<task-id>/recheck/<round>/r<N>-prompt.md and write your verdict to
> <proj>/.rmux_tasks/<task-id>/recheck/<round>/r<N>-recheck-claude.md`。文件里出现 `<agent>`
> 时由 agent 按自己名填。
```

### 2.4 review 循环提示（来自 2026-08-21 ohmypwsh / win-rmux 实战）

- **产物一致命名**：统一放 `.rmux_tasks/<task-id>/`，轮次用 `recheck/<round>/r<N>-` 前缀区分；
  旧的保留归档（每轮新建目录不覆盖，`.rmux_tasks/README.md` 是归档索引）。
- **三份都到齐才算一轮**：轮询用「三文件全出现 -> 读齐 -> 综合」，别拿到一份就改。
- **不盲目按单 agent 意见改**：三方可能意见不同，主窗口把 must-fix 归纳（共同的必改、
  单方的参考/标注），避免改过头。上一轮 review 实践：codex/kimi/claude 对一个真回归
  （如 `$features 整段重复`）会独立命中，主窗口据此定改法。
- **复核轮 prompt 必须给「上轮已改什么」**（diff 或提交号），否则 agent 会重复报已修项。
- **中长 prompt 写文件让 agent Read**（drive 一条短指令），避免 send-keys 截断/排队；短
  指令仍走 drive 严格流程（发->Enter->capture 验证提交）。
- **agent 读密钥/guard 源码会被自身策略或 secret-guard 反拦**：prompt 恒附 "skip
  secret/credential files"（见 troubleshooting「agent 行为」）。
- **不关单元**：循环中不要 `kill-session`：那会丢所有 agent 上下文；只有终态达成(一致的
  无需再改)才 close。

### 2.5 快速 review（单 agent 轻量变体）

> 何时用：小改动快速把关、单文件/单提交 diff、只想快速拿一份 review，不值得开满 3 个 agent
> 跑完整 review-cycle。用 **1 个 agent、单轮、无 recheck 循环**；拿到的意见由主窗口自行判断
> 采纳，不追求"三方一致"。

```text
1. guard（前置守卫，同 review-cycle）+ launch 单 pane：会话名 rv-<task-id>（review 任务用 rv- 前缀，
   见 0.1 命名分类），只建 1 个 pane（默认 codex，--no-alt-screen 便于 capture/observe；可按需换 kimi/claude）
2. 写好指令文件 .rmux_tasks/<task-id>/review/prompt.md（同 2.3 首轮模板；产物名固定
   review-<agent>.md，<agent> 由 drive 短指令解析，与步骤 1 选的 agent 一致）
3. drive 一条短指令（带 agent 名 resolver，勿让 agent 自己猜产物名）：
   "You are <agent>. Read .rmux_tasks/<task-id>/review/prompt.md and write your verdict to
   .rmux_tasks/<task-id>/review/review-<agent>.md"
4. observe/judge 轮询单一 review 文件出现（固定 review-<agent>.md，如 review-codex.md）
   -> 读文件（不经 rmux，备屏完整）
5. 主窗口自行判断采纳哪些 must-fix -> 改代码 -> close（不跑 recheck 循环）
```

- 与完整 review-cycle 的区别：**单一 agent、单一轮次、无 AGREE 三方判定、无 recheck**；
  只在"意见只作参考、改不改由主窗口自己定"的场景用。
- 产物仍落 `.rmux_tasks/<task-id>/review/`，命名 review-<agent>.md（单文件）；不要用
  `r<N>-recheck` 前缀（那是循环专属）。
- 单 pane 启动时 launcher 只跑 `new-session -d`（直接建，不带 `-A`：`-A` 会静默附加到同名
  残留会话，正是环境探针要防的叠窗格）；不 `split-window`。

## 3. 产物目录约定（标准，严格）

所有项目和任务产物统一归档在 **项目根 `.rmux_tasks/`** 下，按**任务 id** 分层，每个任务一个
独立目录，内部再按阶段归档。**定义成标准**，新增任务一律遵循，不散落。

```text
<project>/
  .rmux_tasks/                          # 任务归档根（运行时产物；入库与否按项目约定，win-rmux 本体入库作归档）
    README.md                           # 归档索引（任务总览：id/标题/阶段/结论/关联提交）
    <task-id>/                          # 每个任务一个目录；task-id = <工具>-<日期>-<短名>，如 r-20260821-wsl 或 v-20260821-features
      prompt.md                         # 本轮/本任务主指令文件（research 或 review 指令，供 agent Read 防截断）
      research/                         # 研究任务：阶段一 研究
        research-<topic>.md             # 研究报告（结论/依据/方案/取舍）
        poc-<topic>/                    # 最小原型 POC（可独立运行 + 一句怎么跑）
      review/                           # 评审任务：阶段一 首轮独立评审
        review-codex.md
        review-kimi.md
        review-claude.md
      recheck/<round>/                  # 评审任务：复核循环（round = 1 起递增）
        r<N>-prompt.md                  # 第 N 轮指令文件（三 agent 共用同一份）
        recheck-codex.md
        recheck-kimi.md
        recheck-claude.md
```

编码规范（严格）：

- **根**：`<project>/.rmux_tasks/`；所有研究/评审产物、指令文件、POC 一律入其下，不在项目根散落。
- **任务 id**：`<工具>-<YYYYMMDD>-<英文短名>`；工具 = `r`（research）/ `v`（review 评审复核）。
  例：`r-20260821-wsl`（研究 WSL）、`v-20260821-features`（评审 features 修复）。
- **指令文件**：每任务一个 `prompt.md`；多轮复核则在 `recheck/<round>/r<N>-prompt.md`。
  三 agent 共用同一份指令（prompt 里不要写死单个 agent 名）。
- **产物命名**：`research-<topic>.md`、`review-<agent>.md`、`recheck-<agent>.md`、
  `poc-<topic>/`。agent 固定 `codex|kimi|claude`。
- **同任务多轮**：research 一次->多子题可在 `<task-id>/research/poc-<sub>/` 细分；
  review 多轮在 `recheck/<round>/` 递增，旧的保留不覆盖。
- **归档索引**：`.rmux_tasks/README.md` 记录每个 task-id 的 阶段/结论/关联提交（win-rmux
  review 归档即此模式）。
- **ignore**：`.rmux_tasks/` 是否入 git 按项目约定；运行时产物若不想入库，在项目 `.gitignore`
  加 `.rmux_tasks/`（win-rmux 本体自己的任务产物即放 `.rmux_tasks/`，入库作归档）。

