# refresh-user-env.ps1
# 把 User 作用域环境变量补齐到当前进程环境，供后续启动的 agent 子进程继承。
#
# 背景（2026-08-21 实测）：宿主进程（CI / agent 宿主 / IDE 派生的 shell）常常不加载
# User 环境变量，导致从它派生的 agent 缺关键变量——codex 实测报
# `Missing environment variable: DEEPSEEK_API_KEY`（provider 的 env_key 在 User 作用域
# 已设置，但进程环境没有）。
#
# 设计取舍：
# - 只「补齐缺失」：若 Process 已有同名值（宿主有意注入的 PROXY / BASE_URL / PATH 等），
#   不覆盖。这样既补 API key，也不冲掉宿主为本会话特意设的值。
# - 跳过 PATH / PSModulePath / TERM / COLORTERM / NO_COLOR：PATH 由守卫重建（Machine+User），
#   PSModulePath 需保留 Machine+User 并集（直接覆盖会丢 Machine 模块路径，破坏 pwsh 模块加载），
#   NO_COLOR 守卫删除、TERM/COLORTERM 守卫显式设置。
# - dot-source 时清理局部变量，避免污染调用方作用域。
#
# 用法（SKILL.md 前置守卫内，必须 dot-source 让设置落在当前会话，子进程调用无效）：
#   . "$SkillDir/scripts/refresh-user-env.ps1"
[CmdletBinding()]
param()

$skip = @('PATH', 'PSModulePath', 'TERM', 'COLORTERM', 'NO_COLOR')
$user = [Environment]::GetEnvironmentVariables('User')
$n = 0
foreach ($e in $user.GetEnumerator()) {
  if ($skip -contains $e.Key.ToUpperInvariant()) { continue }
  if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable([string]$e.Key, 'Process'))) {
    try {
      [Environment]::SetEnvironmentVariable([string]$e.Key, [string]$e.Value, 'Process')
      $n++
    } catch {
      Write-Warning "refresh-user-env: failed to set $($e.Key): $($_.Exception.Message)"
    }
  }
}
Write-Host "refresh-user-env: 补齐 $n 个缺失的 User 环境变量（已存在的跳过）"
# dot-source 时清理局部变量，避免污染调用方作用域
Remove-Variable skip,user,n,e -ErrorAction SilentlyContinue
