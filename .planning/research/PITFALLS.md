# Domain Pitfalls: Chimeway v1.17 Adopter Proof Paths

**Domain:** Clean-room adopter proofs for an Elixir/Phoenix notification library
**Researched:** 2026-08-08
**Confidence:** MEDIUM — based on current Hex documentation plus direct inspection of Chimeway's package, guides, aliases, tests, and CI lanes.

## Critical Pitfalls

### Pitfall 1: Calling a repository-path test a clean install

**What goes wrong:** A proof uses `{:chimeway, path: ...}`, an in-repo demo host, or a pre-existing lockfile. It succeeds because it compiles the checkout, sees uncommitted files, and inherits the repository's dependency graph rather than what an adopter can obtain. The current Accrue lane is expressly path-backed (`ACCRUE_PATH` plus `CHIMEWAY_PATH=../..`), so it proves the pinned integration relationship, not an independent Chimeway installation.

**Why it happens:** Path dependencies are convenient for tracer bullets and make debugging quick. They also mask missing package files, incorrect optional-dependency metadata, source-only configuration, and version-resolution errors.

**Consequences:** Docs can be copyable only inside the maintainer checkout. A release may package successfully but fail for a new consumer. The green badge becomes a false adoption signal.

**Prevention:** Create every proof host under a unique temporary directory outside the repository. Build and unpack the root tarball with `MIX_ENV=prod mix hex.build --unpack`; point the proof host only at that unpacked artifact (or a deliberately served local tarball), run a fresh `mix deps.get`, and assert its generated `mix.lock` has no repository paths. Do not reuse root/demo `deps`, `_build`, `MIX_HOME`, `HEX_HOME`, or lockfiles. A source-checkout lane may remain, but name it an integration-development lane, not clean-room installation.

**Detection:** Fail if `mix deps.tree`/lockfile contains `path`, the proof host is beneath the repository root, `CHIMEWAY_PATH` is set, or the proof source has access to repository-only fixture modules. Archive the artifact location and resolved Chimeway version in the CI log.

**Phase placement:** Phase 1 — build the reusable clean-room harness and the core notification-and-trace proof before claiming any partner proof.

### Pitfall 2: Treating tarball contents as executable package proof

**What goes wrong:** `mix verify.parity` and `mix hex.build --unpack` validate the whitelist but never compile, start, migrate, or run an external host against the packaged artifact. Chimeway already performs this valuable package-content check; it is necessary but not sufficient for v1.17.

**Why it happens:** File parity is deterministic, fast, and release-adjacent, so it is easy to mistake for consumer coverage.

**Consequences:** Missing runtime config, excluded compile-time modules, undocumented Mix-task requirements, or an invalid optional dependency graph pass the package gate.

**Prevention:** Make the clean-room command a chain with independent checkpoints: package build/unpack -> new host resolution/compile -> host schema generation/migration -> supervision boot -> trigger -> durable delivery/trace assertion. Preserve the existing parity gate as a separate prerequisite, not the success condition.

**Detection:** A contract test should prove the clean-room command invokes both `hex.build --unpack` and the external host's actual `mix` tasks, then checks a persisted notification/delivery and `Chimeway.Traces.explain_delivery/1` outcome.

**Phase placement:** Phase 1.

### Pitfall 3: Accidentally testing a different release mode than Hex consumers

**What goes wrong:** The root project changes dependencies through environment variables (`CHIMEWAY_SKIP_*_DEP`, `ACCRUE_PATH`, `SIGRA_PATH`). Some are intentionally required for sibling development. A proof that inherits them can silently omit an optional integration or resolve a path override that does not exist in the published package. The source package build is explicitly made in `MIX_ENV=prod` to avoid a development-only Sigra override; the clean-room proof must respect that boundary.

**Prevention:** Start proofs with a small explicit allowlist of environment variables (`MIX_ENV`, isolated database URL, bounded temp paths); fail on every `CHIMEWAY_*_PATH`, `ACCRUE_PATH`, `*_SKIP_*`, and `HEX_*` override not intentionally required by the scenario. Record which package version and dependency versions the proof resolved. For partner proofs, distinguish "published Hex partner" from "pinned sibling source compatibility" in the command name and guide.

**Detection:** Print sanitized dependency provenance (`mix deps.tree`) and assert expected package SCMs. Run the clean-room harness in a process whose environment is constructed rather than inherited.

**Phase placement:** Phase 1 for harness isolation; Phase 3 for Accrue's source-versus-published partner contract.

### Pitfall 4: Mistaking fake-provider success for transactional email E2E

**What goes wrong:** Mailglass tests use `Mailglass.Adapters.Fake` and fixture webhook credentials, which appropriately test adapter behavior without secrets. They do not prove that a real provider accepts mail, can reach the callback URL, or that production credentials/configuration are valid.

