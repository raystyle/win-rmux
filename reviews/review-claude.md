# win-rmux Review (Claude Code)

Date: 2026-08-21
Scope: `skills/win-rmux/SKILL.md` (guard + drive sections), `skills/win-rmux/scripts/install-agent-hooks.ps1`, `skills/win-rmux/scripts/refresh-user-env.ps1`, `references/` consistency.
Verification basis: command claims checked against installed rmux 0.10.0 (`D:\ohmyenv\rmux\rmux.exe`) where possible - `send-keys` flags `-l / --wait* / --stable-for / --timeout` all confirmed via `rmux send-keys --help`.

## 1. SKILL.md

### Guard section (lines 32-46)

- **`skills/win-rmux/SKILL.md:43,45` - `$PSScriptRoot` breaks when pasted interactively.** `$PSScriptRoot` is only populated inside a `.ps1` file. The guard is presented as a paste-and-run block ("每次先跑"); run in an interactive pwsh (the normal case for a driving agent), `$PSScriptRoot` is `$null`, so `. "/scripts/refresh-user-env.ps1"` and the `pwsh -File ...install-agent-hooks.ps1` call both fail. Needs an explicit skill-dir variable or a note to wrap the guard in a script file.
- **`skills/win-rmux/SKILL.md:40` - PATH rebuild drops process-only entries.** Rebuilding `$env:Path` as Machine+User discards every PATH entry the current process added (harness-injected dirs, session shims). If `rmux` / agent launchers are prepended only by the host profile and not present in registry PATH, the guard itself breaks rmux resolution. rmux-usage.md:198 acknowledges the side effect; the skill should too (or merge rather than replace).
- **`skills/win-rmux/SKILL.md:36` - polluted-daemon guard can nuke unrelated sessions.** The guard trusts `rmux list-sessions`, but the docs themselves document tiny-CLI false negatives (rmux-usage.md:203). A false negative here triggers `kill-server`, killing unrelated sessions. Run the check with `RMUX_DISABLE_TINY_CLI=1`. Also `Get-Process rmux` (line 35) matches transient client invocations, not just the daemon - mostly benign, worth a comment.

### Drive section (lines 84-100)

- **`skills/win-rmux/SKILL.md:126` - judge fallback contradicts the two-step Enter rule.** The CPU-probe fallback sends `-- 'prompt' Enter` in one `send-keys`, directly contradicting the drive rule at lines 93-98 ("Enter 与文本同发会被吞，不提交"). The one-shot pattern taught here is exactly the one the skill forbids. Same contradiction in `references/extensions.md:85` and `references/rmux-usage.md:163`.
- **`skills/win-rmux/SKILL.md:87-91` - `Get-AgentPane` hard-codes pane indexes despite line 14.** It maps name -> registry index -> pane index, i.e. it *does* hard-code pane position, contradicting line 14 ("寻址按 agent 名，不硬编码 pane 索引"). After the documented respawn-pane crash + reflow (lines 177-179), `0.1`/`0.2` point at the wrong agent. rmux-usage.md:207 (pitfall 6: "发送前先 find-panes 确认目标") says to verify the target first; drive does not.
- **`skills/win-rmux/SKILL.md:94` - recipe omits `-l` while line 99 requires it for spaces.** Line 99 says prompts with spaces need `-l` (or token + `Space`), but the main recipe at line 94 sends `-- '<ascii-prompt>'` without `-l`. Real prompts almost always contain spaces; make `-l` the default in the recipe.
- **`skills/win-rmux/SKILL.md:93-95` - no `$LASTEXITCODE` check between the two sends.** If the text send times out or fails, `Enter` is still sent alone (empty submit / re-submits previous prompt in codex/kimi).
- Minor: `skills/win-rmux/SKILL.md:100` - `--wait quiet|--wait-text|...` conflates a `--wait` *value* with the separate flags; rmux-usage.md:204 states it correctly ("`--wait` 本版本仅 quiet，`--wait-*` 是独立参数").

