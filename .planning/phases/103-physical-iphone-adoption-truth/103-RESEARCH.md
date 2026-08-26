# Phase 103: Physical iPhone & Adoption Truth - Research

**Researched:** 2026-08-26
**Domain:** Redacted cross-repository iPhone proof and adoption-operations documentation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

The locked decisions are copied verbatim in 103-CONTEXT.md: retain hermetic Extension v1; introduce a separate versioned physical proof envelope/bundle; bind immutable Chimeway artifact and exact CrossWake remote/SHA/contract/evidence/marker digests; delegate CrossWake semantic validation at the pinned source revision; use fixed owner-qualified facts and fail-closed non-echoing privacy validation; retain no tokens, payloads, identities, device identifiers, endpoints, screenshots, logs, or uncontrolled maps; isolate a closed visible-alert attestation with states observed/not_observed/unavailable and append-only retries; publish one canonical mobile adoption guide; and use Threshold A release_ready_physical_pending versus Threshold B physical_support_promoted. Apple credentials, signing, selected phone, and alert observation are the only legitimate external/subjective gates.

### the agent's Discretion

Exact module, task, rule-ID, fixture, bundle, JSON-field, completion-marker, CrossWake-integration, and guide-layout names remain discretionary only if schemas stay closed/versioned/deterministic/atom-safe/digest-linked, CrossWake remains semantic authority, and DOCS-01 stays easy to find and contract checked.

### Deferred Ideas (OUT OF SCOPE)

FCM/Android, generic background sync, engagement analytics, screenshots/video retention, a general attestation platform, and broader device/support matrices.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| TWIN-03 | Physical sandbox proof records permission, registration, APNs acceptance, visible alert, and protected activation as redacted machine evidence with subjective display isolated. | New physical envelope/bundle, selected CrossWake extension, append-only publisher, and separate attestation. |
| DOCS-01 | Accurate integration/operator guide for boundaries, setup, migration, outcomes, offline opens, commands, and non-goals. | Canonical ExDoc guide, shallow README/selector links, executable docs contracts. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve stable notification keys/version and the durable event -> notification -> delivery -> attempt spine.
- Preserve host ownership of auth, tenancy, URLs, correlation IDs, credentials, and raw token custody.
- Keep adapters replaceable and contract-tested; do not leak sensitive payload fields.
- Maintain named verify/ci entrypoints with local/CI parity.
- Objective acceptance is executable evidence; only credentials/hardware and subjective display observation can be human-gated.

## Summary

Phase 103 has two thresholds. Threshold A ships credential-free schemas, validators, fixtures, preflight, CI/doc parity, and an explicit physical-evidence-pending guide. Threshold B alone can promote TWIN-03: it requires the signed physical run, source-bound CrossWake validation, Chimeway machine facts, and a separate observed alert attestation. [CITED: 103-CONTEXT.md]

Keep Chimeway.MobileProof.Extension v1 unchanged: it is a closed hermetic contract. Add a distinct physical proof class/envelope and an atomic bundle containing independently typed Chimeway, CrossWake, attestation, and completion-marker records joined by full digests and opaque run reference. [VERIFIED: codebase inspection — lib/chimeway/mobile_proof/extension.ex, Phase 103 context]

Resolve CrossWake revision drift first. Phase 102 CI pins f2c502cdb1ce572a4a57257d9e3c051665704b90, but the local CrossWake checkout is 5b4713bcef51e2ea68a0633e966c16652672bb82 and its retained physical evidence names source commit 5f4265932ee781aa4cc75c6bd3d8e416488ca640. Select and prove a clean detached compatible SHA that exposes the notification extension; never reuse the hermetic pin by default. [VERIFIED: local repositories, .github/workflows/ci.yml, CrossWake Phase 162 evidence]

CrossWake Evidence.check/2 is source-bound: it needs canonical bytes to verify approved hashes; check/1 intentionally cannot pass without them. Chimeway must run the CrossWake-owned validator at the selected revision and retain only safe digests, never copied semantic report/source bytes. The current CrossWake artifact proves offline study, not notification delivery. [VERIFIED: ../crosswake/lib/crosswake/proof_lane/evidence.ex and current evidence]

