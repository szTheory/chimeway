# Phase 91: Quality & Supply-Chain Polish - Research

**Researched:** 2026-07-30
**Domain:** GitHub Actions CI/release config, asdf/setup-beam toolchain resolution, Dependabot v2, Hex supply-chain audit
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**QUAL-01 — Toolchain source of truth**
- **D-01:** Create `.tool-versions` as the single canonical toolchain source, declaring the current canonical versions (`erlang 27` + `elixir 1.19-otp-27`). Use loose lines that resolve to today's behavior — do NOT tighten to a new patch that would silently shift the tested version.
- **D-02:** Convert every single-pinned `setup-beam` block (build-test-lint, verify_gates, dev, verify_example, verify_runtime_prefix, and the other ~10 jobs currently carrying inline `elixir-version:"1.19"` / `otp-version:"27"`) to `version-file: .tool-versions`.
- **D-03:** The OTP `{26,27}` matrix leg (`test`) and the `1.17` floor leg (`test_floor_1_17`) KEEP explicit `elixir-version`/`otp-version` pins. They deliberately exercise non-canonical versions; this is not the duplication QUAL-01 eliminates.
- **D-04:** Cache keys stay as-is — they already derive from `steps.beam.outputs.elixir-version` / `steps.beam.outputs.otp-version` (resolved), so they auto-follow `.tool-versions` with no edit.

**QUAL-02 — Dependabot**
- **D-05:** Add `.github/dependabot.yml` covering two ecosystems: `mix` (directory `/`) and `github-actions` (directory `/`).
- **D-06:** Weekly schedule; group minor/patch updates per ecosystem to hold down PR noise. Actions are SHA-pinned today; dependabot updates the pinned SHA in place (with the human-readable tag in the PR).

**QUAL-03 — Least-privilege permissions**
- **D-07:** Declare top-level `permissions: contents: read` in `ci.yml`.
- **D-08:** Jobs that run `scripts/ci/obs-summary.sh` (which calls `gh api` for CI-run timing) escalate with a job-level `permissions: { contents: read, actions: read }`. All other jobs inherit the read-only top-level default with no escalation.
- **D-09:** No job needs write scopes — verified: `ci.yml` has zero `GITHUB_TOKEN` write usage.

**QUAL-04 — mix_audit advisory scan**
- **D-10:** Add `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}` to `mix.exs` deps.
- **D-11:** Extend the `ci.audit` alias from `["hex.audit"]` to `["hex.audit", "deps.audit"]`.
- **D-12:** Preserve the existing advisory-only posture: the CI "Dependency advisory audit" step keeps `continue-on-error: true`.

**QUAL-05 — CI↔release Elixir skew**
- **D-13:** `release.yml` stays pinned at Elixir 1.17 / OTP 27. No change.
- **D-14:** Broaden the existing `test_floor_1_17` leg from nightly-only to run on **push + nightly** (all non-`pull_request` events), keeping it OFF for PRs. Prefer a dedicated `resolve_tiers` output (e.g. `run_floor`) over an inline event check.
- **D-15:** The floor leg must actually GATE on push. Wire `TEST_FLOOR_1_17` into the push gate (`ci-gate`, via `aggregate-gate.sh`) so a floor failure blocks push CI, with the PR-skip treated as a pass by the aggregate. It remains a `needs:` of `nightly-gate` as today.

### Claude's Discretion
- Exact `.tool-versions` line syntax accepted by `erlef/setup-beam@8251…`'s `version-file` — planner picks the form that reproduces today's resolved versions. **← This research resolves it decisively (see Pitfall 1).**
- Dependabot cosmetics (open-PR limit, commit-message prefix, labels, grouping granularity).
- `mix_audit` version bound if `~> 2.1` is stale at plan time — pick the current stable minor.
- Whether QUAL-05 uses a new `run_floor` output vs. a reused non-PR condition — implementation-local.

