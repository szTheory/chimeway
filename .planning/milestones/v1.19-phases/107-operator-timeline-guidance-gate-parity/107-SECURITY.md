---
phase: "107"
slug: "operator-timeline-guidance-gate-parity"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-09-13"
---

# Phase 107 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Host tenant scope → core trace query | A host-selected tenant authorizes the correlated delivery and parent notification read. | Tenant and durable lifecycle identifiers |
| Durable notification row → public explanation | Persisted lifecycle facts enter the privacy-safe operator DTO. | `seen_at` / `read_at` timestamps only |
| Safe explanation → optional admin HTML | Closed core evidence is rendered by a host-mounted operator surface with defense-in-depth redaction. | Allowlisted timeline events and empty details |
| Adopter config/auth → inbox package | Host-owned identity, authorization, PubSub, and secret inputs cross into the optional inbox package. | Opaque tenant and recipient references |
| Mix alias → CI aggregate gates | Local executable evidence becomes one hosted lane consumed by both aggregate gates. | Command membership and job result state |
| Release-test path → recursive deletion | Test-owned temporary paths cross into destructive filesystem cleanup. | Expanded temporary-directory path |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-107-01 | Information Disclosure | `Traces`, `SafeEvidence`, admin timeline | high | mitigate | Exact empty lifecycle detail, closed event admission, two redaction layers, and hostile-sentinel tests. | closed |
| T-107-02 | Spoofing / Information Disclosure | `explain_delivery/2`, Trace Detail | high | mitigate | Tenant-qualified joins, fail-closed mounted authorization, and wrong-scope tests. | closed |
| T-107-03 | Tampering / Repudiation | Seen/read projection | high | mitigate | Persisted parent timestamps are the sole independent authority; sibling and replay tests reject inference. | closed |
| T-107-04 | Repudiation | Timeline ordering | medium | mitigate | Exact timestamp is the primary key and closed event rank only breaks ties; inversion and tie tests cover both branches. | closed |
| T-107-05 | Information Disclosure | Inbox guide contract | high | mitigate | Opaque `cw_*` examples plus executable exclusions for raw recipient, caller metadata, and notification content forms. | closed |
| T-107-06 | Spoofing / Information Disclosure | Host inbox integration | high | mitigate | Both auth callbacks, tenant membership, recipient mapping, secret custody, and current reauthorization are host-owned and contracted. | closed |
| T-107-07 | Tampering / Repudiation | Reload and lifecycle guidance | high | mitigate | Durable rows remain authoritative; reload messages are lossy hints; lifecycle and engagement facts do not imply one another. | closed |
| T-107-08 | Repudiation | Alias and aggregate parity | medium | mitigate | Mutation tests pin exact alias order, sole CI invocation, both `needs` edges, result tokens, and nightly exclusions. | closed |
| T-107-09 | Tampering / Denial of Service | Release-contract cleanup | critical | mitigate | Recursive removal is centralized behind expanded-root, immediate-child, closed-prefix, existing-directory, and non-symlink checks; structural tests permit one guarded call only. | closed |

*Only open threats at or above the configured `high` threshold count toward `threats_open`.*

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-13 | 9 | 9 | 0 | `gsd-security-auditor` |

Evidence reproduced during audit: 52 core trace/SafeEvidence tests, 9 admin component/redaction tests, 5 mounted demo tests, 40 focused documentation tests, 3 cleanup-safety tests, 4 gate-parity tests, and green `mix verify.inbox`.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-13
