# Project Research Summary

**Project:** Chimeway v1.17 Adopter Proof Paths
**Domain:** Clean-room adoption evaluation for an embedded Elixir/Phoenix notification library
**Researched:** 2026-08-08
**Confidence:** MEDIUM-HIGH

## Executive Summary

Chimeway v1.17 should make adoption *provable*, not add product surface. The product already has canonical guides, a rich demo host, partner verification lanes, package-file parity checks, and explainable notification primitives. The missing link is a prospective adopter's trustworthy path from a stated goal to an independent, artifact-consuming outcome. Build exactly three clean-room tracer bullets: core notification plus trace, Mailglass transactional email, and Accrue billing escalation.

The recommended implementation is one small committed Phoenix/Ecto-shaped fixture scaffold and one root-owned runner. For every path, the runner builds Chimeway in production mode with `mix hex.build --unpack`, copies the fixture to a new temporary location outside the checkout, resolves Chimeway only from that artifact, creates and migrates a fresh PostgreSQL database, then makes a public-API assertion on `Chimeway.Traces.explain_delivery/1`. Existing `verify.*` suites remain the behavioral authorities; the new proof answers the narrower and more valuable question: can an adopter follow the documented path using what the package actually contains?

The central risks are false clean-room claims from path dependencies or inherited state, overclaiming local fake-email coverage as provider E2E, and presenting an Accrue pinned-ref compatibility check as a released-package proof. Mitigate them with hermetic process/environment setup, explicit source provenance, synthetic/redacted fixture data, a public explainability assertion on every path, and two distinct Accrue labels/contracts: a released-package adopter proof only when the required integration is present in the resolved release, otherwise an immutable pinned-ref compatibility proof.

## Key Findings

### Recommended Stack

Use the existing supported platform rather than inventing proof infrastructure: Elixir 1.17+ / the repository's strict CI toolchain, Phoenix/Ecto with PostgreSQL 15, ExUnit, existing Mix aliases, and a short shell runner. Build the root in `MIX_ENV=prod` and use Hex's local `--unpack` artifact as the dependency boundary. The fixture is a deliberately minimal host, not a second DemoHost or generated application on every run.

**Core technologies:**

- **Elixir/Mix + Hex `mix hex.build --unpack`:** creates the pre-publish artifact boundary an adopter can consume.
- **Minimal Phoenix/Ecto fixture + PostgreSQL 15:** supplies host-owned repo, config, supervision, and fresh migration conditions without UI or assets.
- **ExUnit:** verifies installation, the natural path entrypoint, durable outcome, and public trace evidence deterministically.
- **Mailglass `~> 1.3`:** exercises transactional-email composition through a safe fake/test transport, never credentials or provider networking.
- **Accrue:** supports event-driven billing dunning, but release availability of `Accrue.Integrations.Chimeway` must be checked before making a released-package claim.

### Expected Features

**Must have (table stakes):**

- A concise adoption selector mapping evaluator intent to Core, Mailglass, or Accrue, with prerequisites, expected result, and ownership boundaries.
- One packed/artifact-consuming clean-room fixture for each of the three paths, with a fresh database and no source-tree dependency.
- A public explainability assertion per path: core lifecycle trace, Mailglass adapter/attempt trace, and Accrue campaign/signal outcome trace.
- Copyable named commands, human-readable but redacted evidence output, and CI-backed docs-to-command contracts.

**Should have (differentiators):**

- Explainability as the completion condition—not merely a green notification test.
- A compact Host / Chimeway / Partner responsibility matrix for every route.
- Stable-identity evidence (notification key/version, tenant, idempotency, correlation identifiers) and one controlled suppression/failure observation where it stays deterministic.

**Explicit anti-features / defer:**

- No new browser/admin evaluation UI, Playwright path, inbox work, or UI assets.
- No broad CI-performance initiative, CI topology rewrite, or duplicated full `verify.*` suites inside the new lane.
- No all-integrations mega-demo, new runtime delivery semantics, partner feature expansion, Docker Compose/Testcontainers/local registry, or Hex publishing during CI.
- No live provider accounts, real recipients, webhook secrets, or live billing accounts in baseline proofs; live provider/webhook validation remains optional future work.

### Architecture Approach

One thin adoption-proof harness should map three stable proof IDs to their guide anchors, fixture setup, natural business entrypoint, and expected explanation. It builds and unpacks the production artifact, materializes a fresh host, invokes public APIs and generated migrations, and prints sanitized provenance/evidence. Documentation contracts verify selector-to-guide-to-command reachability; runtime recipes prove behavior. Existing DemoHost, installer golden tests, `verify.mailglass`, and `verify.accrue` retain their deeper specialization and must not be copied or re-run wholesale.