**Primary recommendation:** complete Threshold A first, with support wording deliberately pending; then perform an append-only Threshold-B promotion only after every executable validator passes and the one subjective alert state is observed.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Package digest, delivery/attempt/trace, APNs acceptance | API / Backend | Database | Chimeway owns durable lifecycle/explainability. [VERIFIED: Phase 102 code] |
| Permission/token observation | Native iOS | API / Backend | iOS observes authorization/registration; host receives authority without retaining proof tokens. [CITED: https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns] |
| Protected activation | API / Backend | Native iOS | CrossWake/host owns one-time authorization. [CITED: 103-CONTEXT.md] |
| Visible alert | Native iOS | Human observer | Subjective fact must be separately attested. [CITED: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications] |
| Bundle validation/publication | API / Backend | Storage | Closed schema/privacy/digest/no-replace validation. [VERIFIED: CrossWake Evidence/NativePromotion] |
| Operations guide | Static docs | API / Backend | One ExDoc authority prevents drift. [VERIFIED: mix.exs and doc contracts] |

## Standard Stack

| Component | Version / Pin | Purpose |
|---|---|---|
| Existing MobileProof Extension | v1 unchanged | Historical hermetic proof contract. [VERIFIED: Extension] |
| New physical proof module/bundle | v1 physical schema | Closed envelope, attestation, privacy/no-replace validation. [CITED: D-01–D-12] |
| Immutable built Chimeway archive | SHA-256 per run | Artifact provenance binding. [VERIFIED: verify.physical_proof_contract] |
| CrossWake source-bound verifier | selected full SHA, not old pin | CrossWake-owned semantic validation. [CITED: D-04–D-06] |
| Existing ExUnit/doc/release contracts | project local | Negative corpus and guide/alias/CI parity. [VERIFIED: mix ci.verify_gates] |

