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

function Test-Installed([string]$Content) {
  return $Content -and ($Content.Contains($Marker))
}

function Add-JsonHook([hashtable]$Root, [string]$Event, [string]$Command, [string]$Matcher = '') {
  if (-not $Root.ContainsKey('hooks')) { $Root['hooks'] = @{} }
  $hooks = $Root['hooks']
  if (-not $hooks.ContainsKey($Event)) { $hooks[$Event] = @() }
  $entry = [ordered]@{ hooks = @([ordered]@{ type = 'command'; command = $Command; timeout = 10 }) }
  if ($Matcher) { $entry['matcher'] = $Matcher }
  $hooks[$Event] = @($hooks[$Event]) + $entry
}

function Install-JsonHooks([string]$Path, [string]$Label, [string[]]$Events, [string]$Matcher = '') {
  Write-Host "[$Label] $Path"
  $content = if (Test-Path $Path) { Get-Content -Raw $Path } else { '{}' }
  if (Test-Installed $content) { Write-Host '  already installed'; return }
  Backup $Path
  $root = $content | ConvertFrom-Json -AsHashtable
  foreach ($ev in $Events) { Add-JsonHook $root $ev $HookCmd $Matcher }
  $json = $root | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
  Write-Host '  installed'
}

function Install-Kimi {
  $path = Join-Path $HOME '.kimi-code\config.toml'
  Write-Host "[kimi] $path"
  $content = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
  if (Test-Installed $content) { Write-Host '  already installed'; return }
  Backup $path
  $esc = $HookCmd.Replace('\','\\').Replace('"','\"')
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