### Deferred Ideas (OUT OF SCOPE)
- Making the advisory audit blocking (removing `continue-on-error`).
- Broader permission hardening beyond `ci.yml` (release.yml / publish-hex.yml least-privilege).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUAL-01 | `.tool-versions` is the single toolchain source feeding `setup-beam` (`version-file:`) and cache keys | Exact strict-mode syntax resolved: `erlang 27.3.4` + `elixir 1.19.5-otp-27` (Pitfall 1 + Code Example 1). 14 inline `1.19` blocks to convert; 2 legs (matrix `test`, `test_floor_1_17`) keep pins. |
| QUAL-02 | `.github/dependabot.yml` covers `mix` and `github-actions` | Verified v2 schema, `groups`/`update-types`, `directory: "/"` for both (Code Example 2). |
| QUAL-03 | `ci.yml` declares top-level `permissions: contents: read` (jobs escalate only where needed) | Exactly 15 build/verify jobs run obs-summary → need `actions: read`; gate/resolve/floor jobs inherit read-only. Zero write usage confirmed (Code Example 3). |
| QUAL-04 | `mix_audit` runs advisory-only as a real advisory-DB scan | `mix_audit 2.1.5` current (`~> 2.1` resolves it); provides `mix deps.audit`; `only: [:dev,:test], runtime: false` correct (Code Example 4). |
| QUAL-05 | CI↔release Elixir skew resolved: release stays 1.17; a 1.17 CI leg runs on push/nightly and gates | Full wiring recipe: `run_floor` output + broadened `if:` + add to `ci-gate` aggregate; structural skipped-as-pass (Code Example 5). |
</phase_requirements>

## Summary

This is a config-only phase touching `ci.yml`, `release.yml`, `mix.exs`, and two new files (`.tool-versions`, `.github/dependabot.yml`). Four of the five requirements are low-risk once the exact external syntax is nailed; the fifth (QUAL-01) carries a **non-obvious correctness trap that will hard-fail CI if implemented from the CONTEXT.md example syntax verbatim.**

**The top finding:** `erlef/setup-beam`'s `version-file:` input **forces `version-type: strict`** (the action errors out otherwise), and strict resolution is an **exact-key map lookup** — it does NOT do the "latest matching patch" resolution that today's loose inline `elixir-version: "1.19"` / `otp-version: "27"` inputs perform. Therefore loose partial lines (`erlang 27`, `elixir 1.19-otp-27`) will NOT resolve under `version-file` and CI fails with `Requested strict … version not found`. The `.tool-versions` file **must carry the fully-pinned patch versions** that today's loose inputs resolve to. As of this research those are **`elixir 1.19.5-otp-27`** and **`erlang 27.3.4`** (verified against a green `main` run 30512806893, 2026-07-30). This satisfies D-01's *intent* ("reproduce today's resolved versions, don't silently shift") — the exact syntax was explicitly Claude's Discretion, so this is a resolution, not a conflict.

The QUAL-05 gate wiring has a second subtle correctness point: `aggregate-gate.sh` treats *any* non-`success` result (including `skipped`) as a failure. The "PR-skip treated as a pass" requirement (D-15) must be achieved **structurally** — by making the floor leg's run condition identical to `ci-gate`'s run condition — **not** by weakening `aggregate-gate.sh` to treat `skipped` as pass (which would silently defang every other required lane).

**Primary recommendation:** Pin exact patch versions in `.tool-versions` (`elixir 1.19.5-otp-27`, `erlang 27.3.4`) captured from the latest green `main` run at plan time; convert the 14 loose inline setup-beam blocks to `version-file: .tool-versions` while leaving the matrix and floor legs pinned; add `run_floor` to `resolve_tiers` mirroring `run_nightly`, broaden the floor `if:`, and append `TEST_FLOOR_1_17` to the `ci-gate` aggregate arg list only (never to `pr-gate`, never to `aggregate-gate.sh` skipped-semantics).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Toolchain version resolution (QUAL-01) | CI runner (`setup-beam` action) | Repo root (`.tool-versions`) | The action reads the file at job start; `.tool-versions` is the single source of truth consumed identically by all jobs. |
| Dependency-update automation (QUAL-02) | GitHub platform (Dependabot service) | Repo (`.github/dependabot.yml`) | Dependabot is GitHub-native; no workflow wiring — config-only. |
| Token least-privilege (QUAL-03) | GitHub Actions permission model | Per-job `permissions:` blocks | `GITHUB_TOKEN` scope is set declaratively in the workflow; top-level default + per-job escalation. |
| Supply-chain vuln scan (QUAL-04) | Build tool (`mix` / mix_audit) | CI advisory step | `mix deps.audit` runs inside `mix ci.audit`; advisory-only via `continue-on-error`. |
| Version-skew enforcement (QUAL-05) | CI orchestration (`resolve_tiers` + gate jobs) | `aggregate-gate.sh` | Tier flags + gate aggregation are the existing CI orchestration layer; QUAL-05 extends flags + one gate arg list. |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `erlef/setup-beam` | `@8251c48…` (pinned, current) | Installs Erlang/OTP + Elixir; resolves versions | Canonical BEAM CI action; already used in every lane. |
| Dependabot | `version: 2` schema | Automated dependency-update PRs (mix + actions) | GitHub-native, zero-infra supply-chain hygiene. |
| `mix_audit` | `2.1.5` (`~> 2.1`) | Scans `mix.lock` against the Elixir security advisory DB | The de-facto Hex CVE scanner (mirego/mix_audit); complements `hex.audit`. |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mix hex.audit` (built-in) | Hex core | Flags retired packages | Already in `ci.audit`; kept alongside `deps.audit` (D-11). |
| `actionlint` (optional) | latest | Static-validates workflow YAML | Local pre-flight for the `ci.yml` edits (validation, not a dep). |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.tool-versions` (asdf format) | `mise.toml` (`version-file` also parses `*.toml`) | asdf `.tool-versions` is the ecosystem default and what D-01 specifies; no reason to introduce mise. |
| `mix_audit` | `sobelow` | Sobelow is Phoenix-focused static analysis, not a CVE/advisory scanner; wrong tool for QUAL-04. |
| Dependabot | Renovate | Renovate is more configurable but adds an app dependency; Dependabot is native and matches D-05. |

