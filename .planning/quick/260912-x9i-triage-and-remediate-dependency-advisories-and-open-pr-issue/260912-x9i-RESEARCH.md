# Quick Batch 260912-x9i: Dependency Advisories and GitHub Inbox - Research

**Researched:** 2026-09-13
**Domain:** Elixir/Hex and npm supply-chain hygiene, GitHub inbox triage, release readiness
**Confidence:** HIGH for repository and live GitHub state; MEDIUM for advisory-feed interpretation

## Summary

The dependency work is bounded and worth doing before release. The JavaScript surface is already clean. The root lock can take Dependabot PR #28's one-file update, which removes the current Decimal and Mint advisories while preserving the existing dependency declarations. The admin and inbox package locks can be refreshed inside their current constraints to versions that returned a clean `mix hex.audit` in isolated solver probes. The demo host needs the same refresh plus removal of its now-stale Accrue 1.5.0 compatibility pins. [VERIFIED: `package.json:1-11`, `mix.exs:35-46`, `examples/chimeway_demo_host/mix.exs:35-61`; isolated Mix solver probes, 2026-09-13]

One genuine constrained residual remains: both Accrue's Braintree dependency and Threadline currently restrict Hackney to the 1.x line, while all four current Hackney advisories are fixed at 4.0.1. Forcing Hackney 4 with an override is not a safe release-hygiene change. Record the residual, its actual dependency paths, and a follow-up issue; do not hide or waive it as “audit clean.” [CITED: https://hex.pm/api/packages/accrue/releases/1.5.1] [CITED: https://hex.pm/api/packages/braintree/releases/0.16.0] [CITED: https://hex.pm/api/packages/threadline/releases/0.9.0] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47071]

The GitHub inbox itself is simple: PR #28 is a clean, green, one-file lock refresh that should be incorporated into the current stabilization work; PR #22 is a stale, conflicting, draft predecessor and should be closed as superseded once the replacement release PR exists. There are no open issues. The latest CI on remote `main` is green, but the active worktree is 107 commits ahead of its old upstream, so the release decision must use checks from the final implementation SHA, not the old `main` run or PR #28's old-base checks. [VERIFIED: GitHub REST/Checks APIs, 2026-09-13, https://github.com/szTheory/chimeway/pulls]

**Primary recommendation:** Incorporate #28's exact root lock update, refresh the three subordinate Mix locks with the minimal manifest correction for the Accrue demo lane, accept and track only the upstream-constrained Hackney 1.x residual, then run every dependency audit and the repository's release aggregates against the final SHA before closing #22/#28 and cutting the release.

## Project Constraints (from AGENTS.md)

