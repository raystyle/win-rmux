# win-rmux agent state hook
# 由 codex / kimi / claude 的 hook 系统调用，把 agent 状态回写到 rmux 会话环境。
# 输入：stdin JSON（含 hook_event_name），或位置参数（herdr 风格 action）。
param([string]$Action = "")

$unit  = $env:WIN_RMUX_UNIT
$agent = $env:WIN_RMUX_AGENT
if (-not $unit -or -not $agent) { exit 0 }

$event = $Action
if (-not $event) {
  try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $event = ($raw | ConvertFrom-Json).hook_event_name }
  } catch { exit 0 }
}
if (-not $event) { exit 0 }

$key = $event.ToLowerInvariant()
$state = switch ($key) {
  'session'            { 'idle' }
  'idle'               { 'idle' }
  'working'            { 'working' }
  'blocked'            { 'blocked' }
  'sessionstart'       { 'idle' }
  'userpromptsubmit'   { 'working' }
  'pretooluse'         { 'working' }
  'posttooluse'        { 'working' }
  'posttoolusefailure' { 'working' }
  'subagentstart'      { 'working' }
  'precompact'         { 'working' }
  'permissionrequest'  { 'blocked' }
  'permissionresult'   { 'working' }
  'stop'               { 'idle' }
  'interrupt'          { 'idle' }
  'sessionend'         { 'idle' }
  default              { exit 0 }
}

& rmux set-environment -t $unit ("AGENT_STATE_" + $agent) $state 2>$null | Out-Null
exit 0