### Other SKILL.md findings

- **`skills/win-rmux/SKILL.md:106` - `stream-pane --lines` is a blocking stream.** command-verification.md:143 shows it TIMEOUTs (continuous streaming); the skill lists it alongside `capture-pane` as a quick read with no caveat, so an agent following it hangs. Add a caveat or `--timeout`.
- **`skills/win-rmux/SKILL.md:138` - recover block depends on `$wd` from launch.** `$wd` is only defined in the launch section; run standalone, `-d ""` degrades to wt's USERPROFILE default, which rmux-usage.md:168 explicitly warns against. Use `(Get-Location).Path` in the recover block.
- **`skills/win-rmux/SKILL.md:115` - `show-environment` output comment misleading.** Actual output is `AGENT_STATE_codex=working` (hooks.md:11, command-verification.md:65), not the bare value; judge parsing must strip the `KEY=` prefix.

## 2. Scripts

### install-agent-hooks.ps1

- **`scripts/install-agent-hooks.ps1:120-121` - duplicate `[features]` table corrupts codex config (highest-impact bug).** `Enable-CodexHooksFeature` blindly appends `[features]` + `hooks = true`. If `~/.codex/config.toml` already has a `[features]` table (any feature), the result is a duplicate-table TOML error, so codex fails to parse its config entirely - and `hooks = true` is never set for an existing table either. Detect an existing `[features]` section and insert just `hooks = true` into it.
- **`scripts/install-agent-hooks.ps1:81,109,121` - parent-dir assumption aborts the whole install.** `[IO.File]::WriteAllText` / `AppendAllText` throw if the parent dir does not exist. On a machine where kimi (or codex) was never run, `~/.kimi-code` / `~/.codex` is missing; with `$ErrorActionPreference = 'Stop'` (line 7) the whole run aborts, so one missing agent blocks hook install for the other two. Create dirs with `New-Item -ItemType Directory -Force` first, and wrap each agent in try/catch so failures do not cascade.
- **`scripts/install-agent-hooks.ps1:70-71` - empty/whitespace JSON file crashes `Install-JsonHooks`.** Empty file: `Get-Content -Raw` returns `$null` -> `$null` binds to `[hashtable]$Root` -> NRE inside `Add-JsonHook`. Whitespace-only file: `ConvertFrom-Json` throws. Guard with `if (-not "$content".Trim()) { '{}' }`.
- **`scripts/install-agent-hooks.ps1:31,37-38` - matcher/timeout never repaired on existing entries.** Matcher is only written on fresh creation; an entry installed by an older version of this script (command matches, matcher missing) is treated as current and never repaired, though hooks.md:35 says claude hooks may not fire without `matcher`. Same for the SessionEnd timeout 10 -> 3 (line 75): an existing entry keeps its old timeout.
- Minor:
  - `:70,88,116` - `Get-Content -Raw $Path` without `-LiteralPath`; wildcard chars in `$HOME` would break.
  - `:31` - `-eq` is case-insensitive, so path-case drift counts as "current" (`-ceq` would be stricter).
  - Hashtable round-trip (`ConvertFrom-Json -AsHashtable` -> `ConvertTo-Json`) loses key order, so the user's whole `settings.json` is reordered/reformatted on first install (diff churn).

### refresh-user-env.ps1

- **`scripts/refresh-user-env.ps1:18,29` - `$e` leaks into caller scope.** The `foreach` loop variable is not in the `Remove-Variable` cleanup list, so dot-sourcing leaks `$e` into the caller's scope - defeating the stated purpose of line 29.
- **`scripts/refresh-user-env.ps1:21` - silently clobbers host-injected Process values.** By design it overwrites any Process-scope value with the User registry value (CI proxies `HTTP(S)_PROXY`, `OPENAI_BASE_URL`, `ANTHROPIC_BASE_URL` overrides, ...). At minimum document it; a "only set vars missing from Process" mode would be safer for the stated goal (adding missing API keys).
- Minor:
  - No `try/finally` around the loop, so an exception skips the `Remove-Variable` cleanup.
  - A `$null`/empty User value -> `SetEnvironmentVariable(key, '', 'Process')` deletes the var instead of setting it empty (edge).

