---
phase: 100
slug: optional-apns-adapter
status: verified
threats_open: 0
asvs_level: 1
created: 2026-08-22
---

# Phase 100 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Host resolver → Chimeway adapter | Host-owned lookup supplies transient APNs material only after an attempt starts and only for an exact tenant/environment/topic/binding revision. | Device token and dispatcher reference (secret/transient); exact binding scope (sensitive) |
| Durable target → provider request | Closed persisted intent is revalidated before it becomes a bounded APNs payload and headers. | Environment, topic, APNs ID, expiry, opaque open reference, collapse ID, rendered alert payload |
| Executor → provider | Durable lifecycle state controls provider-emission authority and distinguishes pre-handoff failure from post-handoff ambiguity. | Attempt identity, request, provider handoff state |
| Raw Pigeon/APNs stream → closed result | Provider-controlled stream identity, status, and body are correlated, bounded, decoded, and reduced to closed facts. | Untrusted provider response; status/reason/timestamp |
| Chimeway adapter → host invalidation | Only a complete authoritative 410 result can request a host-owned compare-and-update. | Exact tenant/environment/topic/binding revision invalidation key |
| Installer/package → host runtime | Optional migrations and dependencies cross into host-owned storage and runtime configuration. | Nullable safe intent map; dependency graph; host-selected prefix |
| Packaged verifier → CI aggregates | Hermetic disabled/enabled consumer evidence becomes a required local and hosted release gate. | Dependency/audit results and fixed allowlisted proof output |
| Durable attempts → operator surfaces | Stored provider facts cross read-time allowlisting and revalidation before traces, logs, or telemetry expose them. | Bounded safe evidence; no token, raw body, payload, or dispatcher internals |

---

## Threat Register

