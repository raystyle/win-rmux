REVISE: 方向正确、与六原语和 troubleshooting 边界划得清楚，但有 1 个会导致实际跑循环踩坑的逻辑错误（轮询命中旧产物）+ 几处措辞/关键词不一致。

审查范围：`skills/win-rmux/SKILL.md`「任务原语」段、`references/task-workflows.md`、`references/README.md`（`git diff HEAD` + 新文件）。

## must-fix

### 1. 循环轮询会命中上一轮旧产物文件（task-workflows.md 2.2 步骤 4、1.2 步骤 6）

review-cycle 第二轮起，drive 完 recheck 指令后「轮询 `reviews/recheck-<agent>.md` 出现」——但该文件名与上一轮相同，文件**已存在**，`Test-Path` 轮询会立刻命中旧内容，主窗口读到的是上一轮的复核结论，据此判断「一致达成」可能是假收敛。research 的迭代回路（1.2 步骤 6「drive 追问 → 回第 3 步轮询产物出现」）有同样问题：`reports/research-<主题>.md` 首轮已存在。

且 2.4 提示「旧的保留归档」与固定文件名互相矛盾——同名写入是覆盖不是归档。

建议（二选一写进步骤）：
- 每轮换文件名：`recheck-<agent>-r<N>.md`（3 节产物约定里已提到 `review-<agent>-rN.md` 这个备选，应升格为主约定）；或
- 每轮 drive 前先删除/改名上一轮的 `recheck-*.md`，再轮询「出现」；并在文中显式写明「轮询前先清旧产物，否则命中上轮回合」。

### 2. 复核模板的 `git diff HEAD` 语义依赖「修复是否已提交」，未交代（task-workflows.md 2.3 复核模板）

`Run: git diff HEAD (compare current state vs 我按 review 改的)`：
- 括号注释本身描述不准——`git diff HEAD` 比的是工作区 vs 最后提交，不是「vs 我按 review 改的」；
- 若主窗口把修复 commit 了，`git diff HEAD` 为空，复核 agent 看不到任何修复内容，只能重报或瞎报。

2.4 提示里已正确要求「复核轮 prompt 必须给上轮已改什么（diff 或提交号）」，但模板只写了 `git diff HEAD` 一种。建议模板改成按提交状态二选一：未提交 → `git diff HEAD`；已提交 → `git show <hash>` / 给提交号，并把括号注释改为「对照上轮 review 的 must-fix 逐项验证」。

## 应改（不一致/误导措辞）

### 3.  verdict 关键词三处不一致（task-workflows.md 2.2 步骤 5 vs 2.3 模板 vs SKILL.md）

- 2.3 模板要求产物以 `AGREE:` / `REGRESSION:` 开头；
- 2.2 步骤 5 判断条件写「三份复核实 todos 都是 APPROVE/无 must-fix」——`APPROVE` 在模板里不存在，agent 不会产出这个词；且「三份复核实 todos 都是」是乱句（疑为「三份复核都是」）；
- SKILL.md 要点写「三方 recheck 都标记『无 must-fix、一致达成』」。

退出条件本身够明确（三方都无 must-fix），但判定关键词必须统一为模板实际产出的 `AGREE:`，否则主窗口按 `APPROVE` 去 grep 会永远判不成一致。建议：步骤 5 改为「三份 recheck 都以 `AGREE:` 开头（无 must-fix）」，SKILL.md 要点同步。

### 4. SKILL.md review-cycle 图末行自相矛盾

`└── 循环终态：不关执行单元，直接 close/recover` ——「不关执行单元」与「直接 close」并排放，读作终态也不关，与 task-workflows.md 2.1「终态达成后才 close（或 recover）」的原意相反。建议改为「循环期间不关单元；终态达成后才 close（或 recover 继续）」。

## 提示（非必改）

### 5. research 模板标注「ASCII」但含中文占位（task-workflows.md 1.3）

模板代码块内有「结论/依据/可行方案/取舍」「你名」等中文。若按「直接 send 短版」路径发送会触发中文乱码坑（troubleshooting 五）。建议要么模板全 ASCII（`conclusion/evidence/options/trade-offs`），要么显式注明「含中文的完整模板只能写文件让 agent Read，send-keys 只发短指令」。

## 已核对无问题

- 与六原语自洽：任务原语定位为组合工作流、复用 launch/locate/drive/observe/judge/recover-close，无矛盾；drive 仍强调严格流程（发→Enter→capture 验证）。
- troubleshooting 边界：task-workflows.md 开头声明「排查去 troubleshooting，本文只给步骤+提示」，2.4 的坑类提示均带 troubleshooting 指引，SKILL.md 要点也只是指针不承载坑内容——符合「唯一坑维护点」约定。
- skip secret/credential、长 prompt 写文件让 agent Read、不关执行单元三要点在 SKILL.md 与 task-workflows.md 一致体现，与 troubleshooting「agent 行为」「send-keys」条目吻合。
- README.md 索引补充与快速入口一致，无冲突。
