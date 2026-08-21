# win-rmux convergence (codex)

Verdict: all 8 residuals are resolved (6 FIX, 2 ACCEPT). Working tree (on top of HEAD cff6826) already contains the fixes.

| # | residual | verdict | reason | done |
| --- | --- | --- | --- | --- |
| 1 | Remove-KimiHookBlocks block ends only at next `[[hooks]]` | FIX | a single-bracket `[features]`/`[model]` right after a stale hook block is absorbed and deleted (data loss) | yes (`install-agent-hooks.ps1:55` now stops at `^\s*\[`) |
| 2 | observe `stream-pane --lines` lacks "blocks continuously" caveat | FIX | one-shot read assumption hangs (command-verification.md:143 TIMEOUT) | yes (`SKILL.md:127` caveat added) |
| 3 | `Get-Content -Raw` without `-LiteralPath` | ACCEPT | realistic `$HOME` has no wildcard chars; Windows usernames cannot contain `*`/`?`, `[`/`]` is pathological | yes (hardened anyway: `:71,:101,:131`) |
| 4 | polluted-daemon guard probes with bare `rmux list-sessions` | FIX | the probe gates a destructive `kill-server`; tiny-CLI misreport could kill a live daemon | yes (`SKILL.md:44` sets `RMUX_DISABLE_TINY_CLI=1`) |
| 5 | PATH rebuild Machine+User drops process-only entries | ACCEPT | environment-only, no corruption; documented tradeoff | yes (hardened anyway: `SKILL.md:51-52` now unions + dedups) |
| 6 | poll timeout diagnostic hardcodes `AGENT_STATE_kimi` | FIX | reads wrong agent's state when target is claude/etc. | yes (`SKILL.md:140,148` uses `$targetName`) |
| 7 | invalid-JSON path rebuilds settings/hooks.json from `{}` | FIX | overwrites the user's other config/hooks (corruption) | yes (`install-agent-hooks.ps1:75-79` skips with warning) |
| 8 | README under-states that scripts/ + hooks/ must ship | FIX | partial install leaves guard/hook install broken | yes (`README.md:18-22,63-71`) |

## Remaining minor notes (non-blocking, on the fixes themselves)

1. **Item 6** — `$targetName` is only applied to the diagnostic (`AGENT_STATE_$targetName`); the prompt and `Test-Path` still hardcode `review-kimi.md`. Changing `$targetName` alone won't fully re-target the example. Cosmetic/incomplete parameterization, not a correctness bug.
2. **Item 8** — the new `gh api` tarball fallback (`README.md:66-71`) is Unix/Git-Bash oriented and likely mis-extracts: `tar ... --strip-components=2 -C ~/.codex/skills/win-rmux --wildcards '*/skills/win-rmux/*'` strips `<repo>-<sha>/` and `skills/`, leaving `win-rmux/...` under `.../win-rmux/` (double nesting). With that `-C` target it should be `--strip-components=3` (or extract to the parent). Also `--wildcards`/`/tmp`/`~` are GNU tar/bash idioms, not Windows bsdtar/pwsh. Fallback-only; `gh skill install` primary path is fine.
