# win-rmux 三 agent 评审归档（2026-08-21）

本项目一次「三 agent（codex / kimi / claude）评审 + 多轮收敛 + 终态一致」的完整记录。
评审由 rmux skill（`skills/win-rmux`）驱动，产物按轮次入档。

## 分轮产物

| 阶段 | 文件 | 内容 |
| --- | --- | --- |
| 首轮评审 | `review-*.md` ×3 | 三端各自对 SKILL.md / install-agent-hooks.ps1 / refresh-user-env.ps1 / references 的独立评审（含真实 Bug、一致性矛盾、次要项） |
| 修复后复验 | `recheck-*.md` ×3 | 第 1 轮修复（dd31d06）后逐条核验：4 项核心修复确认；一致揪出 pane 校验回归（list-panes window 作用域误报）并给修复方案 |
| 终审 | `final-*.md` ×3 | pane 校验改 display-message、写产物补 -l、轮询超时、[features] 正则——三端全 FINAL_OK |
| 收敛裁决 | `converge-*.md` ×3 | 对 8 项非阻塞残留裁决：claude 7 ACCEPT + item7 REJECT；codex 6 FIX + 2 ACCEPT；kimi 8/8 FIX。item7（无效 JSON 覆盖）三方一致必修 |
| 终态确认 | `signoff-*.md` ×3 | 收敛后 HEAD `cf2182e`：三端全员 `FINAL_AGREED`，无剩余正确性/损坏路径 |
| 第 4 轮 | `r4-*.md` ×3 + `r4-prompt.md` | backlog（ohmypwsh 实战）反哺 win-rmux：launch/drive 重构 + 坑职责收敛到 troubleshooting.md。三端均抓出 `$wd` 未定义回归、`--wait quiet` 矛盾、spinner 词不可靠；全部已修 |

## 结果闭环（HEAD: cf2182e）

评审驱动共 4 个提交：

- `60c7482` fix: hook 安装路径感知幂等 + 新增 User 环境同步脚本
- `8584cbd` docs: 沉淀 2026-08-21 实测踩坑 + 修正 drive 原语
- `dd31d06` fix: 按三 agent review 修复守卫/脚本/文档不一致
- `2d0af8e` docs: observe 节新增 TUI 备屏文件产物获取
- `ff358ed` docs: 记录全程仅使用 pwsh（PowerShell 7）的环境约束
- `01c19a9` fix: 复验回归修复
- `cff6826` docs: 修正 [features] 幂等注释范围表述
- `cf2182e` fix: 收敛终审残留

**第 4 轮（HEAD: 3c6c9bc）** launch/drive 重构 + 坑收敛，共 3 提交：

- `a3a59e2` fix: 第4轮三 agent review 收敛——drive 严格流程化 + 消除文档矛盾
- `9b6602e` docs: 坑职责收敛到专门 troubleshooting.md（主 SKILL 只留原语+索引）
- `3c6c9bc` docs: 归档第4轮 review + README 分轮表更新

## 关键结论（三端交叉印证）

- 守卫 `$PSScriptRoot` 内联为空 → 显式 `$SkillDir`
- pane 校验用 `display-message`（`list-panes` 是 window 作用域）
- Enter 必须单独 send-keys 发；含空格 prompt 用 `-l`
- 无效 JSON **跳过而非重建**（避免静默覆盖用户配置）
- claude 的 `PermissionRequest` 非标准事件；codex 的 `Stop` hook 不上报 idle
- 环境约束：全程仅用 pwsh（PowerShell 7）

## 复现

```powershell
# 三 agent 评审产物可按轮次读取（markdown）
# git log --oneline 查看评审驱动提交
```
