REVISE:

本轮新增的 research / review-cycle 两任务原语方向正确、与六原语总体自洽，但有 6 处必改项：
断链的坑索引、两处错误/自相矛盾的表述、一处逻辑矛盾、退出条件与产物命名的内部不一致。

## 1. 「长 prompt 截断」是坑，却断链且未归入 troubleshooting（坑职责冲突）

- `skills/win-rmux/SKILL.md:265` 与
  `skills/win-rmux/references/task-workflows.md:51,119` 都写
  「长 prompt 写文件让 agent Read，避免 send-keys 截断/排队」，并指向
  `troubleshooting.md` 的「drive 相关」，但 `troubleshooting.md` 的 drive 表里**没有**
  「长 prompt 截断 / 写文件 Read」这一行，引用落空。
- 这本身就是一条踩坑（长 prompt 经 send-keys 截断/排队），按仓库约定
  「踩坑唯一维护在 `troubleshooting.md`」应当把它作为一行追加进 drive 表，SKILL 与
  task-workflows 只保留「怎么跑」+ 指向该行；现在却把坑内容散落在 task-workflows 里，
  与「本文只给必要提示、异常排查去 troubleshooting」的自述不一致。

建议：在 `troubleshooting.md`「二、drive 相关」新增一行
「长 prompt 被截断/排队 → send-keys 长文本不可靠 → 完整指令写文件，drive 一条短指令
Read 该文件」，再把 SKILL.md / task-workflows.md 的正文精简为引用。

## 2. 「前置守卫已含 gh 是否安装检查」是错误指令

- `skills/win-rmux/references/task-workflows.md:49` 称「前置守卫已含 gh 是否安装检查」，
  但 `SKILL.md` 的「前置守卫」段落没有任何 `gh` 检查（只有 rmux 进程/会话、PATH、
  user-env、hook 安装）。
- research 原语明确依赖 `gh search code` / `gh api`，若照此文档执行会误以为 gh 已被
  守卫保证，机器没装 gh 时研究任务直接失败。

建议：二选一——在 SKILL 前置守卫补一句 `Get-Command gh` 检查，或把该句改为
「研究前先自检 `gh --version`」，不要声称守卫已覆盖。

## 3. 产物目录「被 .gitignore 忽略」与事实和下一句矛盾

- `skills/win-rmux/references/task-workflows.md:141-142` 写「全部放入被 `.gitignore`
  忽略的 `reports/`、`reviews/`」，但仓库当前**没有 `.gitignore`**，且 `reviews/*` 全部
  tracked（`git ls-files reviews/*` 列出 20 个文件，README 亦入库作归档）。
- 同一段紧接着又说「win-rmux 本体把 reviews 入库作归档」——两句自相矛盾。

建议：删掉「被 `.gitignore` 忽略」的说法，改为「运行时产物，入库与否按项目约定；
win-rmux 本体把 reviews 入库作归档」。

## 4. SKILL 图里「不关执行单元，直接 close/recover」自相矛盾

- `skills/win-rmux/SKILL.md:257` 循环终态写「不关执行单元，直接 close/recover」。
  但六原语中 `close` = `kill-session -t $unit`，恰恰就是关闭执行单元；「不关」与
  「直接 close」在同一句里冲突。
- `task-workflows.md` 的正确意图是：循环中不 kill，终态达成后才 close（kill-session）
  或 recover。SKILL 图这句把两个阶段压成了一句。

建议：改为「循环全程不 kill 单元；终态达成后才 close（或 recover）」。

## 5. review-cycle 退出条件用词不一致（APPROVE vs AGREE / todos）

- `task-workflows.md:79` 判断条件写「三份复核实 **todos** 都是 **APPROVE**/无 must-fix」，
  但同一文件的 prompt 模板（:93-94、:105）要求 agent 只写
  「**AGREE:**（无 must-fix）/ **REGRESSION:**（有 must-fix）」，根本没有 `APPROVE` 和
  `todos` 这两个信号。
- 照步骤 5 的字面去找 `APPROVE` 会找不到产物，退出条件（何时算「一致达成」）因此不明确。

建议：统一为一个信号词。若保持模板用 `AGREE:`，则步骤 5 改为
「三份 recheck 都以 `AGREE:` 开头（即无 must-fix）→ 一致达成」；并把目录/概览里的
「无 must-fix」与 `AGREE:` 对齐。

## 6. 复核产物命名三套并存，轮询会漏文件

- `task-workflows.md` 出现三种复核产物名：
  - :60、:137 `recheck-<agent>.md`
  - :78 「或用新一轮 `review-*.md` 命名」
  - :137 「或 `review-<agent>-rN.md` 跨多轮」
- 与 SKILL.md「review 与 recheck 是两种产物」的二分定义冲突；按步骤 4 轮询
  `recheck-*` 时，若 agent 用了另一种命名就「三份到齐」永远判不成立，导致循环卡死或
  误判未产出。

建议：只保留一个复核产物名（推荐 `recheck-<agent>.md`，跨多轮用 `rN` 前缀区分如
`rN-recheck-<agent>.md`，或保留 `review-<agent>-rN.md` 但全局只此一种），删除
「或用新一轮 review-*.md 命名」与「或 review-<agent>-rN.md」的并列写法。

---

结论：方向正确、无 REJECT 级问题；以上 6 项均为会造成实际跑任务踩坑或破坏退出条件
可判读性的必改项，修完即可 APPROVE。