**Why it happens:** Live email and webhooks require accounts, secrets, DNS/tunnelling, and nondeterministic external services, which are inappropriate for ordinary PR CI.

**Consequences:** An adopter reads “end-to-end” as provider delivery verification, while the actual guarantee is a local transactional-email composition plus Chimeway trace result.

**Prevention:** Define the Mailglass tracer bullet as a deterministic local E2E: packaged Chimeway + host mailable + Mailglass fake/test adapter -> Chimeway delivery/attempt/trace assertion. State plainly that provider account, sender verification, Swoosh adapter, and public webhook ingress are host/Mailglass responsibilities. Keep live-provider smoke outside normal CI and only add it later with isolated credentials if it becomes a release requirement.

**Detection:** The guide's expected output must name the fake/test transport. A contract test rejects live-provider wording unless a separate secret-backed evidence lane exists; it also verifies that errors/tokens are not rendered in output.

**Phase placement:** Phase 2 — Mailglass proof and its responsibility-boundary documentation.

### Pitfall 5: Partner proof depends on an unversioned or mismatched external source

**What goes wrong:** Accrue's current CI checkout is pinned to a SHA, while `mix.exs` allows a Hex `~> 1.3` optional dependency and local execution replaces it with a path. A passing test can validate only that exact checkout, not the documented public-version range; conversely, a proof intending Hex use can secretly exercise source-only APIs.

**Prevention:** Choose and label one v1.17 claim: (a) packaged Chimeway plus a released Accrue constraint, or (b) a cross-repository compatibility proof at a recorded immutable Accrue SHA. Prefer (a) for the adopter path and retain (b) as maintainer compatibility evidence. The proof must expose both resolved versions and reject an unexpected path override. If released Accrue cannot supply the integration module, say so and keep the installer path out of adopter-facing instructions.

**Detection:** Assert the resolver selected the declared Hex package/version for the adopter proof; put the SHA, repository, and rationale in the sibling lane's CI summary. A test should fail when Accrue's required integration module is absent rather than conditionally skipping it with `Code.ensure_loaded?/1`.

**Phase placement:** Phase 3 — Accrue clean-room proof, after the generic harness is proven in Phase 1.

### Pitfall 6: Passing because tests conditionally disappear or shared state leaks

**What goes wrong:** Integration modules guarded by `Code.ensure_loaded?/1` can compile to no tests when an optional dependency fails to resolve. Shared Postgres names, Oban jobs, application config, and static fixture identities make a new external host proof order-dependent. Chimeway's existing suite already marks partner/config-mutating tests serial and explicitly notes database pollution hazards around journey data.

**Prevention:** Make dependencies required by each tracer bullet and assert their modules/functions at the test entrypoint. Give every proof a distinct database/schema, migrate it from zero, clean it through Ecto rather than broad host cleanup, restore application configuration, and drain/perform the exact queue deterministically. Use unique idempotency keys, tenant IDs, recipient identities, and correlation IDs per run. Assert both the business outcome and the trace's causal fields.

**Detection:** Run the proof twice in a row with random ExUnit ordering and a fresh database; a skipped scenario or an assertion against rows from a prior run is a failure. Emit the database name, test seed, and sanitized correlation ID to CI summaries.

**Phase placement:** Phase 1 harness; scenario-specific assertions in Phases 2 and 3.

### Pitfall 7: Unsafe host defaults hide the library/host boundary

**What goes wrong:** A guide assumes `localhost` Postgres credentials, a public schema, a repo named `MyApp.Repo`, a configured Oban instance, or that adding `Chimeway.Application` creates/migrates all required state. It may work in the demo and fail in an umbrella, production release, or separately configured Chimeway repo. New installs use the `"chimeway"` prefix; `prefix: false` is legacy compatibility only.

**Prevention:** The proof host should declare all host-owned seams explicitly: Ecto repo/database, migration command and prefix, Chimeway runtime repo configuration, supervision ordering, dispatcher/Oban decision, tenancy, idempotency, URL generation, mailable mapping, credentials, and webhook routing. Use safe test-only values only inside the generated proof host; never show them as production defaults. Test both standard Phoenix app layout and only the umbrella behavior actually supported by the installer—do not claim all host shapes without a proof.

**Detection:** Contract tests ensure docs use placeholders for host identifiers and include the required tenant/idempotency/prefix decisions. The clean-room host should fail with a clear diagnostic if repo, prefix, or required host module is missing.

**Phase placement:** Phase 1 for core host contract; Phase 2 for Mailglass-owned config; Phase 3 for Accrue-owned config.

## Moderate Pitfalls

### Pitfall 1: Documentation and executable proof take different branches