- Support Elixir 1.17+ / OTP 26+, Ecto 3.x / PostgreSQL 15+, optional Phoenix 1.7/1.8, optional Oban 2.x, and the Swoosh 1.x adapter seam. [VERIFIED: `AGENTS.md:12-18`; verbatim values: `Elixir 1.17+ / OTP 26+`, `Ecto 3.x + PostgreSQL 15+`, `Phoenix 1.7/1.8`, `Oban 2.x`, `Swoosh 1.x`]
- Preserve stable `notification_key` identity, the event → notification → delivery → attempt lifecycle, first-class idempotency/suppression reasons, replaceable adapters, and host ownership boundaries. [VERIFIED: `AGENTS.md:20-27`]
- Maintain named `mix verify.*` and `mix ci.*` entrypoints with CI/local parity; machine-testable release evidence must be executable and tied to the implementation SHA. [VERIFIED: `AGENTS.md:29-36`]
- Do not leak sensitive payload fields through telemetry or operator surfaces. [VERIFIED: `AGENTS.md:32-32`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Dependency resolution | Build/release | Package manifests | Each independently runnable Mix project owns a manifest/lock pair; Hex's solver, not handwritten lock edits, owns resolution. |
| Advisory enforcement | Build/release | CI | `mix hex.audit`, `mix deps.audit`, and `npm audit` turn advisory state into executable evidence. |
| Optional integration compatibility | Root library | Demo/CI fixtures | Root declares optional partners; demo and CI prove their real combined graphs. |
| PR/issue disposition | GitHub | Release workflow | GitHub owns mergeability/check state, while the release workflow must bind acceptance to the final SHA. |

## Current Baseline

### Milestone and repository state

- The v1.19 milestone audit says `status: tech_debt` with `requirements: 9/9`, `phases: 4/4`, `integration: 12/12`, and `flows: 2/2`; it explicitly recommends one bounded stabilization pass rather than another product phase. [VERIFIED: `.planning/v1.19-MILESTONE-AUDIT.md:2-9,37-41,90-101`; quoted values verbatim]
- The current branch is `resume/v1.18` at `3952b5b4`, 107 commits ahead of its configured old upstream `origin/ci/phase-96-automated-uat-20260810`; remote `main` is `f516b607167023edefeb767182adddbd9709aec5`. [VERIFIED: local Git and GitHub API, 2026-09-13]
- GitHub's active default-branch ruleset requires the `pr-gate` status check. [VERIFIED: GitHub Rulesets API, 2026-09-13, https://github.com/szTheory/chimeway/rules]
- The latest exact-`main` scheduled CI run, run 34679976933 from 2026-09-12, succeeded, including `pr-gate`, `ci-gate`, and `nightly-gate`. This is baseline evidence, not evidence for the unpushed 107-commit implementation. [VERIFIED: GitHub Actions API, 2026-09-13, https://github.com/szTheory/chimeway/actions/runs/34679976933]

### Audit inventory before remediation

| Surface | Locked vulnerable packages | Current result | Evidence |
|---|---|---|---|
| Root | `decimal "2.4.1"`, `mint "1.9.3"`, `hackney "1.25.0"` | 7 Hex advisories: 2 high, 4 medium, 1 low. `mix deps.audit` also flags Decimal/Hackney but its feed does not currently report Mint. | [VERIFIED: `mix.lock:17,37,52`; `mix hex.audit` and `mix deps.audit`, 2026-09-13] |
| `chimeway_admin` | `phoenix "1.8.7"`, `phoenix_live_view "1.1.30"`, `plug "1.19.2"`, `postgrex "0.22.2"`, `hackney "1.25.0"` | 12 Hex advisories. | [VERIFIED: `chimeway_admin/mix.lock:11,21,23,26,28`; `mix hex.audit`, 2026-09-13] |
| `chimeway_inbox` | `phoenix "1.8.7"`, `phoenix_live_view "1.1.31"`, `plug "1.19.2"`, `postgrex "0.22.2"`, `hackney "1.25.0"` | Same vulnerable families as admin. | [VERIFIED: `chimeway_inbox/mix.lock:11,21,23,26,28`; `mix hex.audit`, 2026-09-13] |
| Demo host | `cowboy "2.15.0"`, `cowlib "2.16.1"`, `decimal "2.4.1"`, `mint "1.8.0"`, `hpax "1.0.3"`, `req "0.5.18"`, `phoenix "1.8.7"`, `phoenix_live_view "1.1.31"`, `plug "1.19.2"`, `postgrex "0.22.3"`, `swoosh "1.26.0"`, `hackney "1.25.0"` | 28 Hex advisory records across the stale aggregate lock. | [VERIFIED: `examples/chimeway_demo_host/mix.lock:11-17,21,28-29,38,43,46,48,51-57,63,66-67`; `mix hex.audit`, 2026-09-13] |
| Root JavaScript | `@playwright/test "1.60.0"` | `npm audit --json`: zero vulnerabilities. `npm outdated --json`: empty object. | [VERIFIED: `package.json:1-11`; npm registry audit/outdated, 2026-09-13] |

### Currency inventory before remediation

- Root `mix hex.outdated` reports available updates for Accrue `1.5.0 → 1.5.1`, Ecto SQL `3.13.5 → 3.14.0`, ExDoc `0.40.3 → 0.40.4`, Oban `2.24.0 → 2.24.1`, and Tzdata `1.1.4 → 1.1.5`. Mailglass `1.11.0 → 2.5.0` is a constraint-blocked major and has no current audit finding, so it is outside this low-risk pass. [VERIFIED: `mix hex.outdated`, 2026-09-13]
- Admin and inbox each report small/current-line refreshes for Floki, LazyHTML, Oban, Phoenix, and LiveView; inbox also reports Phoenix PubSub `2.2.0 → 2.3.0`. [VERIFIED: subordinate `mix hex.outdated`, 2026-09-13]
- Demo reports safe current-line refreshes for LazyHTML, Oban, Phoenix, Plug, PlugCowboy, and Threadline. Decimal/Ecto SQL are explicitly “Update not possible” under the stale manifest pins; Mailglass and Sigra have constraint-blocked majors without current advisory findings. [VERIFIED: demo `mix hex.outdated`, 2026-09-13]

This supports a security/current-line refresh, not a general major-upgrade campaign.

### Official fixed-version floors

These are the floors relevant to the versions currently locked; where an advisory has several maintained-branch fixes, the table uses the floor for the branch this repository should move to.

| Package | Required safe target | Advisory evidence |
|---|---:|---|
| Decimal | `>= 3.0.0` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-32686] |
| Mint | `>= 1.10.0` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-82728] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-82729] |
| Hackney | `>= 4.0.1` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47069] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47071] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47075] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47076] |
| Plug | `>= 1.19.5` on 1.19, or current `1.20.3` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-54892] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-56813] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-56814] |
| Postgrex | `>= 0.22.4` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-58225] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-66838] |
| Phoenix | `>= 1.8.9` on 1.8 | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-56811] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-56812] |
| Phoenix LiveView | `>= 1.1.33` on 1.1, or `>= 1.2.9` on 1.2 | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-64941] |
| Cowboy | `>= 2.18.0` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-65624] [CITED: https://github.com/advisories/GHSA-w4f7-4cxr-rv3c] |
| Cowlib | `>= 2.19.0` for the prefixed-integer DoS; use current `2.20.0` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-59248] [CITED: https://github.com/advisories/GHSA-g2wm-735q-3f56] |
| HPAX | `>= 1.0.4` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-58226] |
| Req | `>= 0.6.1` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-49755] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-49756] |
| Swoosh | `>= 1.26.3` | [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-54893] |

