# Re-check of fixes (Claude Code)

Date: 2026-08-21. Follow-up to `reviews/review-claude.md`.
Method: read current SKILL.md / install-agent-hooks.ps1 / refresh-user-env.ps1 / references/hooks.md; where behavior was uncertain, verified empirically against the installed rmux 0.10.0 (`D:\ohmyenv\rmux\rmux.exe`).

## Checklist verdicts

### 1) SKILL.md

**1a. Guard uses `$SkillDir`, not `$PSScriptRoot` - FIXED (with a note)**
- `SKILL.md:41-43` defines `$SkillDir` explicitly with an install-path comment; `SKILL.md:52,54` use it for both the dot-source and the installer invocation; `SKILL.md:57-58` documents why (`$PSScriptRoot` is empty when pasted into an interactive pwsh).
- Residual: the default value is a Claude-specific, machine-specific path (`C:\Users\ray\.claude\skills\win-rmux`). The "按本机安装路径填" comment acknowledges it, but an agent that runs the guard verbatim on a Codex install (or from a repo checkout) gets a failing dot-source. Auto-detect (e.g., try `$HOME\.codex\skills\win-rmux`, `$HOME\.claude\skills\win-rmux`, repo fallback) would be more robust.

**1b. Drive uses `-l` + separate Enter - FIXED, but the NEW pane-verify snippet is buggy**
- `SKILL.md:111-112`: text send now uses `-l`, Enter is a separate `send-keys`. Correct.
- `SKILL.md:105-108` (new target check) **always warns in a correct layout**. Empirically confirmed: `rmux list-panes -t <session>:0.0` does NOT select that pane - it expands to the pane's window and lists ALL panes (test returned both `0:pwsh` and `1:pwsh` for target `rvtest:0.0`; tmux target-window semantics). So in the standard 3-agent layout the output is three lines (codex/kimi/claude), and `@(...) -notmatch 'codex'` returns the two non-codex lines -> non-empty -> truthy -> `Write-Warning` fires every time even when the target is right. Conversely the check cannot isolate the requested pane at all.
  Fix: use `rmux display-message -p -t $p -F '#{pane_current_command}'` - empirically verified to resolve a single pane target (returned exactly the requested pane each time). E.g.:
  `if ((rmux display-message -p -t $p -F '#{pane_current_command}' 2>$null) -notmatch 'codex') { Write-Warning ... }`
  (or filter `list-panes -t "$unit`:0" -F '#{pane_index} #{pane_current_command}'` by index).

**1c. Judge fallback two-step - FIXED**
- `SKILL.md:164-166`: `# 同样走两段式：先文本(-l)再单独 Enter` + two separate `send-keys` with `-l`. Consistent with the drive rule now.

### 2) install-agent-hooks.ps1

**2a. Empty/whitespace JSON - FIXED**
- `install-agent-hooks.ps1:70-71`: `$content` normalized to `'{}'` when missing/null/whitespace-only. The earlier NRE / ConvertFrom-Json throw on empty file is gone.
- Residual concern (moderate): the new catch branch (`:72-78`) for *invalid* JSON prints a warning, backs up, then rebuilds from `{}` - and since `changed` becomes true, **overwrites the user's settings.json/hooks.json with a hooks-only file** (line 89-91). A hand-edited file with a trailing comma gets replaced rather than skipped. Backup mitigates, but "skip with warning, do not rewrite" is safer for a parse failure.

**2b. Parent dirs created - FIXED**
- `:87-88` (hooks.json / settings.json), `:97-98` (kimi config.toml), `:126-128` (codex config.toml): `Split-Path -Parent` + `New-Item -ItemType Directory -Force`. Fresh machines without `~/.kimi-code` / `~/.codex` no longer throw.

**2c. Per-agent try/catch - FIXED**
- `:164-173`: each of the four install steps wrapped in try/catch with a `$fail` counter; one agent failing no longer aborts the rest; summary warning at the end.

**2d. `[features]` dedup - FIXED in the main case, two residual edges**
- `:131` early-returns if `hooks = true` already present anywhere (idempotent, also covers user-enabled case).
- `:135-154` when `[features]` already exists: inserts `hooks = true` at the end of the table body (before the next table header, or EOF), no duplicate table header appended. Algorithm walked through - correct for: features last, features followed by another table, empty features body, `[[hooks]]`-style headers terminating the body.
- Residual edge 1 (real): if the existing `[features]` body contains `hooks = false` (user explicitly disabled), line 131 does not match (`Contains('hooks = true')` false), the insert adds a second `hooks` key -> TOML duplicate-key error -> codex config fails to parse. Should check for `hooks = <any value>` (e.g. regex `(?m)^\s*hooks\s*=`) and skip/warn instead of insert.
- Residual edge 2 (cosmetic): `Contains('hooks = true')` is a blunt substring test - a match inside a comment (`# never set hooks = true`) suppresses installation.
- Cosmetic: the inserted block keeps an internal bare `` `n `` while the file is re-joined with `` `r`n `` (`:134,145,152,153`) -> mixed EOLs. TOML-legal, but inconsistent.

### 3) refresh-user-env.ps1

- **Only fills missing vars - FIXED.** `:27` gates on `[string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key,'Process'))` before setting; host-injected Process values (PROXY / BASE_URL / ...) are no longer clobbered. Rationale documented (`:9-11`).
- **Skip list - FIXED.** `:22` now `PATH, PSModulePath, TERM, COLORTERM, NO_COLOR`, case-insensitive via `ToUpperInvariant()` (`:26`); the PSModulePath rationale (must keep Machine+User union or pwsh module loading breaks) is documented at `:12-14`.
- **`$e` leak - FIXED.** `:38` `Remove-Variable skip,user,n,e`.
- Residual (low): still no `try/finally`, so a throw from `ToUpperInvariant()`/`GetEnvironmentVariable` would skip cleanup - low risk now that the risky set call has its own try/catch. Empty-string Process value counts as missing and gets filled (reasonable semantics).

### 4) references/hooks.md event table vs installer

- **FIXED / matches.** `hooks.md:28` codex = `SessionStart/UserPromptSubmit/PreToolUse/PermissionRequest/Stop/SessionEnd` == installer `:165`. `hooks.md:29` claude = 5 events, explicitly notes `SubagentStop` not registered == installer `:169`. `hooks.md:30` kimi = `SessionStart/UserPromptSubmit/PreToolUse/PermissionRequest/Stop/Interrupt` == installer `:114`. The stale "native session/working/blocked/idle" and "SessionStart->session id" rows are gone; state mappings now match `hooks/win-rmux-agent-state.ps1` (sessionstart->idle, userpromptsubmit/pretooluse->working, permissionrequest->blocked, sessionend->idle), and the codex Stop-not-firing caveat is consistent with SKILL.md:214.
- Bonus: `hooks.md:35` now honestly notes `PermissionRequest` is not a standard Claude Code event, so claude may never report `blocked`.
- Residual (minor): `hooks.md:63-64` still says output is bare `idle | working | blocked` while `:11` (correctly) shows `AGENT_STATE_codex=working`; SKILL.md:153 comment has the same bare-value implication.

## Remaining bugs (not on the checklist, still open from the first review)

1. **NEW - `SKILL.md:137`**: the TUI file-product send is `rmux send-keys ... -- $writePrompt` **without `-l`**, contradicting the rule at `SKILL.md:110` - and `$writePrompt` contains spaces, parentheses, and quotes (exactly the case `-l` was added for). Add `-l`.
2. **NEW - `SKILL.md:140`**: `while (-not (Test-Path ...)) { Start-Sleep 15 }` is an unbounded poll; if the agent never writes the file (crashed, mis-prompted), the driver hangs forever. Add an attempt/timeout cap with a diagnostic (capture pane + hook state) on exhaustion.
3. **SKILL.md:44-45**: polluted-daemon guard still trusts bare `rmux list-sessions` - a tiny-CLI false negative (documented at rmux-usage.md:203) triggers `kill-server` on unrelated sessions. Use `RMUX_DISABLE_TINY_CLI=1` for this probe.
4. **SKILL.md:49**: PATH rebuild (Machine+User) still drops process-only PATH entries; if rmux/agent launchers are only prepended by the host profile, the guard breaks its own resolution. Merge instead of replace, or document.
5. **install-agent-hooks.ps1:31,37-38**: pre-existing entries with a matching command are never repaired (missing `matcher` for claude, stale SessionEnd timeout 10 vs 3).
6. **install-agent-hooks.ps1 invalid-JSON path** rebuilds-and-overwrites (see 2a residual).
7. **install-agent-hooks.ps1 `[features]` + `hooks = false`** duplicate-key edge (see 2d residual 1).
8. Minor, unchanged: `SKILL.md:117` `--wait quiet|--wait-text|...` conflates `--wait`'s value with separate flags; `SKILL.md:123` `stream-pane --lines` still listed without a blocking caveat (command-verification.md:143 shows TIMEOUT); `SKILL.md:153`/`hooks.md:63` show-environment output format; `SKILL.md:178` recover still interpolates launch-scoped `$wd`; no `$LASTEXITCODE` check between text and Enter sends (`SKILL.md:111-112`); `Get-Content -Raw` without `-LiteralPath` in the installer; hashtable JSON round-trip reorders user settings keys; `SKILL.md:13` cites `references/options.md` for a pwsh `default-shell` while options.md:11 actually documents `default-shell cmd.exe` (the pwsh behavior is the empirical note, not the option).
9. **README packaging claims** (`README.md:32-33,63-65`) still under-scope what ships (`scripts/`, `hooks/` are now hard runtime deps of the skill); unverified whether `gh skill` copies the whole skill tree.

## Bottom line

- 1a, 1b(-l/Enter), 1c, 2a, 2b, 2c, 2d(main case), 3 (all three), 4: **confirmed fixed and correct**.
- One fix introduced a new bug: the pane-target verification at `SKILL.md:105-108` misuses `list-panes` (window-scoped) and will warn on every correct mixed layout - replace with `display-message -p -t $p -F '#{pane_current_command}'` (verified working).
- New observe/file-product section adds two issues: missing `-l` at `SKILL.md:137` and the unbounded poll at `SKILL.md:140`.