**What goes wrong:** The guide changes a dependency constraint, `render_key`, command, config key, prefix, or expected trace status, while CI keeps running a hand-written equivalent. Existing doc contracts protect selected marker strings, but marker checks cannot establish that the entire copied sequence executes.

**Prevention:** Put the canonical command sequence in a checked-in script/fixture and have both CI and the guide refer to its exact name. Use a lightweight doc contract for links, responsibility wording, and command markers, but make the script's passed assertions the truth. Version expected outcomes deliberately rather than matching unstable raw output.

**Phase placement:** Phase 4 — adoption front door plus executable-doc contracts, after all three scenario commands exist.

### Pitfall 2: Adding full duplicate CI lanes erodes the signal

**What goes wrong:** Each tracer bullet gets its own root build, dependency fetch, Postgres service, and cache, duplicating the already 13-lane `ci-gate`. The prior milestone recorded that compile-once caching is correct but does not meet its wall-clock target; indiscriminate lane growth makes adopter proof less reliable and more expensive.

**Prevention:** Share one hermetic harness and one artifact-producing job; add only scenario steps that need different partner graphs. Key caches on the clean-room host manifest and package inputs, never on mutable temp output. Keep PR selection narrow (affected proof plus contracts), retain all proof paths on main/release confidence, and make skipped/conditional jobs visible rather than silently green.

**Phase placement:** Phase 4 — CI composition and gate wiring, with the product proof semantics already fixed.

### Pitfall 3: Leaking secrets or real recipient data in proof output

**What goes wrong:** Provider credentials, webhook basic-auth data, full email addresses, payload bodies, or database URLs enter logs, traces, fixture snapshots, or CI summaries while demonstrating explainability.

**Prevention:** Use deterministic synthetic identities and fake transports in normal CI; redact configuration and trace metadata before printing. Ensure proof assertions use structural fields (status, reason, selected adapter, correlation ID) rather than serialized payloads. A real-provider lane, if ever authorized, uses scoped secrets and no debug dump.

**Phase placement:** Phase 2 and Phase 4 (partner proof design and CI/log contracts).

## Minor Pitfalls

### Pitfall 1: Confusing installation proof with upgrade proof

**What goes wrong:** A fresh host success is taken as evidence that a legacy public-schema install, existing migrations, or an older package version can upgrade safely.

**Prevention:** Keep the v1.17 tracer bullets explicitly new-install-only. Link the existing storage-prefix upgrade guide for migration/legacy concerns and avoid destructive cleanup in proof scripts.

**Phase placement:** Phase 4 documentation boundary.

### Pitfall 2: Copying volatile literal versions into multiple guides

**What goes wrong:** root installation uses `~> 1.1` while partner pages contain their own Chimeway constraints; later releases change one but not another.

**Prevention:** Derive or contract-test all adopter-facing Chimeway constraints against `mix.exs` major/minor, as the existing packaged README gate does. Keep partner versions justified by their compatibility proof.

**Phase placement:** Phase 4 documentation contracts.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| 1. Core clean-room harness + notification/trace | Path dependency and unpack-only false positives; inherited lock/cache/env; shared DB/Oban state | Fresh temp host, packed artifact, isolated environment and database, migration/boot/trigger/trace checkpoints, provenance assertions |
| 2. Mailglass proof | Claiming fake adapter is live provider E2E; leaking callback credentials/payloads | Local deterministic Mailglass composition proof; responsibility split and explicit non-goals; redacted synthetic data |
| 3. Accrue proof | CI-pinned sibling source is presented as a released-Accrue install; conditional module skip | Separate released-package adopter proof from pinned compatibility lane; resolve and assert exact package/version/module |
| 4. Adoption front door, docs, CI | Docs/script drift, silently skipped jobs, CI fan-out/cost regression | Canonical executable scripts linked by guides, contract tests for wording/commands, visible gates and selective PR/main composition |

## Sources

- [Hex `mix hex.build` v2.5.1](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html) — MEDIUM: authoritative current package-build behavior; documents `--unpack` and exclusion of non-Hex path/git dependencies from package resolution.
- [Hex `mix hex.publish` v2.5.1](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) — MEDIUM: authoritative current dry-run and package-check behavior.
- [Hex FAQ](https://hex.pm/docs/faq) — MEDIUM: current documentation publication and immutability constraints.
- Project evidence: `mix.exs`, `.github/workflows/ci.yml`, installer/prefix contracts, and existing Golden Path/Mailglass/Accrue guides — MEDIUM: directly inspected current implementation and CI topology.

## Research Notes

Context7 and the configured Brave-backed seam were unavailable in this run; conclusions about Hex behavior were cross-checked against current official Hex documentation via web search. No live provider or external partner repository behavior was asserted beyond Chimeway's pinned-CI configuration.
