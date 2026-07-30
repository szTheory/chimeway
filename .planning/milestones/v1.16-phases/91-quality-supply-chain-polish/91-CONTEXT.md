# Phase 91: Quality & Supply-Chain Polish - Context

**Gathered:** 2026-07-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the remaining small-but-compounding toolchain-truth and supply-chain gaps in the
CI/release configuration: one source of truth for toolchain versions (QUAL-01), automated
dependency-update PRs (QUAL-02), least-privilege workflow permissions (QUAL-03), an advisory
vulnerability scan (QUAL-04), and a reconciled CI-vs-release Elixir version (QUAL-05).

**Scope anchor:** config-only. Touches `.github/workflows/ci.yml`, `.github/workflows/release.yml`,
`mix.exs` aliases/deps, and new files `.tool-versions` + `.github/dependabot.yml`. No product/library
code changes. Every verify lane must actually gate — no silent/advisory-only legs where a real gate
is intended (QUAL-05).
</domain>

<decisions>
## Implementation Decisions

### QUAL-01 — Toolchain source of truth
- **D-01:** Create `.tool-versions` as the single canonical toolchain source, declaring the current
  canonical versions (`erlang 27` + `elixir 1.19-otp-27`). Use loose lines that resolve to today's
  behavior — do NOT tighten to a new patch that would silently shift the tested version.
- **D-02:** Convert every single-pinned `setup-beam` block (build-test-lint, verify_gates, dev,
  verify_example, verify_runtime_prefix, and the other ~10 jobs currently carrying inline
  `elixir-version:"1.19"` / `otp-version:"27"`) to `version-file: .tool-versions`.
- **D-03:** The OTP `{26,27}` matrix leg (`test`) and the `1.17` floor leg (`test_floor_1_17`) KEEP
  explicit `elixir-version`/`otp-version` pins. They deliberately exercise non-canonical versions;
  this is not the duplication QUAL-01 eliminates.
- **D-04:** Cache keys stay as-is — they already derive from `steps.beam.outputs.elixir-version` /
  `steps.beam.outputs.otp-version` (resolved), so they auto-follow `.tool-versions` with no edit.

### QUAL-02 — Dependabot
- **D-05:** Add `.github/dependabot.yml` covering two ecosystems: `mix` (directory `/`) and
  `github-actions` (directory `/`, i.e. `.github/workflows`).
- **D-06:** Weekly schedule; group minor/patch updates per ecosystem to hold down PR noise. Actions
  are SHA-pinned today; dependabot updates the pinned SHA in place (with the human-readable tag in
  the PR).

### QUAL-03 — Least-privilege permissions
- **D-07:** Declare top-level `permissions: contents: read` in `ci.yml`.
- **D-08:** Jobs that run `scripts/ci/obs-summary.sh` (which calls `gh api` for CI-run timing)
  escalate with a job-level `permissions: { contents: read, actions: read }`. All other jobs inherit
  the read-only top-level default with no escalation.
- **D-09:** No job needs write scopes — verified: `ci.yml` has zero `GITHUB_TOKEN` write usage (no PR
  comments, no artifact uploads, no status/check writes). The only token consumer is the advisory
  `gh api` timing query, which already degrades gracefully if denied.