**Major components:**

1. **Adoption selector and canonical guides** — route an evaluator to one journey and state ownership boundaries.
2. **Proof manifest/recipes** — map `core`, `mailglass`, and `accrue` to stable commands, guide anchors, inputs, and assertions.
3. **Clean-room fixture host and runner** — build the artifact, isolate environment/database, migrate, execute public path entrypoints, and emit safe diagnostics.
4. **Doc/release contracts and one adoption CI lane** — keep instructions, package content, aliases, and gate topology truthful without duplicating behavioral suites.

### Critical Pitfalls

1. **Repository-path success called a clean install** — always use a copied temporary host, an unpacked production artifact, fresh dependency/build state, and path/provenance assertions.
2. **Package parity mistaken for runtime adoption proof** — retain `verify.parity` as a prerequisite, then independently resolve, compile, migrate, boot, trigger, and explain from the external host.
3. **Inherited environment/optional-dependency overrides** — use an allowlisted environment and reject `CHIMEWAY_*_PATH`, `ACCRUE_PATH`, `*_SKIP_*`, and accidental `HEX_*` overrides; record sanitized dependency provenance.
4. **Fake transport described as provider E2E** — call Mailglass coverage deterministic local composition; make provider acceptance, sender verification, and public webhooks explicit partner/host responsibilities.
5. **Pinned Accrue source represented as a release proof** — an adopter proof must resolve a declared released Accrue package and assert the integration module; if unavailable, retain a separately named pinned immutable-ref compatibility proof, including the SHA and its limitation.

## Scope Recommendation

Approve v1.17 as **adopter evaluation proof paths**, not a UI milestone and not a broad CI-performance milestone. Its only target journeys are:

1. **Core notification + trace** — public trigger with stable notification identity, tenant/idempotency/correlation inputs, durable lifecycle, and `explain_delivery/1` evidence.
2. **Mailglass transactional email** — host mailable and `render_key`, safe local/test transport, and redacted adapter/attempt explainability evidence.
3. **Accrue billing escalation** — payment-failed starts the campaign and payment-paid produces the truthful signal/cancel/progression outcome, without directly calling a notifier.

Every journey must consume a packed/local-release Chimeway artifact from a clean-room host and make an adopter-visible, public explainability assertion. This is the non-negotiable bar for a v1.17 "proof"; source-tree test success or package file-list parity alone is insufficient.

## Implications for Roadmap

### Phase 1: Hermetic Artifact Harness and Core Proof

**Rationale:** Core establishes the shared clean-room contract before partner complexity can conceal a false installation proof.

**Delivers:** A fixture scaffold, manifest/runner, production `hex.build --unpack` pipeline, isolated process/temp/database setup, dependency provenance guards, core migrations, public `trigger/3` scenario, and `explain_delivery/1` assertion.

**Addresses:** packed-artifact coverage, copyable command contract, stable identity and explainability evidence.

**Avoids:** source/path coupling, inherited build/lock/environment state, unpack-only false positives, shared DB/Oban state, and reliance on private test helpers.

### Phase 2: Mailglass Transactional Email Proof

**Rationale:** Mailglass extends the validated shared harness through the most direct partner-facing adopter journey while keeping external systems out of CI.

**Delivers:** A clean-room Mailglass recipe with host-owned mailable mapping and `render_key`, fake/test transport, adapter/attempt trace assertion, sanitized output, and explicit responsibility boundary.

**Addresses:** transactional-email route selection and credential-free evaluation.

**Avoids:** claims of live provider delivery, provider/webhook secrets in logs, and duplication of existing Mailglass webhook/provider-depth coverage.

### Phase 3: Accrue Billing Escalation Proof and Compatibility Truth

**Rationale:** Accrue has the greatest external dependency and should reuse a proven harness, not define its semantics through a path-backed CI checkout.

**Delivers:** A billing-event-driven recipe that proves payment failure initiates the dunning workflow and payment success produces the expected Outcome Signal/termination evidence. It must expose one of two mutually exclusive modes:

- **Released-package adopter proof:** resolves the declared Accrue Hex release, asserts `Accrue.Integrations.Chimeway` exists, and labels the resolved versions.
- **Pinned-ref compatibility proof:** uses only a recorded immutable Accrue ref/SHA, labels itself as cross-repository compatibility evidence, and never appears as independent released-package installation guidance.

