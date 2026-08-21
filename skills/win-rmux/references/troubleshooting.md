# win-rmux 踩坑排查集（唯一坑维护点）

> 本文是 win-rmux 唯一的「踩坑/排障」维护文档。其它文档（主 SKILL、references/*）**不承担
> 坑职责**，只在此处查；遇到错误时回这里逐条对照。「坑」= 实测踩到过的异常行为 + 现象 + 排查/
> 处理。新增坑一律追加到本文，不要散落进其它文档。
>
> 相关：主 SKILL 的操作原语见 `SKILL.md`；launch/drive 的完整**实现**（launcher 脚本、流程
> 代码）见 `references/rmux-usage.md`。本文只管「出错了怎么处理」。

## 一、launch 相关

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| `new-session` 报 `os error 5`（`Windows refused to launch an independent RMUX daemon`） | 宿主在 job object 内，独立 daemon 无法脱离 | 必须走 wt 启动（launcher 放 wt 内执行）；宿主直接跑会失败。多 agent 三 pane 布局见 rmux-usage |
| wt 打开后 agent 工作目录是 `%USERPROFILE%` 而非目标 | 宿主侧 `$wd` 未定义 → `wt -d ""` 回退默认起始目录 | 宿主入口与 recover 段都要先 `$wd = (Get-Location).Path` |
| 三个 pane 都是错误目录 | launcher 内 `-c $wd` 拿到 USERPROFILE（`$wd` 未正确传） | 确认 wt 用了 `-d $wd`，且 launcher 在 `$wd` 目录下以 `-File` 运行 |
| wt 标签一闪即关、无报错 | launcher 失败即退出 | 把 launcher 输出重定向到日志文件再读，或脚本尾部加暂停 |
| agent pane 缺 DEEPSEEK_API_KEY 等环境变量 | launcher body 没 dot-source `refresh-user-env.ps1` | launch 前必须先跑一次前置守卫（含 user-env 同步 + hook 安装）；launcher 只含环境守卫 PATH/NO_COLOR/TERM |

## 二、drive 相关

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| 发了 prompt 但 agent 没动 | Enter 被吞（文本+Enter 同发、或时序被忽略） | `capture-pane` 看输入框；仍停留则单独重发 `Enter` |
| capture 见 `❯ Press up to edit queued messages` | 之前重发导致同一 prompt 排队两次 | 先 `C-c` 清队列只发一次；**勿盲补发**（会执行两遍） |
| `--wait quiet` 报 timed out | pane 仍 `working`（TUI 实际已就绪），指令可能已入输入框待提交 | **超时 ≠ 未发送**，勿重发同 prompt；`capture` 验证后只补 `Enter` |
| 长 prompt 发送后不完整 / 被截断 / 排队 | send-keys 长文本不可靠（超长被打断入队） | 完整指令写文件（如 `.rmux_tasks/<task>/prompt.md`），`drive` 一条短指令 `Read <prompt路径> and follow it exactly` |
| 找不到 agent 产生的产物文件 | 轮询了固定/旧文件名，命中上轮旧内容或遗漏本轮 | 用轮次前缀命名（`r<N>-<agent>.md`），或每轮 drive 前先清本 task 旧产物；轮询比对 `LastWriteTime` 晚于本轮 drive |
| 补发 `Enter` 也不提交 | 可能 C-c 已把 prompt 清掉，或输入框状态异常 | `capture` 看输入框内容再决定；不要连发键 |
| claude 深度思考时 CPU 不增、误判「未提交」 | CPU 法是进程累计值，深思考常驻低增量 | 用尾部状态 busy/ready（token 计数在涨=b busy）判活，CPU 只作辅助 |

## 三、TUI 备屏 / 判活

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| claude/kimi 的 `capture-pane`/`pane-snapshot` 返回空（备用屏） | 全屏 TUI 走 alternate screen，完整帧不可从外部读 | 长回复/结论写文件再读；当前帧尾部少量状态行仍可 capture |
| spinner 出现 `Cogitating…`/`Skedaddling…`/`Frolicking…` 各种词 | Claude TUI 随机轮换趣味词，不编码阶段语义 | **勿按动词断义**。只看「busy/ready 二值」：spinner 行非空且 `Nk tokens` 计数在涨 = busy；空 `❯` + 底部 statusline = ready |
| kimi 的文案不同 | kimi 不用 Claude 那套 spinner 词 | busy/ready + token 计数在涨的判活思路两 agent 通用 |
| 进程 CPU 增长无法判断 claude 状态 | 累计 CPU 对深思考不敏感 | 用 token 计数判活；`Get-Process claude` 的 CPU 只辅助手工确认 |

## 四、agent 行为

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| codex/kimi 弹「Do you trust this directory?」 | 新目录首次进入的信任确认，yolo 参数不绕过 | capture 检测到提示后 send-keys 选信任（codex `1` + Enter；kimi 高亮项直接 Enter）；codex 可 `config.toml` `[projects.'<path>'] trust_level="trusted"` 预置永久信任 |
| codex 状态卡 `working` 不回落 | codex 的 Stop hook 不上报 idle | judge codex 用进程 CPU 回退，或手动 `rmux set-environment -t $unit AGENT_STATE_codex idle` 清理 |
| `respawn-pane -k` 重启 codex 崩溃、布局重排 | respawn-pane 对 codex 实测不稳 | 不在 codex pane 用 respawn；重排在现存 pane 左侧 `split-window -h -b` 插回还原上 2 下 1 |
| claude 读 `*.key.ps1`/`.secrets` 被自身策略拦 | claude 安全策略拦截凭据访问，`Action blocked to prevent credential exposure` 后放弃任务 | review/审查 prompt 显式附：`do NOT read/open secret/credential files (nothing under .secrets, no *key*.ps1, no API-key/token files)`，focus 只留 code structure/logic/consistency |
| 含 `mysql://`/`AKIA`/`api_key` 字面量的内容被误拦 | 宿主装有 secret-guard 类内容拦截 hook（如 ohmypwsh），把模式字面量当真密钥 | review 时同样跳过这些文件；guard 自身源码/研究文档/测试样例含此类字样，注意避免误报 |

## 五、send-keys / 输入

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| 中文 payload 乱码 / 不显示 | 中文经 send-keys 丢失（乱码字节打到 API，偶发 `server closed connection...`） | prompt 用 ASCII/英文；实在要中文走 `claude -p` 管道，不直接 send-keys |
| `C-m` 不提交，成字面量 `^M` | 回车键名只有 `Enter` 有效 | 用 `Enter`；不要用 `C-m` |
| 把键注入错误 pane | `send-keys` 目标写错 | 发送前 `find-panes` 确认目标 pane |
| `C-c` 连按两次退出 claude 会话 | Claude Code 的 C-c 连按=退出 | **`C-c` 只发一次**；清输入队列单次，不生效先 `capture` 确认再决定。「C-c 只清未提交不打断思考」是 claude 实测；其他 TUI（尤其 kimi）Ctrl+C 可能中断运行 |
| tiny CLI 报 `can't find pane` | `rmux.exe` tiny 分发器对部分目标解析失败 | 设 `RMUX_DISABLE_TINY_CLI=1` 走 full helper |
| send-keys 提示 pane 不存在 | 目标 pane 已关闭/换位 | `list-panes` / `find-panes` 复查当前 pane id |

## 六、版本 / 命令行为

| 现象 | 原因 | 排查 / 处理 |
| --- | --- | --- |
| `--wait-next-text`/`--wait-visible-text` 无效 | 本版本 `--wait` 只支持 `quiet`；它们是独立参数不是 `--wait` 值 | 等待用 `--wait quiet` + `--stable-for` + `--timeout`；其余参数用独立开关 |
| `rmux claude`（teammate 模式）内层会话不可见 | 自动 `--teammate-mode tmux` + 私有 tmux shim，socket 每实例随机，外层看不到内层 | 调试用 `claude -p`（纯文本可捕获）或让用户目视窗格 |

## 维护约定

- 新增踩坑一律追加到本文对应 section；不要散落进主 SKILL 或其它 references。
- 主 SKILL 各段只留「操作原语」，遇错指向本文；本文是唯一坑维护点。
- 现象/原因/处理三列尽量各一行，保持可速查。
