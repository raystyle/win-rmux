# r4-claude — win-rmux SKILL.md 第 4 轮审查

REVISE: 变更方向正确（wt 内启动 daemon 与 job object 踩坑闭环、launcher 去 attach 化都成立），
但有两处高优先级问题必须改：① 宿主侧入口引用了已被重构挪走的 `$wd`，按文档操作会整单元
工作目录错误；② 新增「`--wait quiet` 超时」踩坑与 observe 段既有指引对同一现象给出两套
矛盾处理法，照旧文执行恰好触发新踩坑警告的重复排队。

审查对象：`skills/win-rmux/SKILL.md` 工作区未提交变更（git diff HEAD，64+/13-）。
对照文件：`references/commands.md`（`-e` 在 new-session/split-window 均支持 ✓）、
`references/rmux-usage.md`、`references/hooks.md`（`-e VAR=value` 双写法实测 ✓）、
`references/command-verification.md`。命令语法层面未发现与 rmux 实际不符的新错误。

## 必须修改（高）

### 1. 宿主侧入口使用未定义的 `$wd`（SKILL.md:110，连带 :246）

- **问题**：旧版 launch 代码块第一行 `$wd = (Get-Location).Path` 本轮被挪进
  `launch-unit.ps1`（:89，运行在 wt 子进程内），但宿主侧入口 :110 仍插值
  `-d "$wd"`，recover 段 :246 也依赖它。宿主会话里 `$wd` 现在没有任何赋值点。
- **后果**：`$wd` 为空 → `wt -d ""` 回退默认起始目录。`references/rmux-usage.md`
  实测结论明确「wt 新窗口默认 cwd 是 `%USERPROFILE%`，不继承调用方 cwd，必须显式
  `-d <目录>`」→ launcher 内 `(Get-Location).Path` 取到 USERPROFILE → 会话/三个
  pane 全部 `-c` 错目录，agent 在错误工作区跑。这是本次重构引入的回归。
- **建议**：宿主侧入口块首行补 `$wd = (Get-Location).Path`（或明确
  `$wd = '<launch-unit 所在/目标工作目录>'`），并在 recover 段同样说明 `$wd` 来源；
  :77 「当前目录为 `$wd`」这句歧义表述一并改掉（读起来像在定义宿主变量）。

### 2. 新踩坑与既有指引矛盾：`--wait quiet` 超时的处理法（SKILL.md:186 vs :261-267）

- **问题**：两处描述同一现象（pane 仍 `working` 时 `--wait quiet` 超时、指令已入
  TUI 输入框/已排队），但给出两套 SOP：
  - :186（observe 段，commit 2d0af8e 已有）：「超时后**补发一次 `Enter` 即可**，
    指令已入缓冲区，agent 完成后会执行」——无任何前置检查。
  - :261-267（本轮新增）：「先 capture 确认 `❯` 后为空再发；超时后查 queued
    messages，有排队用 `C-c` 清空再只重发一次；**不要盲目补发**」。
- **后果**：用户读到 :186 会直接补发——正是新踩坑警告的「误重发导致同一 prompt 排队
  两次」路径。r4-prompt 明确要求查「新增踩坑与既有踩坑重复但不一致」，此条命中。
- **建议**：改写 :186 为指向新踩坑的引用，如：「`--wait quiet` 超时 ≠ 未发送（指令
  可能已入输入框/已排队），处理见『关键踩坑』对应条：先查 queued messages，勿盲补发」。
  新踩坑为唯一权威版本，删除 :186 的独立处置结论。

## 建议修改（中）

### 3. launch 引言末句答非所问且例子归类错误（SKILL.md:74-75）

「何时可退化到宿主侧直连：宿主不在 job object 内（如普通交互终端 `$Visible=$false`
后台 headless）时，下面的 wt 启动可作为统一入口……」：

- 标题问「何时退化到宿主直连」，正文结论却是「wt 作为统一入口」，没有回答提问；
- 括号把「普通交互终端」和「`$Visible=$false` 后台 headless」并列为「不在 job object
  内」的例子——后台 headless 的 agent 宿主恰是 job object 高发场景（本轮改造的动机），
  `$Visible` 是前台/后台模式开关（:18），不是宿主类型，归类误导；
