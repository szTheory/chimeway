# Phase 95: Accrue Billing-Escalation Proof - Research

**Researched:** 2026-08-09
**Domain:** Hermetic Accrue/Chimeway consumer proof
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Natural Accrue Lifecycle Boundary
- **D-01:** Start the proof through Accrue's `invoice.payment_failed` event and end the waiting dunning workflow through its `invoice.paid` outcome event; do not call a bundled Chimeway notifier directly to simulate either boundary.
- **D-02:** Prove the actual Accrue-to-Chimeway integration workflow: payment failure starts the campaign and payment success routes the outcome signal that progresses or terminates it.

### Clean Consumer Topology
- **D-03:** Extend `ArtifactConsumerFixture` with a separately callable Accrue proof, preserving the Phase 93 artifact-only `:chimeway` dependency, isolated temporary host/database, provenance validation, and cleanup discipline.
- **D-04:** Do not use DemoHost, the source-tree checkout, or a repository-maintainer `verify.*` lane as the adopter proof; they may be regression analogs but cannot establish packaged-consumer provenance.

### Public Workflow Evidence
- **D-05:** Emit one strict, machine-parseable `CHIMEWAY_ACCRUE_PROOF` record derived exclusively from public workflow/trace APIs. It must prove both waiting progression and the `invoice.paid` / outcome-signal result.
- **D-06:** Allowlist only stable workflow/notification identity, non-sensitive lifecycle state/reason, and ordered timeline facts necessary to establish progression and outcome. Reject duplicate or unknown keys; exclude billing identifiers, recipient data, payloads, metadata blobs, credentials, raw structs, and direct database inspection from public proof output.

### Release Provenance and Guidance
- **D-07:** Treat the proof as an independent released-package adopter proof only when its resolved Accrue Hex release contains the Chimeway integration; identify the exact released Chimeway and Accrue package versions in that case.
- **D-08:** If released-package availability cannot be established, identify the immutable integration ref/SHA and label the result solely as compatibility evidence, never as released-package installation guidance.
- **D-09:** Prefer the current verified Accrue `1.3.0` released-package path when the generated proof validates that release contains the integration; otherwise fall back to the CI-pinned `236fa2f1649e771f3b515603495436badeed3c7b` compatibility label.

### the agent's Discretion
- Exact generated module names, safe output field spelling/order, fixture values, command wiring, and focused contract-test placement, provided the lifecycle, provenance, public-evidence, and truthful-labeling decisions above remain intact.

### Deferred Ideas (OUT OF SCOPE)
- Live provider/webhook payment acceptance, credentials, retries, and production billing data — host/provider responsibility outside this deterministic proof.
- New Chimeway runtime lifecycle semantics, notifier APIs, or adapter behavior — outside the proof/documentation scope.
- `verify.adoption_paths`, a dedicated adoption CI lane, and cross-path drift enforcement — Phase 96.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| ACCR-01 | Billing-event escalation, workflow progression, outcome-signal termination, and trace evidence. | Use Accrue event helpers plus public workflow/trace APIs. |
| ACCR-02 | Truthful released-package versus pinned-ref guidance. | Branch label from the generated consumer's resolved Accrue source/version. |
</phase_requirements>

## Summary

Extend `Chimeway.Test.ArtifactConsumerFixture`, rather than creating a new harness. Generate one isolated consumer that uses the unpacked Chimeway artifact as its only `:chimeway` dependency, an exact `:accrue, "1.3.0"` dependency, one temporary `ArtifactConsumer.Repo`, and both libraries' migrations. Start through `Accrue.Test.trigger_event/2` for `invoice.payment_failed`, then end the waiting path through `invoice.paid`. [VERIFIED: artifact fixture; Accrue lifecycle test; `deps/accrue/hex_metadata.config`]

The record must be derived only from `Chimeway.Workflows.explain/2`, `Chimeway.Workflows.list_traces/2`, and optional `Chimeway.Traces.explain_delivery/1`. Current behavior becomes `:waiting` / `waiting_for_step_progression`, then `:active` / `signal_received`; describe this as ending the waiting escalation path, not completing the workflow. [VERIFIED: `lib/chimeway/workflows.ex`; Accrue integration source]

