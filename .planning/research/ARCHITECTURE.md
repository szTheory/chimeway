# Architecture Patterns: Chimeway v1.17 Adopter Proof Paths

**Domain:** Clean-room, CI-backed adoption proofs for an embedded Elixir/Phoenix notification library
**Researched:** 2026-08-08
**Confidence:** HIGH for repository integration points; MEDIUM for the local Hex-artifact mechanism.

## Recommended Architecture

Build one **thin adoption-proof harness** that consumes the same canonical instructions an adopter sees, but runs them in a freshly scaffolded host against a locally unpacked production package artifact. Keep the existing root and demo-host integration suites as the detailed behavioral authorities. The new harness verifies installation-to-business-outcome-to-explanation; it must not reproduce every adapter, webhook, UI, or workflow edge case already covered elsewhere.

```text
README adoption selector
        |
        +--> Golden Path guide ------> core proof recipe
        +--> Mailglass guide --------> mailglass proof recipe
        +--> Accrue dunning guide ---> accrue proof recipe
                                      |
                                      v
                       proof runner builds root Hex artifact (MIX_ENV=prod)
                                      |
                                      v
             fresh temporary host + generated migrations + minimal host config
                                      |
              +-----------------------+------------------------+
              |                        |                        |
         Chimeway.trigger/3      Mailglass adapter       Accrue billing event
              |                        |                        |
              +------------------------+------------------------+
                                      |
                                      v
                    Chimeway.Traces.explain_delivery/1 assertions
                                      |
                                      v
                           one named CI lane / ci-gate

Existing specialization remains authoritative:
verify.install_golden | ci.test README snippet | verify.mailglass | verify.accrue
```

The artifact is important: a proof that points a temporary host at `path: "../.."` only proves the checkout, while an adopter receives the root package. `mix hex.build --unpack --output ...` is specifically intended to inspect a local package before publication; use the unpacked root as the clean-room host's Chimeway dependency. Build under `MIX_ENV=prod`, matching the existing release-gate proof and avoiding test-only dependency overrides.

### New and Modified Components

| Component | Responsibility | Communicates With | Ownership boundary |
|---|---|---|---|
| README adoption selector (modify) | Selects exactly one canonical journey by desired outcome; states Chimeway/partner responsibilities and links to the proof command. | Three introduction guides | Documentation only; no second set of install instructions. |
| Canonical integration guides (modify) | Remain the copyable source for dependency, configuration, trigger/event, and trace steps. Each exposes a stable proof identifier/command. | Proof manifest/contract tests | Guides describe host code; they do not prescribe host auth, URLs, tenancy lookup, or correlation policy. |
| Adoption proof manifest/recipes (new, test-owned) | Declarative mapping from `core`, `mailglass`, and `accrue` to guide anchors, artifact inputs, setup, outcome assertion, and explainability assertion. | Runner and doc-contract tests | No application runtime code; keep values non-secret and deterministic. |
| Clean-room host scaffold (new, test fixture) | Minimal generated Mix/Phoenix-shaped consumer: its own repo/config/application and one notifier or partner event bridge. Runs migrations from the packaged artifact. | Unpacked Chimeway, Postgres, partner fixture when needed | Explicitly supplies host-owned `tenant_id`, `idempotency_key`, correlation ID, recipient identity, and action URL. It must not reuse `DemoHost` modules. |
| Adoption proof runner (new) | Creates isolated temp directories/databases, builds/unpacks artifact, materializes the relevant host, invokes documented commands/API, and emits concise evidence on failure. | Manifest, scaffold, existing aliases | Orchestrates only; it must call public Chimeway APIs and generated migrations, never private schemas or test helpers. |
| Existing demo host (modify minimally) | Stays the runnable reference and integration fixture for real Mailglass/Accrue semantics. Its proof tests continue to cover UI-facing/redaction and partner wiring. | `verify.example`, `verify.mailglass`, `verify.accrue` | Do not turn it into the clean-room host or add a new UI path. |
| Existing release/doc contracts (modify) | Enforce selector-to-guide-to-proof-name reachability, exact supported commands, packaged-doc presence, and CI topology. | README, guides, aliases, CI | Text/contract authority; no duplicate runtime proof. |
| CI adoption lane (new) | Executes all three artifact-consumer proofs once on push/main and dispatch, then is folded into `ci-gate`. | Artifact build, Postgres, optional pinned Accrue checkout | Keep off ordinary PRs; `pr-gate` retains fast doc/gate contracts. |

