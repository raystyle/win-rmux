# r4 review — kimi

REVISE: launch 段重构方向正确、与 references 一致；但新增「--wait quiet 超时」踩坑与
observe 段既有处置指令直接矛盾，另有 2 处次要误导，需修订后收敛。

审查范围：`git diff HEAD`（仅 `skills/win-rmux/SKILL.md`，+64/-13），对照
`references/rmux-usage.md`、`references/extensions.md`、`references/overview.md`。

## 必须修改

### 1. 【逻辑矛盾】新增踩坑与 observe 段 L186 对同一症状给出相反处置

- 既有段落 `SKILL.md:186`（observe 段，本轮未动）：

  > 发送指令时若 pane 仍 `working`，`--wait quiet` 会超时（send-keys 报 timed out）——
  > **超时后补发一次 `Enter` 即可**，指令已入缓冲区，agent 完成后会执行。

- 新增踩坑 `SKILL.md:261-267`（关键踩坑段）：

  > 误以为没发送而重发 → 同一条 prompt 排队两次……处理：先 capture 确认 `❯` 后为空再发；
  > 超时后查「queued messages」，若有排队用 `C-c` 清空输入队列，再只重发一次；
  > **不要盲目补发**。

同一症状（pane working 时 `--wait quiet` 超时），L186 说「补发一次 Enter 即可」，新踩坑说
「不要盲目补发，先查排队、必要时 C-c 清空再只重发一次」。用户照着文档操作会在两处拿到
相反指令，且 L186 的「补发 Enter」正是新踩坑里实测踩出重复排队（`Press up to edit
queued messages`）的动作之一。这属于 prompt 点名要查的「新增踩坑与既有段落矛盾」。

建议改法：把 L186 整句替换为指向新踩坑的一句，例如：

> 发送指令时若 pane 仍 `working`，`--wait quiet` 会超时（send-keys 报 timed out）——
> **超时 ≠ 未发送，处置见「关键踩坑」`--wait quiet` 条：先查 queued messages，不要盲目补发**。

（保留症状描述，删除「补发一次 Enter 即可」这个与新踩坑冲突的处方。）

## 次要（建议改，不阻塞）

### 2. 【误导性描述】`SKILL.md:118-119` 称 launcher「内含完整守卫」，实际不含

L118-119：「可把同一份 `launch-unit.ps1` 的 body 直接用宿主 pwsh 执行（**内含完整守卫**）」。

但 launcher 脚本（L80-104）只含 `RMUX_DISABLE_TINY_CLI` / `NO_COLOR` / `TERM` / PATH 重建，
**没有**「前置守卫」段（L40-57）里的两项关键内容：

- `refresh-user-env.ps1` 的 User 环境变量同步——前置守卫明确注释「宿主常不加载 User env，
  agent 会缺 DEEPSEEK_API_KEY 等 API key；必须 dot-source」；
- `install-agent-hooks.ps1` 的 hook 检测/安装——缺它 judge 段的 hook 状态通道不可用。

照 L118 的说法在宿主侧直接跑 body，agent 可能缺 API key、judge 无 hook 状态，属于
「按文档操作会踩坑」。建议把「内含完整守卫」改为「内含环境守卫（PATH/NO_COLOR/TERM），
但 User env 同步与 hook 安装仍需先跑前置守卫」。

### 3. 【表述含混】`SKILL.md:74-75` 把「不在 job object 内」与 `$Visible=$false` 混为一谈

L74-75：「宿主不在 job object 内（如普通交互终端 `$Visible=$false` 后台 headless）时」。

`$Visible` 控制的是是否弹可见 wt 看板，与宿主是否被包进 job object 是两个独立维度：
普通交互终端（不在 job 内）同样可能 `$Visible=$true`。括号里的例子把两个概念绑死，
容易让用户误判「$Visible=$true 就不能宿主直连」。建议改为「宿主不在 job object 内
（如普通交互终端、非 CI/agent 宿主）时」，去掉与 `$Visible` 的绑定。

## 已核对无问题项

- launch 重构与 `references/rmux-usage.md:139-188`（独立 wt 窗口启动 daemon、wt 默认 cwd
  不继承需显式 `-d`/`-c`、会话复用守卫、daemon 生命周期）一致；脚本内
  `new-session -d/-s/-c/-e`、`split-window -h/-f -v -d` 与既有实测命令相同，非本轮新引入。
- 「launcher 不含 attach-session，Visible 时单独 recover 弹 attach」与 recover 段
  （L216-220，`attach-session -d`、不 `new-session -A`、不 `kill-server`）及
  `rmux-usage.md:85-113` 一致，无冲突。
- 新增踩坑「C-c 清输入队列」的键名 `C-c` 有效，与 `rmux-usage.md:203`（键名
  Enter/Down/Up/C-c）一致。
- 新增踩坑「备屏 TUI 尾部状态文本可 capture」与 L185（备屏 capture 可读到少量尾部）
  自洽，不与 L164-165（整帧/历史不可得）矛盾——一个讲整帧丢失，一个讲尾部状态行可见。
- `--wait` 仅 `quiet`、`--stable-for`/`--timeout` 参数形态与 `references/extensions.md:79-87`
  一致；宿主侧入口的 `wt -w new --title -d pwsh -NoProfile -File` 形态与
  `rmux-usage.md:155-159` 的既有 wt 弹窗模式一致。
- 「review prompt 内置跳过凭据文件」一条为流程建议，无命令事实错误；其中 C-c/状态词
  （Cogitating/Skedaddling/Frolicking）为 agent TUI 行为描述，标注了实测日期与来源，
  无法离线证伪，不列为问题。唯一提醒：「C-c 只清未提交输入、不打断正在进行的思考」
  是 per-agent 行为（不同 TUI 对 Ctrl+C 的处理不同），建议后续按 agent 实测补充限定，
  本轮不作必须修改项。