**Primary recommendation:** Implement one serialized `prove_accrue!/2` proof, strict evidence/provenance parser, adversarial contracts, and guide wording that branches between exact released versions and the immutable fallback SHA.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Payment event reduction | API / Backend | Database | Accrue reduces the event and calls its configured engine. [VERIFIED: Accrue webhook handler] |
| Workflow/wait/signal state | API / Backend | Database | Chimeway persists the workflow and routes the durable signal. [VERIFIED: workflows and signal APIs] |
| Public proof record | API / Backend | — | Generated consumer projects stable safe values from public APIs only. [VERIFIED: CONTEXT.md D-05/D-06] |
| Release claim | Build resolution | — | Resolved consumer dependency determines released versus compatibility label. [VERIFIED: CONTEXT.md D-07/D-08] |

## Project Constraints (from AGENTS.md)

- Preserve stable notification keys/versions, durable lifecycle behavior, idempotency, and host ownership boundaries. [VERIFIED: AGENTS.md]
- Keep `mix verify.*`/`mix ci.*` parity and do not emit sensitive payload data. [VERIFIED: AGENTS.md]

## Standard Stack

| Library | Version | Purpose | Why |
|---|---:|---|---|
| `:chimeway` | unpacked artifact version | Consumer dependency, public evidence | Preserves Phase 93 package provenance. [VERIFIED: fixture] |
| `:accrue` | `1.3.0` | Billing events and integration | Locked path; metadata includes the integration source. [VERIFIED: `hex_metadata.config`; `mix hex.info accrue`] |
| Ecto SQL/Postgrex | existing constraints | Isolated host database | Existing consumer-harness pattern. [VERIFIED: fixture] |
| Oban | existing constraint | Signal-router execution | `Signal.track/4` persists then enqueues routing. [VERIFIED: `lib/chimeway/signal.ex`] |

**Generated consumer dependencies:** `{:chimeway, path: "<unpacked-root>"}`, `{:accrue, "1.3.0"}`, `{:ecto_sql, "~> 3.11"}`, `{:postgrex, ">= 0.0.0"}`, `{:oban, "~> 2.17"}`. Pinning `1.3.0` makes the release claim reproducible. [VERIFIED: CONTEXT.md D-07 through D-09]

## Package Legitimacy Audit

| Package | Registry | Version | Verdict | Disposition |
|---|---|---:|---|---|
| `accrue` | Hex | `1.3.0` released 2026-05-30 | Registry/package metadata verified | Approved for locked proof path. [VERIFIED: `mix hex.info accrue`; `hex_metadata.config`] |

The package-legitimacy seam supports npm/PyPI/crates, not Hex; verify release contents in the generated consumer before making a released-package claim. [VERIFIED: seam usage]

## Architecture Patterns

`invoice.payment_failed` -> Accrue reducer -> `Accrue.Integrations.Chimeway.start_campaign/3` -> Chimeway workflow/initial delivery -> public waiting evidence -> `invoice.paid` -> `cancel_campaign/3` -> `Signal.track/4` -> signal-router job -> public `signal_received` evidence -> strict proof line. [VERIFIED: Accrue integration; lifecycle test]

Recommended files: `scripts/prove-accrue-consumer.exs` (committed adopter-facing command); `test/support/artifact_consumer_fixture.ex` (generated host, parser, provenance); `test/chimeway/release_gate_contract_test.exs` (serialized E2E/runner/adversarial checks); `test/chimeway/doc_contract_test.exs` and `guides/introduction/accrue-dunning-integration.md` (truthful label wording).

### Strict proof record

`CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.3.0 chimeway_version=<resolved> workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received`

Field spelling/order is discretionary, but require exactly one line, a fixed allowlist, no duplicate/unknown keys, safe value validation, and no IDs/recipients/payload/metadata/credentials/raw structs/database results. [VERIFIED: CONTEXT.md D-05/D-06; Phase 94 parser]

## Don't Hand-Roll

| Problem | Use Instead | Why |
|---|---|---|
| Payment-event simulation | `Accrue.Test.trigger_event/2` | Exercises Accrue's reducer rather than host/notifier glue. [VERIFIED: Accrue test helper] |
| Workflow inspection | `Workflows.explain/2`, `list_traces/2` | Tenant-scoped public state and structural traces. [VERIFIED: workflows API] |
| Delivery inspection | `Traces.explain_delivery/1` | Existing public sanitized seam. [VERIFIED: traces API] |
| Output parsing | existing Phase 94 string-key allowlist pattern | Rejects unknown/duplicate keys without atomization. [VERIFIED: fixture] |

## Common Pitfalls

