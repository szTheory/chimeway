# Chimeway

## What This Is

Chimeway is an open-source, embedded notification layer for Elixir and Phoenix applications. It provides durable notification records, delivery orchestration, and explainable traces from trigger through policy, scheduling, batching, and provider attempts. It is local-first by design: host applications keep their own data, policies, and operational controls.

## Core Value

Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## Current Milestone: v1.16 CI/CD Performance & Reliability

**Goal:** Make CI fast, deterministic, and trustworthy — collapse the ~6.5 min `main` wall-clock (gated by a single cold-compiling job) toward under ~3 min by fixing compiled-artifact caching, without lowering the quality signal or overcomplicating the pipeline.

**Target features:**
- **Cache correctness (headline):** fix the `MIX_ENV`-absent cache-key collision (`lint` `:dev` vs `install_golden` `:test` share one write-once key) so `_build` actually warms; standardize keys on env + resolved OTP/Elixir + `mix.lock`; de-fragment the plain-hex lanes; add a compile-once producer job so deps compile 1× per run instead of ~13×.
- **CI observability:** per-lane cache hit/miss + "N files recompiled" + per-step timing in the job summary, so every win is provable by a run-link delta.
- **Test concurrency:** flip the ~32 pure-DB `DataCase` files to `async: true` (leave the 25 app-env / 5 prefix mutators serial); explicit `pool_size`; `--warnings-as-errors` on `ci.test`.
- **Pipeline tiering:** add a `schedule:` nightly tier (cold-build backstop + full OTP matrix + 1.17 floor leg + heavy Playwright lane); single-OTP on the PR path.
- **Quality & supply-chain polish:** `.tool-versions`, `dependabot.yml`, top-level `permissions: contents: read`, `mix_audit` (advisory), resolve CI↔release Elixir skew.
- **Reliability triage & determinism:** measure real-vs-flaky rate; close/verify the two documented CI-only backlog issues; keep the random ExUnit seed (nightly `--seed 0` ordering run); scoped clock injection.

**Key context:** Baseline measured 2026-07-28 — `main` CI ~373–395s, entire wall-clock gated by the 373s `install_golden` job whose `mix ecto.create` hides a 135s cold compile; compile times are dead-flat across 3 identical-`mix.lock` runs (cache never warms). Runner ≈ 4 cores. Full scoping in `.planning/` plan artifact. Decisions (nightly tier yes; partner lanes stay push-to-main; drop OTP 26 from PR; Dialyzer/coverage deferred; `mix_audit` advisory; keep release at 1.17 floor + add a 1.17 CI leg) recommended and confirmable at the requirements gate. Doc/config/CI-only work — no runtime library behavior changes.

## Requirements

Active requirements for the current milestone are listed below. Archived requirement sets live under `.planning/milestones/vX.Y-REQUIREMENTS.md`.

### Validated

