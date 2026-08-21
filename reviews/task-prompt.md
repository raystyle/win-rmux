# 任务原语（research / review-cycle）审查

你是 reviewer。审查 `D:\win-rmux` 仓库里**本轮新增**的两任务原语文档，只读分析，不修改文件。

## 新增内容
1. `D:\win-rmux\skills\win-rmux\SKILL.md` 的 `## 任务原语` 段（六原语之上组合的两个工作流概览）
2. `D:\win-rmux\skills\win-rmux\references\task-workflows.md`（详细实现：prompt 模板/产物规范/循环条件/坑）
3. `D:\win-rmux\skills\win-rmux\references\README.md`（索引补 task-workflows）

## 两个任务原语的预期
- **research**：根据需求搜信息 / 用 `gh` 搜 GitHub 代码研究 → 产研究报告 + 最小原型 POC，产物写文件。
- **review-cycle**：多 agent 独立 review 代码改动 → 主窗口按报告改码 → 再 recheck（复核上轮修复）→ 循环到三方一致无 must-fix → 不关闭执行单元直到达成一致。

## 如何审查
1. `cd D:\win-rmux && git diff HEAD`（看本轮新增）
2. 读 SKILL.md「任务原语」段 + references/task-workflows.md + references/README.md
3. 对照现状检查：
   - 与六原语（launch/drive/observe/judge/recover-close）是否自洽、会不会与既有驱动流程矛盾
   - 与 troubleshooting.md（唯一坑维护点）是否冲突——task-workflows 里若有坑内容是否应挪到 troubleshooting
   - prompt 模板 / 产物目录约定 / review-cycle 循环退出条件是否清晰可执行
   - 长 prompt 写文件让 agent Read、skip secret/credential、不关执行单元这些要点是否在文档里一致体现

## 只报这些（不报风格）
- 逻辑矛盾 / 与既有原语或坑文档冲突
- 会导致实际跑任务踩坑的错误指令
- 循环退出条件是否够明确（何时算"达成一致"）

## 产出
写 `D:\win-rmux\reviews\task-<你的名字>.md`（如 task-codex.md），开头三选一：
- `APPROVE:` 新原语正确、无必改项
- `REVISE:` 有问题需改（列出具体文件和问题点 + 建议）
- `REJECT:` 方向错误

写完回一句 `DONE <名字>`。
