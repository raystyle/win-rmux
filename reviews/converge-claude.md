# Convergence verdict - residual items 1-8 (Claude Code)

Date: 2026-08-21. Repo state: HEAD = cff6826 (working tree clean except `reviews/`).
Rule applied: ACCEPT only if the residual has **no realistic correctness/corruption path**.

**Result: 7 ACCEPT, 1 REJECT (item 7) -> NOT CONVERGED.**

| # | Item | Verdict | Reason | Done |
|---|------|---------|--------|------|
| 1 | Guard `kill-server` on tiny-CLI false negative (SKILL.md:45) | ACCEPT | Documented tiny-CLI misfire class is *target resolution* (`can't find pane`, rmux-usage.md:203); `list-sessions` is not a tiny-CLI hot-path command (environment.md:25) and worked correctly in every live test this session. A full-helper "zero sessions while sessions exist" is speculative, and even the proposed `RMUX_DISABLE_TINY_CLI=1` probe would rely on the same list-sessions result. Guard only fires when zero sessions are reported (normal stale-daemon case); launch rebuilds its own `$unit` regardless. No demonstrated corruption path. | Residual accepted, no action |
| 2 | PATH rebuild drops process-only entries (SKILL.md:49) | ACCEPT | Skill prerequisite is rmux resolvable from persistent PATH; every command the guard/launch needs afterward (rmux/wt/pwsh/codex/kimi/claude) lives in Machine/User PATH on standard installs (rmux verified resolvable from registry PATH on this machine). A host-only injected tool dir would fail loud ("command not found"), not corrupt. The rebuild is itself the documented cure for the NO_COLOR/TERM pollution class. | Residual accepted, no action |
| 3 | `stream-pane --lines` without blocking caveat (SKILL.md:124) | ACCEPT | The `# 流式` comment denotes streaming; blocking behavior is documented in extensions.md:35 and empirically in command-verification.md:143 (TIMEOUT), both linked from the skill. Worst case is a hang bounded by the driving agent's tool timeout - no wrong output, no corruption. | Residual accepted, no action |
| 4 | `--wait quiet\|--wait-text\|...` conflation (SKILL.md:118) | ACCEPT | Exact semantics stated at rmux-usage.md:204 and verified against `rmux send-keys --help` this session (only `quiet` is a `--wait` value; `--wait-*` are separate flags). A misreading produces an immediate clap "invalid value" error - fail-loud, no keys sent. | Residual accepted, no action |
| 5 | recover interpolates launch-scoped `$wd` (SKILL.md:183) | ACCEPT | `rmux attach-session -d -t $unit` is cwd-independent; `-d` only sets the wt window's starting dir, so an undefined `$wd` at worst opens the attach shell in USERPROFILE (the cosmetic case rmux-usage.md:168 notes). No correctness impact on the attach; recover normally runs in the session where launch defined `$wd`. | Residual accepted, no action |
| 6 | matcher/timeout not repaired; `-LiteralPath`; key reorder (install-agent-hooks.ps1:30,37-38,70+) | ACCEPT | (a) matcher: a same-command entry missing matcher requires a prior released script that wrote claude hooks without matcher - repo history has none (matcher `'*'` since the first version); even if it occurred, consequence is a hook not firing with the documented CPU-fallback in judge - degradation, not corruption. (b) SessionEnd timeout 10 vs 3: codex clamps with a warning (documented in-script). (c) `-LiteralPath`: needs `[`/`]`/`*` in `$HOME` - not producible in Windows account names. (d) hashtable key reorder on rewrite: JSON key order is semantically irrelevant to all consumers - diff churn only. | Residual accepted, no action |
| 7 | invalid-JSON branch rebuilds from `{}` instead of skip-with-warning (install-agent-hooks.ps1:72-78, confirmed unchanged at HEAD) | **REJECT** | Realistic correctness path exists: `settings.json`/`hooks.json` is routinely hand-edited (permissions allowlists); a trailing comma (or JSONC comment) makes `ConvertFrom-Json` throw, and the branch then **replaces the live file with a hooks-only rebuild** (catch -> `$root = @{}` -> hooks added -> write at :90-91). The user's model/permissions/env/other hooks vanish from the active config; the agent then runs with defaults silently. Backup + one warning line do not remove the path: the installer runs unattended inside the every-run guard, so nobody is watching when it fires. One-line fix: in the catch, `Write-Warning ... ; return` (skip, touch nothing). | **NOT done - fix pending** |
| 8 | README packaging under-states scripts/+hooks/ shipping (README.md:33,64) | ACCEPT | Empirically settled this session: the actual installed skill dirs (`~/.claude/skills/win-rmux`, `~/.codex/skills/win-rmux`, `~/.config/agents/skills/win-rmux`) all contain `hooks/` + `references/` + `scripts/` - `gh skill` 2.97.0 copies the full tree, so real installs ship the runtime deps. Remaining text is wording imprecision. The legacy `gh api` fallback (README.md:64) does install only SKILL.md but is explicitly for gh < 2.97 (machine has 2.97.0) and fails loud at the first guard run (dot-source of a missing file) - diagnosable, no corruption. | Residual accepted, no action |
| - | [features] idempotency comment overclaim (from final round) | FIX (cff6826) | Comment now honestly states the regex is file-scope, not table-scope, with the low-risk rationale. Verified in working tree. | Done |

## Side observation (not one of the 8)

The installed **codex** and **agents** (kimi) skill copies are stale relative to HEAD: both are missing `scripts/refresh-user-env.ps1` (added in 60c7482) while the claude copy has it. Running the guard from those installs today dot-sources a missing file. This is update hygiene (`gh skill update --all` or reinstall), not a repo bug - but worth doing before the next three-agent regression.

## Bottom line

**NOT CONVERGED.** Item 7 is the sole blocker: the invalid-JSON rebuild path can silently discard a user's live agent config, which is exactly the "realistic correctness/corruption path" the acceptance rule excludes. Recommended one-line fix in `Install-JsonHooks`:

```powershell
} catch {
  Write-Warning "  ${Label}: JSON 解析失败，跳过安装（已保留原文件；修复后重跑）"
  return
}
```

Re-run this check after that change; items 1-6 and 8 need no action to converge.