- 与 :118-119 的「直接用宿主 pwsh 执行 launcher body」回退口径重叠但不一致。
- **建议**：拆成两句：「宿主在 job object 内（CI/agent 宿主）→ 只能走 wt 启动；宿主
  确认不在 job object 内（普通交互终端）→ wt 启动仍是统一入口，也可直接宿主执行
  launcher body（更轻），失败报 os error 5 时回退 wt」。删掉 `$Visible=$false` 举例。

### 4. judge 的 CPU 回退法与新踩坑「CPU 对 claude 不敏感」未调和（SKILL.md:200-210 vs :271-272）

judge 段把「进程 CPU 增长 >0.5（2s 窗口）」作为 claude 提交判定的回退标准；新踩坑明说
「深度思考阶段『进程 CPU 增长』对 claude 不敏感」。若 agent 一提交即进入深度思考，
judge 的 CPU 法会误报「未提交」→ 运维重发 → 正好踩中问题 2 的重复排队。两处应调和：
judge 段 claude 回退改为优先「尾部状态文本 / queued messages 检查」，CPU 法标注
「深度思考期不可靠，仅辅助」。

### 5. 尾部状态文本的「动词 → 语义」映射不可靠（SKILL.md:269-270）

Claude Code TUI 的 spinner 动词（Cogitating/Skedaddling/Frolicking…）是随机趣味词表
轮换的装饰文案，不编码「深度思考 vs 被安全策略中断」的阶段语义；把 Skedaddling/
Frolicking 映射成「可能被安全策略中断过」是对 2026-08-21 单次事故的过拟合（那次 block
恰好撞上这些词），正常执行同样显示这些词，照此判活会误判。可靠信号只有两类：
spinner 行非空（含 `(N s · ↓Nk tokens)` 计数，计数在涨 = 活）= busy；空 `❯` + 底部
statusline = ready。**建议**：删按动词断义，保留 busy/ready 二值 + token 计数判活；
「被安全策略中断」的判断留给问题 7 的显式 prompt 规避，不靠 spinner 词。
另（跨文档）：`references/rmux-usage.md` 踩坑 4 仍写「capture-pane/pane-snapshot
返回空」，与「尾部状态行可见」（SKILL.md:185、本踩坑）口径不一，建议同步为
「完整帧不可读、仅尾部少量行可读」。

## 建议修改（低）

### 6. 「（内含完整守卫）」名不副实（SKILL.md:118-119）

launcher 只含环境守卫子集（tiny CLI / NO_COLOR / TERM / PATH 重建 / 会话复用），
不含前置守卫的：污染 daemon 守卫、`. refresh-user-env.ps1` dot-source、
`install-agent-hooks.ps1`。按「完整守卫」理解直接宿主执行 launcher body，会漏 hook
安装（judge 无状态可读）与 User env 刷新。建议改为「内含环境守卫；daemon 污染守卫、
user-env 刷新与 hook 安装仍需前置守卫先跑」，或把三项补进 launcher。

### 7. 「secret-guard hook」无出处（SKILL.md:275-276）

win-rmux 仓库（含 references/ 全部文档）没有任何 secret-guard 的定义或说明，它是
ohmypwsh 宿主项目自装的 hook。skill 读者会不知道这 hook 是否存在于自己环境。建议
改成条件句：「宿主项目若装有 secret-guard 类内容拦截 hook（如 ohmypwsh），还会反拦
含 `mysql://`、`AKIA`、`api_key` 模式字面量的……」。

### 8. 附带两条提示（不阻塞）

- launcher 在 wt 内失败（如 os error 5 复发）时脚本一退出标签即关，错误信息不可见。
  建议脚本尾部加失败暂停或把输出重定向到日志文件，否则排障只能盲猜。
- `C-c` 清队列（:266）建议补一句「只发一次，勿连发」——连按两次 C-c 在 Claude Code
  里是退出会话，误触会直接杀掉 pane 里的 claude。

## 已核对无问题的点

- `new-session`/`split-window` 的 `-e`（含双写）与 `commands.md`/`hooks.md` 一致；
  `-f -v` 上 2 下 1、`Enter` 单发、`C-c` 键名、`list-sessions -contains` 守卫均与
  references 实测记录相符。
- job object 踩坑改写后与 launch 段新流程互指一致（:245-250 ↔ :68-75）。
- launcher 去 `attach-session` 化与 recover 段「attach 单独弹窗」不矛盾；
  `attach-session -d` 幂等语义未变。
- 三条新踩坑中「review prompt 跳过密钥文件」的操作建议本身成立（除出处问题 7）。