No new external package is needed. [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Threshold A: fixtures + docs -> closed validator -> verify.physical_proof_contract
                           -> docs/release contracts -> ci.verify_gates

Threshold B:
immutable Chimeway tar -> Alpha host -> Chimeway provider-acceptance fact
signed iPhone -> permission/registration -> CrossWake notification extension -> source-bound validator
observer state -> separate visible-alert attestation
safe record digests + opaque run -> atomic no-replace bundle -> coordinated support promotion
```

### Required Patterns

1. Independently typed records: exact keys, versions, owner values, ordering, full hashes, recursive privacy scan; only observed is promotable. [CITED: D-02–D-12]
2. Source-bound CrossWake authority: checkout exact remote/SHA, hash canonical evidence and marker bytes, call CrossWake checker, retain digest-only references. [CITED: D-03–D-07]
3. One guide: add guides/introduction/mobile-adoption-operations.md to ExDoc; README and Adoption Paths link but do not duplicate the runbook. Contract-test roles, commands, wording, links, and boundaries. [CITED: D-14–D-18]

### Anti-Patterns to Avoid

- Reusing Phase 102 pin or any floating revision.
- Calling provider acceptance receipt, display, protected activation, inbox read, or engagement.
- Embedding visible alert in executable facts or retaining screenshots/video/logs.
- Copying/reinterpreting CrossWake facts in Chimeway.
- Overwriting prior runs or calling Threshold A physical support.

## Don't Hand-Roll

| Problem | Use Instead | Why |
|---|---|---|
| Authorization/token acquisition | Signed host UserNotifications/UIKit APIs | OS-owned, rotating opaque token lifecycle. [CITED: Apple APNs registration docs] |
| CrossWake proof semantics | CrossWake public source-bound validator | Keeps fact/source authority with owner. [VERIFIED: Evidence.check/2] |
| No-replace publication | CrossWake NativePromotion pattern | Atomic collision/marker integrity. [VERIFIED: CrossWake source] |
| Open maps/unsafe atoms | Existing Extension exact-key patterns | Prevents atom/sensitivity/error-echo failures. [VERIFIED: Extension] |

## Common Pitfalls

### Revision and report drift

Phase 162 final-tree reconciliation/evidence says complete, while 162-VERIFICATION.md remains an older gaps_found report. Require selected-SHA source-bound evidence verification as a machine preflight; do not trust either the old Phase 102 pin or summary-only status. [VERIFIED: CrossWake artifacts]

### Evidence conflation

Provider success is not visible delivery/open. Keep Chimeway provider acceptance, CrossWake protected activation, and human alert attestation separate. Apple documents separate user authorization and APNs registration/token callbacks. [CITED: https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29]

### Mutable promotion

Every retry must have fresh opaque run reference/destination. Collision, duplicates, or completion-digest mismatch fail. [CITED: D-12; VERIFIED: NativePromotion]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The chosen CrossWake revision exposes a public source-bound Chimeway-notification physical extension compatible with current evidence APIs. [ASSUMED] | Stack/Open Questions | Coordinated CrossWake change or different pin is required before Threshold A. |

## Open Questions

1. Which exact CrossWake remote SHA/module/API exposes the notification assertion list for permission, authenticated registration, and protected activation? Current inspected PhysicalIphoneContract is offline-study-specific. First plan task must resolve, fixture, and test this. [VERIFIED: current CrossWake source]
2. How will canonical CrossWake bytes remain ephemeral while Evidence.check/2 receives them? Keep them inside CrossWake checking scope and expose only result plus safe digests. [CITED: D-03/D-04]
3. Has Phase 162 independent verification accepted its reconciliation? Until then, run exact selected-SHA source-bound check and focused CrossWake tests before Chimeway promotion. [VERIFIED: CrossWake state/artifacts]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir/Mix | validators/contracts | ✓ | OTP 28 | — |
| Docker | local test parity | ✓ | 29.5.2 | CI service |
| Xcode/xcrun | signed iPhone build | ✓ | Xcode 26.6 | none |
| iOS Simulator | native contract checks | ✓ | iOS 26.5 | never physical proof |
| Apple signing + selected iPhone | Threshold B | ✗ external | — | none |
| CrossWake checkout | source validation | ✓ | 5b4713… | detached selected SHA |

## Validation Architecture

| Req | Behavior | Test Type | Command | Gap |
|---|---|---|---|---|
| TWIN-03 | physical schema rejects key/order/owner/revision/digest/privacy/no-replace failures | unit | mix verify.physical_proof_contract | Wave 0 |
| TWIN-03 | hermetic v1 remains immutable | unit | mix test test/chimeway/mobile_proof_extension_test.exs | existing |
| TWIN-03 | selected CrossWake bytes/marker/source-bound check pass | integration auto | selected-SHA compatibility runner + focused CrossWake tests | Wave 0 |
| TWIN-03 | attestation only allows three states and automation cannot produce observed | unit | mix test test/chimeway/mobile_physical_proof_test.exs | Wave 0 |
| DOCS-01 | guide roles/commands/vocabulary/links/support wording/non-goals do not drift | doc contract | mix ci.verify_gates | Wave 0 |

Per wave run: mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract. Threshold B adds generated source-bound bundle verification; only visible alert observation is subjective.

## Security Domain

| ASVS | Applies | Control |
|---|---|---|
| V2/V3 | Yes | Host/CrossWake own authenticated registration/one-time open and replay. |
| V4 | Yes | Fixed owner-qualified facts. |
| V5 | Yes | Exact keys/enums/order, bounded fields, privacy scan, non-echoing errors. |
| V6 | Yes | SHA-256 binding and source-bound check; no custom signing. |
| V14 | Yes | Credential-free CI; signed host is external preflight. |

Test forged revision, raw token/provider-body leak, fabricated device fact, overwrite/replay, and CI/package provenance misrepresented as physical behavior. [CITED: D-04–D-08]

## Sources

### Primary (HIGH confidence)

- Chimeway Extension, verifier, fixtures, mix aliases, CI, doc/release tests.
- CrossWake current 5b4713bcef51e2ea68a0633e966c16652672bb82, Phase 162 evidence, Evidence, NativePromotion, state/support matrix.
- Apple APNs registration, remote registration, and notification permission docs.

### Secondary (MEDIUM confidence)

- Research-plan Context7 route had no installed client; official Apple web fallback was fetched and cached.

## Metadata

Standard stack, architecture, and pitfalls: HIGH confidence from current source/artifact inspection. Valid until 2026-09-02 because CrossWake physical state is fast-moving.