**Addresses:** billing dunning evaluation without bypassing the partner's natural event boundary.

**Avoids:** direct notifier calls, conditional test disappearance, hidden source-only API use, and false public-release claims.

### Phase 4: Adoption Front Door, Executable Docs, and Gate Wiring

**Rationale:** Only expose the selector and assert the complete route-to-command contract after all three recipes have stable, evidence-producing outcomes.

**Delivers:** README/HexDocs selector, responsibility matrices, canonical command/expected-evidence references, doc/release contract tests, `mix verify.adoption_paths`, one observable main/dispatch CI adoption lane, and `ci-gate` aggregation.

**Addresses:** documentation drift, discoverability, package-release parity, and sustainable CI confidence.

**Avoids:** silently skipped paths, duplicate full CI lanes, PR-gate wall-clock expansion, stale version strings, and overclaiming the scope as upgrade or provider acceptance coverage.

### Phase Ordering Rationale

- The artifact boundary, environment sanitation, temporary host, and fresh database are prerequisites for every credible route; build and prove them in Core first.
- Mailglass and Accrue are independent vertical recipes after Phase 1, but Accrue is riskier and must follow the shared harness plus explicit partner provenance policy.
- Public docs and gate aggregation depend on stable command names and output markers; wire them last while inexpensive doc contracts can protect the work throughout.
- Keep a single serial adoption lane on main/dispatch with explicit per-path steps and failure artifacts. Preserve fast PR contract checks and measure cost before adding any cache or matrix complexity.

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 1:** validate exact unpacked-package dependency mechanics, fixture migration/configuration seams, and hermetic environment construction against current project helpers.
- **Phase 3:** release-time verification of the selected Accrue package's integration module and version compatibility; this determines whether the released-package path is admissible.
- **Phase 4:** inspect existing gate contracts and live CI timing before modifying required-lane topology.

Phases with standard patterns (can skip broad research):

- **Phase 2:** the repository already documents Mailglass adapter/mailable semantics; implementation should use its deterministic fake/test seam rather than research live providers.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Official Hex/Phoenix/GitHub Actions documentation and repository evidence support the artifact fixture; exact Accrue release availability is unresolved. |
| Features | HIGH | Scope and adoption gap are directly grounded in PROJECT.md, current guides, aliases, and existing verification lanes. |
| Architecture | HIGH | Component boundaries and existing integration authorities were directly inspected; the proposal intentionally composes established project patterns. |
| Pitfalls | MEDIUM-HIGH | Root path overrides, package parity limits, CI topology, and partner constraints are direct project evidence; external provider behavior is deliberately out of scope. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Accrue release proof status:** Before adopter-facing wording is approved, resolve the intended Hex version in a clean host and verify the Chimeway integration module is packaged. If that fails, ship only the explicitly scoped pinned-ref compatibility proof for v1.17.
- **Supported Phoenix band:** Pin the fixture to the project's declared/documented support range rather than silently using current generator defaults; a compatibility matrix is future work.
- **Async determinism:** Select public, deterministic completion seams for delivery/workflow assertions and prove repeatability from a fresh database; do not add sleeps or polling.
- **Clean-room enforcement:** Decide whether the fixture lockfile is generated or committed, but enforce that runtime dependencies, temp roots, caches, and environment cannot resolve back into the repository.

## Sources

### Primary (HIGH confidence)

- [Project scope](../PROJECT.md) — v1.17 goal, target paths, and scope boundary.
- [Stack research](STACK.md) — artifact-consumer fixture, supported tooling, CI topology, and technology constraints.
- [Feature research](FEATURES.md) — adopter table stakes, explicit anti-features, and route dependency model.
- [Architecture research](ARCHITECTURE.md) — harness components, ownership boundaries, data flow, and build order.
- [Pitfalls research](PITFALLS.md) — clean-room, provenance, partner-claim, state-isolation, and CI/documentation risk controls.

### Secondary (MEDIUM confidence)

- [Hex `mix hex.build`](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html) — local `--unpack` package artifact behavior.
- [Phoenix `mix phx.new`](https://phoenix.hexdocs.pm/Mix.Tasks.Phx.New.html) — minimal PostgreSQL host generation options.
- [GitHub Actions PostgreSQL service containers](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers) — CI database service pattern.

---
*Research completed: 2026-08-08*
*Ready for roadmap: yes*
