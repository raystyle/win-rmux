# install-agent-hooks.ps1
# 检测并安装 codex / kimi / claude 的 agent 状态 hook（幂等）。
# 用法：pwsh -NoProfile -File skills/win-rmux/scripts/install-agent-hooks.ps1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$SkillRoot  = Split-Path $PSScriptRoot -Parent
$HookScript = Join-Path $SkillRoot 'hooks\win-rmux-agent-state.ps1'
$HookCmd    = "pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$HookScript`""
$Marker     = [System.IO.Path]::GetFileName($HookScript)

function Backup([string]$Path) {
  if (Test-Path $Path) {
    $bak = "$Path.bak-$([DateTime]::Now.ToString('yyyyMMddHHmmss'))"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    Write-Host "  backup -> $bak"
  }
}

function Add-JsonHook([hashtable]$Root, [string]$Event, [string]$Command, [string]$Matcher = '', [int]$Timeout = 10) {
  if (-not $Root.ContainsKey('hooks')) { $Root['hooks'] = @{} }
  $hooks = $Root['hooks']
  if (-not $hooks.ContainsKey($Event)) { $hooks[$Event] = @() }
  # 清理旧路径 win-rmux 条目（命令含 marker 但路径不同）+ 去重：最新命令只保留一条
  $kept = New-Object System.Collections.Generic.List[object]
  $latest = $null
  $removed = 0
  foreach ($existing in @($hooks[$Event])) {
    $cmd = if ($existing.hooks) { $existing.hooks[0].command } else { '' }
    if ($cmd -eq $Command) { $latest = $existing; continue }  # 已是最新命令
    if ($cmd -like "*$Marker*") { $removed++; continue }      # 旧路径 win-rmux hook：移除
    $kept.Add($existing)
  }
  $changed = ($removed -gt 0) -or (-not $latest)
  if (-not $latest) {
    $latest = [ordered]@{ hooks = @([ordered]@{ type = 'command'; command = $Command; timeout = $Timeout }) }
    if ($Matcher) { $latest['matcher'] = $Matcher }
  }
  $hooks[$Event] = [object[]]$kept + , $latest
  return $changed
}

function Remove-KimiHookBlocks([string]$Content, [string]$EscCmd) {
  # 按 [[hooks]] 块切分，删除「含 marker 但命令非当前路径」的块（迁移/重装时清旧块）。
  # 块在任意下一个 TOML 表头（[ 或 [[ 开头）处收尾，避免把块后夹的单括号段一并吞删。
  $lines = $Content -split "`r?`n"
  $result = New-Object System.Collections.Generic.List[string]
  $removed = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[\[hooks\]\]\s*$') {
      $block = New-Object System.Collections.Generic.List[string]
      $block.Add($lines[$i])
      $j = $i + 1
      while ($j -lt $lines.Count -and $lines[$j] -notmatch '^\s*\[') {
        $block.Add($lines[$j]); $j++
      }
      $blockText = $block -join "`n"
      if ($blockText.Contains($Marker) -and -not $blockText.Contains($EscCmd)) { $removed++; $i = $j - 1; continue }
      foreach ($l in $block) { $result.Add($l) }
      $i = $j - 1
    } else {
      $result.Add($lines[$i])
    }
  }
  [pscustomobject]@{ Content = ($result -join "`r`n"); Removed = $removed }
}

function Install-JsonHooks([string]$Path, [string]$Label, [string[]]$Events, [string]$Matcher = '') {
  Write-Host "[$Label] $Path"
  $content = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { '{}' }
  if (-not $content -or -not $content.Trim()) { $content = '{}' }   # 空/空白文件兜底
  try {
    $root = $content | ConvertFrom-Json -AsHashtable
  } catch {
    # 无效 JSON：告警并跳过（不改动该文件），避免从 {} 重建覆盖用户的其他配置
    Write-Warning "  ${Label}: $Path 不是有效 JSON，已跳过（未改动；请手工修复后重跑）"
    return
  }
  if (-not $root.ContainsKey('hooks')) { $root['hooks'] = @{} }
  $changed = $false
  foreach ($ev in $Events) {
    # Codex 对 SessionEnd 钩子有 3s 硬上限（超了会被钳制并告警），其余事件保持 10s。
    $timeout = if ($ev -eq 'SessionEnd') { 3 } else { 10 }
    if (Add-JsonHook $root $ev $HookCmd $Matcher $timeout) { $changed = $true }
  }
  if (-not $changed) { Write-Host '  already installed'; return }
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Backup $Path
  $json = $root | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
  Write-Host '  installed'
}