**Installation:**
```bash
# mix.exs deps (D-10) — no CLI install; mix resolves on next deps.get
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
```

**Version verification (performed this session):**
- `mix_audit` latest stable = **2.1.5** (published 2025-06-09; hex.pm/api/packages/mix_audit). `~> 2.1` resolves to 2.1.5 — D-10's bound is current, no bump needed.
- Latest Elixir 1.19.x built for OTP 27 = **1.19.5** (builds.hex.pm, published 2026-01-09). Today's loose `1.19` resolves here.
- Today's resolved OTP = **27.3.4** (green run 30512806893, 2026-07-30).

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `mix_audit` | Hex | ~6 yrs (owner `remi`) | Widely used (mirego) | github.com/mirego/mix_audit | OK | Approved |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

`mix_audit` is published by mirego (owner `remi@exomel…`), BSD-3-Clause, with a public source repo and a well-known `mix deps.audit` task — confirmed via hex.pm API this session. `[VERIFIED: hex.pm]`. No new `github-actions` packages are introduced (Dependabot updates existing SHA-pinned actions in place).

## Architecture Patterns

### System Data Flow (config-only)

```
                    .tool-versions  (NEW, repo root)
                    elixir 1.19.5-otp-27
                    erlang 27.3.4
                          │  read by version-file:
                          ▼
   ┌──────────────────────────────────────────────────────────┐
   │ ci.yml  (top-level: permissions: contents: read)          │
   │                                                            │
   │  resolve_tiers ──► outputs: otp_matrix, run_nightly,       │
   │                              run_floor (NEW)               │
   │        │                                                   │
   │        ├─► 14 build/verify jobs  (version-file:)           │
   │        │      each: permissions {contents:read,actions:read}│
   │        │      lint runs `mix ci.audit` (hex.audit+deps.audit│
   │        │            NEW, continue-on-error:true)           │
   │        │                                                   │
   │        ├─► test (matrix, KEEPS pins)                       │
   │        ├─► test_floor_1_17 (KEEPS pins;                    │
   │        │      if: run_floor=='true'  ← broadened)          │
   │        │                                                   │
   │        ├─► pr-gate     (PR only; floor NOT included)       │
   │        ├─► ci-gate     (non-PR; +TEST_FLOOR_1_17 NEW)      │
   │        └─► nightly-gate(nightly; TEST_FLOOR_1_17 as today) │
   └──────────────────────────────────────────────────────────┘

   .github/dependabot.yml (NEW) ──► GitHub Dependabot service
        ├─ ecosystem: mix (/)            → mix.exs/mix.lock update PRs
        └─ ecosystem: github-actions (/) → SHA-pin bump PRs

   release.yml  (UNCHANGED: elixir 1.17 / otp 27)  ← skew now exercised
                                                     by test_floor_1_17 on push
```