## 3. references/ consistency

- **`references/hooks.md:26-30` - event table stale vs the installer.** Doc says: codex = `SessionStart`/`PermissionRequest` only; claude = SessionStart / tool-use / SubagentStop; kimi = native `session/working/blocked/idle`. The script actually registers: 6 codex events (incl. `UserPromptSubmit`, `Stop`, `SessionEnd`), 5 claude events, and kimi gets the claude-style set `SessionStart/UserPromptSubmit/PreToolUse/PermissionRequest/Stop/Interrupt` (install-agent-hooks.ps1:102,127,129). Also "SessionStart -> session id" (hooks.md:29) does not match the hook script mapping (-> `idle`).
- **`references/hooks.md:63-64` vs `:11` - same file disagrees on `show-environment` output.** Line 63 implies bare `idle|working|blocked`; line 11 correctly shows `AGENT_STATE_codex=working`.
- **`references/extensions.md:85`, `references/rmux-usage.md:163,174` - text+Enter combined in one send-keys.** Conflicts with SKILL.md:98's absolute two-step rule (rmux-usage.md:175 only carves out *long* prompts). Pick one rule and align all examples.
- **`references/command-verification.md:143` vs `SKILL.md:106`** - the reference proves `stream-pane --lines` blocks (TIMEOUT); the skill presents it as a read. See finding above.
- **`README.md:32-33,63-65` - packaging claims inconsistent and under-scoped.** Line 19 says `references/` ships, line 33 says only `references/rmux-usage.md`, and the `gh api` fallback (line 64) installs only SKILL.md. SKILL.md now hard-depends on `scripts/` and `hooks/` (guard lines 43-45; the hook script path is baked into agent configs at install time) - any install path that does not ship those directories produces a skill whose guard fails on first run. Verify `gh skill` copies the whole `skills/win-rmux/` tree and fix the README text.

## Checked out fine

- Pane/layout claims: `-f -v` full-width split for the 上2下1 layout, `0.0/0.1/0.2` mapping (matches rmux-usage.md measured layout).
- `Enter`-only vs `C-m` literal `^M` pitfall, consistent across SKILL.md / keybindings.md / rmux-usage.md.
- `list-sessions` + `-contains` instead of `has-session` exit codes (SKILL.md:55, overview.md:48, CLAUDE.md:17 all consistent).
- tiny CLI / `RMUX_DISABLE_TINY_CLI=1` (SKILL.md:120, rmux-usage.md:203, environment.md:5).
- codex Stop-hook-does-not-fire caveat (SKILL.md:174 <-> hooks.md:36, same date and claims).
- `commands.md` flag face matches `rmux list-commands` / `send-keys --help` (incl. `-l`, `-N`, `--stable-for`, `--timeout`).
- options.md / formats.md / keybindings.md tables internally consistent with command-verification.md output.
- refresh-user-env skip list (PATH/TERM/COLORTERM/NO_COLOR) matches the guard's TERM/COLORTERM/PATH handling; dot-source requirement comment is correct.

## Suggested fix order

1. install-agent-hooks.ps1: `[features]` duplicate-table bug (breaks codex config).
2. install-agent-hooks.ps1: create parent dirs + per-agent try/catch (one missing agent blocks all).
3. SKILL.md:126 judge example -> two-step Enter (align extensions.md:85, rmux-usage.md:163).
4. SKILL.md:43,45 `$PSScriptRoot` interactive-paste fix.
5. install-agent-hooks.ps1 empty-file guard; matcher/timeout repair.
6. SKILL.md:87-91 pane-target verification (find-panes/list-panes before send).
7. Docs sweep: hooks.md event table, show-environment format, stream-pane caveat, README packaging.
