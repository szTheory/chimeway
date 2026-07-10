---
phase: 81
slug: design-tokens-reconciliation-documentation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-09
---

# Phase 81 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `81-RESEARCH.md` → `## Validation Architecture`. This is a doc/asset phase
> (static CSS/JSON/Markdown, no runtime, no CI) — validation is deterministic shell +
> parser checks, all runnable locally in <5s.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — no test framework installed or warranted (doc/asset phase, no runtime) |
| **Config file** | none |
| **Quick run command** | `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` (zero-drift hard gate) |
| **Full suite command** | run the Per-Task Verification Map top-to-bottom (git-diff + `node -e JSON.parse` + hex-equality greps) |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run the parse + hex-equality quick check for whatever file the task touched.
- **After every plan wave:** Run the full Per-Task Verification Map.
- **Before `/gsd-verify-work`:** Full map green; `git diff --exit-code` zero-drift check is the hard gate.
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

*Plan/wave/task IDs finalized by the planner; this map lifts the RESEARCH `Phase Requirements → Validation Map` rows.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TOKEN-04 (zero-drift) | — | N/A | git | `git diff --exit-code chimeway_admin/priv/static/chimeway_admin.css` (exit 0) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-01 | — | N/A | hex-equality | extract `--cw-{ink..code}` from `tokens.css` + shipped, lowercase, compare (all 15 equal) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-01/03 | — | N/A | value-equality | grep each verbatim semantic/non-color token from both files; compare (all equal) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-02 | — | N/A | json-parse | `node -e "JSON.parse(require('fs').readFileSync('brandbook/tokens/tokens.json','utf8'))"` (exit 0) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-02/D-10 | — | N/A | alias-resolution | walk JSON; every `{a.b.c}` `$value` resolves to a real path (zero unresolved) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-02/DTCG | — | N/A | dtcg-shape-lint | every `$type:dimension`/`duration` `$value` is `{value,unit}` object (zero bare strings) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-05 | — | N/A | resolution + grep | `:root`(light) + `[data-theme=dark/light]` + `@media(prefers-color-scheme:dark)` present; zero `filter: invert(` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-05 | — | N/A | contrast/hex-equality | net-new dark values ≥4.5:1 text / ≥3:1 large+UI; verbatim values asserted hex-equal to shipped | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | TOKEN-04 | — | N/A | doc-presence | `notes/decision-log.md` has DOCUMENTED/DEFERRED entry for DIV-1..DIV-7, each with `git diff` invariant | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | D-06 | — | N/A | grep | `--cw-info` = `var(--cw-blue)` (CSS) / `{color.primitive.blue}` (JSON), no hex literal | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `brandbook/tokens/` directory — greenfield, must be created.
- [ ] `notes/` directory — greenfield, must be created.
- [ ] No framework install needed — validation is git + `node`/`jq` one-liners, both present.

*Environment: `git`, `node` (JSON.parse), optional `jq` all available; no build tooling required or permitted.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Net-new dark color meets WCAG 2.2 | TOKEN-05 | Contrast math on any genuinely net-new dark value (research finds this set ~empty; final rendered audit is Phase 86) | Compute ratio for the pairing; assert ≥4.5:1 text / ≥3:1 large+UI. Verbatim-copied values are asserted hex-equal to shipped instead of re-computed. |

---

## Validation Sign-Off

- [ ] All tasks have an automated verify command or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the two greenfield directory MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
