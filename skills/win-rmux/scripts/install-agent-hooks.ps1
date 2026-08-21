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
  $lines = $Content -split "`r?`n"
  $result = New-Object System.Collections.Generic.List[string]
  $removed = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[\[hooks\]\]\s*$') {
      $block = New-Object System.Collections.Generic.List[string]
      $block.Add($lines[$i])
      $j = $i + 1
      while ($j -lt $lines.Count -and $lines[$j] -notmatch '^\s*\[\[hooks\]\]\s*$') {
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
  $content = if (Test-Path $Path) { Get-Content -Raw $Path } else { '{}' }
  $root = $content | ConvertFrom-Json -AsHashtable
  $changed = $false
  foreach ($ev in $Events) {
    # Codex 对 SessionEnd 钩子有 3s 硬上限（超了会被钳制并告警），其余事件保持 10s。
    $timeout = if ($ev -eq 'SessionEnd') { 3 } else { 10 }
    if (Add-JsonHook $root $ev $HookCmd $Matcher $timeout) { $changed = $true }
  }
  if (-not $changed) { Write-Host '  already installed'; return }
  Backup $Path
  $json = $root | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
  Write-Host '  installed'
}

function Install-Kimi {
  $path = Join-Path $HOME '.kimi-code\config.toml'
  Write-Host "[kimi] $path"
  $content = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
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
  $marker = '# win-rmux: enable agent-state hooks'
  $content = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
  if ($content.Contains($marker)) { Write-Host "[codex] config.toml hooks already enabled"; return }
  Write-Host "[codex] $path"
  Backup $path
  $block = "`n$marker`n[features]`nhooks = true`n"
  [System.IO.File]::AppendAllText($path, $block, [System.Text.UTF8Encoding]::new($false))
  Write-Host '  config.toml hooks enabled'
}

Write-Host "== win-rmux agent hook 检测/安装 =="
Write-Host "hook script: $HookScript"
Install-JsonHooks (Join-Path $HOME '.codex\hooks.json') 'codex' @('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','Stop','SessionEnd')
Enable-CodexHooksFeature
Install-JsonHooks (Join-Path $HOME '.claude\settings.json') 'claude' @('SessionStart','UserPromptSubmit','PreToolUse','PermissionRequest','Stop') '*'
Install-Kimi
Write-Host "done"
