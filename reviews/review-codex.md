# win-rmux review (codex)

Scope: SKILL.md guard/drive, the two install/env scripts, and references vs actual commands.
Verified against a live rmux 0.10.0 daemon and the actual `~/.codex`, `~/.claude`, `~/.kimi-code` configs.

## 1. skills/win-rmux/SKILL.md

### Guard (lines 32-46)

- **Bug — `$PSScriptRoot` is undefined in inline execution** (`SKILL.md:43`, `SKILL.md:45`).
  `$PSScriptRoot` only exists inside a `.ps1` file. Pasted/run interactively (the normal way a skill guard is executed) it is the empty string, so both
  `. "$PSScriptRoot/scripts/refresh-user-env.ps1"` and `pwsh -NoProfile -File "$PSScriptRoot/scripts/install-agent-hooks.ps1"`
  resolve to `<drive>:\scripts\...` and fail. Verified: `$PSScriptRoot` is empty in an interactive pwsh. Derive the skill dir explicitly instead.
- **Minor — PATH rebuild drops Process-scope additions** (`SKILL.md:40`). `Machine + User` loses any PATH injected only into the current process, and appends a trailing `;` if the User PATH is empty. Tradeoff is documented in `rmux-usage.md`, so low severity.
- Guard daemon-pollution logic (`SKILL.md:35-36`) is otherwise sound. `Get-Process rmux` matches both the daemon (`libexec\rmux\rmux.exe --__internal-daemon`) and an attach client (`rmux.exe attach-session`), but the `list-sessions` emptiness check still gates `kill-server` correctly.

### Drive (lines 84-100)

- Two-step send-keys (text, then a separate `Enter`) is correct and matches `rmux-usage.md` (Enter swallowed when sent with text). `send-keys --wait quiet --stable-for 800ms --timeout 15s` flags verified present via `rmux send-keys --help`.
- **Minor — `Get-AgentPane` is case-sensitive and hardcodes window 0** (`SKILL.md:88-90`). `[array]::IndexOf($agents.name, $name)` uses ordinal string equality; `0.$i` only holds for the default 3-agent layout (>3 is documented as “待定”).

## 2. scripts/install-agent-hooks.ps1

- **Bug — empty existing JSON crashes the installer** (`install-agent-hooks.ps1:70-71`). `Get-Content -Raw` + `ConvertFrom-Json -AsHashtable` throws on a 0-byte `hooks.json`/`settings.json`; with `$ErrorActionPreference='Stop'` (`:7`) the whole install aborts.
- **Bug — missing parent dirs** (`:86`, `:114`, `:127`, `:129`). Assumes `~/.codex`, `~/.claude`, `~/.kimi-code` already exist. On a machine where an agent has never run, `WriteAllText`/`AppendAllText` throw `DirectoryNotFoundException`.
- **Bug — duplicate `[features]` table in codex config** (`:117`, `:120-121`). `Enable-CodexHooksFeature` appends a second `[features]` header; if `config.toml` already has `[features]` (or `hooks = true` without the marker comment), this is a duplicate TOML table. Idempotency only checks the comment marker, not an existing section/key.
- **Minor — backup timestamp collision** (`:15-16`, `:94`, `:99`). `Backup` uses second-granularity names with `-Force`; `Install-Kimi` can call `Backup` twice on the same file within one second (cleanup then install), silently overwriting the first backup.
- **Claude hook registration is questionable** (`:129`). `matcher='*'` is applied to *all* events including `SessionStart`/`UserPromptSubmit`/`PermissionRequest`, where Claude's matcher is only meaningful for `PreToolUse`/`PostToolUse`/`Stop`. Also `PermissionRequest` is not a standard Claude Code hook event (standard set: `PreToolUse`, `PostToolUse`, `Notification`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `SessionStart`, `PreCompact`, `SessionEnd`), so Claude likely never reports `blocked`. Recommend verifying against the installed Claude version.

## 3. scripts/refresh-user-env.ps1

- **Bug — `PSModulePath` is clobbered to User-only** (`refresh-user-env.ps1:15`). The skip list omits `PSModulePath`; setting Process scope to the User value drops Machine paths. Verified locally: Machine `C:\Program Files\WindowsPowerShell\Modules;...`, User `D:\ohmyenv\modules`, Process is the union. This can break pwsh module auto-loading after the guard runs.
- **Dot-source hygiene** (`:29`). `Remove-Variable skip,user,n` plus the un-removed loop var `$e` use generic names; when dot-sourced they overwrite and then delete caller-scope variables of the same name. Use `$private:` or script scope.
- **Minor** (`:19`). `.ToUpperInvariant()` is redundant since `-contains` is already case-insensitive.

## 4. references vs actual commands

- **Inconsistent — `environment.md:23-24`** says `rmux-daemon.exe` is the daemon. The actual running daemon is `libexec\rmux\rmux.exe --__internal-daemon` (confirmed via `Win32_Process.CommandLine`), matching `rmux-usage.md`, not `environment.md`.
- **Inconsistent — `extensions.md:85`** example still sends text and `Enter` in one `send-keys` (`-- '/status' Enter`), contradicting `SKILL.md:98` (“Enter 必须单独一次 send-keys 发”) and `rmux-usage.md` item 8.
- **Inconsistent — `hooks.md:26-30`** table is stale vs the installer. It claims kimi uses native `session/working/blocked/idle`, codex only `SessionStart`/`PermissionRequest`, and claude `SessionStart`/tool-use/`SubagentStop`. The script actually registers codex-style events for all three (codex 6, claude 5, kimi 6). The hook script `win-rmux-agent-state.ps1` switch handles both sets, but the doc table does not match what gets installed.
- **Verified correct**: `overview.md:48` (`has-session` exit code unreliable in PowerShell `if`, use `list-sessions`+`-contains`; `has-session -t nope` exits 1 with no stdout). `SKILL.md:80` locate format works (`#{pane_pid}`, `#{pane_current_command}`, `#{pane_top/left/width/height}`, `#{pane_current_path}`, `#{pane_title}`, `#{session_attached}`, `#{session_windows}` all resolve). Hook state channel works (`show-environment -t execution-unit AGENT_STATE_codex/kimi/claude` returns `working`/`idle`).