### Anti-Patterns to Avoid
- **Writing loose `.tool-versions` lines** (`erlang 27`, `elixir 1.19-otp-27`) — hard-fails under forced-strict `version-file`. See Pitfall 1.
- **Making `aggregate-gate.sh` treat `skipped` as pass** to satisfy the "PR-skip as pass" clause — silently weakens every required lane. Achieve it structurally instead. See Pitfall 2.
- **Adding the floor to `pr-gate`** — violates D-14 (floor OFF for PRs) and would fail every PR (floor is skipped on PR → aggregate fails).
- **Setting job-level `permissions:` without re-declaring `contents: read`** — job-level permissions *replace* (not merge with) the top-level block; omitting `contents: read` breaks `actions/checkout`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Version resolution from a file | A bash step that greps `.tool-versions` and feeds `elixir-version:` | `version-file: .tool-versions` (native) | The action already parses asdf format; hand-parsing reintroduces the duplication QUAL-01 removes. |
| CVE scanning of deps | Custom advisory-DB fetch | `mix_audit` (`mix deps.audit`) | Maintained advisory DB, correct `mix.lock` parsing. |
| Dependency-update PRs | Cron job that bumps `mix.lock` | Dependabot | Native grouping, changelog links, SHA-tag comments. |
| Gate aggregation | New per-lane `if:` failure checks | Extend `aggregate-gate.sh` arg list | Contract already exists and is locally runnable. |

**Key insight:** Every capability here has a native/existing mechanism; the phase's work is wiring exact syntax, not building logic.

## Common Pitfalls

### Pitfall 1: `version-file` forces strict resolution — loose partial versions hard-fail  ★ TOP RISK
**What goes wrong:** Writing `.tool-versions` as `erlang 27` / `elixir 1.19-otp-27` (the loose form) causes every converted job to fail at the setup-beam step with `Requested strict Elixir version (1.19-otp-27) not found in version list` (and likewise for Erlang).
**Why it happens:** setup-beam refuses `version-file` unless `version-type: strict` (`src/setup-beam.js:28-34`: *"you have to set version-type=strict if you're using version-file"*). Under strict, `getVersionFromSpec` does a **direct map lookup** `versions0[spec]` (`setup-beam.js:527-535`) against a map whose **keys are full patch versions** (`elixirVersions["1.19.5"]="1.19.5"`, built from `builds.txt` line `v1.19.5-otp-27`; `getElixirVersions` line 432/440). There is no key `"1.19"` or `"27"`, so the lookup returns `null` → the action throws. The loose inline inputs work today only because the *default* `version-type: loose` path uses `semver.maxSatisfying` for "latest matching patch."
**How to avoid:** Pin the exact patch versions that today's loose inputs resolve to. Capture them from the latest green `main` run's setup-beam log (`Using Elixir X.Y.Z (built for Erlang/OTP N)` and `Installed Erlang/OTP version` → `N.N.N`). As of 2026-07-30: `elixir 1.19.5-otp-27`, `erlang 27.3.4`. Do NOT add `version-type: loose` (the action rejects it with a file) and do NOT keep partial lines.
**Warning signs:** Any converted job red at "Setup BEAM" with a "not found in version list" message; a suggestion in the error to *"be using option 'version-type': 'strict'"* means the opposite branch was hit.

### Pitfall 2: `aggregate-gate.sh` treats `skipped` as failure — "PR-skip as pass" must be structural
**What goes wrong:** Naively adding `TEST_FLOOR_1_17` to a PR-reachable gate, or "fixing" the aggregate to treat `skipped` as pass, either fails every PR or silently defangs all lanes.
**Why it happens:** `aggregate-gate.sh:15-21` fails on *any* lane value `!= "success"`, explicitly including `skipped`. On PRs the floor leg is skipped by design (D-14).
**How to avoid:** Make the floor's run condition **identical** to `ci-gate`'s run condition. `ci-gate` runs `if: always() && github.event_name != 'pull_request'`; set `run_floor='true'` iff `event != 'pull_request'`. Then whenever `ci-gate` evaluates, the floor has actually run (never skipped) → `TEST_FLOOR_1_17` is `success`/`failure`, never `skipped`. Add the floor to `ci-gate` only; leave `pr-gate` and `aggregate-gate.sh` untouched.
**Warning signs:** A PR run where `ci-gate` unexpectedly executes; a push run where `ci-gate` fails citing `TEST_FLOOR_1_17: skipped`.

### Pitfall 3: Job-level `permissions:` replaces, not merges
**What goes wrong:** A job that sets `permissions: { actions: read }` loses `contents: read` and `actions/checkout` fails.
**Why it happens:** GitHub Actions job-level `permissions` fully overrides the top-level block.
**How to avoid:** obs-summary jobs must declare both: `permissions: { contents: read, actions: read }` (matches D-08 verbatim).