function Install-Kimi {
  $path = Join-Path $HOME '.kimi-code\config.toml'
  $dir  = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Write-Host "[kimi] $path"
  $content = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { '' }
  $esc = $HookCmd.Replace('\','\\').Replace('"','\"')
  # 无论是否已装，先清理「含 marker 但命令非当前路径」的残留块（迁移/重复场景）
  $r = Remove-KimiHookBlocks $content $esc
  if ($r.Removed -gt 0) {
    Write-Host "  cleaned $($r.Removed) stale hook block(s)"
    Backup $path
    [System.IO.File]::WriteAllText($path, $r.Content, [System.Text.UTF8Encoding]::new($false))
    $content = $r.Content
  }
  if ($content -and $content.Contains($esc)) { Write-Host '  already installed'; return }
  Backup $path
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine()
  foreach ($ev in @('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','Stop','Interrupt')) {
    [void]$sb.AppendLine('[[hooks]]')
    [void]$sb.AppendLine('event = "' + $ev + '"')
    [void]$sb.AppendLine('command = "' + $esc + '"')
    [void]$sb.AppendLine('timeout = 10')
    [void]$sb.AppendLine()
  }
  [System.IO.File]::AppendAllText($path, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
  Write-Host '  installed'
}

function Enable-CodexHooksFeature {
  $path = Join-Path $HOME '.codex\config.toml'
  $dir  = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $marker = '# win-rmux: enable agent-state hooks'
  $content = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { '' }
  # 幂等判断用「行首 hooks 键」正则而非子串 Contains：避免注释(行首#)里的 hooks 误判、
  # 避免 hooks=false 时插入重复键。注意：该正则是全文范围（非严格 [features] 表级），
  # 若其他表下恰好有 hooks 键也会命中——codex config 实际无此键，现实风险低。
  $hooksLine = '(?m)^\s*hooks\s*=\s*'
  if ($content -and $content -match $hooksLine) {
    Write-Host "[codex] config.toml hooks already present"; return
  }
  Write-Host "[codex] $path"
  Backup $path
  $newLine = "${marker}`nhooks = true`n"
  if ($content -match '(?m)^[ \t]*\[features\]\s*$') {
    # 已有 [features] 表：在其表体末尾插入（表内除 hooks 外可能还有别的键），不追加重复表头
    $lines = $content -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $inFeatures = $false
    $inserted = $false
    foreach ($ln in $lines) {
      if ($ln -match '^\s*\[features\]\s*$') { $inFeatures = $true; $out.Add($ln); continue }
      if ($inFeatures -and $ln -match '^\s*\[.*\]\s*$') {
        # 遇到下一个表头：把 hooks 插到本表尾（表体末尾）
        $out.Add(($newLine -replace '\n$',''))
        $out.Add('')
        $inserted = $true
        $inFeatures = $false
      }
      $out.Add($ln)
    }
    if ($inFeatures) { $out.Add(($newLine -replace '\n$','')); $inserted = $true }
    [System.IO.File]::WriteAllText($path, ($out -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Host '  [features] 表内已插入 hooks = true'
  } else {
    # 无 [features] 表：追加完整块
    [System.IO.File]::AppendAllText($path, "`n$marker`n[features]`nhooks = true`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host '  config.toml 追加 [features] hooks = true'
  }
}

Write-Host "== win-rmux agent hook 检测/安装 =="
Write-Host "hook script: $HookScript"
$fail = 0
try    { Install-JsonHooks (Join-Path $HOME '.codex\hooks.json') 'codex' @('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','Stop','SessionEnd') }
catch  { Write-Warning "codex: $($_.Exception.Message)"; $fail++ }
try    { Enable-CodexHooksFeature }
catch  { Write-Warning "codex config.toml: $($_.Exception.Message)"; $fail++ }
try    { Install-JsonHooks (Join-Path $HOME '.claude\settings.json') 'claude' @('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','Stop') '*' }
catch  { Write-Warning "claude: $($_.Exception.Message)"; $fail++ }
try    { Install-Kimi }
catch  { Write-Warning "kimi: $($_.Exception.Message)"; $fail++ }
if ($fail -gt 0) { Write-Warning "完成，但有 $fail 项失败（其余已装）" } else { Write-Host 'done' }
