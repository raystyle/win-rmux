# win-rmux SKILL.md 第 4 轮审查（codex）

REVISE: 变更方向正确（把 launch 迁进 wt、补充 3 条踩坑都有价值），但存在一处必须消除的逻辑矛盾，以及一处会误导用户的“完整守卫”描述。下列问题按严重度排序。

## 必须修改

### 1. observe 段与新增「`--wait quiet` 超时」踩坑互相矛盾

- 行号：186 与 261–267
- 现状：
  - 行 186（observe 段）写：`--wait quiet` 超时后 **补发一次 `Enter` 即可**，指令已入缓冲区，agent 完成后会执行。
  - 行 261–267（新增踩坑）写：超时 ≠ 未发送，指令可能已入输入框待提交；**误以为没发送而重发 → 同一 prompt 排队两次**；处理是 `C-c` 清空输入队列后“再只重发一次”，并明确 **不要盲目补发**。
- 问题：两段描述的是同一个场景（pane 仍 `working`、`--wait quiet --timeout` 报 timed out），给出的补救动作相反。按行 186 操作会直接踩中行 261–267 警告的“盲目补发 → 重复排队”。references/rmux-usage.md 行 210 仍写“否则只补发一次 `Enter`”，同样与新踩坑不一致。
- 建议：把行 186 的“超时后补发一次 `Enter` 即可”改为指向新踩坑的正确处理，例如：超时后先 capture 查「queued messages」，有排队则 `C-c` 清队列后只重发一次，不要盲目补发；并同步修订 rmux-usage.md 行 210。

### 2. launch 脚本自称“内含完整守卫”，但缺 User env 同步（refresh-user-env.ps1）

- 行号：53–55（前置守卫）、79–104（launch-unit.ps1）、118–119
- 现状：
  - 行 53–55 明确前置守卫必须 `. "$SkillDir/scripts/refresh-user-env.ps1"`，否则宿主不加载 User env 时 agent 会缺 `DEEPSEEK_API_KEY` 等 API key，且必须 dot-source、子进程调用无效。
  - 行 119 把 `launch-unit.ps1` 的 body 描述为 **内含完整守卫**。
  - 但 launch-unit.ps1（79–104）只做了 `RMUX_DISABLE_TINY_CLI / NO_COLOR / TERM / COLORTERM / PATH` 清理，**没有** dot-source `refresh-user-env.ps1`，也没有跑 `install-agent-hooks.ps1`。
- 问题：`Start-Process` 默认继承宿主进程环境，所以“先跑前置守卫、再弹 wt”的流程能侥幸把 User env 传给 wt；但文档把 launcher 标为“完整守卫”是事实错误，任何跳过前置守卫、只按 launch 段操作的用户都会让 wt 内的 agent 缺 User 作用域环境变量（API key）。这与行 53–55 的强制要求矛盾。
- 建议：二选一：
  1. 在 launch-unit.ps1 内补上 `$SkillDir` 与 `. "$SkillDir/scripts/refresh-user-env.ps1"`（再启动 agent），并把“完整守卫”改成“环境清理 + User env 同步”；hook 安装为一次性，可注明由前置守卫完成。
  2. 保留 launcher 现状，但删除“内含完整守卫”字样，并在 launch 段显式写“launch 前必须先跑前置守卫（含 refresh-user-env），宿主 Start-Process 继承已刷新的 User env”。

## 次要问题

### 3. 宿主侧入口未定义 `$wd`

- 行号：110（以及既有 recover 段的 218）
- 现状：宿主侧入口用 `-d "$wd"`，但 SKILL.md 全文从未定义 `$wd`（只有 launch-unit.ps1 行 89 在另一个进程内定义了它，宿主侧不可见）。`$unit` 有定义（行 25），`$wd` 没有。
- 建议：在行 109 前补 `$wd = (Get-Location).Path`（或与 `$unit` 一并定义），并顺带补上 recover 段。

### 4. 日期不一致

- 行号：68
- 现状：launch 段写“（2026-08-22 修正）”，而全文其它实测时间戳均为 2026-08-21（本文件审查日也是 2026-08-21）。
- 建议：改为 2026-08-21，或确认是否有意为之。

### 5. judge 段“CPU 增长判提交”与新踩坑“深思考阶段 CPU 不敏感”未交叉引用

- 行号：200/208–210 与 271–272
- 现状：judge 段回退策略把 claude/kimi 的提交判断写成“进程 CPU 增长”；新增踩坑却说“深度思考阶段进程 CPU 增长对 claude 不敏感，看尾部状态文本更快更准”。二者不是完全矛盾（一个是执行阶段、一个是深思考阶段），但 judge 段没有提示这条例外，读者会照旧在深思考阶段误判。
- 建议：在 judge 段回退策略处加一句“claude 深度思考阶段 CPU 可能不增长，改用尾部状态文本（见关键踩坑）”。

### 6. 状态文本示例是 claude 专属，却笼统归给 claude/kimi

- 行号：268–270
- 现状：`Cogitating…` / `Skedaddling…` / `Frolicking…` 是 Claude Code 的状态文案，kimi 并不使用这些字样。行 268 写成“claude/kimi 备屏…尾部状态行可见”，随后直接列这三条 claude 文案，容易让人误以为 kimi 也显示这些字符串。
- 建议：把示例明确标注为 claude，kimi 另列其自身状态文案（或注明“kimi 文案不同，思路相同”）。

### 7. `C-c 清空输入队列（不打断正在进行的思考）` 待实测确认

- 行号：266–267
- 现状：称 `rmux send-keys -t <pane> -- C-c` 只清未提交输入、不打断正在进行的思考。这是对 agent TUI 行为的强断言；多数 TUI 的 Ctrl+C 会中断当前运行，未必只清排队输入。
- 建议：补充一句“该行为已在 claude TUI 实测”的来源/场景，或弱化为“先确认不会打断当前思考再发 C-c”，避免照文档操作误中断 agent。

## 未发现问题（已核对）

- launch-unit.ps1 中 `new-session -d`、`split-window -h -d`、`split-window -f -v -d`、`-e VAR=value` 与 rmux 0.10.0 `--help`/references 一致，上 2 下 1 布局正确。
- `list-sessions -F '#{session_name}'` + `-contains` 守卫、`attach-session -d` recover 与 references/rmux-usage.md 一致，未发现命令参数错误。
- 新增“review 类 prompt 跳过凭据/密钥文件”踩坑与前置守卫、secret 约束之间未见矛盾。