### Data Flow

1. An adopter begins at a short README selector: **core notification + trace**, **transactional email through Mailglass**, or **billing-triggered dunning through Accrue**.
2. The selected guide owns the public recipe. It ends with one named proof command and the expected business outcome plus an `explain_delivery/1` observation.
3. The CI runner builds the root package in production mode, unpacks it, and gives the fresh host only that artifact. This is in addition to—not a replacement for—the current `verify.parity`/release package-file checks.
4. The fresh host configures its own Ecto repo and application boundary, runs `mix chimeway.gen.migrations` and `mix ecto.migrate`, and injects only safe fixture values for host-owned inputs.
5. The proof executes the path's natural entrypoint: `Chimeway.trigger/3` for core and Mailglass; the Accrue billing event/campaign entrypoint for dunning. The Accrue proof must not trigger the dunning notifier directly from host code.
6. The runner obtains an ID from the returned trace and asserts `Chimeway.Traces.explain_delivery/1`: stable notification key, terminal/pending state appropriate to the scenario, and the decisive timeline event. For Accrue, assert the Outcome Signal/cancel result and no escalation delivery; for Mailglass, assert the Chimeway attempt records the Mailglass adapter without exposing rendered body or credentials.
7. Existing suites retain their depth: `readme_snippet_test.exs` locks the public core snippet against a real DB; `verify.mailglass` retains adapter/webhook/demo-host assertions; `verify.accrue` retains Accrue lifecycle and demo-host proof; installer golden tests retain generator idempotency and migration shape.

### Proof Contracts by Path

| Path | New clean-room assertion | Reused existing authority | Must not duplicate |
|---|---|---|---|
| Core Phoenix notification + trace | Packaged dependency installs; generated migrations run; a host notifier calls `trigger/3` with tenant/idempotency/correlation; returned delivery explains with the expected stable key and planning event. | `test/chimeway/integration/readme_snippet_test.exs`; installer golden/idempotency/prefix tests. | Demo admin browser, workflow branches, migration template snapshot details. |
| Mailglass transactional email | Host-owned mailable mapping and `Chimeway.Adapters.Mailglass` produce an email attempt; explanation exposes adapter/outcome and no sensitive render body. Use fake/test delivery, no provider key. | `verify.mailglass`, especially the demo-host Mailglass delivery and webhook pipeline coverage. | Webhook signature permutations, Mailglass sandbox implementation, admin UI redaction rendering. |
| Accrue billing dunning | A billing failure starts the campaign through Accrue; a payment signal terminates it; trace explains `accrue.dunning` and signal-driven outcome. | `verify.accrue` and demo `AccrueDunningProofTest`. | Accrue fixtures/processor internals, Oban queue mechanics, every escalation timing branch. |

## Component Boundaries

### Chimeway owns

- Package installation surface, generated migrations, durable event → notification → delivery → attempt lifecycle, trace query API, stable notification identity, idempotency enforcement, and redaction-safe operator metadata.
- The canonical guide contracts and the clean-room runner that proves its own public API from the packaged artifact.
- The CI aggregation relationship and failure evidence for its proof lane.

### Host application owns

- Authentication/authorization, tenant resolution and the concrete `tenant_id`, recipient/domain lookup, URLs/action links, correlation-ID policy, host repo/application supervision, and provider credentials.
- Its notifier/mailable and domain-event subscription. Fixtures should demonstrate explicit values, never imply Chimeway supplies them.

### Integration partners own

- Mailglass template/Swoosh/provider behavior and webhook-provider semantics.
- Accrue invoices, subscriptions, payment recovery facts, and campaign-event emission.

The clean-room fixture may implement the smallest host-owned contracts needed to cross these boundaries, but must not make Chimeway responsible for them. No new UI, inbox behavior, admin route, or browser test belongs to this milestone's proof architecture.

## Patterns to Follow

### Pattern 1: Artifact consumer, not source-tree consumer

**What:** Create a temporary host dependency that resolves `:chimeway` from the root's locally unpacked production artifact (or a local package repository produced from it), not from `path: "../.."`.