### Pitfall 4: Broadening the floor adds a lane to the push critical path
**What goes wrong:** Push CI now runs the 1.17 floor lane (deps.get + compile + ecto + `ci.test`) it previously skipped.
**Why it happens:** D-14 intentionally moves the floor into the push tier.
**How to avoid:** Accept it — it runs in parallel with existing lanes and gates via `ci-gate`; it is the intended cost of closing the skew. It stays OFF for PRs, so the fast PR tier is unaffected.

## Code Examples

### 1. `.tool-versions` (QUAL-01) — NEW file, repo root
```
# Source: erlef/setup-beam version-file requires strict, full-patch versions.
# Values reproduce today's loose 1.19 / 27 resolution (green run 30512806893, 2026-07-30).
# Re-capture from the latest green main run at plan time if a newer 1.19.x/27.x has landed.
erlang 27.3.4
elixir 1.19.5-otp-27
```
Converted setup-beam block (replaces the 14 inline `elixir-version:"1.19"`/`otp-version:"27"` pairs):
```yaml
      - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
        id: beam
        with:
          version-file: .tool-versions
          version-type: strict
```
> Note: `version-type: strict` is mandatory with `version-file` (the action errors without it). Cache keys need no edit — they already read `steps.beam.outputs.elixir-version`/`otp-version` (D-04). The matrix `test` job (`ci.yml:231-235`, uses `matrix.elixir`/`matrix.otp`) and `test_floor_1_17` (`ci.yml:1138-1142`, pinned 1.17/27) are NOT converted (D-03).