### QUAL-04 — mix_audit advisory scan
- **D-10:** Add `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` to `mix.exs` deps.
- **D-11:** Extend the `ci.audit` alias from `["hex.audit"]` to `["hex.audit", "deps.audit"]`.
  hex.audit (retired-package check) and deps.audit (mix_audit's CVE-advisory-DB scan) are
  complementary — keep both.
- **D-12:** Preserve the existing advisory-only posture: the CI "Dependency advisory audit" step
  keeps `continue-on-error: true`. Findings surface in job output; the scan never blocks the gate,
  matching the deliberate hex.audit stance documented at `ci.yml:91-95` and SECURITY.md.

### QUAL-05 — CI↔release Elixir skew
- **D-13:** `release.yml` stays pinned at Elixir 1.17 / OTP 27 (`release.yml:259-260`). No change.
- **D-14:** Broaden the existing `test_floor_1_17` leg from nightly-only
  (`if: needs.resolve_tiers.outputs.run_nightly == 'true'`) to run on **push + nightly** (i.e. all
  non-`pull_request` events), keeping it OFF for PRs so the PR tier stays fast. Prefer a dedicated
  `resolve_tiers` output (e.g. `run_floor`) over an inline event check, mirroring the existing
  `otp_matrix` / `run_nightly` flag pattern.
- **D-15:** The floor leg must actually GATE on push, not run silently. Wire `TEST_FLOOR_1_17` into
  the push gate (`ci-gate`, via `aggregate-gate.sh`) so a floor failure blocks push CI, with the
  PR-skip treated as a pass by the aggregate. This closes the skew (release's 1.17 pin is now
  exercised AND enforced on push) and guards against the vacuous-pass footgun. It remains a `needs:`
  of `nightly-gate` as today.

### Claude's Discretion
- Exact `.tool-versions` line syntax accepted by `erlef/setup-beam@8251…`'s `version-file`
  (`erlang 27` + `elixir 1.19-otp-27` vs. fuller strings) — planner picks the form that reproduces
  today's resolved versions.
- Dependabot cosmetics (open-PR limit, commit-message prefix, labels, grouping granularity).
- `mix_audit` version bound if `~> 2.1` is stale at plan time — pick the current stable minor.
- Whether QUAL-05 uses a new `run_floor` output vs. a reused non-PR condition — implementation-local.

### Folded Todos
None — `todo.match-phase 91` returned zero matches.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.github/workflows/ci.yml` — all lanes; setup-beam blocks, cache keys, `resolve_tiers`
  (lines 37-61), advisory audit step (86-97), `test_floor_1_17` (1116-1160), `ci-gate` (1161-1183),
  `nightly-gate` (1191-1204).
- `.github/workflows/release.yml` — Elixir/OTP pin (lines 259-260).
- `mix.exs` — `ci.audit` alias (line 83), deps list, `elixir: "~> 1.17"` (line 10).
- `scripts/ci/aggregate-gate.sh` — pass/fail contract for gate aggregation (skipped-as-pass semantics).
- `scripts/ci/obs-summary.sh` — `gh api` timing query (line ~110) that motivates the QUAL-03
  `actions: read` escalation.
- `.planning/ROADMAP.md` — Phase 91 success criteria (the 5 TRUE-conditions).
- `.planning/REQUIREMENTS.md` — QUAL-01..QUAL-05 (lines 41-45).
- `.planning/METHODOLOGY.md` — decisive-recommendation + escalation-gate lenses applied here.
- Phase 90 context (`.planning/phases/89-.../` predecessors and ROADMAP Phase 90 notes) — the
  `resolve_tiers` / `fromJSON` OTP-matrix tier architecture QUAL-05 builds on.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `resolve_tiers` job already computes per-event flags (`otp_matrix`, `run_nightly`) via a bash step
  writing `$GITHUB_OUTPUT` (ci.yml:45-61) — the natural home for a QUAL-05 `run_floor` flag.
- `scripts/ci/aggregate-gate.sh` already implements the gate aggregation contract used by both
  `ci-gate` and `nightly-gate` — QUAL-05 extends its arg list, no new script needed.
- Cache keys already reference `steps.beam.outputs.*`, so QUAL-01's version-file switch requires no
  cache-key edits.
- Advisory-audit step already carries the exact advisory-only posture QUAL-04 must match
  (`continue-on-error: true` + explanatory comment).

### Established Patterns
- Phase 90 tier model: PR = single `{27}` fast tier; push/nightly = `{26,27}`; nightly adds
  cold-build + `verify_admin` + 1.17 floor via a separate `nightly-gate`. QUAL-05 must respect this
  split — floor moves into the push tier without polluting the fast PR tier.
- Actions are SHA-pinned with a trailing human tag comment — dependabot must update the SHA.
- All lanes share uniform Postgres creds via top-level `env:` (ci.yml:31-34).

### Integration Points
- `.tool-versions` (new) ← read by `setup-beam version-file:` in the single-pinned jobs.
- `.github/dependabot.yml` (new) ← GitHub-native, no workflow wiring.
- `permissions:` top-level block (new) in `ci.yml` ← inherited by all jobs; obs-summary jobs override.
- `mix_audit` dep ← surfaced through `mix deps.audit` inside the `ci.audit` alias, run by the
  existing advisory step.
- `TEST_FLOOR_1_17` result ← consumed by `aggregate-gate.sh` in `ci-gate` (new) and `nightly-gate`
  (existing).
</code_context>

<specifics>
## Specific Ideas

- QUAL-05 gate wiring was an explicit decision point: chose to GATE the floor on push (not run it
  advisory-only), because "closing the skew" requires the release's 1.17 pin to be enforced, and a
  non-gating leg would reproduce the vacuous-pass footgun flagged in project memory.
- QUAL-04 keeps BOTH hex.audit and deps.audit rather than replacing — they cover different threat
  classes (retired packages vs. disclosed CVEs).
</specifics>

<deferred>
## Deferred Ideas

- Making the advisory audit blocking (removing `continue-on-error`) — deliberately out of scope;
  QUAL-04 mandates advisory-only parity with hex.audit. Revisit only if/when SECURITY.md accepted-risk
  posture changes.
- Broader permission hardening beyond `ci.yml` (e.g. release.yml / publish-hex.yml least-privilege) —
  QUAL-03 is scoped to `ci.yml`; other workflows are a possible future supply-chain phase.

### Reviewed Todos (not folded)
None — no pending todos matched Phase 91.
</deferred>
