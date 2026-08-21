# win-rmux SKILL.md 第 4 轮审查任务

你是本任务的 reviewer。审查对象：`D:\win-rmux\skills\win-rmux\SKILL.md` 的**本轮变更**，只读分析，不修改任何文件。

## 变更背景
win-rmux skill 最近做了两处更新：
1. **launch 段重构**：把「host 侧直接 new-session」改为默认「从 wt 窗口内启动 daemon」（因 CI/agent 宿主 job object 会阻止独立 daemon，os error 5）。launcher 脚本不再内含 attach-session（避免 wt 卡前台）。
2. **关键踩坑新增 3 条**：
   - `--wait quiet` 超时 ≠ 未发送，指令可能已入输入缓冲区 → 误重发导致重复 prompt 排队（`Press up to edit queued messages`）；处理用 `C-c` 清输入队列而非盲补发
   - 备屏 TUI 尾部状态文本可当判活信号（Cogitating…/Skedaddling…/Frolicking…）
   - review 类 prompt 应内置「跳过凭据/密钥文件」，因 claude 会被自身安全策略拦 + secret-guard hook 会反拦模式字面量

## 如何审查
1. 先执行：`cd D:\win-rmux && git status` 和 `git diff HEAD`（若工作区是未提交变动）
2. 读 `D:\win-rmux\skills\win-rmux\SKILL.md` 全文（尤其 launch 段和关键踩坑段）
3. 对照 `references/` 目录下其它文档，检查描述是否一致、有无矛盾

## 只报这些问题（不要报风格）
- 事实/命令错误：某条命令的参数、语义、行为与实际 rmux 不符
- 逻辑矛盾：文中两处说法冲突（如 launch 描述与 recover/judge 冲突、新增踩坑与既有段落矛盾）
- 会误导用户的缺失/错误指令（按文档操作会踩坑的）
- 新增 3 条踩坑是否存在事实错误或与 skill 既有踩坑重复但不一致

## 产出
把完整 review 写到文件 `D:\win-rmux\reviews\r4-<你的名字>.md`（如 r4-codex.md）。
文件开头写三选一：
- `APPROVE:` 变更正确，无必须修改项
- `REVISE:` 有问题需改（列出具体行号 + 原因 + 建议改法）
- `REJECT:` 变更方向错误

写完后回一句 `DONE <名字>`。
