# refresh-user-env.ps1
# 把 User 作用域环境变量同步到当前进程环境，供后续启动的 agent 子进程继承。
#
# 背景（2026-08-21 实测）：宿主进程（CI / agent 宿主 / IDE 派生的 shell）常常不加载
# User 环境变量，导致从它派生的 agent 缺关键变量——codex 实测报
# `Missing environment variable: DEEPSEEK_API_KEY`（provider 的 env_key 在 User 作用域
# 已设置，但进程环境没有）。win-rmux 前置守卫已重建 PATH（Machine+User）并显式设置
# TERM / COLORTERM / NO_COLOR，这里跳过它们避免覆盖守卫的决策。
#
# 用法（SKILL.md 前置守卫内，必须 dot-source 让设置落在当前会话，子进程调用无效）：
#   . "$PSScriptRoot/scripts/refresh-user-env.ps1"
[CmdletBinding()]
param()

$skip = @('PATH', 'TERM', 'COLORTERM', 'NO_COLOR')
$user = [Environment]::GetEnvironmentVariables('User')
$n = 0
foreach ($e in $user.GetEnumerator()) {
  if ($skip -contains $e.Key.ToUpperInvariant()) { continue }
  try {
    [Environment]::SetEnvironmentVariable([string]$e.Key, [string]$e.Value, 'Process')
    $n++
  } catch {
    Write-Warning "refresh-user-env: failed to set $($e.Key): $($_.Exception.Message)"
  }
}
Write-Host "refresh-user-env: synced $n User env vars to process env"
# dot-source 时清理局部变量，避免污染调用方作用域
Remove-Variable skip,user,n -ErrorAction SilentlyContinue
