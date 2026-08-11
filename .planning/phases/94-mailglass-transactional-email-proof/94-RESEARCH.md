# Phase 94: Mailglass Transactional-Email Proof - Research

**Researched:** 2026-08-08  
**Domain:** Hermetic Elixir/Ecto consumer proof for the Mailglass transactional-email adapter  
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Clean Consumer and Ownership Boundary
- **D-01:** Extend the Phase 93 ArtifactConsumerFixture with a separately callable Mailglass proof path; preserve the unpacked Chimeway artifact as the consumer's only :chimeway dependency, unique temporary PostgreSQL database, provenance validation, failure-safe cleanup, and serialized release-gate execution. Do not use DemoHost, a source-tree path dependency, or mix verify.mailglass as the adopter proof.
- **D-02:** Use one host-owned ArtifactConsumer.Repo for Mailglass persisted state and migrate both libraries through the generated host's normal Ecto migration path. The existing Mailglass.TestRepo arrangement is test-harness isolation, not the intended adopter architecture.
- **D-03:** Keep Phase 93's direct :oban consumer opt-in and add a direct Mailglass dependency compatible with the repository's resolved Mailglass 1.3 line. Run the proof only in the established Mailglass-compatible environment; do not change Chimeway's core Elixir support floor.

### Transactional Email Orchestration
- **D-04:** Generate an adopter-owned, email-only notifier with a fixed stable notification_key and version plus fixed explicit tenant_id and idempotency_key inputs. Its rendering/2 must persist an email render_key and render_version.
- **D-05:** Generate an adopter-owned Mailglass.Mailable and configure the email channel to use Chimeway.Adapters.Mailglass, mapping the exact stable render key to the host mailable function. Prove notifier -> persisted render identity -> configured map -> host mailable -> Mailglass adapter, not merely generic adapter success.
- **D-06:** Configure Mailglass.Adapters.Fake with the host repo and explicit Fake ownership setup before the synchronous trigger. Use Mailglass's public migration wrapper, not hand-written Mailglass DDL or a Phoenix-oriented installer.

### Evidence, Safety, and Truthful Language
- **D-07:** Use Chimeway.Traces.explain_delivery/1 as the sole adopter-facing lifecycle evidence source. Require its email channel, notification/render identity, successful delivery and attempt outcome, Mailglass adapter identity, and ordered lifecycle evidence. A separate Fake assertion may verify exactly one generated host mailable was recorded, but it is test validation rather than public trace evidence.
- **D-08:** Emit one strict, machine-parseable CHIMEWAY_MAILGLASS_PROOF line with transport=fake and only allowlisted stable identity, channel/render identity, status/attempt, adapter, and timeline fields. Reject duplicate or unknown keys and forbid recipient addresses, subject/body/assigns, credentials, raw Mailglass structs, provider IDs/responses, full metadata, and direct database inspection from proof output.
- **D-09:** Follow the brandbook's literal, calm what happened -> why it matters -> next step voice. Say Fake recorded the host-composed message and Chimeway recorded a successful Mailglass adapter attempt; never use unqualified email delivered language.

### Documentation and Developer Experience
- **D-10:** Update the canonical Mailglass integration guide with a concise clean-consumer proof section: what it proves (local configured composition, mailable selection, Chimeway routing/attempt persistence) and what it does not prove (real provider acceptance, sender/domain verification, inbox placement, production credentials, provider callbacks, or live webhook feedback). Cross-reference the blueprint rather than duplicating a second end-to-end guide.
- **D-11:** Correct the guide's implication that Mailglass needs a separate Ecto repo: Mailglass uses a host-configured repo, while this proof intentionally uses one consumer-owned repo. Label mix verify.mailglass accurately as a repository maintainer regression suite, not a command supplied to a Hex consumer.

### the agent's Discretion
- Exact helper/module names, fixture-local non-sensitive message values, safe output field spelling/order, migration filename, and focused contract-test placement, provided all provenance, ownership, evidence, redaction, and documentation decisions above remain intact.

### Deferred Ideas (OUT OF SCOPE)
- Real-provider acceptance, credentials, sender/domain verification, deliverability/inbox placement, and production feedback tests — host/provider responsibility, outside deterministic CI proof.
- Webhook simulation and feedback progression — explicitly outside MAIL-01/MAIL-02 proof scope.
- Browser/admin proof — optional unpublished sibling surface; adds no artifact-consumer confidence.
- verify.adoption_paths and dedicated adoption CI lane — Phase 96.
- Chimeway core runtime dependency, migration, adapter, or Elixir-floor changes — out of scope.
</user_constraints>

## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| MAIL-01 | The Mailglass path proves configured transactional-email orchestration and trace evidence in the clean consumer fixture. | Extend the existing artifact scaffold with one host repo, a host Mailglass migration wrapper, email-only notifier/mailable/config, and trace-derived allowlisted evidence. [VERIFIED: codebase grep] |
| MAIL-02 | Mailglass guidance and proof output accurately distinguish fake-transport behavior from live-provider delivery and feedback coverage. | Keep the Fake count assertion inside the contract test; make the public line trace-only and document the exact local-composition boundary. [VERIFIED: codebase grep] |

## Project Constraints (from AGENTS.md)

- Persist stable `notification_key` plus version; module names are not durable identity. [VERIFIED: AGENTS.md]
- Preserve the durable lifecycle spine: event -> notification -> delivery -> attempt. [VERIFIED: AGENTS.md]
- Treat idempotency and suppression reasons as first-class behavior. [VERIFIED: AGENTS.md]
- Keep adapters replaceable through explicit behaviours and contract tests. [VERIFIED: AGENTS.md]
- Preserve host ownership of auth, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md]
- Maintain `mix verify.*` and `mix ci.*` entrypoints with local/CI parity, and do not leak sensitive payload fields into telemetry or operator surfaces. [VERIFIED: AGENTS.md]

## Summary

Implement this as a second capability of `Chimeway.Test.ArtifactConsumerFixture`, not as a new demo, CI lane, or production integration. The Phase 93 fixture already creates a unique temporary consumer and PostgreSQL database, validates that its sole `:chimeway` dependency is the unpacked artifact, runs generated migrations, executes a proof script, parses a strict line, and tears down on both success and failure. [VERIFIED: codebase grep]