## Prescriptive Remediation

### 1. Incorporate PR #28's root lock refresh

PR #28 changes only `mix.lock`, is `CLEAN`/`MERGEABLE`, and has a successful required `pr-gate`. Its head is `d03c7b88e51738083b3ab12575b10730f94d1592`; its base is the old remote-main SHA `f516b607167023edefeb767182adddbd9709aec5`. [VERIFIED: GitHub Pulls/Checks APIs, 2026-09-13, https://github.com/szTheory/chimeway/pull/28]

Apply that exact lockfile delta to the stabilization branch rather than inventing a competing update. It moves the important root packages as follows: Accrue `1.5.0 → 1.5.1`, Decimal `2.4.1 → 3.1.1`, Ecto `3.13.6 → 3.14.2`, Ecto SQL `3.13.5 → 3.14.0`, ExDoc `0.40.3 → 0.40.4`, ExMoney `5.24.2 → 6.2.1`, Mint `1.9.3 → 1.10.0`, Oban `2.24.0 → 2.24.1`, and Tzdata `1.1.4 → 1.1.5`. [VERIFIED: GitHub PR #28 file patch and isolated solver reproduction, 2026-09-13]

An isolated application of that resolution reduces root `mix hex.audit` to only the four Hackney advisories. Because PR #28 was tested against old `main`, rerun all current gates after incorporation. Do not merge solely on its existing checks. [VERIFIED: isolated Mix solver/audit probe, 2026-09-13]

### 2. Refresh admin and inbox locks inside existing manifests

No manifest constraint changes are required for either optional package: both already allow the safe Phoenix/Ecto family. Their direct declarations include `{:oban, "~> 2.17"}`, `{:phoenix, "~> 1.7"}`, `{:phoenix_live_view, "~> 1.0"}`, and `{:ecto_sql, "~> 3.11"}`. [VERIFIED: `chimeway_admin/mix.exs:22-34`, `chimeway_inbox/mix.exs:22-34`; values quoted verbatim]

Use targeted solver updates, accepting only the transitives they require:

```bash
cd chimeway_admin
mix deps.update phoenix phoenix_live_view plug postgrex tzdata hackney oban floki lazy_html
mix deps.get
mix hex.audit

cd ../chimeway_inbox
mix deps.update phoenix phoenix_live_view phoenix_pubsub plug postgrex tzdata hackney oban floki lazy_html
mix deps.get
mix hex.audit
```

The isolated probes resolved Phoenix `1.8.13`, LiveView `1.2.11`, Plug `1.20.3`, Postgrex `0.22.4`, Hackney `4.7.4`, Ecto `3.14.2`, Ecto SQL `3.14.0`, Oban `2.24.1`, Floki `0.38.4`, LazyHTML `0.1.12`, and Tzdata `1.1.5`; both subsequent Hex audits were clean. [VERIFIED: isolated Mix solver/audit probes, 2026-09-13] Package currency was checked against the official Hex API. [CITED: https://hex.pm/api/packages/phoenix] [CITED: https://hex.pm/api/packages/phoenix_live_view] [CITED: https://hex.pm/api/packages/plug] [CITED: https://hex.pm/api/packages/postgrex]

### 3. Correct the demo's stale Accrue compatibility pin, then refresh

The demo explicitly pins `{:decimal, "~> 2.0", override: true}` and `{:ecto_sql, "~> 3.13.0", override: true}` to accommodate Accrue 1.5.0. Its comment says Accrue “requires decimal ~> 2.0 / ecto ~> 3.13.” [VERIFIED: `examples/chimeway_demo_host/mix.exs:41-49`; quoted values verbatim]

That premise is obsolete for Accrue 1.5.1: its official release metadata declares Decimal `~> 3.0` and Ecto/Ecto SQL `~> 3.13`. [CITED: https://hex.pm/api/packages/accrue/releases/1.5.1] The CI Accrue lane is still pinned to commit `cafc526f752b917a0abf8cbdbf3030cb367ae346`, while official tag `accrue-v1.5.1` resolves to `d30fc25dbf6ba551792c66ff451b4b93c0af4bf1`. [VERIFIED: `.github/workflows/ci.yml:784-793`; value `cafc526f752b917a0abf8cbdbf3030cb367ae346` quoted verbatim] [CITED: https://github.com/szTheory/accrue/tree/accrue-v1.5.1]

Make these coupled changes:

1. Change the demo Decimal override to `~> 3.0` and Ecto SQL override to `~> 3.14.0`; rewrite the adjacent comments to describe the actual Accrue 1.5.1 contract.
2. Repin the Accrue CI checkout to immutable commit `d30fc25dbf6ba551792c66ff451b4b93c0af4bf1`.
3. Run `mix deps.update --all` in the demo, then `mix deps.clean --unused` and `mix deps.get` so obsolete Mint/HPAX/Req/Finch entries disappear if they are no longer reachable.
4. Require `mix verify.accrue` because that alias compiles the root and runs both root and demo `:accrue` tests. [VERIFIED: `mix.exs:153-158`]

The isolated probe resolved Cowboy `2.19.0`, Cowlib `2.20.0`, Phoenix `1.8.13`, LiveView `1.2.11`, Plug `1.20.3`, PlugCowboy `2.9.0`, Postgrex `0.22.4`, Swoosh `1.28.0`, Threadline `0.9.0`, and Tzdata `1.1.5`, while removing the stale Mint/HPAX/Req/Finch chain. [VERIFIED: isolated Mix solver/audit probe, 2026-09-13]

### 4. Leave JavaScript unchanged

Do not manufacture an npm change. `@playwright/test "1.60.0"` is the only declared npm package, and both audit and outdated checks are clean. [VERIFIED: `package.json:9-11`; npm registry audit/outdated, 2026-09-13]

## Constrained Residual Risk

### Hackney 1.x: genuine, upstream-constrained

After the safe root/demo upgrades, Hackney remains at `1.25.0`. The live root tree has three paths: `accrue → braintree → hackney`, `threadline → hackney`, and `tzdata → hackney`. [VERIFIED: `mix deps.tree`, 2026-09-13] Tzdata 1.1.5 itself permits Hackney 4, but Accrue 1.5.1 still requires Braintree `~> 0.16`, Braintree 0.16.0 requires Hackney `~> 1.15`, and Threadline 0.9.0 requires Hackney `~> 1.18`. [CITED: https://hex.pm/api/packages/tzdata/releases/1.1.5] [CITED: https://hex.pm/api/packages/accrue/releases/1.5.1] [CITED: https://hex.pm/api/packages/braintree/releases/0.16.0] [CITED: https://hex.pm/api/packages/threadline/releases/0.9.0]

All four current Hackney records are fixed at 4.0.1, so no available 1.x refresh closes them. [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47069] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47071] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47075] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-47076]

**Disposition:** accept temporarily and open one tracking issue naming the exact dependency paths and four advisory IDs. Do not add a Hackney 4 override; it would contradict partner constraints and convert a known, auditable residual into an unverified integration state. Re-check when Accrue adopts Braintree 0.17+/Hackney 4 and Threadline relaxes its Hackney requirement.

### Cowlib 2.20 advisory-feed mismatch: constrained scanner noise

The demo's post-refresh `mix hex.audit` may still report three Cowlib records even at 2.20.0. Official GitHub advisory GHSA-g2wm-735q-3f56 defines the affected interval as `>= 2.9.0, <= 2.16.1`, and GHSA-w4f7-4cxr-rv3c scopes the vulnerable packages to Cowboy `< 2.16.0` and Gun, not Cowlib 2.20.0. [CITED: https://github.com/advisories/GHSA-g2wm-735q-3f56] [CITED: https://github.com/advisories/GHSA-w4f7-4cxr-rv3c] The Cowlib 2.20.0 tag also contains the upstream fix commit recorded for CVE-2026-43971. [VERIFIED: official `ninenines/cowlib` tag/commit ancestry probe, 2026-09-13] [CITED: https://osv.dev/vulnerability/EEF-CVE-2026-43971]

**Disposition:** document the exact remaining audit output and the authoritative GitHub ranges/commit ancestry; do not pin an arbitrary Git SHA or downgrade. This is a feed-mapping exception, not permission to ignore future Cowlib findings. Confidence is MEDIUM because the EEF/Hex audit feed and GitHub package/range metadata disagree.

## GitHub PR and Issue Disposition

| Item | Live state | Recommendation |
|---|---|---|
| PR #28 | Open, non-draft, clean/mergeable, one changed file (`mix.lock`), required `pr-gate` green; based on old remote `main`. [VERIFIED: GitHub Pulls/Checks APIs, 2026-09-13, https://github.com/szTheory/chimeway/pull/28] | Incorporate its exact lock delta into the current stabilization branch. After final-SHA verification, merge if it remains the chosen integration path; otherwise close with “incorporated by <replacement PR/SHA>.” |
| PR #22 | Open draft, dirty/conflicting, no current checks, 100 changed files, old head `61004f…`. [VERIFIED: GitHub Pulls/Checks APIs, 2026-09-13, https://github.com/szTheory/chimeway/pull/22] | Do not rebase or merge. Close as superseded only after the replacement/current release PR is published, linking that PR/SHA so history remains intelligible. |
| Issues | Zero open issues. [VERIFIED: GitHub Issues API, 2026-09-13, https://github.com/szTheory/chimeway/issues] | Create exactly one bounded Hackney-upstream tracking issue if the residual remains after final solving; avoid separate issue spam for each advisory. |

## Standard Stack

No new packages should be installed.

| Tool | Version observed | Purpose | Required use |
|---|---:|---|---|
| Mix/Hex | Mix 1.19.5 | Resolve each Mix project and query Hex retirement/advisory data | Use solver-generated locks and `mix hex.audit`; never edit locks manually. |
| `mix_audit` | `~> 2.1` declaration | Secondary Elixir advisory feed | Run root `mix deps.audit`; do not mistake its current Mint omission for safety. [VERIFIED: `mix.exs:43-46`; value `{:mix_audit, "~> 2.1"...}` quoted verbatim] |
| npm | 11.1.0 | JS audit/currency | Run `npm audit` and `npm outdated`; make no JS change while clean. |
| GitHub CLI/API | gh 2.95.0 | Authoritative PR/check/ruleset state | Query exact SHA checks before disposition or release. |

## Architecture Patterns

### Dependency evidence flow

```text
manifest constraints
        ↓
Hex/npm official solver → generated lockfile → per-project advisory audit
        ↓                                      ↓
integration/release gates ← final dependency graph ← documented residual only
        ↓
exact implementation SHA checks → PR disposition → release decision
```

### Pattern 1: Each runnable Mix project owns its lock

Root, `chimeway_admin`, `chimeway_inbox`, and the demo host are independently runnable and must each be resolved and audited. Updating root alone cannot prove subordinate package safety. [VERIFIED: repository `mix.exs`/`mix.lock` inventory, 2026-09-13]

### Pattern 2: Change a manifest only when the manifest creates the vulnerability

The admin/inbox advisories are stale-lock problems, so refresh locks only. The demo's Decimal advisory is deliberately held by an obsolete compatibility override, so update that override and its pinned Accrue proof together. [VERIFIED: `examples/chimeway_demo_host/mix.exs:41-49`, `.github/workflows/ci.yml:784-793`]

### Pattern 3: Residual risk must be graph-specific

Record advisory ID, severity, fixed floor, exact dependency path, why the floor cannot resolve, and the event that permits removal. “Transitive” alone is not a risk disposition.

### Anti-patterns to avoid

- **Manual `mix.lock` editing:** loses solver checksums and graph consistency.
- **Forcing Hackney 4:** violates currently published Accrue/Braintree and Threadline constraints.
- **Calling all Cowlib output a false positive:** only the specifically cross-checked 2.20.0 records earn that exception.
- **Treating PR #28's green check as final:** it ran against the old base, not the stabilization result.
- **Updating only root:** leaves known high advisories in admin, inbox, and demo locks.
- **Broad unrelated upgrades:** this batch is security/release hygiene, not a framework-major modernization.

## Don't Hand-Roll

| Problem | Don't build/do | Use instead | Why |
|---|---|---|---|
| Lock resolution | Handwritten lock patches | Mix/Hex solver | Preserves checksums and validates all constraints. |
| Advisory parsing | Custom CVE scraper | `mix hex.audit`, `mix deps.audit`, npm audit, official OSV/GHSA | Avoids incomplete severity/range logic. |
| Constraint bypass | `override: true` for Hackney 4 | Upstream-compatible releases | An override proves resolution, not runtime compatibility. |
| PR rescue | Rebase stale PR #22 | Close-as-superseded with a replacement link | Avoids replaying 100 conflicted files and obsolete history. |
| Check trust | Human visual inspection alone | GitHub Checks API tied to exact SHA | Meets the repository's machine-evidence rule. |

## Runtime State Inventory

| Category | Items found | Action required |
|---|---|---|
| Stored data | None — dependency locks/manifests do not rename or migrate application records. [VERIFIED: requested change scope and manifest inspection] | No data migration. |
| Live service config | GitHub has open PRs #22/#28, an active `pr-gate` ruleset, and check runs outside git. [VERIFIED: GitHub APIs, 2026-09-13] | Close/merge only after final-SHA checks; link superseding work. |
| OS-registered state | None found; no services, launch agents, or task registrations are changed by lock refreshes. [VERIFIED: repository change scope] | None. |
| Secrets/env vars | Hex reports an expired local authentication session, but public package/advisory queries succeed. No secret name changes are needed. [VERIFIED: Hex CLI output, 2026-09-13] | Do not reauthenticate merely for this batch; CI/public resolution must remain credential-free. |
| Build artifacts / installed packages | Existing `_build`, `deps`, and `node_modules` may reflect old locks. | Let `mix deps.get` reconcile, use `mix deps.clean --unused` for unreachable demo transitives, and use clean CI for final proof. |

## Common Pitfalls

### Pitfall 1: Declaring “audit clean” while suppressing constrained output

**What goes wrong:** Release notes imply zero advisories although Hackney 1.x remains.

**How to avoid:** Attach the final command output and explicitly separate genuine Hackney constraints from the Cowlib 2.20 feed mismatch.

### Pitfall 2: Leaving the Accrue proof pinned to 1.5.0

**What goes wrong:** The demo remains on vulnerable Decimal 2 solely to satisfy a no-longer-current partner fixture.

**How to avoid:** Move the immutable CI ref, demo overrides, comments, and lock in one atomic task, then run `mix verify.accrue`.

### Pitfall 3: Losing optional-package coverage

**What goes wrong:** Root tests pass, but mounted admin/inbox/demo combinations regress after a lock refresh.

**How to avoid:** Run `mix verify.example`, `mix verify.inbox`, and the aggregate CI gates, not just root unit tests. [VERIFIED: `mix.exs:98-110,135-139,160-167`]

### Pitfall 4: Closing PRs before a replacement is addressable

**What goes wrong:** Useful provenance disappears and contributors see an unexplained closure.

**How to avoid:** Publish/link the replacement PR or commit first, then close #22/#28 with explicit disposition.

## Validation Architecture

Nyquist validation is enabled. [VERIFIED: `.planning/config.json:15-20`; value `"nyquist_validation": true` quoted verbatim]

### Fast evidence per task

| Changed surface | Command |
|---|---|
| Root lock | `mix deps.get && mix hex.audit && mix deps.audit && mix ci.lint && mix ci.test` |
| Admin lock | `cd chimeway_admin && mix deps.get && mix hex.audit && mix test --warnings-as-errors` |
| Inbox lock | `cd chimeway_inbox && mix deps.get && mix hex.audit && mix test --warnings-as-errors` |
| Demo manifest/lock | `cd examples/chimeway_demo_host && mix deps.get && mix hex.audit && mix test --warnings-as-errors` |
| JS proof | `npm ci && npm audit && npm outdated` |

### Phase gate

Run the repository's release-facing aliases after all lockfiles settle:

```bash
mix ci
mix verify.example
mix verify.accrue
mix verify.inbox
mix ci.verify_gates
```

The aliases are already executable contracts: `ci` expands to `ci.lint` and `ci.test`; `ci.verify_gates` expands to `ci.verify_contracts`, `ci.verify_accrue_package`, and `ci.crosswake_provider_feedback_docs`. [VERIFIED: `mix.exs:65-86,125-139`; values quoted verbatim]

Finally, query GitHub run/job/step results for the exact pushed implementation SHA and require the active `pr-gate`; do not substitute an ancestor unless subsequent commits are verification artifacts only and that relationship is documented. [VERIFIED: `AGENTS.md:29-36`]

### Wave 0 gaps

None. Existing audit commands, package tests, optional-integration verifiers, and release contracts cover the changed surfaces. No new test framework or dependency is required.

## Security Domain

### Applicable ASVS categories

| ASVS category | Applies | Control |
|---|---|---|
| V2 Authentication | No direct code change | Dependency refresh must not alter host-owned authentication boundaries. |
| V3 Session Management | Indirectly | Upgrade Phoenix/Plug/LiveView to advisory-safe versions and run mounted package tests. |
| V4 Access Control | No direct code change | Preserve host ownership; no policy change in this batch. |
| V5 Input Validation | Yes | Advisory-safe HTTP/query/cookie/parser dependencies; do not bypass official patched floors. |
| V6 Cryptography | Indirectly | Retain official TLS/HTTP packages and their supported constraints; do not hand-roll transport logic. |

### Threats addressed

| Pattern | STRIDE | Standard mitigation |
|---|---|---|
| Parser/resource-exhaustion advisories | Denial of service | Resolve to official patched floors and enforce audits in CI. |
| CRLF/header/cookie injection | Tampering | Upgrade Plug/Hackney/Cowboy/Cowlib where constraints permit; track the Hackney residual. |
| SSRF allowlist bypass | Spoofing / information disclosure | Hackney 4.0.1+ when partner constraints permit; document current upstream constraint. |
| SQL injection in Postgrex options/replay | Tampering | Postgrex 0.22.4+ in every mounted package/demo graph. |
| Supply-chain substitution | Tampering | Use existing official packages, official registries, solver locks, and exact immutable GitHub refs. |

## Package Legitimacy Audit

Not applicable: the recommended work introduces no external package names. Every named dependency already exists in a checked-in manifest/lock and is refreshed only through the official Hex/npm registries. No install checkpoint is required.

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | [ASSUMED] A downstream consumer that does not opt into Accrue or Threadline can resolve Tzdata 1.1.5 with Hackney 4. | Residual risk | Consumer packaging may retain another Hackney 1 edge; confirm with the existing clean-consumer/package gate before describing consumer exposure in release notes. |

## Resolved Questions

1. **Upstream Hackney 4 timing — RESOLVED.**
   - Current official Accrue/Braintree and Threadline releases constrain the graph to Hackney 1.x.
   - The stabilization does not wait on an unknown upstream schedule. If Hackney remains in the final graph, publish one bounded tracking issue and proceed only with the residual disclosed and every otherwise-actionable gate green; never force an incompatible override.

2. **Cowlib 2.20.0 feed mapping at release time — RESOLVED.**
   - Official GitHub ranges and verified upstream fix ancestry do not identify Cowlib 2.20.0 as vulnerable for the currently mismapped records.
   - Re-run the raw Cowlib audit immediately before release. Document the exact feed exception only when that final run reproduces it; if it does not reproduce, omit the exception instead of carrying stale scanner language forward.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|---|---|---:|---:|---|
| Elixir | Mix projects | Yes | 1.19.5 | Project floor remains 1.17; CI matrix supplies compatibility evidence. |
| Erlang/OTP | Mix projects | Yes | 27 | CI matrix supplies supported-version evidence. |
| Mix/Hex | Resolution/audits | Yes | Mix 1.19.5 | None needed; public calls work despite expired auth. |
| Node.js | Playwright/npm checks | Yes | 22.14.0 | Project declares `>=18`. [VERIFIED: `package.json:3-5`; value `"node": ">=18"` quoted verbatim] |
| npm | JS audit | Yes | 11.1.0 | None needed. |
| GitHub CLI | Live inbox/checks | Yes | 2.95.0 | GitHub REST API via authenticated CLI. |
| PostgreSQL | Integration gates | CI/service managed | 15+ project target | Use `scripts/test-db`/CI service as encoded by aliases. |

## Sources

### Primary repository and live-service evidence (HIGH)

- `AGENTS.md`, `.planning/STATE.md`, `.planning/PROJECT.md`, `.planning/v1.19-MILESTONE-AUDIT.md`
- Root, admin, inbox, demo `mix.exs`/`mix.lock`; root `package.json`/`package-lock.json`
- `.github/workflows/ci.yml`, root Mix aliases, integration tests
- Live GitHub Pulls, Issues, Checks, Actions, and Rulesets APIs for `szTheory/chimeway`, queried 2026-09-13
- Local `mix hex.audit`, `mix deps.audit`, `mix hex.outdated`, `npm audit`, `npm outdated`, and isolated Mix solver probes, 2026-09-13

### Official external sources (MEDIUM)

- Hex package/release APIs: https://hex.pm/api/packages/accrue, https://hex.pm/api/packages/braintree, https://hex.pm/api/packages/threadline, https://hex.pm/api/packages/tzdata
- OSV advisory API/pages for all EEF identifiers listed in the fixed-floor and residual-risk tables
- GitHub Advisory Database: https://github.com/advisories/GHSA-g2wm-735q-3f56 and https://github.com/advisories/GHSA-w4f7-4cxr-rv3c
- Official `szTheory/accrue` release/tag and `ninenines/cowlib` tag/commit history

## Metadata

**Confidence breakdown:**

- Dependency inventory: HIGH — read every in-scope manifest/lock and ran the installed audit tools.
- Minimal resolution: HIGH — reproduced in isolated copies without modifying the worktree.
- GitHub disposition: HIGH — read live authoritative API state.
- Advisory range interpretation: MEDIUM — official OSV/GHSA data is current but the Cowlib feeds presently conflict.
- Residual exposure: MEDIUM — constraint paths are verified, but application exploitability depends on host usage and configuration.

**Research date:** 2026-09-13
**Valid until:** 2026-09-20 (advisories, package releases, and GitHub state are fast-moving)