**When:** Every clean-room path, because they make an adopter-facing installation claim.

**Why:** The current `release_gate_contract_test.exs` already builds with `MIX_ENV=prod` and validates package contents. The proof should reuse that release-realistic construction and extend it to runtime adoption, not introduce a second packaging implementation.

**Implementation shape:** Extract the existing `mix hex.build --unpack` helper mechanics to a test support module used by both release contract and adoption runner, with a unique temp root and cleanup in `after`/`on_exit`.

### Pattern 2: One vertical assertion per proof, specialization elsewhere

**What:** Each proof has only three assertions: install/migrate, natural business entrypoint, and explainable result.

**When:** The new `verify.adoption_paths` command and its CI job.

**Why:** Current aliases already partition detailed coverage. Re-running `verify.mailglass` and `verify.accrue` inside an adoption lane multiplies setup cost while producing correlated failures. The adoption lane answers “can a prospect follow the docs with the artifact?”; partner lanes answer “does the integration work exhaustively?”

### Pattern 3: Public trace as the common outcome protocol

**What:** Each path yields a delivery ID and verifies `Chimeway.Traces.explain_delivery/1`, using a path-specific expected stable key and decisive event.

**When:** Always, including successful delivery. A proof without an explanation assertion is incomplete for Chimeway's product value.

**Example:**

```elixir
[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)

assert explanation.notification_key == expected_notification_key
assert :delivery_planned in Enum.map(explanation.timeline, & &1.event)
```

For the Accrue terminal path, fetch the associated workflow trace after the payment event and assert the signal/cancellation reason; do not assume every proof has the same terminal status.

### Pattern 4: Documentation contracts test links and commands; runtime tests test behavior

**What:** Extend `doc_contract_test.exs`/`release_gate_contract_test.exs` only to assert stable identifiers, guide ordering, selector links, proof command names, package inclusion, and the `ci-gate` lane. Place actual installation/runtime behavior in the adoption runner.

**Why:** This preserves the present split: doc contracts prevent drift cheaply on PRs; the artifact proof detects real copyability failures on main/dispatch.

## Anti-Patterns to Avoid

### Anti-Pattern 1: A second DemoHost

**What:** Forking `examples/chimeway_demo_host` into another sample app for clean-room proof.

**Why bad:** It creates two sets of notifier, config, fixtures, migrations, and partner dependency work to keep synchronized, while masking path-dependency coupling.

**Instead:** Keep DemoHost as the rich source-tree reference. Generate a deliberately tiny temporary host from recipe data and require it to consume the packaged artifact.

### Anti-Pattern 2: UI as the adoption proof

**What:** Making `/admin/chimeway`, LiveView, or Playwright the success criterion for all three paths.

**Why bad:** It expands scope into UI and host auth, adds slow/flaky setup, and obscures the core explanation contract. Existing demo tests already cover admin trace rendering/redaction.

**Instead:** Verify explainability via public trace APIs; retain the UI as an optional human exploration surface.

### Anti-Pattern 3: Treating partner fixture internals as adopter API

**What:** Copying `DemoHost.AccrueFixtures`, test repos, fake processor controls, or Mailglass fake setup into documentation.

**Why bad:** It leaks test mechanics and inverts responsibility boundaries.

**Instead:** Docs use only public host configuration and partner entrypoints. The runner hides test-only mechanics behind its fixture seam; the guide links to the canonical partner docs where configuration is partner-owned.

### Anti-Pattern 4: Duplicating each existing verify lane inside the new lane

**What:** Calling `verify.example`, `verify.mailglass`, and `verify.accrue` from `verify.adoption_paths`.

**Why bad:** Increases CI wall-clock, creates duplicated failures, and makes it unclear whether a regression is docs/artifact installation or partner behavior.

**Instead:** Add one independent vertical command and continue running current named lanes separately in `ci-gate`.

## CI and Release Integration

### Commands and topology

Add a single public maintainer alias such as `mix verify.adoption_paths`; it invokes the three recipes serially in isolated temporary roots/databases and emits the path name in failures. Do not make it part of the default fast `mix ci` if the artifact build and partner path checks materially slow contributors.