- ✓ v1.16 Phase 90 Pipeline Tiering (PR/main/nightly) — TIER-01/02/03/04: a `schedule:`-driven nightly tier where a bare `resolve_tiers` setup job emits `otp_matrix` (`["27"]` on `pull_request`, `["26","27"]` otherwise) and `run_nightly`, feeding `test`'s OTP matrix via `fromJSON()` so the PR path stays single-OTP {27} while push/nightly run {26,27}; the relocated Playwright `verify_admin` lane plus a cache-free `nightly_cold_build` backstop and a `test_floor_1_17` leg pinned to Elixir 1.17/OTP 27 (honoring `mix.exs` `~> 1.17`) run nightly-only; `nightly-gate` mirrors `ci-gate`'s `aggregate-gate.sh` pass/fail over those four lanes while `ci-gate` drops to 13 lanes; concurrency keyed on `github.event_name` (cancel-in-progress scoped to `pull_request`). Locked by `release_gate_contract_test.exs` + `ci_observability_contract_test.exs` (142 tests); proven live on GitHub-hosted runners (nightly dispatch run 30512184143 = all nightly jobs green; PR run 30512220386 = exactly one OTP-27 leg). Verified 4/4 must-haves.
- ✓ v1.16 Phase 87 CI Observability & Cache Diagnostics — OBS-01/02/03/04: `scripts/ci/obs-recompile.sh` (deps/app recompile counts) + `scripts/ci/obs-summary.sh` (cache HIT/PARTIAL/MISS classification + REST per-step timing, whitelist-only output) render a cache/recompile/timing table in every one of the 14 build lanes' job summaries, locked by `test/chimeway/ci_observability_contract_test.exs` (31 tests); pre-optimization baseline committed as `.planning/CI-PERF-BASELINE.md` (four facts + delta ledger + run permalink). Verified 13/13 must-haves; human-confirmed live render on run 30416472070.
- ✓ v1.15 Brand Identity & Brand Book (Phases 82–86) — Logo lockup family (LOGO-01/02/03/04/05/06, NOTES-02) selected at a human checkpoint and shipped as optimized SVGs + favicon/OG derivatives; standalone `file://`-safe scoped HTML brandbook with token swatches, component states, brand voice/microcopy, and do/don't (BOOK-01/02/03, STATE-01/02, VOICE-01/02/03); README `<picture>` lockup + ExDoc `:logo`/`:favicon` wiring, v1.14 contracts green (INTEG-01/02/03/04); offline WCAG contrast calc + cited exemptions + research/red-team notes with machine-enforced scope boundary (A11Y-01/02/05, NOTES-01/03/04). **Accepted-risk:** A11Y-03 (focus-not-obscured) and A11Y-04 (CVD emulation) manual browser checks were owner-waived 2026-07-28 — recorded as documented known gaps, not passes; 30/32 requirements complete.
- ✓ v1.15 Phase 81 — TOKEN-01/02/03/04/05 canonical copy-safe `--cw-*` token layer: `brandbook/tokens/tokens.css` (bare `:root` SSOT, 15 verbatim primitives, generalized semantic tier, light/dark/system theming, no filter inversion) + hand-authored DTCG `brandbook/tokens/tokens.json` mirror (alias refs, light/dark sibling groups), with sub-primitive divergences DIV-1..DIV-7 recorded DOCUMENTED/DEFERRED in `notes/decision-log.md`; shipped admin CSS proven byte-identical (`git diff --exit-code`).
- ✓ v1.14 Phase 80 — CI-01/02/03/04/05 two-aggregate CI topology: fast always-on `pr-gate` + push/dispatch-only 14-lane `ci-gate`, anti-pending event guards (live PR #3 proof), nested/npm/Playwright/per-lane-demo caches keyed on lockfiles, and complex CI logic extracted to `scripts/ci/*.sh` — all locked by `release_gate_contract_test.exs`.
- ✓ v1.14 Phase 79 — DOCS-14/15/16/17, ADPT-01 README rewritten as an additive-superset decision page (local-first value prop + public-API trigger-to-explain snippet chain), stub guides delinked, and byte-identical source-tree/packaged-README (unpacked-Hex) contract locks.
- ✓ v1.14 Phase 78 — TRUTH-01/02/03 root package release identity, canonical repository/source links, and sibling preview/path install-status copy are aligned and enforced by ExUnit release/doc contracts plus a deterministic local Hex unpack proof (`mix ci.verify_gates`, `mix verify.parity`).
- ✓ v1.14 Phase 77 — TRUTH-04 planning milestone identifiers and package release tags are separated; Phase 77 records the root-only package model, sibling preview/path package status input, and downstream truth ownership.
- ✓ v1.13 Storage Isolation and Upgrade Path — PFX-01/02/03/04, MIG-01/02/03/04, RUN-01/02/03/04, UPG-01/02/03, DOCS-01/02, DEMO-01, GATE-01, GATE-01-GAP ([archive](.planning/milestones/v1.13-REQUIREMENTS.md))
- ✓ v1.11 Operator Console Polish & Hardening — ADMIN-01/02/03, DES-01/02/03/04, SAFE-01/02/03/04, PRIV-01/02, EXPL-01/02, DOCS-12, GATE-08, SMOKE-01 ([archive](.planning/milestones/v1.11-REQUIREMENTS.md))
- ✓ v1.10 Ecosystem Completions — ECOS-08/09/10, DEMO-09/10, DOCS-10/11, GATE-07 ([archive](.planning/milestones/v1.10-REQUIREMENTS.md))
- ✓ v1.9 Adopter Complete — ECOS-06/07, DEMO-07/08, INBX-01/02, DOCS-08/09, GATE-05/06 ([archive](.planning/milestones/v1.9-REQUIREMENTS.md))

### Active

**v1.16 CI/CD Performance & Reliability** (started 2026-07-28) — CI pipeline efficiency, determinism, and DX. Requirements in `.planning/REQUIREMENTS.md`; roadmap in `.planning/ROADMAP.md` (Phases 87–92). Goal + target features in the [Current Milestone](#current-milestone-v116-cicd-performance--reliability) section above.

Carried-forward candidates NOT in v1.16 scope (future milestones): the two accepted-risk A11Y manual checks (A11Y-03 focus-not-obscured, A11Y-04 CVD emulation — a short in-browser pass); TENANT-01 (broader tenant spine consistency), PRIV-03 (recursive redaction hardening), INBX-03 (inbox PubSub badge), INT-03 (mark_seen progression E2E), PKG-01 (sibling package promotion). See archived [v1.14 requirements](.planning/milestones/v1.14-REQUIREMENTS.md).

### Out of Scope

- Broad channel matrix, generic CRUD admin, full TeamPulse SaaS shell — see [Out of Scope](#out-of-scope) below
- Dynamic per-tenant database prefixes — Chimeway supports one static storage prefix per host app config, not prefix-per-request tenancy

## Prior Milestone: v1.14 Public Truth and Verification Architecture

**Shipped:** 2026-07-03

**Delivered:**
- Root package release identity, canonical repository/source links, release manifest, changelog, HexDocs source refs, README install constraint, and sibling preview/path install-status copy aligned and contract-enforced (TRUTH-01/02/03/04).
- Deterministic local Hex unpack proof with env-scoped Sigra override so the prod package build stays Hex-legal while dev/test resolution is preserved.
- README rewritten as an additive-superset public decision page with a public-API trigger-to-explainability snippet chain, stub guides delinked, locked by byte-identical source-tree/packaged-README contracts (DOCS-14/15/16/17, ADPT-01).
- Two-aggregate CI topology: fast always-on `pr-gate` for PRs plus a push/dispatch-only 14-lane `ci-gate` for release confidence, with anti-pending event guards proven by a live PR (CI-01/02/03).
- Complex CI logic extracted to `scripts/ci/*.sh`; nested/npm/Playwright/per-lane-demo caches keyed on lockfiles; contributor/maintainer gate docs aligned; D-08 `pr-gate` branch-protection ruleset (id 18486746) set up (CI-04/05).

## Latest Shipped Milestone: v1.15 Brand Identity & Brand Book

**Shipped:** 2026-07-28 (override_closeout — A11Y-03/A11Y-04 manual browser checks owner-waived, accepted-risk; 30/32 requirements complete)

**Delivered:** A self-contained, repo-safe `brandbook/` package — reconciled copy-safe `--cw-*` design tokens (CSS + hand-authored DTCG JSON), a human-selected six-mark logo lockup family (optimized SVGs + dual-theme favicon + OG card), a standalone `file://`-safe scoped HTML brandbook (token swatches, component states, live theme toggle + contrast matrix, brand voice/microcopy, do/don't), README `<picture>` lockup + ExDoc `:logo`/`:favicon` wiring (v1.14 contracts green), and an accessibility audit closed with an offline WCAG contrast calc, verbatim-cited exemptions, research/red-team notes, and a machine-enforced `brandbook/`-only scope guard. All work stayed doc/asset-only; `chimeway_admin` and tokens.css held zero-drift. The two manual browser accessibility checks were consciously waived by the owner and carry forward as accepted-risk documented gaps (not passes).

**Original goal (for the record):** Critically pressure-test the existing written brand book (`prompts/chimeway-brand-book.md`) and operationalize it into a self-contained, repo-safe, implementation-ready `brandbook/` package with real, programmatically-generated, vector-first artifacts — so Chimeway reads as credible on GitHub / HexDocs / landing pages and future UI/docs/marketing work is accelerated.

**Target features:**
- **Logo system** — multiple programmatically-generated SVG directions to choose from (icon-only, logotype, ≥1 fully-integrated typemark, horizontal lockup, stacked, mono, inverse, favicon/small). No rectangular background cages; mark + wordmark visually unified; primary lockup carries no subtitle.
- **Design tokens** — JSON + CSS variables (light/dark/system, semantic state colors, focus-ring, type/spacing/radius/border/shadow/motion), **reconciled with the existing `chimeway_admin` `--cw-*` tokens** rather than forked.
- **Standalone HTML brandbook** (primary deliverable) — opens via `file://`, responsive, scoped CSS that cannot leak into the repo.
- **Brand voice & UX microcopy** — voice/tone by context, error pattern (what happened / why it matters / how to fix), CTA style, naming rules, good/bad examples.
- **Component states & usage** — hover/focus/active/disabled/loading/error/empty/skeleton/selected; do/don't logo & brand usage.
- **Decision notes + red-team pass** — pros/cons/tradeoffs, analogue, implementation cost, ship/reject/defer, confidence per recommendation; accessible-by-default; research-backed with citations.

**Milestone-start scope decisions (defaults; revisit at requirements gate):**
- **Rollout boundary:** `brandbook/` package + README header + favicon this milestone; full `chimeway_admin` `cw.tokens` re-theme deferred to a follow-on milestone.
- **Font strategy:** system font stack + documented OSS webfont recommendation; wordmark/typemark rendered as SVG outlines (no bundled font binary) — honors repo-size/licensing discipline.
- **Logo directions:** 3–5 fully-worked directions, each with rationale, for user selection.

**Hard taste constraints (non-negotiable):** no background cages, unified mark+wordmark, ≥1 integrated typemark direction, multiple options for the user to pick, no clipart, unique brand-based imagery/type. Existing fonts/colors are a seed, not locked.

**Deliverable discipline:** self-contained in `brandbook/` at repo root; SVG/HTML/CSS/JSON/MD first; no large binaries or new build system unless clearly justified.

Full handoff context preserved in `prompts/brand-book-pressure-test.md`; written brand spec under pressure-test is `prompts/chimeway-brand-book.md`.

**Standing hygiene debt (tracked, not this milestone's deliverable):** 3 red CI lanes on `main` (Example host smoke, TeamPulse journeys, Accrue dunning — `ci-gate` at 12/15; see `.planning/CI-HARDENING-BACKLOG.md`). This milestone is doc/asset-only and does not touch runtime code, so it will not worsen CI.

## Current State

**v1.16 Phase 90 Pipeline Tiering (PR/main/nightly) complete (2026-07-30):** A `schedule:`-driven nightly tier now absorbs the expensive full-matrix, cold-build, and heavy-browser work so the PR path stays fast and single-OTP. A bare `resolve_tiers` setup job computes `otp_matrix` (`["27"]` on `pull_request`, else `["26","27"]`) and `run_nightly` (true on `schedule` or `workflow_dispatch -f run_nightly=true`), feeding `test`'s matrix via `fromJSON()`; the concurrency group is keyed on `github.event_name` with `cancel-in-progress` scoped to `pull_request` so a push can never cancel an in-flight nightly. The heavy Playwright `verify_admin` lane moved to nightly-only and was stripped from `ci-gate` (14→13 lanes) in one atomic commit (a skipped dependency fails `aggregate-gate.sh` identically to a real failure). New nightly-only jobs `nightly_cold_build` (zero cache, cold-build correctness backstop) and `test_floor_1_17` (Elixir 1.17/OTP 27 floor, own `test-floor-` cache namespace), plus a `nightly-gate` aggregate mirroring `ci-gate`'s `aggregate-gate.sh` contract over the four nightly lanes, complete the tier. Locked by 142 contract tests (`release_gate_contract_test.exs` + `ci_observability_contract_test.exs`); verified 4/4 must-haves and proven live (full-nightly dispatch run 30512184143 all green; PR-path run 30512220386 ran exactly one OTP-27 leg). Code review: 0 blockers, 4 advisory warnings (notably WR-01 — the release/`ci-gate` path no longer verifies admin integration until the next nightly, the intended TIER-02 speed tradeoff, worth recording as accepted risk). The phase's code + SUMMARY commits are on `origin/main` (pushed during execution for the live-CI proofs); the review (`b2f766d`) and completion (`1ac2259`) docs commits remain local on `main` until pushed.

**v1.16 Phase 87 CI Observability & Cache Diagnostics complete (2026-07-29):** All 14 CI build lanes now emit a per-job cache hit/miss table, a deps-vs-app recompile count, and a per-step timing table to `$GITHUB_STEP_SUMMARY` via `scripts/ci/obs-recompile.sh` + `scripts/ci/obs-summary.sh` (whitelist-only, never dumps env/secrets), locked by `ci_observability_contract_test.exs` (31 tests). The pre-optimization baseline (~373–395s `main` wall-clock, 373s `install_golden`, ~135s hidden compile in `ecto.create`, dead-flat compile across identical-lock runs) is committed in `.planning/CI-PERF-BASELINE.md` with a run permalink + delta ledger, so Phase 88+ can prove wins by run-link delta. Verified 13/13 must-haves; human-confirmed live render on CI run 30416472070. First of six v1.16 phases (87–92); the three finalization commits remain local on `main` (unpushed).

**v1.15 Brand Identity & Brand Book shipped (2026-07-28, override_closeout):** All six phases (81–86) complete. The `brandbook/` package is self-contained and repo-safe: reconciled `--cw-*` tokens (CSS + DTCG JSON), a human-selected optimized-SVG logo lockup family with favicon/OG derivatives, a `file://`-safe scoped HTML brandbook (tokens, component states, live theme toggle + contrast matrix, brand voice, do/don't), README + ExDoc brand wiring with v1.14 contracts green, and an accessibility audit closed via an offline WCAG contrast calc + cited exemptions + research/red-team notes + a machine-enforced scope guard. 30/32 requirements complete; the milestone held doc/asset-only discipline with zero drift on `chimeway_admin`/`tokens.css`. **Accepted-risk carry-forward:** A11Y-03 (focus-not-obscured) and A11Y-04 (CVD emulation) manual browser checks were owner-waived — a short in-browser pass would close them. Note: the v1.15 branch history (Phases 85–86, 33 commits) remains local on `main` and unpushed; the `pr-gate` ruleset requires it to land via PR, and the v1.15 git tag is local-only until that history reaches the remote.

**v1.15 Phase 81 (2026-07-10):** Design-token reconciliation & documentation landed. `brandbook/tokens/tokens.css` is the canonical, copy-safe `--cw-*` SSOT (de-scoped from the shipped `@layer cw.tokens` / `:where(.chimeway-admin)` wrapper to bare `:root` + `[data-theme]` + `@media`), mirrored by a hand-authored DTCG `brandbook/tokens/tokens.json`, with every sub-primitive divergence recorded as DOCUMENTED/DEFERRED in `notes/decision-log.md` (DEFERRED items deferred to a future ADMIN-RETHEME-01 milestone). The shipped admin CSS was never patched (byte-identical, verified). Downstream v1.15 artifacts (HTML brandbook, docs) consume these token names as a cross-phase contract.

**v1.14 Public Truth and Verification Architecture shipped (2026-07-03):** All four phases (77–80) are complete and verified. Phase 77 recorded the root-only package model and separated planning-vs-package tag namespaces (TRUTH-04). Phase 78 aligned root package metadata, release manifest, changelog, HexDocs source refs, README install constraint, canonical repository/source links, and sibling install-status copy, enforced by ExUnit release-gate + doc contracts and a deterministic local Hex unpack proof (env-scoped Sigra override keeps the prod build Hex-legal) (TRUTH-01/02/03). Phase 79 rewrote the README as an additive-superset decision page with public-API trigger-to-explain snippets and byte-identical source/packaged-README contract locks (DOCS-14/15/16/17, ADPT-01). Phase 80 split CI into a fast always-on `pr-gate` plus a push/dispatch-only 14-lane `ci-gate`, proved the anti-pending topology on a live PR, added cache coverage, and extracted complex CI logic to `scripts/ci/*.sh` (CI-01/02/03/04/05). All 14 requirements satisfied; open-artifact audit clear.

**Known fast-follow (out of v1.14 scope):** `main` currently fails `mix ci.lint` — ~18 pre-existing unformatted committed files plus vulnerable-dep audit flags, none touched by Phase 80. Now that `pr-gate` (which includes `Lint`) is the required PR check, this drift blocks PR merges until a `mix format` + dependency-bump fast-follow lands.

**v1.13 Storage Isolation and Upgrade Path shipped (2026-07-02):** New installs can generate and run Chimeway-owned tables in a dedicated `chimeway` Postgres schema by default; existing public-schema installs remain supported through explicit `prefix: false` compatibility. Runtime prefix behavior is verified across trigger, trace, admin, inbox, recovery, workflow, digest, webhook, policy, and worker paths, with docs, demo proof, and `mix verify.runtime_prefix` / CI parity in place.

**v1.11 Operator Console Polish & Hardening shipped (2026-06-04):** The optional `chimeway_admin` surface is now a coherent host-mounted operator console with seven-page route truth, scoped design tokens and themes, recovery/auth/tenancy hardening, redacted DTO/rendered-HTML contracts, a canonical integration guide, browser smoke, `mix verify.admin`, CI parity, and a passed milestone audit.

**v1.11 Phase 68 Admin Truth Alignment complete (2026-06-04):** The shipped `chimeway_admin` route map, demo copy, route helpers, and LiveView/host-mounted tests now align around the real seven-page operator console: Command Center, Trace Lookup, Trace Detail, Feed Debug, Definitions, Health, and Recovery.

**v1.11 Operator Console Polish & Hardening active (2026-06-04):** The milestone hardens the already-emerging `chimeway_admin` command center as a production operator surface. It includes SEED-004 persona/JTBD and SEED-002 adoption-surface context. Scope is deliberately not a generic CRUD admin or SaaS control plane; it is an embedded, host-authenticated LiveView console for explaining notification outcomes and taking safe recovery actions.

**v1.10 Ecosystem Completions shipped (2026-06-04):** Threadline telemetry reporter + audit-ledger proof (ECOS-08), Sigra auth notification flows with redacted traces and clean-CI binding proof (ECOS-09), Sigra auth blueprint and demo host proofs (ECOS-10, DEMO-09/10), Threadline/Sigra integration guides with doc-contract truth locks (DOCS-10/11), and `mix verify.threadline` / `mix verify.sigra` gates in CI + MAINTAINING (GATE-07). Phase 67 closed the audit gap by repinning Sigra CI to `szTheory/sigra@62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`, adding vacuous-pass guards, fixing the Sigra guide API shape, and recording CI proof run `26925122158` / job `79433504716`.

**v1.9 Adopter Complete shipped (2026-05-30):** Accrue dunning vertical slice (Phases 58–60) — billing events drive Chimeway dunning workflows with Outcome Signal termination; blueprint recipe, demo proof, golden-path guide, and `mix verify.accrue` gate (ECOS-06/07, DEMO-07, DOCS-08/09, GATE-05 Accrue). Hex release automation via Release Please + 9-lane ci-gate + gated Hex publish (GATE-06, Phase 60.1). INBX inbox UI vertical slice (Phases 61–62) — headless API polish, optional `chimeway_inbox` package, demo mount, integration guide, and `mix verify.inbox` octet (INBX-01/02, DEMO-08, DOCS-08/09 Inbox, GATE-05 Inbox). **264+ doc-contract tests** green; Accrue and inbox verify gates pass.

**v1.8 Ecosystem Integration Blueprints shipped (2026-05-30):** Phases 54–57, 57.1 — Mailglass adapter, inbound feedback bridge, blueprint recipe, demo proof, integration docs, and `mix verify.mailglass` gate.

Prior: **v1.7 READ + Adoption Polish** shipped 2026-05-29 (Phases 48–53). Read/unread workflow glue, journey CI (`mix verify.journeys`), adoption docs, and demo host proof remain the adoption foundation.

## Product Arc

- `v1.3 Workflow Journeys` — durable, explainable multi-step workflows and escalations (shipped 2026-04-30).
- `v1.4 Channel Feedback Loops` — outbound channels plus inbound receipts/webhooks feeding workflow progression (shipped 2026-05-08).
- `v1.5 Adoption Surface` — installer, golden-path docs, reference recipes, demo trace path, operator admin MVP, release gates (shipped 2026-05-29).
- `v1.6 Consumer Journey Proof` — TeamPulse demo, deterministic seeds, journey CI, one-command spin-up (shipped 2026-05-29).
- `v1.7 READ + Adoption Polish` — read/unread workflow glue, natural escalation demo, adoption-evidence tail (shipped 2026-05-29).
- `v1.8 Ecosystem Integration Blueprints` — Mailglass-first adapter, inbound feedback bridge, reference recipe, demo proof, integration docs, and verify gate (shipped 2026-05-30).
- `v1.9 Adopter Complete` — Accrue dunning blueprint, INBX inbox UI package, Hex release automation, verify.accrue/inbox gates (shipped 2026-05-30).
- `v1.10 Ecosystem Completions` — Threadline telemetry bridge + Sigra auth flows (shipped 2026-06-04).
- `v1.11 Operator Console Polish & Hardening` — embedded admin command center, design system, safety/privacy contracts, and admin verify gate (shipped 2026-06-04).
- `v1.12 Quality Readiness Audit` — planning-only audit pass that identified storage isolation, release/package truth, CI/DX, README, tenant, privacy, and reliability seams (2026-06-30).
- `v1.13 Storage Isolation and Upgrade Path` — Chimeway-owned Postgres schema support and upgrade-safe public compatibility (shipped 2026-07-02).
- `v1.14 Public Truth and Verification Architecture` — package/release truth, README/docs front door, fast PR gate, full release gate parity, and clean adoption proof (shipped 2026-07-03).

## Next Milestone Goals

**Current milestone:** v1.14 Public Truth and Verification Architecture

**Target goals:**
- Make the public package/release story truthful and contract-tested.
- Make README and first-hop docs answer the right adopter jobs-to-be-done before linking deeper.
- Split contributor PR feedback from full release verification without weakening release/publish gates.
- Prove the install/package/docs path from a clean consumer perspective.

**Included seeds:** SEED-002 (Adoption Surface & Reference Flows), SEED-004 (Personas & DX Roadmap).

**Explicitly deferred:** tenant spine redesign, dynamic per-tenant database prefixes, automatic production data moves, Oban optionality behavior changes, recursive redaction refactor, admin redesign, new ecosystem integrations, inbox PubSub polish, broad channel matrix, full TeamPulse SaaS shell, generic CRUD admin, template editing, provider configuration UI, visual workflow editor, arbitrary bulk recovery, cross-app SaaS console, cohort analytics, and publishing `chimeway_admin`/`chimeway_inbox` unless separately approved.

### Shipped v1.13 Features (Validated)

- Static storage prefix config supports default `prefix: "chimeway"` and explicit `prefix: false` public legacy mode, with invalid and missing values failing early.
- `mix chimeway.gen.migrations` now emits default schema-aware migrations while preserving explicit public/legacy generation.
- Generated migrations create the selected schema when needed and qualify Chimeway tables, indexes, references, alters, drops, and raw SQL.
- Runtime DB paths honor configured storage prefix across trigger fanout, idempotency, traces, admin, inbox, recovery, workflows, signals, digests, webhooks, policies, preferences, and workers.
- Docs cover installation, golden path, troubleshooting, manual move/rollback guidance, and Oban-prefix separation.
- Demo host and generated-prefixed runtime proof show trigger-to-trace rows land in the configured `chimeway` schema.
- `mix verify.runtime_prefix`, installer golden proof, doc contracts, release-gate contracts, and CI parity cover storage isolation and public legacy compatibility.

### Shipped v1.10 Features (Validated)

- Threadline telemetry reporter bridges Chimeway lifecycle outcomes into Threadline `audit_actions` with redacted metadata and correlation IDs (ECOS-08)
- Sigra auth events dispatch Chimeway notifiers for magic-link/auth flows with sensitive-token redaction at the integration boundary (ECOS-09)
- Sigra auth reference blueprint documents notifier authoring, event wiring, and Chimeway-vs-Sigra responsibility split with doc-contract truth lock (ECOS-10)
- Demo host proves Threadline audit correlation and Sigra auth notification flow with operator trace inspectability (DEMO-09/10)
- Threadline and Sigra golden-path guides are locked by doc-contract tests and listed in HexDocs extras (DOCS-10/11)
- `mix verify.threadline` and `mix verify.sigra` run in CI, are counted by release-gate contracts, and appear in the MAINTAINING pre-ship checklist (GATE-07)
- Phase 67 closed the ECOS-09 audit gap with clean-CI proof, partner SHA repin, and vacuous-pass guards

### Shipped v1.11 Features (Validated)

- Multi-page admin command center route/documentation truth alignment across demo copy, route helpers, LiveView tests, and host-mounted tests (ADMIN-01/02/03)
- Scoped packaged admin design tokens, light/dark/system theme contracts, responsive shell primitives, long-content protections, and reduced-motion-safe interactions (DES-01/02/03/04)
- Recovery actions require explicit confirmation, re-authorize at event time with tenant/resource/candidate context, handle stale/noop candidates, and persist allowlisted operator evidence (SAFE-01/02/03/04)
- Admin read models and rendered LiveViews preserve redaction boundaries while still exposing useful masked and explainable operator facts (PRIV-01/02)
- Operator copy distinguishes sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure; Definitions UI is locked to DB-inferred persisted history (EXPL-01/02)
- Canonical admin integration guide, doc contracts, `mix verify.admin`, `verify_admin` CI lane, release-gate parity, and Playwright Chromium browser smoke (DOCS-12, GATE-08, SMOKE-01)

### Shipped v1.9 Features (Validated)

- Accrue `invoice.payment_failed` starts multi-step dunning workflow; `invoice.paid` terminates via Outcome Signal — no host glue (ECOS-06)
- Accrue dunning reference blueprint with doc-contract truth lock and billing-state split language (ECOS-07)
- Demo host Accrue dunning proof with operator traces at `/admin/chimeway` (DEMO-07)
- Golden-path Accrue integration guide with doc-contract tests (DOCS-08/09 Accrue)
- `mix verify.accrue` CI gate + MAINTAINING pre-ship septet (GATE-05 Accrue)
- Release Please SSOT, 9-lane ci-gate, automerge + recovery publish path (GATE-06)
- Headless inbox API: `unread_count/1`, paginated `list_for_recipient/2`, stable DTO maps (INBX-01)
- Optional `chimeway_inbox` package: Auth behaviour, router macro, bell-dropdown LiveView (INBX-02)
- Demo host `/inbox` mount with journey proof for list → mark_read → badge (DEMO-08)
- Inbox integration guide with doc-contract tests (DOCS-08/09 Inbox)
- `mix verify.inbox` CI gate + MAINTAINING pre-ship octet (GATE-05 Inbox)

### Shipped v1.8 Features (Validated)

- `Chimeway.Adapters.Mailglass` optional dep with runtime config, outbound `deliver/2`, tenancy stamp, error classification, redacted success meta (ECOS-01)
- Shared `Chimeway.Adapter.ContractTest` coverage for Mailglass including simulate_error and executor email routing (ECOS-02)
- `provider_message_id` on attempt rows + adapter-native webhook parse seam (ECOS-03 spine)
- Mailglass webhook verify/resolve/normalize/dedup callbacks mapping Anymail events to `:delivered/:bounced/:failed` (ECOS-03/04)
- ECOS-05 reference blueprint with doc-contract truth lock — Chimeway orchestrates when/why, Mailglass handles templating
- DEMO-06: TeamPulse invite email through Mailglass with `/admin/chimeway` operator trace proof
- DOCS-06 golden-path integration guide (dependency → config → trigger → delivery → inbound feedback)
- DOCS-07 doc-contract locks guide truth including webhook call-shape guards (Phase 57.1)
- GATE-04: `mix verify.mailglass` CI job + MAINTAINING pre-ship sextet

### Shipped v1.7 Features (Validated)

- `cancel_signals` DSL on `wait_until` progress rules with declaration-time validation (READ-01)
- `enter_waiting/6` auto-populates `pending_signals` from progress rules — no host glue
- Inbox `mark_read`/`mark_seen` emit durable `chimeway.notification.read`/`.seen` signals via `Signal.track/4` (READ-02)
- Signal-routed early resume from `:waiting` with explainable `signal_received` transition (READ-03)
- TeamPulse payment escalation demo uses READ-driven progression — no `PendingWebhookAdapter` choreography (DEMO-03)
- Mention-escalation reference recipe documents read-cancel plus time-based `wait_until` fallback (DEMO-04)
- JOUR-06 read-cancel proof on Sync and Oban due-worker paths plus time-fallback
- JOUR-07/08 admin persona traces for Sam suppression and Morgan escalation
- Demo host README and `mix demo.up` moduledoc aligned to shipped READ behavior (DOCS-04/05)
- GATE-03: `mix verify.journeys` covers JOUR-01..08 (10 tests); MAINTAINING.md pre-ship quintet updated

### Shipped v1.6 Features (Validated)

- TeamPulse demo domain with three persona JTBD notifiers (`teampulse.invite_sent`, `teampulse.password_reset`, `teampulse.payment_reminder`)
- Deterministic, idempotent `DemoHost.Seeds` + `mix demo.seed` (adopter-copyable public API)
- `mix demo.up` (root) and `mix demo.admin` (demo host) one-command spin-up with admin URL banner
- Journey E2E suite: invite delivery, suppression explainability, webhook workflow progression
- Host-mount `chimeway_admin` integration test through demo host router
- GATE-02: `mix verify.journeys` CI job + pre-ship quintet in MAINTAINING.md (v1.6 foundation, JOUR-01..05)
- GATE-03: expanded journey suite JOUR-06..08 — READ read-cancel + admin persona traces (v1.7, 10 tests)

### Shipped v1.5 Features (Validated)
- `mix chimeway.gen.migrations` (or install task) with idempotent golden-diff verification
- Golden-path integration doc: fresh host → trigger → trace query → optional webhook feedback
- Two or more reference recipes (password-reset support trace; feedback escalation workflow)
- Demo host trace-inspection path documented beyond webhook-only E2E
- Optional `chimeway_admin` MVP: redacted trace lookup by user/correlation with host auth behaviour
- Doc-contract gates and `mix verify.example` in release checklist
- Persona/JTBD-driven DX alignment (SEED-004: Feature Developer, Support Operator, Product Manager)

**Included seeds:** SEED-002 (Adoption Surface & Reference Flows), SEED-004 (Personas & DX Roadmap)

**Explicitly deferred:** read/unread auto-branching, full SEED-003 ecosystem matrix, vendor adapters in core, bell inbox UI, marketing campaign tooling

## Out of Scope

- Hosted, multi-tenant notification SaaS or open-core billing model — Chimeway is embedded OSS infrastructure.
- Reimplementing channel/provider foundations such as Swoosh or Oban — Chimeway integrates with them.
- Marketing automation, campaigns, or customer-engagement journey tooling — Chimeway is transactional/product notification focused.
- Hard-coding one SMS/push vendor — adapter seams remain replaceable.
- Broad channel-matrix expansion before orchestration behavior is mature — timing, batching, and recovery are the higher-leverage gaps for current adopters.

## Context

This project is being initialized from a detailed idea brief and prior-art synthesis focused on an ecosystem gap in Elixir/Phoenix notifications. Existing channel primitives are strong, but teams repeatedly rebuild routing, fanout, preferences, idempotency, read/seen state, retries, digests, and operator diagnostics. Chimeway targets that gap with an idiomatic, explicit, inspectable model that avoids opaque framework magic.

Prior context includes:
- Product and brand positioning emphasizing local-first ownership and explainable delivery.
- Domain research mapping lessons from Noticed (Rails), Laravel Notifications, Symfony Notifier, and Elixir channel libraries.
- Engineering DNA from sibling OSS libraries: strict CI, verification entrypoints, contract tests, and release hygiene.
- Operator IA intent centered on timeline tracing, redaction, and support-friendly debugging.
- Host-app integration seam guidance for auth, tenancy, URL generation, and correlation IDs.
- The shipped v1.0 milestone established the durable spine, policy checkpoints, telemetry correlation, safe adapter resolution, and transactional Oban dispatch as the baseline to build from.
- The shipped v1.1 milestone established production-trust behavior across preferences, reliability, observability, and integration documentation.
- v1.4 shipped multi-channel outbound contracts and inbound feedback loops with E2E proof on a reference Phoenix host.
- Next value jump is adoption surface: reference flows, integration docs, and operator UX — not more channel matrix expansion.
- Adopter assessment (2026-05-28): ~82% done for embedded-notification scope — **resolved by v1.5** (installer task, golden path, operator UI, demo trace path, release gates).
- Adopter assessment (2026-05-29): ~88–92% done post-v1.6 — adoption evidence (TeamPulse demo, seeds, `mix demo.up`, `mix verify.journeys`, host-mount admin E2E) resolved the pre-adopter confidence gap.
- v1.9 Adopter Complete shipped 2026-05-30 — Accrue dunning + INBX inbox UI + Hex release automation; all three SEED-004 personas now have adoptable paths.
- Adopter assessment post-v1.9: ~98% for embedded-notification scope — Accrue composition and end-user inbox UI proven; Threadline/Sigra completed that ecosystem wedge in v1.10.
- v1.11 Operator Console Polish & Hardening shipped the optional admin console polish/hardening wedge: command center, design system, safe recovery, redaction/explainability contracts, docs, browser smoke, and `mix verify.admin`.
- v1.12 quality-readiness research identified database/schema ownership as the highest-leverage architectural cleanup before more adoption polish or ecosystem breadth.
- v1.14 focuses on public trust rather than runtime expansion: docs, package metadata, release automation, and CI gates must say the same thing and be reproducible by maintainers and contributors.

## Constraints

- **Tech Stack**: Elixir/Phoenix/Ecto-first with Oban and Swoosh integration seams — align with existing ecosystem strengths.
- **Architecture**: Stable notification keys (for example, `comment.created`) must be persisted as durable identity — avoid module-name coupling in data.
- **Data Ownership**: Host app database is source of truth for events, inbox state, deliveries, attempts, deferrals, and digest batches — no hosted control plane.
- **Database Hygiene**: Chimeway-owned tables should live in a dedicated Postgres schema for new installs; public-schema use is an explicit compatibility mode.
- **Composability**: Channel/provider integrations must use replaceable adapter behaviours — avoid hard vendor lock-in.
- **Operability**: Redacted, queryable traces must exist for support and debugging — explainability is core value, not optional polish.
- **Quality Bar**: Named `mix verify.*` and `mix ci.*` workflows, compile warnings as errors, and documented release checks are mandatory.
- **Release Truth**: Public package metadata, docs, release automation, and README install claims must remain aligned by executable contracts.
- **Contributor DX**: Fast PR checks should be clear and actionable, while release/publish checks remain exhaustive and reproducible locally.
- **Admin UI**: `chimeway_admin` remains an optional, host-mounted LiveView package; core stays Phoenix-free and owns redacted read models/recovery APIs.
- **Scope**: Orchestration and explainability remain higher leverage than broad channel expansion.
- **Scope**: v1.9 shipped Accrue dunning + INBX inbox UI + Hex automation; v1.10 shipped the Threadline/Sigra remainder; v1.11 shipped operator console polish and hardening.
- **Compatibility**: Version baseline should track active Phoenix/Elixir LTS norms in sibling repositories.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Persist stable notification keys as data identity | Survives module renames and preserves historical traceability | Implemented in Phase 01 notifier contract + persistence flow |
| Local-first embedded architecture | Host apps need ownership, auditability, and composability without SaaS dependency | Implemented (Phases 01-03) |
| Keep core explicit and inspectable | Elixir users expect clear behaviours and low magic | Implemented in Phase 01 trigger and inbox APIs |
| Treat explainability as product surface | "Why wasn't this sent?" is the primary operator differentiator | Implemented via durable traces and Phase 08 outcome surfacing |
| Integrate channel/job primitives instead of replacing them | Swoosh/Oban already solve core delivery substrates well | Implemented in Phase 02 (Swoosh/Adapter) and Phase 03/12 (Oban) |
| Start with durable spine + one channel slice | Fastest path to validate end-to-end architecture and DX | Durable spine completed in Phase 01 |
| Enforce OSS release hygiene as executable contracts | Maintainers need deterministic, repeatable release confidence | Implemented in Phase 05 docs/test/release hardening |
| Transactional Oban Dispatch | Prevent orphaned pending deliveries on transaction failure | Implemented in Phase 12 |
| String-safe adapter lookup | Prevent atom table exhaustion from runtime channel strings | Implemented in Phase 11 |
| Persisted policy controls | Keep suppression explicit, explainable, and durable across planning and perform gates | Implemented in Phase 13 |
| Durable attempt history and convergence | Make retries and final outcomes inspectable under concurrency and failure | Implemented in Phase 14 |
| Tenancy-aware trace queries | Preserve host ownership boundaries in observability surfaces | Implemented in Phase 15 |
| Integration docs as product surface | Lower host-app adoption risk with explicit setup and adapter guidance | Implemented in Phase 16 |
| Prioritize orchestration before channel breadth in v1.2 | Scheduling, batching, rendering, and recovery create larger product value than adding more providers now | Shipped in v1.2 |
| Keep canonical lifecycle identity through orchestration features | Deferred, digested, recovered, and emitted flows should stay explainable on durable rows | Implemented across phases 17-23 |
| Persist orchestration and rendering declarations as durable data | Replay, recovery, and preview should not depend on notifier module re-entry | Implemented across phases 21-23 |
| Prioritize workflow journeys before channel breadth in v1.3 | Multi-step SaaS notification behavior is the next major adoption gap after single-notification orchestration | Shipped in v1.3 |
| Atomic webhook ingress via Multi+Oban | Prevent orphaned async feedback processing on partial failure | Shipped in v1.4 (Phase 33) |
| Canonical `chimeway.delivery.*` vocabulary | Align normalization, signals, and trace projection for auditability | Shipped in v1.4 (Phase 34) |
| Generic outbound channel behaviour | SMS/Push/Chat without vendor lock-in; per-channel render contracts | Shipped in v1.4 (Phase 29) |
| v1.5 before channel matrix or ecosystem plugins | Engine credible at v1.4 close; adoption friction is the bottleneck | Shipped 2026-05-29 (Phases 35-41) |
| Defer read/unread-driven workflow branching to v1.7 READ | `pending_signals` not populated on `wait_until`; inbox read does not emit signals | Shipped v1.7 (Phases 48–49) |
| `cancel_signals` validated at declaration time | Runtime validation would hide notifier authoring errors | Shipped v1.7 Phase 48 (D-06) |
| `pending_signals` column is sole durable source | Avoid mirroring into status_context for replay consistency | Shipped v1.7 Phase 48 |
| Inbox signals on first transition only | Idempotent read/seen should not duplicate signal rows | Shipped v1.7 Phase 49 |
| Lifecycle :ok independent of Signal.track | Separate transactions per D-07 — inbox state must not fail on signal errors | Shipped v1.7 Phase 49 |
| signal_received context is event_name only | No payload/notification_id in operator trace projection (READ-03) | Shipped v1.7 Phase 49 |
| READ-driven demo replaces staged webhook seeds | Staged choreography masked engine gap | Shipped v1.7 Phase 50 |
| JOUR-06 covers Sync + Oban due-worker paths | Single-path proof insufficient for async escalation | Shipped v1.7 Phase 51 |
| GATE-01 scoped doc-contract gates separate from default ci | Fast core feedback + explicit pre-ship quartet | Shipped Phase 41 |
| verify.example additive subprocess chain | Demo host E2E first, chimeway_admin second | Shipped Phase 41 |
| v1.6 journey CI separate from default ci | Fast core feedback; journey proof is explicit pre-ship gate | Shipped v1.6 |
| DemoHost.Seeds as adopter-copyable API | Seeds use Chimeway.trigger/3, not test fixture inserts | Shipped v1.6 |
| Defer Playwright for admin smoke | Host-mount ConnTest + LiveViewTest sufficient for JOUR-04 | Shipped v1.6 |
| Mailglass-only v1.8 scope | Accrue/Threadline/Sigra deferred — prove one ecosystem composition deeply first | Shipped v1.8 |
| Runtime config only in Mailglass adapter | No compile-time secrets; config read at call time via Application.get_env/3 | Shipped v1.8 Phase 54 |
| Dual lifecycle Chimeway attempts + Mailglass ledger | Intentional — Chimeway owns orchestration explainability | Shipped v1.8 Phase 54 |
| Mailglass test config unconditional in config/test.exs | Config loads before dep compile | Shipped v1.8 Phase 54 |
| Journey suite keeps Logger adapter; Mailglass isolated | `@moduletag :mailglass` selective CI — no journey regression | Shipped v1.8 Phase 56 |
| Guide vs blueprint doc separation | Introduction guide owns end-to-end path; blueprint is focused recipe | Shipped v1.8 Phase 57 |
| Webhook doc-contract explicit string list for multi-token patterns | ~w sigil splits multi-word forbidden patterns incorrectly | Shipped v1.8 Phase 57.1 |
| Accrue-only v1.9 SEED-003 slice | Mailglass vertical-slice pattern reusable; prove billing composition before Threadline/Sigra | Shipped v1.9 |
| Threadline/Sigra complete SEED-003 in v1.10 | After Mailglass and Accrue, finish ecosystem matrix with audit bridge + auth flows, docs, demo proof, and named gates | Shipped v1.10 |
| Partner-owned Sigra integration module + pinned SHA | Keep integration in Sigra repo per Accrue precedent; Chimeway CI pins to a SHA containing `Sigra.Integrations.Chimeway` | Shipped v1.10 Phase 67 |
| Verify lanes must fail loud on zero-test partner integrations | Release gates now assert module/function presence and per-lane test-count floors | Shipped v1.10 Phase 67 |
| Optional `chimeway_inbox` Phoenix package | Core `lib/chimeway` stays Phoenix-free; clone chimeway_admin mount pattern | Shipped v1.9 Phase 61 |
| Accrue runtime: false + manual TestRepo bootstrap | Avoid OTP app boot blocking default mix test (Mailglass 54-01 precedent) | Shipped v1.9 Phase 58 |
| Release Please + ci-gate before Hex publish | lattice_stripe pattern; no manual mix hex.publish | Shipped v1.9 Phase 60.1 |
| MAINTAINING pre-ship octet (8 verify gates) | Accrue + inbox gates complete the adopter verify surface | Shipped v1.9 Phase 62 |
| v1.11 admin milestone pairs UI polish with safety contracts | Recovery is action-bearing, so visual polish must ship with auth, tenancy, redaction, docs, and verification | Shipped v1.11 |
| Keep `chimeway_admin` as optional LiveView package | Matches LiveDashboard/Oban Web ergonomics and keeps core Phoenix-free | Shipped v1.11 |
| Admin UI is process explainability, not table CRUD | Operators need to answer what happened and why, not edit raw lifecycle rows | Shipped v1.11 |
| Default new installs to a `chimeway` Postgres schema | Host apps should not get public-schema table sprawl from an embedded infrastructure library | Shipped v1.13 |
| Preserve public-schema installs through explicit legacy mode | Existing users must not be silently migrated or forced through unsafe data moves | Shipped v1.13 |
| Use generated explicit prefixes in copied migrations | Host migrations stay deterministic and do not require `mix ecto.migrate --prefix` migration-history surprises | Shipped v1.13 |
| Do not build dynamic per-tenant DB prefixes in v1.13 | Chimeway already has tenant identity in domain data; prefix-per-tenant would multiply worker, Oban, uniqueness, and recovery failure modes | Shipped v1.13 |
| Root-only Hex package for v1.14 truth cleanup | Only root `chimeway` is currently published; advertising sibling packages as Hex releases would create adopter confusion | Validated Phase 77 |
| Separate planning milestones from package release tags | Planning `v1.x` history and SemVer package releases carry different meanings and should not be conflated | Validated Phase 77 |
| Two-tier CI gate model | Contributors need fast PR feedback; maintainers still need full release confidence before publish/automerge | Shipped v1.14 Phase 80 (pr-gate + 14-lane ci-gate, live PR anti-pending proof) |
| README as adoption decision page | The first public surface should answer adopter JTBD and prove explainability, not expose internals or stale stub links | Shipped v1.14 Phase 79 (additive-superset README, byte-identical source/packaged contract lock) |

## Archived Milestone Context

<details>
<summary>v1.13 Storage Isolation and Upgrade Path planning context</summary>

### Milestone Scope

Make Chimeway a respectful guest in host PostgreSQL databases by defaulting new installs to a dedicated `chimeway` schema while preserving explicit public-schema compatibility for existing installs.

### Delivered Features

- Static storage-prefix config: `prefix: "chimeway"` for isolated installs and `prefix: false` for explicit public-schema legacy mode.
- Schema-aware migration generation across 31 canonical migrations, with prefixed/public fixtures, idempotency proof, and DB execution/rollback contracts.
- Runtime prefix propagation across trigger fanout, duplicate detection, traces, admin, inbox, recovery, workflows, signals, digests, webhooks, policies, preferences, and workers.
- Storage-prefix docs, manual move and rollback guidance, Oban-prefix caveats, demo-host proof, and release-gate/doc-contract coverage.
- Generated prefixed migration runtime proof closing GATE-01-GAP.

### Validated Requirements Snapshot

- PFX-01..04, MIG-01..04, RUN-01..04, UPG-01..03, DOCS-01/02, DEMO-01, GATE-01, GATE-01-GAP — all satisfied (20 requirements).

### Close Notes

- Audit status: `tech_debt` with no blockers.
- Follow-up: refresh Phase 74 and Phase 76 validation metadata; consider extending generated-migration runtime proof beyond trigger-to-trace for future schema-sensitive table changes.

</details>

<details>
<summary>v1.9 Adopter Complete planning context</summary>

### Milestone Scope

Close last adopter-facing gaps: Accrue dunning blueprint (SEED-003 slice) and end-user inbox UI (SEED-004 INBX slice), plus Hex release automation.

### Delivered Features

- Accrue billing events drive dunning workflow lifecycle with Outcome Signal termination (ECOS-06).
- Accrue blueprint recipe + demo host proof + golden-path guide + verify.accrue gate (ECOS-07, DEMO-07, DOCS-08/09, GATE-05).
- Release Please + ci-gate + gated Hex publish (GATE-06).
- Headless inbox API + chimeway_inbox package + demo mount + guide + verify.inbox gate (INBX-01/02, DEMO-08, DOCS-08/09, GATE-05 Inbox).
- Phase 62.1 Nyquist + REQUIREMENTS traceability closure.

### Validated Requirements Snapshot

- ECOS-06/07, DEMO-07/08, INBX-01/02, DOCS-08/09, GATE-05/06 — all satisfied (10 requirements).

</details>

<details>
<summary>v1.8 Ecosystem Integration Blueprints planning context</summary>

### Milestone Scope

Prove Chimeway composes with szTheory ecosystem via first-class Mailglass adapter, inbound feedback bridge, reference blueprint, demo proof, and release gates.

### Delivered Features

- `Chimeway.Adapters.Mailglass` outbound delivery with contract tests (ECOS-01/02).
- Inbound webhook pipeline with `provider_message_id` correlation and Signal-driven progression (ECOS-03/04).
- ECOS-05 blueprint recipe + DEMO-06 demo host Mailglass proof.
- DOCS-06/07 integration guide with doc-contract truth lock; Phase 57.1 closed webhook example gap.
- GATE-04: `mix verify.mailglass` + MAINTAINING pre-ship sextet.

### Validated Requirements Snapshot

- ECOS-01..05, DEMO-06, DOCS-06/07, GATE-04 — all satisfied (9 requirements).

</details>

<details>
<summary>v1.7 READ + Adoption Polish planning context</summary>

### Milestone Scope

Connect inbox read/unread state to workflow progression and close adoption-evidence gaps in demo, docs, and journeys.

### Delivered Features

- `wait_until` auto-populates `pending_signals` from `cancel_signals` progress rules (READ-01).
- Inbox `mark_read`/`mark_seen` emit durable signals routing workflow progression (READ-02/03).
- TeamPulse payment escalation uses READ-driven progression; mention-escalation recipe published (DEMO-03/04).
- Journey CI: JOUR-06 read-cancel (Sync + Oban), JOUR-07/08 admin persona traces.
- Doc truth + GATE-03 expanded journey suite (10 tests).

### Validated Requirements Snapshot

- READ-01..03, DEMO-03/04, JOUR-06..08, DOCS-04/05, GATE-03 — all satisfied (11 requirements).

</details>

<details>
<summary>v1.6 Consumer Journey Proof planning context</summary>

### Milestone Scope

Realistic TeamPulse demo domain with deterministic seeds, one-command admin spin-up, and shift-left journey proof in CI.

### Delivered Features

- TeamPulse notifiers (invite, password reset, payment escalation) with stable notification keys.
- `DemoHost.Seeds` idempotent API + `mix demo.seed` / `mix demo.up` / `mix demo.admin`.
- Journey E2E suite (JOUR-01..05) + host-mount admin integration test.
- `mix verify.journeys` CI job + MAINTAINING.md pre-ship quintet.

### Validated Requirements Snapshot

- DEMO-02, SEED-01, CMD-01, JOUR-01..05, GATE-02 — all satisfied.

</details>

<details>
<summary>v1.5 Adoption Surface planning context</summary>

### Milestone Scope

Make Chimeway adoptable off the lot: installer truth, golden-path docs, reference recipes, demo trace path, optional operator trace MVP, and release doc-contract gates.

### Delivered Features

- `mix chimeway.gen.migrations` with golden-diff and idempotency CI contracts.
- Golden-path guide: dependency → migrations → trigger → trace → optional webhook feedback.
- Journey guide doc-truth rewrite with doc-contract tests.
- Password-reset support trace and feedback escalation reference recipes.
- Demo host IEx trace path without provider webhooks.
- `chimeway_admin` MVP: redacted trace lookup with host auth behaviour.
- GATE-01: `mix ci.verify_gates`, `verify.example` CI job, MAINTAINING.md pre-ship quartet.

### Validated Requirements Snapshot

- INST-01/02, DOCS-01/02/03, RECP-01/02, DEMO-01, OPER-01/02, GATE-01 — all satisfied.

</details>

<details>
<summary>v1.4 Channel Feedback Loops planning context</summary>

### Milestone Scope

Extend Chimeway from email-only outbound delivery to multi-channel contracts with inbound provider feedback that drives workflow progression and operator auditability.

### Delivered Features

- `Chimeway.Rendering.Channel` behaviour and SMS/Push/Chat channel modules with registry resolution.
- Webhook ingestion (`Chimeway.Webhooks.process/4`), ingress durability, and `ProcessFeedbackWorker`.
- Feedback-driven progression via `Chimeway.Signal.track/4` and sync workflow progression.
- Operator traces with `:webhook_received` and workflow transition projection.
- `examples/chimeway_demo_host` E2E proof on real Oban queues.

### Validated Requirements Snapshot

- CHAN-01/02: Generic outbound adapters and per-channel render contracts.
- FEED-01/02: Webhook ingestion and canonical delivery outcomes.
- FLOW-01/02: Signals and outcome-based workflow progression from feedback.
- TRAC-01/02: Operator traces link webhooks to journey steps.

</details>

<details>
<summary>v1.2 Delivery Orchestration planning context</summary>

### Milestone Scope

Turn Chimeway from a durable notification engine into a product-grade notification layer that can decide not just whether to send, but when, how, and in what grouped form.

### Delivered Features

- Delivery windows and recipient-timezone-aware quiet-hours deferral.
- Scheduled resume and digest accumulation/emission over canonical delivery rows.
- Durable render identity, validated render contracts, and local preview tooling.
- Recovery/reconciliation flows plus grouped outcome analytics.

### Validated Requirements Snapshot

- Delivery planning can persist immediate, deferred, and digest-held behavior with explainable reasons.
- Deferred rows resume safely without duplicating canonical lifecycle history.
- Digest generation and explainability are verified end to end for Oban-backed scheduling.
- Rendering identity, preview, recovery, and outcome analytics all operate from durable persisted state.

</details>

<details>
<summary>v1.1 Production Trust planning context</summary>

### Milestone Scope

Make Chimeway trustworthy enough for real production use by tightening policy behavior, delivery reliability, observability, and integration seams.

### Delivered Features

- Explicit policy and preference controls that suppress before enqueue and before perform.
- Durable reliability and final-state tracking across retries, duplicates, and failures.
- End-to-end observability and support surfaces with safe redaction.
- Documented, contract-tested integration seams for host apps and adapters.

### Validated Requirements Snapshot

- Durable event, notification, delivery, and attempt records exist across trigger fanout flows.
- Idempotency is enforced across event creation and delivery planning.
- Operators can inspect lifecycle traces and answer "why wasn't this sent?" safely.
- Sync-first dispatch and Oban upgrade seams are both supported.
- Policy, preference, reliability, observability, and integration goals were validated in phases 13-16.

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check - still the right priority?
3. Audit Out of Scope - reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-30 — completed Phase 90 (Pipeline Tiering PR/main/nightly)*
