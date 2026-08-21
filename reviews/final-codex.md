# win-rmux final verification (codex) — commit 01c19a9

Verdict: all 4 changes are present and correct. Two minor caveats on change 3 (non-blocking).

## 1. SKILL.md pane verify — display-message (not list-panes)
- `SKILL.md:107` uses `rmux display-message -p -t $p -F '#{pane_current_command}'`. Correct.
- Verified live: `display-message -p -t execution-unit:0.0 -F '#{pane_current_command}'` -> `codex` (single pane), while `list-panes -t execution-unit:0.0 -F '#{pane_current_command}'` returns `codex/kimi/claude`. Confirms the fix rationale in `:105-106` (list-panes `-t <sess>:0.0` is window-scoped and would false-warn).

## 2. SKILL.md write-product send + bounded poll
- `SKILL.md:138` has `-l` before `-- $writePrompt`; `:139` sends `Enter` separately. Correct.
- `SKILL.md:141-145` sets a 3-minute `$deadline` and loops only while `(Get-Date) -lt $deadline`, with an explicit timeout warning. No infinite wait. Correct.

## 3. install-agent-hooks [features] idempotency regex
- `install-agent-hooks.ps1:133` `$hooksLine = '(?m)^\s*hooks\s*=\s*'`; `:134` early-returns on match. Correct.
- Verified regex behavior: `hooks = false`/`hooks=true`/`  hooks = false` match; comment lines `# hooks = true`, `  # hooks = true`, `# win-rmux: ...`, trailing comment `foo = 1 # hooks = true`, and `x = "hooks = true"` do NOT match. No duplicate key on `hooks=false`, no comment false-positive.

## 4. hooks.md / overview.md two-step + KEY= format
- `overview.md:50` shows the two-step form `send-keys -t TARGET -l -- 'text'` + `send-keys -t TARGET -- Enter`. Correct.
- `hooks.md:11` shows `-> AGENT_STATE_codex=working`; `hooks.md:63` states the output is `AGENT_STATE_codex=idle|working|blocked` with a `KEY=` prefix. Correct.

## Remaining issues (minor, change 3 only)
1. The `hooks=` regex is line-anchored but not scoped to the `[features]` table. A `hooks = ...` key in any other table would also trigger the early-return, so `[features] hooks = true` would be skipped. The comment at `install-agent-hooks.ps1:131-132` says "仅当 [features] 表内", which is slightly inaccurate. Unlikely in practice for codex config.toml.
2. `hooks = false` is treated as "already present" and left unchanged, so hooks stay disabled rather than being flipped to `true`. This is the documented tradeoff (avoiding a duplicate key), not a corruption bug.
