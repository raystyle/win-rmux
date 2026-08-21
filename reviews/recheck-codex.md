# win-rmux recheck (codex)

Verdict: all four requested fixes are present and correct. Remaining issues are minor edge cases listed at the end.

## 1. SKILL.md

- Guard now uses `$SkillDir` (not `$PSScriptRoot`): `SKILL.md:43` sets it, `:52` and `:54` use it, `:57-58` documents why. Correct.
  - Caveat: `SKILL.md:43` hardcodes `C:\Users\ray\.claude\skills\win-rmux`. It is annotated "按本机安装路径填", but a skill installed via `gh skill install` on another machine still needs a manual edit. Not a blocker, just non-portable.
- Drive two-step with `-l` + separate Enter: `SKILL.md:111` sends `-l -- '<ascii-prompt>'`, `:112` sends `Enter` separately. Correct (`-l` verified present in `rmux send-keys --help`).
- Judge fallback two-step: `SKILL.md:165-166` uses `-l -- 'prompt'` then a separate `Enter`. Correct.

## 2. install-agent-hooks.ps1

- Empty/whitespace JSON handled: `:71` falls back to `{}`; `:72-78` catches invalid JSON, backs up, and rebuilds from `{}`. Correct.
- Parent dirs created: `:87-88` (Install-JsonHooks), `:97-98` (Install-Kimi), `:127-128` (Enable-CodexHooksFeature). Correct.
- Per-agent try/catch: `:164-172` wrap codex/claude/kimi separately and count failures. Correct.
- `[features]` dedup: `:131` early-returns when `hooks = true` exists; `:135-154` inserts into an existing `[features]` table; `:156-158` appends a fresh block otherwise. Correct for the common case.

## 3. refresh-user-env.ps1

- Only fills missing vars: `:27` checks the Process value first and sets only if null/empty. Correct.
- Skips PATH/PSModulePath/TERM/COLORTERM/NO_COLOR: `:22`. Correct.
- No `$e` leak: `:38` now removes `skip,user,n,e`. Correct.

## 4. references/hooks.md

- Event table now matches the installer exactly: codex `:28` = 6 events (matches `install-agent-hooks.ps1:165`), claude `:29` = 5 events (matches `:169`), kimi `:30` = 6 events (matches `:114`). Correct, and it documents the claude `PermissionRequest` non-standard caveat.

## Remaining bugs / inconsistencies (minor)

1. `overview.md:50` still shows the old single-send form `rmux send-keys -t TARGET -- 'text' Enter` (text+Enter together, no `-l`), contradicting the new two-step `-l` rule now used in SKILL.md, extensions.md, and rmux-usage.md.
2. `SKILL.md:137` (observe write-prompt example) sends `$writePrompt` (contains spaces/backslashes/parens) without `-l`, inconsistent with `SKILL.md:111`/`:165` and the guidance at `SKILL.md:116`.
3. `install-agent-hooks.ps1:131` idempotency check is a loose substring `Contains('hooks = true')`: if `[features]` already has `hooks = false` (or any non-true value), the script proceeds and inserts a second `hooks = true` -> duplicate `hooks` key -> TOML parse error. It also false-positives if `hooks = true` appears in a comment or another table.
4. `install-agent-hooks.ps1:135` vs `:142`: the outer `[features]` detection uses `^\[features\]` (column 0), while the insertion loop allows leading whitespace. An indented `[features]` header is not detected by the outer check, so it falls through to append a duplicate `[features]` table.
5. `install-agent-hooks.ps1:30` dedup/stale detection still only inspects `hooks[0].command`, so a stale win-rmux entry that is not the first hook in a multi-hook entry is missed.
6. `install-agent-hooks.ps1:134`/`:145`/`:152`: the `[features]` insertion path writes `$newLine` with an embedded LF and then joins the file with CRLF, producing mixed line endings (cosmetic; TOML parsers accept it).
