#Requires -Version 7.0
# install.ps1 - 用 gh 全局安装 win-rmux skill 到 codex / kimi / claude code 三端
#
# 用法:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1          # 幂等安装（已存在跳过）
#   pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Force   # 覆盖安装

param([switch]$Force)

$ErrorActionPreference = 'Stop'

$repo      = 'raystyle/win-rmux'
$skillName = 'win-rmux'

# ── 1. 用 gh 从仓库获取 SKILL.md（base64 解码）──
Write-Host "[INFO] 通过 gh 获取 $repo 的 SKILL.md ..." -ForegroundColor Cyan
$b64 = gh api "repos/$repo/contents/SKILL.md" --jq '.content' 2>$null
if (-not $b64) { throw "gh 获取 SKILL.md 失败（确认 gh 已登录且仓库 raystyle/win-rmux 存在）" }
$text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($b64 -replace "`n", '')))
if ([string]::IsNullOrWhiteSpace($text)) { throw 'SKILL.md 内容为空' }

# ── 2. 分发到三端全局 skill 目录 ──
$targets = @(
    (Join-Path $env:USERPROFILE '.codex\skills\win-rmux\SKILL.md'),       # Codex（$CODEX_HOME/skills）
    (Join-Path $env:USERPROFILE '.claude\skills\win-rmux\SKILL.md'),      # Claude Code
    (Join-Path $env:USERPROFILE '.kimi-code\skills\win-rmux\SKILL.md')    # Kimi Code（$KIMI_CODE_HOME/skills）
)

$installed = 0
foreach ($t in $targets) {
    $dir = Split-Path $t -Parent
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if ((Test-Path -LiteralPath $t) -and -not $Force) {
        Write-Host "[跳过] 已存在: $t（-Force 覆盖）" -ForegroundColor DarkGray
        continue
    }
    [System.IO.File]::WriteAllText($t, $text, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "[OK] 已安装: $t" -ForegroundColor Green
    $installed++
}

Write-Host "[完成] win-rmux 已安装到 $installed 端，重启对应 agent 生效" -ForegroundColor Green
