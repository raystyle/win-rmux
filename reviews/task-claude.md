# 任务原语（research / review-cycle）审查 — claude

日期：2026-08-21。对象：本轮新增 `SKILL.md`「任务原语」段 + `references/task-workflows.md` + `references/README.md` 索引。方法：git diff HEAD 对照工作区，逐条与六原语、troubleshooting.md（唯一坑维护点）、本仓库 `reviews/` 实际历史交叉验证。

REVISE: 两任务原语方向正确、与六原语基本自洽（research 复用 launch/drive/observe/judge/close，review-cycle 的「不关单元」与 recover 语义一致；skip-secret 指引与 troubleshooting「四、agent 行为」实测坑对应；README 两处索引齐全）。但有 4 条 must-fix：一处会直接跑错（旧产物同名轮询假命中）、一处退出判据不可自动执行（三种 verdict 词混用）、一处悬空引用（troubleshooting 无所指条目）、一处不实陈述（守卫不含 gh 检查）。

## 必须修改（must-fix）

### 1. 同名产物轮询会被上一轮旧文件假命中（task-workflows.md:72、78）

2.2 步骤 2「轮询 reviews/review-codex|kimi|claude.md 出现」、步骤 4「轮询 reviews/recheck-*.md」——都没有先清掉/改名上一轮同名文件。本仓库 `reviews/` 现存 review-codex/kimi/claude.md、recheck-*.md 全套旧产物：再跑一轮时「文件出现」瞬间为真，主窗口读到**陈旧报告**就开始改代码，整轮循环错位。第 4 轮实战已经自发改用 `r4-<agent>.md` 轮次前缀规避，但文档主约定仍是固定名覆盖。建议三选一并写明：每轮开始先归档/删除旧 `review-*.md`、`recheck-*.md`；或统一轮次前缀命名（`r<N>-review-<agent>.md`，与 3 节「review-<agent>-rN.md 跨多轮」二选一定死一个）；或轮询时比对 `LastWriteTime` 晚于本轮 drive 时间。

### 2. 循环退出判据 token 三处不一致，无法自动判定（task-workflows.md:93-96、104-105 vs 79）

- 2.3 模板规定产物开头词：`AGREE:` / `REGRESSION:`
- 2.2 步骤 5 写：「三份复核实 todos 都是 APPROVE/无 must-fix？」——冒出第三个词 APPROVE，且「复核实 todos」语义不通（疑为「复核结论」笔误）
- SKILL.md:263 写：「三方 recheck 都标记『无 must-fix、一致达成』」——无字面 token

自动判停需要一个唯一可 grep 的词。建议三处统一为 AGREE（模板已定），并写成可执行判据：「三份 recheck-*.md 均以 `AGREE:` 开头 = 达成一致，退出循环」。另建议补一条非收敛保护（如最大轮数 N，超限转人工），否则「不关单元直到一致」理论上可死循环——这也是任务预期里「何时算达成一致」的最后一角。

### 3. 悬空引用：troubleshooting「drive 相关」并无「长 prompt 截断」条目（task-workflows.md:51、SKILL.md:265）

两处都写「见 troubleshooting『drive 相关』长 prompt 截断」，但 troubleshooting.md「二、drive 相关」五个条目里没有这条（全文 grep 无「截断/长 prompt」）。这同时违反 troubleshooting 自己的维护约定（唯一坑维护点、坑不散落别处）：「中长 prompt 经 send-keys 截断 → 写文件让 agent Read」是实测坑，应正式落进 troubleshooting（「二、drive 相关」或「五、send-keys」），两处引用才有着落；否则按文档去查速查表会查空。

### 4. 不实陈述：「前置守卫已含 gh 是否安装检查」（task-workflows.md:49）

SKILL.md 前置守卫（44–57 行）只有 rmux daemon 守卫、NO_COLOR/TERM、PATH、refresh-user-env、install-agent-hooks，**没有任何 gh 检查**；grep 全 skill 亦无。执行者会误以为 gh 可用性已验证。要么删掉这句，要么在 research 前置里真加 `Get-Command gh` 探测（缺则提示装 gh / 跳过 GitHub 子任务）。

## 建议修改（should-fix，不阻塞）

5. **共用指令文件的 `<agent>` 占位无解析说明**（task-workflows.md:71-72、92、95、135）：三 agent Read 同一份 `r<N>-prompt.md`，模板里 `review-<agent>.md` / `Reply CONFIRMED <agent>` 的占位没人指定替换值——三个 agent 可能写同一文件互相覆盖（或字面建出 `review-<agent>.md`）。修法：短 drive 指令带名（"You are kimi. Read r1-prompt.md ... write review-kimi.md"），或模板加一行 "replace `<agent>` with your own name"。
6. **SKILL.md:257 图终态行自相矛盾**：「循环终态：不关执行单元，直接 close/recover」字面即「不关…直接 close」。要点与 2.1 本意是「循环全程不关、终态后才 close/recover」，建议改为「循环中不关单元；终态达成后才 close/recover」。
7. **模板 ASCII 声明与实际内容不符**（task-workflows.md:34、43-45、103）：1.3 标题称「ASCII，避免 send-keys 乱码」，模板却含 `<主题>`、`<你名>`、`<一句话需求>`；2.3 recheck 模板夹中文「我按 review 改的」。短版若直接 send-keys 且占位填了中文，正是 troubleshooting「五」的乱码坑。建议占位改英文（`<topic>`/`<your-name>`），或明标「文件版可中文；send-keys 短版必须纯 ASCII」。
8. **3 节「全部放入被 .gitignore 忽略的 reports/、reviews/」与实际矛盾**（task-workflows.md:141-142）：本仓库根本没有 .gitignore，且明说「reviews 入库作归档」。作为普适约定这句是错的，建议改为「运行时产物目录，是否入库按项目约定（win-rmux 本体将 reviews/ 入库归档）」。

## 已核对无问题

- research 全流程与六原语自洽：launch→locate→drive→observe/judge（轮询 + 超时上限，与 SKILL.md observe 的文件产物法一致）→迭代或 close。
- 「不关闭执行单元」在 SKILL.md 要点 / task-workflows 2.1、2.4 三处表述一致，与 recover（attach-session -d）语义无冲突。
- skip secret/credential 指引与 troubleshooting「四、agent 行为」两条实测坑（claude 策略拦截、secret-guard 误拦）一致对应，两个模板均内置。
- 产物走写文件（不经 rmux）与「TUI 备屏」坑结论一致；README.md 索引行 + 快速入口两处均已补。
- 与 troubleshooting 的坑职责边界总体守住：2.4 的坑条目均以「见 troubleshooting」回指（除第 3 条所指悬空项）。