The 67 plan rows normalize to 62 unique threat IDs; `T-100-SC` is the same supply-chain threat carried forward by six plans.

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-100-01 | Information Disclosure | `Chimeway.Adapters.APNS.deliver/2` | high | mitigate | Transient lookup, exact-scope validation, dynamic dispatcher reference, recursive sentinel tests, and no raw request/result persistence. | closed |
| T-100-02 | Tampering | persisted APNs request intent | high | mitigate | Closed `RequestIntent` validation and immutable-on-conflict storage bind routing facts to the target. | closed |
| T-100-03 | Denial of Service | payload construction | high | mitigate | Final encoded byte count accepts at most 4096 bytes before lookup/transport and excludes arbitrary top-level merges. | closed |
| T-100-04 | Tampering | expiry/retry entry | high | mitigate | Expiry is checked before lookup/I/O for every attempt; exact locks and idempotency allow one winner. | closed |
| T-100-05 | Spoofing | host lookup scope | high | mitigate | Exact tenant/environment/topic/binding-revision equality is required before transient material is accepted. | closed |
| T-100-06 | Repudiation | provider acceptance | medium | mitigate | Attempt-start precedes I/O and success records only `provider_accepted`, never engagement. | closed |
| T-100-07 | Information Disclosure | migration 037 | high | mitigate | One safe intent map only; migration/source tests reject secret, rendered-payload, and provider-body columns. | closed |
| T-100-08 | Tampering | public/prefixed migration parity | high | mitigate | Golden equality, prefix assertions, and three-mode up/down/up tests prevent storage-mode drift. | closed |
| T-100-09 | Elevation of Privilege | storage prefix | medium | mitigate | Fixed prefix-helper pattern; tenant and environment input cannot qualify relations. | closed |
| T-100-10 | Denial of Service | rollback | medium | mitigate | Rollback removes only the nullable variant column and preserves prior rows and constraints. | closed |
| T-100-11 | Information Disclosure | binding lookup and transport | high | mitigate | Transient structs, exact scope, closed return algebra, and sentinel checks across durable and operator surfaces. | closed |
| T-100-12 | Tampering | opaque open reference | high | mitigate | Opaque bounded data is validated but never consumed or re-authorized by the transport. | closed |
| T-100-13 | Denial of Service | payload and timeout | high | mitigate | Final 4096-byte gate and bounded synchronous timeout surround exactly one push. | closed |
| T-100-14 | Repudiation | timeout/exit/lost response | high | mitigate | Post-emission uncertainty becomes an ambiguous handoff with no automatic resend. | closed |
| T-100-15 | Tampering | normalized invalidation reason | high | mitigate | Preserved HTTP status and recognized reason are both required; normalized status-less results cannot invalidate. | closed |
| T-100-SC | Tampering | optional Pigeon/Hex supply chain | high | mitigate | Root stays Pigeon-free; enabled fixture pins Pigeon 2.0.1 and exact checksummed transitives, uses check-locked tree assertions, and runs unsuppressed Hex audit. | closed |
| T-100-16 | Tampering | result classifier | high | mitigate | Exhaustive matrix fails closed; only the exact 410 status/reason/timestamp triple reaches invalidation. | closed |
| T-100-17 | Elevation of Privilege | host invalidation CAS | high | mitigate | Exact four-field callback and target transaction are covered by rotated and cross-scope tests. | closed |
| T-100-18 | Tampering | retry/redrive | high | mitigate | Typed retry allowlist, expiry recheck, terminal ambiguity, and final exhaustion transaction. | closed |
| T-100-19 | Information Disclosure | provider response/evidence | high | mitigate | `SafeEvidence` fixed bounds, redact-before-validate, read-time revalidation, and recursive sentinel tests. | closed |
| T-100-20 | Repudiation | engagement narrative | medium | mitigate | Distinct target outcomes and independent open/seen/read facts prevent acceptance overclaiming. | closed |
| T-100-21 | Denial of Service | concurrent completion | medium | mitigate | Exact row locks and the started-attempt predicate produce one completion winner. | closed |
| T-100-22 | Tampering | packaged dependency graph | high | mitigate | Fresh consumers prove Pigeon absent by default and exactly pinned only after explicit opt-in. | closed |
| T-100-23 | Information Disclosure | proof/CI output | high | mitigate | Fixed allowlisted evidence, sandbox-only fixtures, secret sentinels, and no Apple credential environment. | closed |
| T-100-24 | Repudiation | sandbox acceptance claim | medium | mitigate | Proof explicitly labels sandbox provider handoff and excludes live, device, and open claims. | closed |
| T-100-25 | Tampering | coverage/CI parity | high | mitigate | Parser mutation and release-gate contracts bind aliases, jobs, needs, environment, and aggregate token. | closed |
| T-100-26 | Denial of Service | clean-consumer verifier | medium | mitigate | Bounded archive checks, explicit temporary roots, cleanup trap, exact versions, and non-interactive commands. | closed |
| T-100-27 | Tampering | raw Pigeon response bridge | high | mitigate | Stream correlation, bounded JSON parsing, and complete fact matrix reject inferred or incomplete authority. | closed |
| T-100-28 | Elevation of Privilege | host binding invalidation | high | mitigate | Tracer asserts exact original four-field CAS and proves wrong-scope mutations cannot update. | closed |
| T-100-29 | Information Disclosure | raw response/token boundary | high | mitigate | Only closed facts survive; body is discarded after parsing, token stays transient, and proof output is sentinel-scanned. | closed |
| T-100-30 | Repudiation | normalized/error fallback | medium | mitigate | Stable permanent/ambiguous outcomes preserve honest evidence; normalized atoms cannot masquerade as 410 proof. | closed |
| T-100-31 | Denial of Service | provider response parser | medium | mitigate | Response body is bounded before decode; malformed or oversized input is rejected without CAS. | closed |
| T-100-32 | Tampering | pull-request aggregation | high | mitigate | Contract tests require `verify_apns` membership in both aggregate gates and mutation-test each link. | closed |
| T-100-07-01 | Tampering | Pigeon stream correlation | high | mitigate | Unknown stream IDs produce no completion/CAS; only correlated complete 410 cases can invalidate. | closed |
| T-100-07-02 | Spoofing | host invalidation callback | high | mitigate | Fixture registry atomically compares all four scope fields and preserves replacement revisions. | closed |
| T-100-07-03 | Elevation of Privilege | APNs response classification | high | mitigate | Normalized, incomplete, malformed, wrong, oversized, and uncorrelated cases produce zero successful invalidations. | closed |
| T-100-07-04 | Information Disclosure | package-consumer evidence | high | mitigate | Focused and full commands reject token, raw body, dispatcher, and exception sentinels. | closed |
| T-100-07-05 | Denial of Service | synchronous Pigeon test completion | medium | mitigate | Fresh dispatchers and deterministic correlated completion avoid production-timeout waits; cleanup terminates processes. | closed |
| T-100-07-06 | Repudiation | invalidation outcome proof | medium | mitigate | Registry separately records observed keys and successful mutation counts. | closed |
| T-100-08-01 | Tampering | Pigeon end-stream handling | high | mitigate | Correlated 200 delegates normally; retained non-authority matrix prevents ordinary or malformed invalidation. | closed |
| T-100-08-02 | Repudiation | provider success evidence | medium | mitigate | Tracer asserts `provider_accepted` only and no device/open/seen/read/engagement or CAS facts. | closed |
| T-100-08-03 | Tampering | enabled dependency resolution | high | mitigate | Exact direct versions, committed lock, check-locked, and tree assertions reject drift. | closed |
| T-100-08-04 | Elevation of Privilege | advisory-bearing transitive dependency | high | mitigate | Unsuppressed `mix hex.audit` blocks advisories/retirements; mutation tests forbid removal or ignore configuration. | closed |
| T-100-08-05 | Information Disclosure | packaged test output | high | mitigate | Token, body, dispatcher, and exception sentinels remain enforced in focused and full output. | closed |
| T-100-08-06 | Denial of Service | dependency/callback compatibility | medium | mitigate | Locked graph compiles before no-network tests; deterministic completion avoids live-provider waits. | closed |
| T-100-08-07 | Tampering | local/CI gate parity | high | mitigate | Release contracts bind `mix verify.apns` to the script and both hosted aggregate gates. | closed |
| T-100-09-01 | Repudiation | pre-provider failure stages | high | mitigate | Lookup/payload exceptions prove zero transport calls and bounded pre-handoff evidence. | closed |
| T-100-09-02 | Information Disclosure | lookup exception and token | high | mitigate | Sentinels prove secrets absent from results, attempts, logs, telemetry, and traces. | closed |
| T-100-09-03 | Tampering | transport ambiguity boundary | high | mitigate | Ambiguity is possible only after transport entry; timeout/exit paths remain terminal with no blind retry. | closed |
| T-100-09-04 | Tampering | Pigeon queue/response closure | high | mitigate | One callback path retains stream correlation, bounded decode, exact 410 authority, and ordinary 200 handling. | closed |
| T-100-09-05 | Elevation of Privilege | runtime JSON decoder | medium | mitigate | Decoder comes only from host Pigeon configuration, must export `decode/1`, and failures confer no authority. | closed |
| T-100-09-06 | Repudiation | enabled consumer compilation claim | high | mitigate | Script force-compiles unpacked Chimeway under warnings-as-errors; mutation tests prevent vacuous coverage. | closed |
| T-100-09-07 | Denial of Service | optional dependency absence | medium | mitigate | Dynamic references preserve disabled Pigeon-free compile/boot proof and both package modes rerun. | closed |
| T-100-10-01 | Information Disclosure | open reference validation | high | mitigate | Shared closed ASCII namespace rejects identifiers, URLs, controls, invalid representations, and over-bound input. | closed |
| T-100-10-02 | Tampering | collapse header | high | mitigate | Anchored ASCII allowlist and 1..64-byte checks reject CR/LF/C0/DEL before request construction. | closed |
| T-100-10-03 | Information Disclosure | direct payload construction | high | mitigate | Direct payload calls independently invoke the shared validator with regression coverage. | closed |
| T-100-10-04 | Spoofing | exact target identity | medium | mitigate | Concurrent execution and exact four-field result suites preserve target identity. | closed |
| T-100-10-05 | Denial of Service | input representation/bounds | medium | mitigate | Nil, empty, non-binary, boundary, and over-bound cases fail deterministically without provider I/O. | closed |
| T-100-11-01 | Tampering | package warning gate | high | mitigate | Exact compiler/order contracts and temporary warning mutation prove the strict stage is load-bearing. | closed |
| T-100-11-02 | Repudiation | enabled compile claim | high | mitigate | Chimeway is force-compiled before consumer tests and the full script remains required by `mix verify.apns`. | closed |
| T-100-11-03 | Denial of Service | unrelated dependency warning | medium | mitigate | Dependencies compile normally, then a project-only compiler checks Chimeway with dependency checks disabled. | closed |
| T-100-11-04 | Information Disclosure | verifier output | high | mitigate | Fixed proof line, token/body sentinels, temporary-root validation, and cleanup are rerun. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Verification Evidence

- `100-VERIFICATION.md` reports `status: passed`, 5/5 roadmap truths verified, 59 plan truths checked, 17 prohibitions executable, and no remaining gaps.
- Fresh verifier evidence recorded there includes a successful full `bash scripts/verify-apns.sh`, 34 focused APNs/migration/evidence tests with zero failures, and two warning-gate mutation tests with zero failures.
- `100-REVIEW.md` reports a clean security-aware review of 33 implementation, test, migration, fixture, package, and CI files with zero findings; its independent run records 38 tests with zero failures plus a successful package verifier.
- Summary threat flags are empty (`100-10-SUMMARY.md`: “None”); no other summary declares a threat flag.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit 2026-08-22

| Metric | Count |
|--------|-------|
| Unique threats found | 62 |
| Closed | 62 |
| Open | 0 |

ASVS Level 1 classification used plan-time threat models plus grep-depth implementation and executable-evidence checks. Because no threat remained open and the register was authored at plan time, the secure-phase L1 short-circuit applied; no deeper auditor pass was required.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-22 | 62 | 62 | 0 | Codex (`gsd-secure-phase`) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-22
