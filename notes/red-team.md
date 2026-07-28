# Chimeway Brand Book — Milestone-Close Red-Team Pass

**Date:** 2026-07-28
**Requirement:** NOTES-03 (red-team pass closing with `git diff --stat` scope audit + repo-size/binary check)
**Phase:** 86 — accessibility-audit-notes-red-team-close (Plan 04, runs LAST)
**Disposition:** the scope boundary is **machine-enforced** by a re-runnable guard, **not** asserted in prose.

This is the skeptic pass over the v1.15 **Brand Identity & Brand Book** milestone. It exists to
close one specific footgun: **a pasted `git diff` asserts the scope boundary without enforcing
it.** If the record simply quoted a diff, a future stray edit outside `brandbook/` + the two
allowed integration files would land unnoticed — the diff would be stale and no gate would catch
it. So the boundary lives in a guard (`scripts/brandbook-guards.sh --scope`) that walks
`git status` on every invocation and fails on any out-of-allowlist path. This record closes with
that guard's captured output plus the repo-size/binary budget result — both re-runnable.

## Sources

- `scripts/brandbook-guards.sh` — the `--scope` git-diff/porcelain allowlist walk (D-03). The
  allowlist is the single source of truth for the milestone boundary; widened in Plan 86-04.
- `scripts/logo-guards.sh` — the `--assets` mode carries the repo-size/binary budget block
  (exactly 3 committed rasters, ≤200KB ceiling) reused verbatim for the NOTES-03 audit.
- `.planning/phases/86-accessibility-audit-notes-red-team-close/86-CONTEXT.md` — D-03/D-04 (what
  the boundary is and what the record must close with).
- `notes/decision-log.md` — established notes voice (sourced claim → disposition → proof line)
  and the TOKEN-01 zero-drift invariant (why tokens must never be patched).

## The boundary the milestone claims

Every change this milestone made is confined to **exactly** these paths, and nothing else:

| Path | Why it is in scope |
|------|--------------------|
| `brandbook/**` | the self-contained brand-book package (tokens, HTML book, CSS, logo/favicon/social assets) — all phases |
| `README.md` | Phase 85 **D-01** header lockup integration edit (the one allowed README touch) |
| `mix.exs` | Phase 85 **D-02** ExDoc `:logo`/`:favicon` integration edit (the one allowed `mix.exs` touch) |
| `notes/**` | the milestone record set: `logo-options.md`, `accessibility-checks.md`, `research.md`, `decision-log.md`, and this `red-team.md` |
| `scripts/brandbook-guards.sh` | this guard (the Phase-84 acceptance gate + `--scope` boundary) |
| `scripts/logo-guards.sh` | the sibling Phase-82/83 guard + the NOTES-03 binary budget |
| `scripts/render-svg-png.sh` | the Phase-83 raster render helper |
| `scripts/contrast-audit.sh` | the Phase-86-01 offline WCAG contrast calc |
| `.planning/**` | GSD bookkeeping, out of phase scope but tolerated |

The allowlist carries **no** broad glob — no bare `scripts/*`, no top-level `*`. An over-broad
allowlist would silently defeat the very audit it claims to run. Any path outside this list hits
the deny-by-default `*)` branch and **fails** the scope check. (Verified this pass: a scratch
`STRAY-SCRATCH.tmp` at repo root makes `--scope` exit non-zero.)

## Skeptic challenges and their machine answers

| Sourced claim (skeptic) | Disposition | Proof line (re-runnable) |
|-------------------------|-------------|--------------------------|
| "The scope diff is just pasted — a later stray edit won't be caught." | **Closed.** | `scripts/brandbook-guards.sh --scope` re-walks `git status` on every run; out-of-allowlist paths fail. |
| "The allowlist could be widened to a blanket `scripts/*` and hide smuggled files." | **Closed.** | Allowlist enumerates 4 explicit script paths + `brandbook/**` + `notes/**` + 2 named integration files; no glob. Deny-by-default `*)` retained. |
| "A new binary/raster could slip in over budget." | **Closed.** | `scripts/logo-guards.sh --assets` asserts exactly 3 committed rasters, total ≤204800B. |
| "The audit might have quietly patched a token to fix a contrast miss." | **Closed.** | `git diff --quiet -- brandbook/tokens/tokens.css` (TOKEN-01 zero-drift); sub-threshold pairings are DOCUMENTED WCAG exemptions, never patched. |

## Accepted-risk gap carried forward (recorded honestly, NOT a pass)

The red-team does **not** overstate the milestone as fully manually verified. Two genuinely-manual
accessibility checks were **WAIVED by the project owner on 2026-07-28** (risk accepted, manual
verification not performed) and are recorded as documented known gaps in
`notes/accessibility-checks.md` §6.1/§6.2 — **NOT** as a PASS:

- **A11Y-04** (never-color-alone / CVD emulation across protan/deuter/tritan/achromat) — residual
  risk lowered by the grep-backed never-color-alone architecture (every status = surface + text +
  label + icon), but the human CVD-emulation pass was **not run**.
- **A11Y-03** (focus-not-obscured, SC 2.4.11, keyboard-tab pass) — residual risk lowered by
  RESEARCH A3 (low risk) and the rendered-CSS focus evidence, but the human keyboard-tab pass was
  **not run**.

Both requirements are therefore **partially satisfied only**. Phase 86 verification / the milestone
audit should treat them as accepted-risk known gaps, not a green. This red-team scope+binary close
covers NOTES-03; it does not substitute for the waived manual A11Y attestation.

## Captured proof (verbatim command output)

### (a) `scripts/brandbook-guards.sh --scope` — scope audit + `git diff --stat` + PASS

```
== scope-boundary check (git) ==
PASS  scope: working tree carries only the allowed phase paths
== scope OK ==
```

Captured with this `notes/red-team.md` present as an untracked file — the porcelain walk sees it,
matches it against the `notes/*` allowlist entry, and permits it (the new record file is itself
in-scope). The guard's leading `git diff --stat` line emitted no rows here because there are no
out-of-scope **tracked** modifications pending: the milestone's `brandbook/**` + `README.md` +
`mix.exs` integration edits and the Plan 86-04 guard widening are already committed. A stray path
outside the allowlist (verified this pass with a scratch `STRAY-SCRATCH.tmp`) flips the walk to
`== scope FAILED ==` with exit 1. The boundary is enforced by the walk, not by the diff snapshot.

### (b) `scripts/logo-guards.sh --assets` — repo-size / binary budget (NOTES-03)

```
PASS  raster: favicon.ico carries the 16/32/48 sizes
PASS  raster: apple-touch-icon.png is 180x180
PASS  raster: chimeway-og.png is 1200x630
PASS  binary-budget: 3 rasters, 38579B <= 204800B ceiling
== ASSET GATE PASSED ==
```

**Binary-budget result:** exactly **3** committed rasters — `favicon.ico` (15,086B) +
`apple-touch-icon.png` (2,004B) + `chimeway-og.png` (21,489B) = **38,579B** ≤ **204,800B** (200KB)
ceiling — **PASS**. No new binary was added by this milestone.

## Close

NOTES-03 is satisfied: the `brandbook/`-only scope boundary is **machine-enforced** by the widened
`scripts/brandbook-guards.sh --scope` allowlist (re-runnable, deny-by-default), and this record
closes with the captured `git diff --stat` scope audit and the `logo-guards.sh --assets`
binary-budget result. No token was patched (`brandbook/tokens/tokens.css` zero-drift held); no new
binary was committed. The one honest caveat is the owner-waived manual A11Y-03/A11Y-04 attestation,
recorded above as an accepted-risk gap rather than a pass.