Add a single `verify_adoption_paths` CI job on push-to-main and `workflow_dispatch`, then include it in `ci-gate`. Leave it out of `pr-gate`; fast `mix ci.verify_gates` should enforce the selector/guide/command wiring on every PR. Update the release-gate contract's explicit `@ci_gate_lanes`, pre-ship command list, job-command assertion, and `MAINTAINING.md` count/copy together—those tests intentionally make the topology change explicit.

Run the proof lane after its normal root dependency setup and PostgreSQL service provisioning. Cache its root build separately only if measurement justifies it; the unpacked artifact and temporary hosts must always be recreated, because persistence would undermine clean-room confidence. Reuse the existing CI observability-summary pattern so added wall-clock and cache behavior remain visible.

The Accrue recipe may use the already pinned sibling checkout in CI solely to access the integration under test, but its **Chimeway** dependency must still resolve from the locally built artifact. Pin and document that ref in one shared CI/proof configuration; do not give docs a CI-only checkout requirement for normal Hex adopters.

### Package/release relationship

`verify.parity` and the unpacked-package release contract remain the file-list/truth gates. The new proof is their runtime companion: it demonstrates that the actual artifact, its packaged README/guides, and its generator can be consumed by a fresh app. Avoid requiring examples, sibling packages, or test support files in the root package—the current `files:` whitelist deliberately excludes them.

For release work, run `mix verify.adoption_paths` alongside the existing pre-ship commands, and add it to the release-facing documentation only after the CI lane is green and artifact mode is deterministic. This maintains existing package/release checks without changing the root-only package model.

## Build Order

1. **Define the proof contract and adoption front door.** Choose the three stable proof IDs, write the README selector, make each guide end in an explicit expected outcome/explanation, and add cheap doc-contract assertions. This establishes the user-facing interface before harness code.
2. **Extract package-artifact support and build the core clean-room proof.** Reuse the production `hex.build --unpack` behavior, generate the smallest host, run install/migrations, trigger a notifier, and assert the public trace. Make cleanup, temp-path isolation, and failure diagnostics solid here.
3. **Add the Mailglass clean-room recipe.** Supply a host-owned mailable mapping and fake delivery transport, assert adapter-attempt explainability, and retain all webhook details in `verify.mailglass`.
4. **Add the Accrue clean-room recipe.** Reuse the pinned partner-checkout seam for CI, drive only billing events, prove campaign start and paid termination through the trace, and retain fixture/queue depth in `verify.accrue`.
5. **Wire one CI lane and release parity.** Add its alias, cache/observability setup, `ci-gate` aggregation, release/doc contract updates, and maintainer command documentation. Measure it before deciding whether any setup can share existing producers.

## Scalability Considerations

| Concern | At 100 users / 3 proof paths | At 10K users / 5–8 paths | At 1M users / many partners |
|---|---|---|---|
| Proof recipes | One manifest and three explicit recipe modules. | Split shared scaffold/artifact support from per-partner recipe modules. | Version the recipe contract; review partner changes independently and pin all external refs. |
| CI cost | One serial artifact lane on main/dispatch. | Parallelize only independent recipes after timing evidence; retain a single aggregate lane. | Use a matrix with per-path reports/artifacts, but keep an aggregate required check and avoid duplicating partner suites. |
| Documentation drift | Exact command/anchor contracts in `ci.verify_gates`. | Generate selector entries from the manifest or validate both directions. | Treat proof IDs and guide anchors as versioned public adoption API. |
| Sensitive fixture data | Synthetic tenant, identities, URLs, and fake transports. | Centralize redaction assertions and forbidden-output checks. | Require sanitized CI logs/artifacts; never attach payload or provider secrets as proof evidence. |

## Sources

- Repository evidence (HIGH): `mix.exs` aliases; `.github/workflows/ci.yml`; `test/chimeway/integration/readme_snippet_test.exs`; `test/chimeway/release_gate_contract_test.exs`; installer golden tests; `examples/chimeway_demo_host` proof tests and README; canonical Golden Path, Mailglass, and Accrue guides.
- [Hex `mix hex.build` documentation](https://hex.hexdocs.pm/Mix.Tasks.Hex.Build.html) (MEDIUM via documentation lookup): `--unpack` builds and unpacks a local artifact for pre-publish content verification.