1. **Conditional integration compilation:** Accrue defines the integration only when Chimeway is loaded. Resolve both deps first, then inspect source and ensure the expected module is loaded. [VERIFIED: Accrue integration source; `test/test_helper.exs`]
2. **Async outcome signal:** `invoice.paid` queues `SignalRouterWorker`; deterministically execute/drain it before public inspection. [VERIFIED: signal API; lifecycle test]
3. **False terminal claim:** `route_signal/1` returns the run to `:active` with `signal_received`, so forbid “workflow completed.” [VERIFIED: workflows API]
4. **Provenance drift:** CI's `236fa2f1649e771f3b515603495436badeed3c7b` checkout is compatibility evidence only. [VERIFIED: CONTEXT.md D-08; CI workflow]

## Resolved Questions

1. **Exact signal-job execution API:** Oban 2.x defines public `Oban.drain_queue/1` in `deps/oban/lib/oban.ex`; it uses the configured instance and production execution machinery. The generated host must start Oban with `repo: ArtifactConsumer.Repo`, `testing: :manual`, and `queues: false`, then call `Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true, with_safety: false)` and accept the post-signal proof only when the result equals `%{cancelled: 0, discard: 0, failure: 0, snoozed: 0, success: 1}`. This is available to the clean consumer through its direct Oban dependency and does not require a private test helper. [VERIFIED: Oban public API and drainer source; existing Accrue lifecycle test]
2. **Exact release compile behavior:** Accrue 1.3.0 metadata includes `lib/accrue/integrations/chimeway.ex`; that file's only module-definition guard is `Code.ensure_loaded?(Chimeway)`. After the generated host and dependencies compile, resolve the source from `Mix.Project.deps_paths()[:accrue]`; when the module is absent, compile that resolved file and require `Code.ensure_loaded?(Accrue.Integrations.Chimeway)`. Missing source or failed loading fails before any proof line. The exact-SHA compatibility branch uses the same resolved-source/load gate plus exact-ref validation. [VERIFIED: Accrue integration source; metadata; existing `test/test_helper.exs` recovery pattern; CONTEXT.md D-07/D-09]

## Environment Availability

| Dependency | Available | Evidence | Fallback |
|---|---:|---|---|
| PostgreSQL | ✓ | local server accepts connections; client 14.17 | project test DB container |
| Elixir/OTP + Mix | ✓ | OTP 28 and Mix available | — |
| Hex | ✓ | `mix hex.info accrue` succeeded | — |
| Oban | ✓ | project dependency | none |

## Validation Architecture

| Property | Value |
|---|---|
| Framework | ExUnit [VERIFIED: `test/test_helper.exs`] |
| Quick run | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| Full gate | `mix ci.verify_gates` |

| Req | Test coverage | File exists? |
|---|---|---|
| ACCR-01 | End-to-end consumer, strict parser, no-sensitive-output, cleanup | Wave 1 proof and Wave 2 doc contracts |
| ACCR-02 | Release/SHA branch and guide forbidden-overclaim contracts | Wave 1 provenance proof and Wave 2 guide contracts |

Wave 1 extends the committed runner, fixture, and release-gate contracts; Wave 2 extends the Accrue guide and doc-contract tests. No new CI lane belongs in this phase. [VERIFIED: CONTEXT.md]

## Security Domain

| Area | Control |
|---|---|
| Access control | Use tenant-scoped public workflow reads; do not emit tenant IDs. [VERIFIED: workflows API; CONTEXT.md D-06] |
| Input validation | One fixed string-key record; reject unknown/duplicate values without atomization. [VERIFIED: Phase 94 parser] |
| Data disclosure | Reject billing/recipient/payload/metadata/credential/raw-struct output. [VERIFIED: CONTEXT.md D-06] |
| Claim integrity | Resolved release evidence or exact SHA-only compatibility label. [VERIFIED: CONTEXT.md D-07/D-08] |

## Sources

### Primary (HIGH confidence)

- `test/support/artifact_consumer_fixture.ex`; `test/chimeway/release_gate_contract_test.exs`.
- `deps/accrue/lib/accrue/integrations/chimeway.ex`; `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs`.
- `lib/chimeway/workflows.ex`; `lib/chimeway/signal.ex`; `lib/chimeway/traces.ex`.
- `deps/accrue/hex_metadata.config`; `mix.lock`; `mix hex.info accrue`.

### Secondary (MEDIUM confidence)

- [Accrue Config API](https://accrue.hexdocs.pm/Accrue.Config.html) [CITED: accrue.hexdocs.pm/Accrue.Config.html]
- [Accrue Hex package](https://hex.pm/packages/accrue) [CITED: hex.pm/packages/accrue]

## Metadata

**Confidence breakdown:** Standard stack HIGH; architecture HIGH; pitfalls HIGH—all are grounded in current local source and lifecycle tests.

**Valid until:** 2026-09-08; recheck Hex availability before implementation.