The generated consumer should own exactly one `ArtifactConsumer.Repo`; configure it as Mailglass's repo and make the host migration call `Mailglass.Migration.up/0` and `down/0`. Mailglass's official repository contract states that Mailglass is a facade over a host-configured Ecto repo rather than owning one. [CITED: https://mailglass.hexdocs.pm/Mailglass.Repo.html]

The proof's public claim is intentionally narrow: Mailglass Fake recorded one host-composed mailable and Chimeway persisted a successful attempt through `Chimeway.Adapters.Mailglass`. Fake delivery storage and `set_shared/1` ownership support deterministic test assertions, but neither is provider acceptance or feedback evidence. [CITED: https://mailglass.hexdocs.pm/testing.html] [CITED: https://hexdocs.pm/mailglass/Mailglass.Adapters.Fake.html]

**Primary recommendation:** Add one serialized release-gate contract that calls `prove_mailglass!/1`, proves the exact render-key map path, and accepts only a trace-derived `CHIMEWAY_MAILGLASS_PROOF` allowlist.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Temporary consumer lifecycle and artifact provenance | API / Backend | Database / Storage | The fixture creates and validates the generated host and its isolated database. [VERIFIED: codebase grep] |
| Chimeway durable notification and delivery attempt | API / Backend | Database / Storage | Triggering persists the event-to-attempt lifecycle; `explain_delivery/1` projects that durable state. [VERIFIED: codebase grep] |
| Mailglass persistence | Database / Storage | API / Backend | Mailglass delegates persistence through the host-configured Ecto repo. [CITED: https://mailglass.hexdocs.pm/Mailglass.Repo.html] |
| Mailable assembly and render-key selection | API / Backend | — | The generated host owns the mailable; Chimeway resolves its persisted render key through the configured map. [VERIFIED: codebase grep] |
| Deterministic transport observation | API / Backend | — | Fake records local delivery data under explicit ownership; it is a test observation, not public lifecycle evidence. [CITED: https://hexdocs.pm/mailglass/Mailglass.Adapters.Fake.html] |
| Sanitized proof output and guide boundary | API / Backend | — | The script serializes a fixed safe projection and the guide explains its limits. [VERIFIED: codebase grep]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---:|---|---|
| `chimeway` | unpacked artifact | Public trigger, durable lifecycle, and `Chimeway.Traces.explain_delivery/1` proof surface. [VERIFIED: codebase grep] | This is the artifact whose adopter path is being proven. [VERIFIED: codebase grep] |
| `mailglass` | `~> 1.3` / resolved `1.3.0` | Host mailable, migration wrapper, and Fake transport. [VERIFIED: mix.exs and mix.lock] | It is the locked integration selected by context and the existing adapter compiles against it. [VERIFIED: codebase grep] |
| `ecto_sql` + `postgrex` | consumer-compatible; repository resolves `3.13.5` / `0.22.3` | Host repo and temporary PostgreSQL migrations. [VERIFIED: mix deps] | The existing clean consumer already uses these direct dependencies and `mix ecto.migrate`. [VERIFIED: codebase grep] |
| `oban` | `~> 2.17` / resolved `2.23.0` | Existing direct consumer opt-in retained from Phase 93. [VERIFIED: mix.exs and mix deps] | Preserve the existing artifact consumer topology; do not make Mailglass change core support. [VERIFIED: 94-CONTEXT.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---:|---|---|
| `Swoosh` | transitively resolved `1.26.3` | Mailable composition inside the generated host mailable. [VERIFIED: mix deps] | Use only in the generated host mailable pattern already used by the demo. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| One host repo | `Mailglass.TestRepo` | Rejected: test repo isolation is an internal harness pattern and would not prove adopter ownership. [VERIFIED: 94-CONTEXT.md] |
| Artifact consumer proof | DemoHost or `mix verify.mailglass` | Rejected: these are maintainer regression surfaces, not unpacked-artifact adoption proof. [VERIFIED: 94-CONTEXT.md] |
| Public trace evidence | Direct consumer database queries | Rejected: direct inspection would bypass the public explainability boundary and violates D-07/D-08. [VERIFIED: 94-CONTEXT.md] |

**Generated-consumer dependency shape:**

```elixir
{:chimeway, path: unpacked_artifact},
{:mailglass, "~> 1.3"},
{:ecto_sql, "~> 3.11"},
{:postgrex, ">= 0.0.0"},
{:oban, "~> 2.17"}
```

This adds `mailglass` directly to the generated consumer while retaining the Phase 93 direct dependencies. [VERIFIED: 94-CONTEXT.md]

## Package Legitimacy Audit

The seam's package-legitimacy command supports npm, PyPI, and crates only, not Hex; it cannot issue the required automated verdict for these Hex packages. [VERIFIED: gsd-tools CLI usage]

| Package | Registry | Evidence | Verdict | Disposition |
|---|---|---|---|---|
| `mailglass` | Hex | Existing root optional dependency is constrained to `~> 1.3` and resolved to `1.3.0`; `mix hex.info` identifies its upstream repository as `szTheory/mailglass`. [VERIFIED: mix.exs, mix deps, mix hex.info] | Manual review required | Use the already-resolved 1.3 line only; do not upgrade in this phase. |
| `ecto_sql`, `postgrex`, `oban` | Hex | Existing Phase 93 consumer dependencies and root-resolved packages. [VERIFIED: codebase grep, mix deps] | Existing dependencies | Reuse; do not change versions in this phase. |

**Packages removed due to [SLOP] verdict:** none — no Hex-capable automated verdict exists. [VERIFIED: gsd-tools CLI usage]

## Architecture Patterns

### System Architecture Diagram

```text
release-gate ExUnit test (async: false)
  -> build + unpack Chimeway artifact
  -> ArtifactConsumerFixture.prove_mailglass!
     -> generated host: deps.get -> chimeway migrations -> ecto.create -> ecto.migrate
     -> host migrations: Chimeway generated migrations + Mailglass.Migration wrapper
     -> configure ArtifactConsumer.Repo for Chimeway and Mailglass
     -> Fake.checkout + Fake.set_shared(owner) + synchronous Chimeway.trigger
     -> notifier(render_key/version) -> Chimeway.Adapters.Mailglass
     -> configured render_key map -> host Mailglass.Mailable -> Mailglass Fake
     -> Chimeway.Traces.explain_delivery(delivery_id)
     -> CHIMEWAY_MAILGLASS_PROOF (allowlisted trace projection)
  -> assert one Fake-recorded host mailable (test-only)
  -> validated database and filesystem cleanup
```

The existing adapter resolves `delivery.render_key` through the `mailables` map, merges recipient data into mailable assigns, calls `Mailglass.Outbound.deliver/2`, and records the adapter outcome. [VERIFIED: codebase grep]

### Recommended Project Structure

```text
test/support/artifact_consumer_fixture.ex       # extend generated host/scaffold/parser helpers
test/chimeway/release_gate_contract_test.exs    # serialized end-to-end adoption contract
guides/introduction/mailglass-integration.md    # canonical concise proof/boundary guidance
test/chimeway/doc_contract_test.exs             # doc truth contract for command and limits
```

### Pattern 1: Generated host owns one repo and both migration sets

**What:** Generate `ArtifactConsumer.Repo`, configure it for both applications, add a generated migration module that delegates to `Mailglass.Migration`, and run normal `mix ecto.migrate`. [VERIFIED: 94-CONTEXT.md]

**When to use:** Always for this proof; do not copy the root's `Mailglass.TestRepo` harness. [VERIFIED: 94-CONTEXT.md]

**Example:**

```elixir
defmodule ArtifactConsumer.Repo.Migrations.MailglassInit do
  use Ecto.Migration

  def up, do: Mailglass.Migration.up()
  def down, do: Mailglass.Migration.down()
end
```

This matches the repository's existing migration-wrapper precedent. [VERIFIED: codebase grep]

### Pattern 2: Separate public evidence from Fake validation

**What:** Read lifecycle facts only from `Chimeway.Traces.explain_delivery/1`; separately assert that Fake recorded exactly one host mailable without serializing Fake data. [VERIFIED: 94-CONTEXT.md]

**When to use:** At the end of the synchronous proof, after selecting the one email delivery ID returned from the public trigger result. [VERIFIED: 94-CONTEXT.md]

**Example:**

```elixir
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
true = explanation.channel == "email"
true = explanation.render_key == "artifact_consumer.mailglass_proof.email"
true = explanation.status == :succeeded
true = explanation.last_attempt.outcome == :succeeded
true = explanation.last_attempt.adapter_module == "Chimeway.Adapters.Mailglass"
true = length(Mailglass.Adapters.Fake.deliveries()) == 1
```

`explain_delivery/1` includes channel, render identity, status, last-attempt outcome/module, and chronological timeline. [VERIFIED: codebase grep]

### Anti-Patterns to Avoid

- **Second harness:** Do not build another temporary consumer; extend the existing fixture so artifact provenance, cleanup, and serialized database ownership remain common. [VERIFIED: 94-CONTEXT.md]
- **Private/data evidence:** Do not print `Repo` rows, recipient data, mailable structs, provider response, or rendered content. [VERIFIED: 94-CONTEXT.md]
- **Unqualified delivery language:** Do not call the outcome “email delivered”; Fake proves local recording/composition, not provider or inbox outcome. [VERIFIED: 94-CONTEXT.md]
- **Separate Mailglass repo:** Do not configure a generated `Mailglass.TestRepo`; the official Mailglass contract is host-configured repo ownership. [CITED: https://mailglass.hexdocs.pm/Mailglass.Repo.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Mailglass schema creation | Hand-written Mailglass DDL | `Mailglass.Migration.up/0` / `down/0` in host migration | The public wrapper preserves Mailglass-owned schema evolution. [VERIFIED: codebase grep] |
| Transactional-email transport | Fake SMTP/provider imitation | `Mailglass.Adapters.Fake` | Its public API records deliveries and provides explicit ownership controls. [CITED: https://hexdocs.pm/mailglass/Mailglass.Adapters.Fake.html] |
| Lifecycle explanation | Custom joins or proof-only repository reads | `Chimeway.Traces.explain_delivery/1` | It is the public, structured delivery explanation seam. [VERIFIED: codebase grep] |
| Artifact isolation and cleanup | Another shell harness | `ArtifactConsumerFixture` | It already protects provenance, unique resources, cleanup, and strict output parsing. [VERIFIED: codebase grep] |

**Key insight:** the proof needs only orchestration evidence plus one Fake count; attempting to expose rendered message or provider-shaped data would weaken the public boundary without proving a live transport. [VERIFIED: 94-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Mailglass Fake ownership is missing or too broad

**What goes wrong:** the synchronous proof cannot see the mailable record, or a future cross-process change shares global Fake state. [CITED: https://mailglass.hexdocs.pm/testing.html]

**How to avoid:** call `Mailglass.Adapters.Fake.checkout/0` and explicitly establish the fixture owner with `set_shared(self())` before trigger, then retain the `async: false` serialized proof boundary. [VERIFIED: 94-CONTEXT.md]

### Pitfall 2: The mailable path is not truly exercised

**What goes wrong:** a generic adapter success can pass even if notifier key, persisted render key, config map, or host mailable are not tied together. [VERIFIED: 94-CONTEXT.md]

**How to avoid:** assert the exact email channel, render key/version, adapter module, and exactly one Fake record produced by the generated host mailable. [VERIFIED: 94-CONTEXT.md]

### Pitfall 3: Proof output leaks data or overclaims

**What goes wrong:** output includes recipient/body/metadata/provider data, or says the email was delivered. [VERIFIED: 94-CONTEXT.md]

**How to avoid:** strict parse with no atom creation, exact allowlisted keys, and guide copy that names Fake recording and a successful adapter attempt only. [VERIFIED: codebase grep] [VERIFIED: 94-CONTEXT.md]

### Pitfall 4: Wrong migration/repo architecture

**What goes wrong:** the proof relies on a private test repo or hand-written schema, so it no longer models consumer ownership. [VERIFIED: 94-CONTEXT.md]

**How to avoid:** use the one generated host repo for both Chimeway and Mailglass and run the public migration wrapper through the generated host's normal migration path. [CITED: https://mailglass.hexdocs.pm/Mailglass.Repo.html]

## Code Examples

### Strict evidence serialization design

```elixir
evidence = %{
  transport: :fake,
  notification_key: explanation.notification_key,
  notification_version: notifier.version(),
  delivery_id: explanation.delivery_id,
  channel: explanation.channel,
  render_key: explanation.render_key,
  render_version: explanation.render_version,
  status: explanation.status,
  last_attempt_outcome: explanation.last_attempt.outcome,
  adapter_module: explanation.last_attempt.adapter_module,
  timeline_events: Enum.map_join(explanation.timeline, ",", & &1.event)
}
```

Use a fixed ordered key list and parser map, analogous to the existing core proof, and reject unknown/duplicate/malformed fields before any atom conversion. [VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Root `Mailglass.TestRepo` and demo-host Mailglass tests | One generated adopter-owned repo in a packaged-artifact consumer | Phase 94 decision | Proves the intended host architecture rather than test harness isolation. [VERIFIED: 94-CONTEXT.md] |
| `CHIMEWAY_CORE_PROOF` lifecycle-only allowlist | Dedicated `CHIMEWAY_MAILGLASS_PROOF` with channel/render/adapter/transport fields | Phase 94 decision | Retains strict public evidence while proving the Mailglass-specific seam. [VERIFIED: 94-CONTEXT.md] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The generated host can use the selected Mailglass 1.3 public migration and Fake APIs exactly as the current repository test/demo harnesses do. | Standard Stack / Architecture | The generated fixture will need an API-shape adjustment after its first real run. |

The underlying Mailglass functionality is confirmed by current official docs and local 1.3 usage, but the fetched official docs were for the current 2.4 documentation, not a versioned 1.3 document. [ASSUMED]

## Open Questions (RESOLVED)

1. **Which non-sensitive stable values should the generated proof use?**
   - What we know: names, values, ordering, and migration filename are explicitly discretionary. [VERIFIED: 94-CONTEXT.md]
   - Resolution: use `artifact_consumer.mailglass_proof` as the notification key, `artifact_consumer.mailglass_proof.email` as the render key, and version `1`; contract-test only these stable outputs, not private fixture names. This is resolved under the agent's discretion in CONTEXT.md and matches the values selected by Plan 94-01.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir / Mix | Generated consumer build and proof | ✓ | Elixir/Mix 1.19.5, OTP 28 | None needed; exceeds Mailglass adapter's local 1.18+ note. [VERIFIED: local CLI, codebase grep] |
| PostgreSQL | Temporary consumer database | ✓ | client 14.17; local `:5432` accepting connections | None needed. [VERIFIED: local CLI] |
| Hex packages | Generated consumer `deps.get` | ✓ | existing resolved dependencies include Mailglass 1.3.0 | Network/Hex cache required at execution. [VERIFIED: mix deps] |

**Missing dependencies with no fallback:** none. [VERIFIED: local CLI]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit (project Mix test suite). [VERIFIED: codebase grep] |
| Config file | `config/test.exs`. [VERIFIED: codebase grep] |
| Quick run command | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` |
| Full suite command | `mix ci.verify_gates` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| MAIL-01 | Clean artifact consumer executes exact notifier -> render key -> mailable -> Mailglass Fake route and trace proof. | integration/contract | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` | ✅ extend existing |
| MAIL-01 | Output parser rejects unsafe, duplicate, and unknown Mailglass proof fields. | unit/contract | same release-gate test command | ❌ Wave 0 additions |
| MAIL-02 | Canonical guide states Fake boundary and calls `mix verify.mailglass` a maintainer suite. | documentation contract | `MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --warnings-as-errors` | ✅ extend existing |

### Sampling Rate

- **Per task commit:** targeted release/doc contract command above.
- **Per wave merge:** `mix ci.verify_gates`.
- **Phase gate:** full `mix ci.verify_gates` green before verification; retain existing ecosystem `mix verify.mailglass` as regression evidence, but do not present it as consumer proof. [VERIFIED: 94-CONTEXT.md]

### Wave 0 Gaps

- [ ] Extend `test/chimeway/release_gate_contract_test.exs` with the serialized clean-consumer Mailglass proof and parser/safety rejection assertions.
- [ ] Extend `test/chimeway/doc_contract_test.exs` with required boundary language and forbidden overclaim/consumer-command assertions.
- [ ] No new test framework or CI lane; both are explicitly out of scope. [VERIFIED: 94-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No authentication surface is added. [VERIFIED: 94-CONTEXT.md] |
| V3 Session Management | no | No session surface is added. [VERIFIED: 94-CONTEXT.md] |
| V4 Access Control | no | The proof has no user-facing authorization decision. [VERIFIED: 94-CONTEXT.md] |
| V5 Input Validation | yes | Strict fixed-key proof parser rejects unknown, duplicate, and malformed output; never atomize untrusted keys. [VERIFIED: codebase grep] |
| V6 Cryptography | no | The proof uses no live credentials, provider signature, or cryptographic transport operation. [VERIFIED: 94-CONTEXT.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| PII/secrets in CI proof output | Information Disclosure | Trace-derived allowlist; forbid recipient, body, assigns, credentials, provider response, raw structs, and metadata. [VERIFIED: 94-CONTEXT.md] |
| Source-artifact substitution | Tampering | Preserve fixture validation requiring the one `:chimeway` dependency to equal the unpacked artifact and not repository source. [VERIFIED: codebase grep] |
| Cross-test Fake contamination | Tampering | Explicit Fake checkout/owner setup and serialized `async: false` release-gate proof. [CITED: https://mailglass.hexdocs.pm/testing.html] |

## Sources

### Primary (MEDIUM confidence)

- [Mailglass Repo](https://mailglass.hexdocs.pm/Mailglass.Repo.html) — host-configured Ecto repo ownership.
- [Mailglass Testing](https://mailglass.hexdocs.pm/testing.html) — Fake baseline, deterministic ownership, and narrow test scope.
- [Mailglass Fake API](https://hexdocs.pm/mailglass/Mailglass.Adapters.Fake.html) — checkout, shared owner, and recorded-delivery API.

### Local verification

- `test/support/artifact_consumer_fixture.ex` — packaged-artifact consumer, strict Core proof parser, provenance, unique resources, and cleanup.
- `lib/chimeway/adapters/mailglass.ex` — render-key mailable resolution and success outcome behavior.
- `lib/chimeway/traces.ex`, `lib/chimeway/traces/explanation.ex` — public explanation fields and ordered timeline.
- `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/doc_contract_test.exs` — existing contract-test anchors.

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — the existing resolved 1.3 dependency and local use are verified; fetched official Mailglass docs are current 2.4 docs. [ASSUMED]
- Architecture: HIGH — locked context plus directly inspected fixture, adapter, trace, migration, and release-gate seams. [VERIFIED: codebase grep]
- Pitfalls: HIGH — explicit Phase 94 decisions and official Fake ownership documentation. [CITED: https://mailglass.hexdocs.pm/testing.html]

**Research date:** 2026-08-08  
**Valid until:** 2026-08-15, because Mailglass's public documentation currently describes 2.4 while the phase is intentionally locked to the repository's 1.3 line. [ASSUMED]
