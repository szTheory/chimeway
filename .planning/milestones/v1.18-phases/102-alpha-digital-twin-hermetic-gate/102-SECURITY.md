---
phase: 102
slug: alpha-digital-twin-hermetic-gate
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-26
---

# Phase 102 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Source tree → packaged Alpha fixture | Only a validated immutable Chimeway archive may enter the clean host fixture. | Source archive, SHA-256 digest, migrations, fixture code |
| Git remote → detached CrossWake worktree | Only the canonical public origin and locked full SHA may supply mobile contracts. | Repository origin, commit SHA, clean/detached worktree state |
| Scenario ledger → runner and transport | Untrusted decoded scenario data selects safety-critical actions and expected outcomes. | Versioned string-key JSON, ordered scenario identifiers |
| Fixture clock → Chimeway runtime | Test-controlled time crosses into exercised production call sites while production defaults remain unchanged. | Resolved UTC timestamps and explicit clock provider |
| Host registry → Chimeway and CrossWake | Raw tokens and authorization authority remain host-private; only opaque, scope-bound values cross. | Tenant, environment, topic, binding revision, intent reference |
| Chimeway adapter → scripted transport | A real bounded request crosses, but capture is redacted before observation. | APNs request metadata and closed provider outcome |
| Concurrent dispatch/recovery → durable lifecycle | Multiple claimants may race for one authoritative target, event, or intent. | Target/event identity, revision, lifecycle state, lock/CAS result |
| Offline evidence → host/CrossWake authorization | Client evidence is non-authoritative until current host policy reauthorizes it. | Session, tenant, expiry, manifest, route, one-time intent |
| Runtime diagnostics → proof bytes | Persisted facts, traces, telemetry, exceptions, and observations cross into a closed proof projection. | Potentially sensitive nested runtime evidence and final encoded bytes |
| Proof JSON → mobile extension validator | Future physical evidence is untrusted and may spoof ownership, class, ordering, revision, or device claims. | Closed versioned proof object and delegated CrossWake report |
| CI verification job → aggregate gates | Missing, skipped, renamed, or miswired job results could otherwise create a false green. | Job result, gate environment key, aggregate input |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-102-01 | Tampering | package and CrossWake inputs | high | mitigate | `scripts/prove-alpha-twin.exs` validates archive SHA-256, canonical origin, exact detached SHA, and clean worktree; provenance mutation tests fail closed. | closed |
| T-102-02 | Information Disclosure | tracer host authority and transport observation | high | mitigate | Raw authority stays fixture-private; observations are redacted and actual evidence plus final proof bytes are recursively scanned by the closed proof projection. | closed |
| T-102-03 | Elevation of Privilege | protected-open resolver | high | mitigate | Host intent is atomically consumed once and current tenant/session/revision/manifest/RouteGate authorization is required; stale and replay paths activate nothing. | closed |
| T-102-04 | Denial of Service | scripted processes and database ownership | medium | mitigate | Scenario/request inputs are bounded, sandbox ownership is synchronous, tasks are awaited, and the Alpha CI lane has an explicit 20-minute timeout. | closed |
| T-102-02A | Information Disclosure | registry and transport observation | high | mitigate | `AlphaTwin.Registry` retains raw values, `ScriptedAPNSTransport` emits redacted observations, and nested sentinel tests reject disclosure without echoing values. | closed |
| T-102-03A | Elevation of Privilege | binding and one-time intent authority | high | mitigate | Exact tenant/environment/topic/revision matching, revision CAS, atomic consume-once handling, and rotation/revocation/replay tests deny stale authority. | closed |
| T-102-04A | Tampering | clock and ordered transport script | high | mitigate | Closed provider/result contracts, explicit clock advancement, exact request/outcome consumption, and malformed/reordered input tests preserve deterministic failure. | closed |
| T-102-05 | Tampering | scenario ledger | high | mitigate | The ledger requires exact keys, version, complete unique order, closed string lookup, and no atom creation; mutation tests cover missing, duplicate, reordered, unknown, and extra data. | closed |
| T-102-06 | Tampering | rotation and recovery races | high | mitigate | Tenant/revision-qualified CAS, durable locks and uniqueness, crash recovery, and parallel/repeated process assertions yield one authoritative lifecycle explanation. | closed |
| T-102-07 | Elevation of Privilege | offline protected open | high | mitigate | Atomic host consumption plus current tenant/session/revision/expiry/manifest/RouteGate checks reject expiry, revocation, cross-scope use, denial, and replay with no fallback activation. | closed |
| T-102-08 | Information Disclosure | proof aggregation | high | mitigate | A closed projection recursively scans storage, traces, telemetry, exceptions, redacted observations, and exact final bytes, returning stable rule/path-only failures. | closed |
| T-102-09 | Repudiation | outcome taxonomy | medium | mitigate | Intent, provider outcome, invalidation, open, seen, and read remain separate durable/explained facts; scenario results are derived from actual persisted lifecycle state. | closed |
| T-102-10 | Spoofing | mobile proof extension | high | mitigate | `Chimeway.MobileProof.Extension` enforces exact owner, proof class, version, revision, scenario/assertion order, and delegated canonical CrossWake validation with a complete negative corpus. | closed |
| T-102-11 | Tampering | artifact and CrossWake provenance | high | mitigate | Canonical proof bytes bind the actual archive digest and locked full SHA; floating refs, dirty/detached-state violations, mismatches, and unknown fields are rejected. | closed |
| T-102-12 | Information Disclosure | malformed evidence errors | high | mitigate | Recursive sensitive scans and ordered malformed fixtures prove failures expose only safe rule/path diagnostics and never rejected values. | closed |
| T-102-13 | Repudiation | visible-alert and device claim | medium | mitigate | The proof requires `visible_alert: not_asserted`; fixture, validator, and CI contracts forbid promotion to physical-device or engagement evidence. | closed |
| T-102-14 | Tampering | aggregate CI topology | high | mitigate | Release-gate mutation tests bind `verify_alpha_twin`, its result key, exact commands and provenance, job needs, and both fail-closed aggregate gates. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Verification Evidence

- `102-VERIFICATION.md` reports `status: passed`, all 3 roadmap truths verified, all required artifacts wired, real runtime data flowing end to end, and no remaining gaps.
- `102-VALIDATION.md` reports `nyquist_compliant: true`; all 6 task rows have green automated evidence covering every threat ID, and its audit records 11 focused tests, the CI-topology contract, both named `mix verify.*` gates, and `mix ci.verify_gates` passing 630 tests with 0 failures.
- `102-REVIEW.md` records a clean re-review of 34 implementation, fixture, test, package, and CI files with 0 critical, warning, or informational findings.
- The four summaries report no known stubs or remaining issues and declare no `## Threat Flags`; the Phase 102 plan-time STRIDE registers provide executable ASVS L1 traces for every high-severity threat.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit 2026-08-26

| Metric | Count |
|--------|-------|
| Unique threats found | 17 |
| Closed | 17 |
| Open | 0 |

ASVS Level 1 classification used plan-time threat models plus grep-depth implementation and executable-evidence checks. Because no threat remained open and the register was authored at plan time, the secure-phase L1 short-circuit applied; no deeper auditor pass was required.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-26 | 17 | 17 | 0 | Codex (`gsd-secure-phase`) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-26