### 2. `.github/dependabot.yml` (QUAL-02) — NEW file
```yaml
# Source: docs.github.com dependabot-options-reference (version: 2 schema)
version: 2
updates:
  - package-ecosystem: "mix"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      mix-minor-patch:
        update-types: ["minor", "patch"]
  - package-ecosystem: "github-actions"
    directory: "/"           # scans .github/workflows + root action.yml
    schedule:
      interval: "weekly"
    groups:
      actions-minor-patch:
        update-types: ["minor", "patch"]
```
> `github-actions` ecosystem bumps SHA-pinned `uses:` refs in place, keeping the human-readable tag comment (D-06). `patterns` may be added for finer grouping (Claude's Discretion); `update-types` alone groups all minor/patch. `applies-to` defaults to `version-updates` and is not required here.

### 3. Permissions (QUAL-03) — `ci.yml`
Top-level (after `env:` block, before `jobs:`):
```yaml
permissions:
  contents: read
```
Add to the **15 jobs that run `scripts/ci/obs-summary.sh`** (job-level, replaces default):
```yaml
    permissions:
      contents: read
      actions: read
```
The 15 obs-summary jobs (verified via grep, `ci.yml`): `lint`, `verify_gates`, `verify_docs`, `test`, `verify_example`, `verify_runtime_prefix`, `verify_journeys`, `verify_mailglass`, `verify_accrue`, `verify_inbox`, `verify_threadline`, `verify_sigra`, `verify_admin`, `install_golden_contract`, `nightly_cold_build`.
Jobs that inherit read-only (NO escalation): `resolve_tiers`, `test_floor_1_17`, `pr-gate`, `ci-gate`, `nightly-gate`. Zero write usage confirmed (no `upload-artifact`, `gh pr`, POST, statuses, or checks anywhere in `ci.yml`) — D-09 verified.

### 4. mix_audit (QUAL-04) — `mix.exs`
```elixir
# deps() — add:
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}

# aliases() — extend ci.audit (currently ["hex.audit"], mix.exs:83):
"ci.audit": ["hex.audit", "deps.audit"],
```
The CI step (`ci.yml:96-98`, inside `lint`) is unchanged and keeps `continue-on-error: true` (D-12): `run: mix ci.audit`. `mix deps.audit` scans `mix.lock` against the advisory DB; retired-package checks stay in `hex.audit` (D-11).

### 5. QUAL-05 gate wiring — `ci.yml`
**(a) `resolve_tiers` — add `run_floor` output** (mirrors `run_nightly`, `ci.yml:37-60`):
```yaml
    outputs:
      run_nightly: ${{ steps.flags.outputs.run_nightly }}
      otp_matrix: ${{ steps.flags.outputs.otp_matrix }}
      run_floor: ${{ steps.flags.outputs.run_floor }}     # NEW
    steps:
      - id: flags
        shell: bash
        run: |
          set -euo pipefail
          # ... existing otp_matrix + run_nightly blocks unchanged ...
          if [ "${{ github.event_name }}" != "pull_request" ]; then   # NEW
            echo "run_floor=true"  >>"$GITHUB_OUTPUT"
          else
            echo "run_floor=false" >>"$GITHUB_OUTPUT"
          fi
```
**(b) `test_floor_1_17` — broaden the `if:`** (`ci.yml:1120`):
```yaml
    if: needs.resolve_tiers.outputs.run_floor == 'true'   # was run_nightly == 'true'
```
**(c) `ci-gate` — add the floor to needs/env/args** (`ci.yml:1164-1183`):
```yaml
    needs: [lint, test, verify_gates, verify_docs, verify_example, verify_runtime_prefix,
            verify_journeys, verify_mailglass, verify_accrue, verify_inbox,
            verify_threadline, verify_sigra, install_golden_contract, test_floor_1_17]  # +test_floor_1_17
    # ... env: add
          TEST_FLOOR_1_17: ${{ needs.test_floor_1_17.result }}
    # ... run: append TEST_FLOOR_1_17 to the aggregate arg list
        run: scripts/ci/aggregate-gate.sh LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_RUNTIME_PREFIX VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE VERIFY_INBOX VERIFY_THREADLINE VERIFY_SIGRA INSTALL_GOLDEN TEST_FLOOR_1_17
```
**(d) `nightly-gate` — UNCHANGED.** It already lists `test_floor_1_17` in `needs` and passes `TEST_FLOOR_1_17` (`ci.yml:1194,1202,1204`). On nightly, `run_floor` is also `true`, so the floor runs and reports `success`.
**(e) `pr-gate` — UNCHANGED.** Do NOT add the floor (D-14). On PRs the floor is skipped and no gate references it → "PR-skip as pass" satisfied structurally (Pitfall 2).
**(f) `aggregate-gate.sh` — UNCHANGED.** Its skipped-as-fail contract is correct and must not be softened.

Why this is safe: `ci-gate` runs `if: always() && github.event_name != 'pull_request'`; `run_floor` is `true` on exactly those events. So whenever `ci-gate` evaluates `TEST_FLOOR_1_17`, the floor has run (result is `success`/`failure`, never `skipped`).

## Runtime State Inventory

> This phase is config edits + two new files. No datastore keys, service configs, OS registrations, secrets, or build artifacts embed a renamed/migrated string. It is not a rename/refactor phase.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys change. | none |
| Live service config | Dependabot is GitHub-native; enabling it creates PRs but stores no repo-side state beyond `.github/dependabot.yml`. | none beyond committing the file |
| OS-registered state | None. | none |
| Secrets/env vars | None — `GITHUB_TOKEN` is auto-provisioned; `permissions:` narrows scope, adds no secret. | none |
| Build artifacts | Adding `mix_audit` to deps changes `mix.lock` (new dev/test dep tree). | run `mix deps.get` to update `mix.lock`; commit it |

**Nothing found requiring data migration** — verified: no string is stored/registered outside git that this phase renames.

## Validation Architecture

> Framed around observable CI/`mix`/`actionlint` outcomes — there is no library code in this phase, so validation is behavioral (a real CI run) rather than unit tests. `nyquist_validation: true`, so this section is included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | GitHub Actions run + `mix` output + `actionlint` (YAML lint) |
| Config file | `.github/workflows/ci.yml`, `mix.exs`, new `.tool-versions` / `.github/dependabot.yml` |
| Quick run command | `actionlint .github/workflows/ci.yml` (local YAML/expr validation) |
| Full suite command | Push to a branch and observe the `ci-gate` run (setup-beam resolution + floor gating are only observable in a real runner) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command / Observable | File Exists? |
|--------|----------|-----------|-------------------------------|-------------|
| QUAL-01 | All converted jobs resolve identical Elixir 1.19.5 / OTP 27.3.4 via `.tool-versions` | integration (CI) | Green run; setup-beam log shows `Using Elixir 1.19.5 (built for Erlang/OTP 27)` + OTP `27.3.4` in every converted job | ✅ (new `.tool-versions`) |
| QUAL-02 | Dependabot parses config and can open PRs | config-validation | GitHub Insights → Dependabot shows `mix` + `github-actions` ecosystems with no config error; `actionlint`/YAML parse | ✅ (new `.github/dependabot.yml`) |
| QUAL-03 | Top-level `contents: read` present; obs jobs run with `actions: read`; others read-only | integration (CI) | Green run with `permissions:` in place; obs-summary timing table still renders (proves `actions: read` works); no checkout failures | ✅ (ci.yml edit) |
| QUAL-04 | `mix deps.audit` executes and surfaces findings advisory-only | integration (CI) | `lint` job "Dependency advisory audit" step runs `hex.audit` + `deps.audit`, prints findings, never fails the gate (`continue-on-error`) | ✅ (mix.exs edit) |
| QUAL-05 | Floor leg runs on push AND gates; skipped on PR; still gates on nightly | integration (CI) | Push run: `test_floor_1_17` executes, `ci-gate` includes `TEST_FLOOR_1_17` and fails if the floor fails. PR run: floor skipped, `pr-gate` green, `ci-gate` not run | ✅ (ci.yml edit) |

### Sampling Rate
- **Per task commit:** `actionlint .github/workflows/ci.yml` + `mix deps.get` (lockfile resolves) locally.
- **Per wave merge:** push to a branch; confirm PR path (`pr-gate` green, floor skipped).
- **Phase gate:** a **push to `main`** (or dispatch) run where `ci-gate` is green with `TEST_FLOOR_1_17=success` and every converted job logs the identical resolved versions.

### Wave 0 Gaps
- [ ] `actionlint` availability (see Environment Availability) — if absent, YAML is validated by the CI run itself; not blocking.
- [ ] No test files needed — this phase has no library code. Validation is the CI run + `mix` output.

*(A dedicated negative test — a deliberately-failing 1.17 floor to prove `ci-gate` goes red — is optional; the structural argument in Pitfall 2 + Code Example 5 is sufficient, but a one-off branch experiment de-risks D-15.)*

## Security Domain

> This is a supply-chain hardening phase; `security_enforcement` is enabled (absent in config = enabled).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture / Supply Chain | yes | `.tool-versions` single source; SHA-pinned actions; Dependabot keeps pins current |
| V6 Cryptography | no | No crypto introduced |
| V10 Malicious Code / Dependencies | yes | `mix_audit` (advisory DB) + `hex.audit` (retired pkgs); Dependabot update PRs |
| V14 Config / CI hardening | yes | `permissions: contents: read` least-privilege `GITHUB_TOKEN`; per-job escalation only where needed |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-privileged CI token exfiltrating repo/secrets | Elevation of Privilege | `permissions: contents: read` top-level; `actions: read` only on obs jobs (QUAL-03) |
| Vulnerable transitive Hex dep | Tampering / Info Disclosure | `mix deps.audit` advisory scan surfaces CVEs (QUAL-04) |
| Stale/compromised pinned action SHA | Tampering | Dependabot `github-actions` updates + human-tag PR review (QUAL-02) |
| Toolchain-version drift hiding a broken floor | Repudiation / silent failure | `.tool-versions` truth + 1.17 floor gated on push (QUAL-01/05) |

> Note: `mix_audit` and `hex.audit` remain **advisory-only** by explicit decision (D-12; promoting to blocking is deferred `DEF-AUDIT-BLOCK`). This is an accepted-risk posture documented in SECURITY.md, not an oversight.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline `elixir-version`/`otp-version` per job | `version-file: .tool-versions` (single source) | setup-beam added version-file support | Removes ~14-way duplication; requires strict/full-patch pins |
| Ad-hoc manual dep bumps | Dependabot grouped weekly PRs | Dependabot v2 groups | Lower PR noise via `groups`/`update-types` |
| `hex.audit` only | `hex.audit` + `mix deps.audit` | mix_audit 2.x | Adds CVE-advisory coverage on top of retired-package checks |

**Deprecated/outdated:** none relevant. `~> 2.1` for mix_audit is current (2.1.5).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Today's resolved toolchain is Elixir 1.19.5 / OTP 27.3.4 and these are the exact strings to pin | Summary, Code Example 1 | LOW-MED: if a newer 1.19.x/27.x lands before plan time, pinning 1.19.5/27.3.4 would freeze a slightly-older patch than a fresh loose run. Mitigation: re-capture from the latest green `main` run at plan time (method documented). `[VERIFIED: run 30512806893]` at research time. |
| A2 | `~> 2.1` resolves to mix_audit 2.1.5 and D-10's bound needs no change | Standard Stack | LOW: verified current this session; a 2.2.x could appear but `~> 2.1` would still resolve safely (`>= 2.1.0 and < 3.0.0`). |
| A3 | Dependabot `groups` with only `update-types` (no `patterns`) groups all minor/patch per ecosystem | Code Example 2 | LOW: cosmetic (Claude's Discretion). Worst case is grouping granularity, not breakage. |

**Every load-bearing correctness claim (version-file strict behavior, aggregate skipped-as-fail, obs-summary job set, zero write usage) is `[VERIFIED]` against source/repo, not assumed.**

## Open Questions

1. **Exact patch drift between research and execute time.**
   - What we know: today (2026-07-30) loose `1.19`/`27` → `1.19.5` / `27.3.4`.
   - What's unclear: whether a newer 1.19.x or 27.x publishes before the phase executes.
   - Recommendation: the planner (or the execute task) re-reads the latest green `main` run's setup-beam output and pins those exact strings, so `.tool-versions` reproduces *that run's* versions. Non-blocking.

2. **Optional negative-path proof for D-15.**
   - What we know: the structural argument (floor `if:` == `ci-gate` `if:`) guarantees the floor gates on push.
   - What's unclear: whether the team wants a live "red floor → red ci-gate" demonstration.
   - Recommendation: optional throwaway branch experiment; the structural reasoning is sufficient for correctness.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | Re-capturing resolved versions from CI logs | ✓ (used this session) | present | Read the setup-beam log in the Actions UI |
| `actionlint` | Local YAML pre-flight | unknown (not required) | — | CI run validates the workflow; skip local lint |
| `mix` | `mix deps.get` to resolve mix_audit into `mix.lock` | ✓ (Elixir project) | 1.19.5 | — |
| Network to builds.hex.pm | setup-beam version download in CI | ✓ (runner) | — | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** `actionlint` (optional; CI run is the authoritative validator).

## Sources

### Primary (HIGH confidence)
- `erlef/setup-beam` `src/setup-beam.js` (main branch, fetched this session) — `version-file` forces strict (L28-34); strict = direct map lookup `versions0[spec]` (L527-535); version-map keys are full patches (`getElixirVersions` L414-443, `parseToolVersionsFile` L820-842). `[VERIFIED]`
- Green `main` CI run **30512806893** (2026-07-30) setup-beam logs — resolved `Using Elixir 1.19.5 (built for Erlang/OTP 27)`, OTP `27.3.4`. `[VERIFIED: run logs]`
- `builds.hex.pm/builds/elixir/builds.txt` — latest `1.19.5-otp-27` (2026-01-09). `[VERIFIED]`
- hex.pm API `packages/mix_audit` — latest 2.1.5 (2025-06-09), `mix deps.audit`, github.com/mirego/mix_audit, BSD-3. `[VERIFIED: hex.pm]`
- Repo files read directly: `ci.yml` (resolve_tiers, 15 obs-summary jobs, test_floor_1_17, ci-gate, nightly-gate, pr-gate), `mix.exs` (deps, ci.audit alias, `~> 1.17`), `scripts/ci/aggregate-gate.sh` (skipped-as-fail contract), `scripts/ci/obs-summary.sh` (`gh api …/jobs`), `release.yml` (1.17/27 pin). `[VERIFIED]`

### Secondary (MEDIUM confidence)
- GitHub Docs — Dependabot options reference (`version: 2`, `mix`/`github-actions`, `groups`/`update-types`, `directory: "/"`). `[CITED: docs.github.com]`
- setup-beam README — file-format inference (`.tool-versions` vs `.toml`), key mapping (`otp-version`→`erlang`, `elixir-version`→`elixir`). `[CITED]`

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- QUAL-01 version-file syntax: HIGH — read setup-beam source + confirmed today's resolved versions from a live run.
- QUAL-02 dependabot schema: HIGH — official docs + verified ecosystem strings.
- QUAL-03 permissions: HIGH — enumerated obs-summary jobs and confirmed zero write usage by grep.
- QUAL-04 mix_audit: HIGH — hex.pm API confirmed version/task/legitimacy.
- QUAL-05 gate wiring: HIGH — read every referenced job + the aggregate contract; structural correctness argument.

**Research date:** 2026-07-30
**Valid until:** 2026-08-29 for schema/API claims; **A1 (exact patch strings) is time-sensitive — re-capture at plan time.**
