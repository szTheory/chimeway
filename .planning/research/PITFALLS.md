# Pitfalls Research

**Domain:** Embedded multi-channel notification infrastructure  
**Researched:** 2026-04-23  
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Unstable Notification Identity

**What goes wrong:**  
Historical rows become disconnected after refactors because notification type identity is tied to module names.

**Why it happens:**  
Teams persist implementation details (module/class names) instead of stable domain keys.

**How to avoid:**  
Persist stable `notification_key` + version from day one. Add validation and migration guidance for key changes.

**Warning signs:**  
Rename discussions include "DB backfill required," or old rows cannot resolve to current notifier logic.

**Phase to address:**  
Phase 1 - Core data spine and notifier contract.

---

### Pitfall 2: Hidden Sends Without Durable Trace

**What goes wrong:**  
Provider calls happen but failures are only in logs, making support/debugging impossible.

**Why it happens:**  
Dispatch implementation is written before durable event/delivery/attempt schema design.

**How to avoid:**  
Persist event, notification, delivery, and attempt rows before and after dispatch boundaries.

**Warning signs:**  
"User didn't get notification" tickets require log archaeology instead of one query.

**Phase to address:**  
Phase 1-2 - persistence model and first outbound channel.

---

### Pitfall 3: Idempotency Gaps Cause Duplicate Sends

**What goes wrong:**  
Retries or repeated triggers create duplicate recipient deliveries.

**Why it happens:**  
Idempotency is delegated to queue/provider behavior only, without local constraints.

**How to avoid:**  
Define deterministic idempotency keys, enforce DB uniqueness, and record duplicate suppression outcomes.

**Warning signs:**  
Two delivery rows with same business event semantics and close timestamps.

**Phase to address:**  
Phase 1-2 - trigger pipeline and delivery planning.

---

### Pitfall 4: Policy Only Checked at Enqueue Time

**What goes wrong:**  
Users receive messages after changing preferences or after reading in-app notifications.

**Why it happens:**  
Delayed jobs trust stale policy decisions from initial enqueue.

**How to avoid:**  
Run policy twice: pre-enqueue and pre-perform. Store suppression reason in trace.

**Warning signs:**  
Incidents where users report "I turned this off but still got email."

**Phase to address:**  
Phase 2-3 - outbound adapter + async dispatch policy integration.

---

### Pitfall 5: Admin Surface Built Before Data Semantics

**What goes wrong:**  
Pretty dashboard exists but cannot answer operational questions or safely redact sensitive payloads.

**Why it happens:**  
UI scope starts before lifecycle states and trace model are finalized.

**How to avoid:**  
Finalize state machine and trace schema first; build admin UI as a thin projection over durable facts.

**Warning signs:**  
UI uses ad hoc computed status labels not backed by persisted lifecycle states.

**Phase to address:**  
Phase 3-4 - observability and optional admin mount.

---

### Pitfall 6: Channel Lock-In in Core

**What goes wrong:**  
Core package becomes tightly coupled to one provider SDK, blocking adoption and upgrades.

**Why it happens:**  
Early velocity favors direct provider calls without behaviour boundaries.

**How to avoid:**  
Define adapter behaviours and contract tests before adding non-trivial channels.

**Warning signs:**  
Core dependencies include multiple provider clients that most users do not need.

**Phase to address:**  
Phase 2 onward - adapter seam and per-channel packages.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Sync-only dispatch forever | Fast initial implementation | Reliability limits, no retry/queue control | Acceptable only for early prototype stage. |
| No attempt table, only final status | Fewer tables/migrations | No forensic visibility into transient failures | Never acceptable for production release. |
| Store full raw payloads everywhere | Easy debugging | PII leakage risk and DB bloat | Only in local/dev with explicit redaction disabled. |
| Skip contract tests for adapters | Faster first integration | Regressions when adding providers/channels | Never once external adapters are public. |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Swoosh | Assuming send success equals user-visible delivery | Persist provider acceptance and keep explicit status wording. |
| Oban | Treating uniqueness as runtime concurrency control | Use uniqueness for insertion dedupe and queue limits for concurrency/rate. |
| Twilio/SMS | Missing consent/STOP handling | Require explicit consent model and webhook callback validation. |
| Push providers | Ignoring invalid token lifecycle | Persist token health and invalidate on provider terminal errors. |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Missing composite indexes on recipient inbox queries | Slow unread/feed queries and high DB CPU | Index by tenant/recipient/read-state/time | Often around 10k+ active recipients. |
| Large payload JSON blobs on hot tables | Vacuum pressure and slow scans | Store compact snapshots + references, enforce size limits | 100k+ delivery rows/day. |
| Single queue for all channels | Starvation and retry storms | Per-channel queues and isolated worker concurrency | Moderate load spikes and provider outages. |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Exposing admin trace routes without host auth callback | Privileged data disclosure and unauthorized actions | Require explicit host-provided auth policy and fail closed defaults. |
| Logging secret tokens or full provider payloads | Credential and PII leakage | Redact sensitive fields and classify payload visibility. |
| Unsigned webhook callbacks | Spoofed delivery status and audit tampering | Verify signatures, timestamps, and replay windows. |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Conflating `seen` with `read` | Incorrect fallback suppression and confusing inbox behavior | Keep separate timestamps and explicit APIs for each transition. |
| Vague failure messaging ("notification failed") | Support cannot resolve incidents quickly | Store and surface structured suppression/failure reason codes. |
| Over-notifying across channels by default | User fatigue and preference opt-outs | Respect preference defaults, quiet hours, and escalation timing. |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Trigger API:** Often missing deterministic idempotency key path - verify dedupe works under retries.
- [ ] **Outbound adapter:** Often missing attempt persistence - verify each provider call creates attempt rows.
- [ ] **Preference controls:** Often missing perform-time recheck - verify delayed jobs honor latest settings.
- [ ] **Admin trace:** Often missing safe redaction - verify secrets/PII never appear in list views.
- [ ] **CI lanes:** Often missing integration and docs-contract checks - verify lane parity with CONTRIBUTING guidance.

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Unstable notification identity | HIGH | Introduce stable key mapping table, backfill rows, add compatibility resolver. |
| Duplicate sends from missing idempotency | HIGH | Add unique constraints, reprocess duplicate events, document incident guardrails. |
| Untraceable failures | MEDIUM | Add attempt table + telemetry spans, backfill partial historical diagnostics where possible. |
| Policy staleness on delayed jobs | MEDIUM | Patch perform-time checks, replay suppressed/incorrect deliveries with audit markers. |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Unstable notification identity | Phase 1 | Migration + API tests prove stable key/version storage. |
| Hidden sends without durable trace | Phase 1-2 | Integration tests show attempt rows for success/failure paths. |
| Idempotency gaps | Phase 1-2 | Property/integration tests cover repeated trigger and retry scenarios. |
| Policy only checked at enqueue | Phase 2-3 | Delayed fallback tests prove late suppression works. |
| Premature admin UI over weak data model | Phase 3-4 | Trace UI test fixtures backed by persisted lifecycle states. |
| Channel lock-in in core | Phase 2+ | Contract tests pass for fake + real adapter implementations. |

## Sources

- `prompts/elixir_notifykit_research_brief.md`
- `prompts/chimeway-admin-ui-and-operator-ia.md`
- `prompts/chimeway-testing-and-e2e-strategy.md`
- `prompts/chimeway-host-app-integration-seam.md`

---
*Pitfalls research for: Chimeway*
*Researched: 2026-04-23*
