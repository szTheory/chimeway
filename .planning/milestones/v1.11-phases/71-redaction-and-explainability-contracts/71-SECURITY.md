---
phase: 71
slug: redaction-and-explainability-contracts
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-04
verified: 2026-06-04
---

# Phase 71 - Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Core database rows to `Chimeway.Admin` DTOs | Durable payload, render, provider, metadata, session, token, secret, auth-code, and full-PII fields must not cross into admin read models. | Durable event, notification, delivery, and attempt rows to core DTO maps. |
| Browser search input to LiveView assigns and rendered HTML | Full recipient identities, auth codes, tokens, and freeform secrets arrive as untrusted input and must not be retained in rendered assigns. | Browser form params to Trace Search and Feed LiveViews. |
| Core trace explanation to LiveView rendering | Trace detail receives durable lifecycle facts and must render only safe, masked operator information. | Trace explanations to admin LiveView HTML. |
| LiveView session and params to rendered HTML | Host session and route params may contain secrets and must not be echoed. | LiveView session/route data to rendered HTML. |
| Core durable status atoms to operator copy | UI translates durable facts into labels without mutating persistence semantics. | Delivery status, attempt, suppression, and timeline facts to admin labels. |
| Provider/internal send facts to Delivered copy | Provider acceptance must not be overclaimed as final recipient delivery. | Attempt success and webhook/timeline facts to lifecycle copy. |
| Persisted DB definition history to Definitions UI | UI must describe only facts inferred from Chimeway rows, not source-code inventory. | Persisted notification key/version history to Definitions HTML. |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-71-01 | Information Disclosure | `Chimeway.Admin` DTO maps | mitigate | Exact DTO key allowlists and recursive forbidden key/value assertions in `test/chimeway/admin_test.exs:8`, `test/chimeway/admin_test.exs:26`, and `test/chimeway/admin_test.exs:66`; fixture covers payload, render, provider, metadata, auth-code, token, and full PII at `test/chimeway/admin_test.exs:71`. | closed |
| T-71-02 | Information Disclosure | Rendered admin LiveViews | mitigate | `privacy_leak_live_test.exs` asserts sensitive values absent and masked facts present for Dashboard, Trace Detail, Feed, Recovery, Definitions, and Trace Search at `chimeway_admin/test/chimeway_admin/live/privacy_leak_live_test.exs:24`, `:40`, `:57`, `:77`, `:101`, and `:117`; fixture seeds required sensitive locations at `:141`. | closed |
| T-71-03 (71-01) | Information Disclosure | Search query echo in Trace Search and Feed | mitigate | Trace Search consumes submitted query then assigns rendered `query: ""` at `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex:43` and `:72`; Feed consumes submitted recipient then assigns rendered `query: ""` at `chimeway_admin/lib/chimeway_admin/live/feed_live.ex:15` and `:27`; both render redacted recipients at `trace_search_live.ex:148` and `feed_live.ex:72`. | closed |
| T-71-04 (71-01) | Repudiation | Privacy hardening removes operator explanation facts | mitigate | Rendered privacy tests assert useful masked/explainable facts remain visible while sensitive values are absent at `privacy_leak_live_test.exs:33`, `:48`, `:71`, `:86`, `:110`, and `:135`. | closed |
| T-71-01-SC | Tampering | Package manager installs | accept | Accepted risk documented below; Phase 71 research and summaries record no new packages, and `git diff -- mix.exs mix.lock chimeway_admin/mix.exs chimeway_admin/mix.lock` produced no diff. | closed |
| T-71-03 (71-02) | Repudiation / Integrity | Lifecycle label presenter | mitigate | `ChimewayAdmin.Components.Status.lifecycle_label/1` centralizes Sent, Provider accepted, Delivered, Suppressed, Retryable failure, and Terminal failure labels at `chimeway_admin/lib/chimeway_admin/components/status.ex:31`; component tests cover the six labels at `chimeway_admin/test/chimeway_admin/components/status_test.exs:6`. | closed |
| T-71-04 (71-02) | Repudiation | Delivered overclaim | mitigate | Delivered requires explicit timeline feedback in `status.ex:113`; provider acceptance is the conservative `:succeeded` default at `status.ex:142`; dashboard and trace tests assert Provider accepted appears and Delivered is absent without feedback at `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs:37` and `:50`. | closed |
| T-71-05 | Repudiation | Definitions copy | mitigate | Definitions renders DB-inferred persisted-history copy at `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex:21`, `:26`, and `:30`; tests require that copy and forbid registry/skew/module-discovery/source-code-scan claims at `chimeway_admin/test/chimeway_admin/live/definitions_live_test.exs:10`, `:29`, and `:46`. | closed |
| T-71-02-SC | Tampering | Package manager installs | accept | Accepted risk documented below; Plan 71-02 summary records `tech-stack.added: []`, and package manifests/locks have no Phase 71 diff. | closed |

*Status: open - closed*
*Disposition: mitigate (implementation required) - accept (documented risk) - transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-71-01 | T-71-01-SC | Phase 71 did not install packages or change package manifests/locks; package-manager tampering risk is accepted as not applicable to this phase's implementation scope. | GSD security audit | 2026-06-04 |
| AR-71-02 | T-71-02-SC | Phase 71 Plan 02 did not install packages or change package manifests/locks; package-manager tampering risk is accepted as not applicable to this phase's implementation scope. | GSD security audit | 2026-06-04 |

---

## Unregistered Flags

No unregistered threat flags. The Phase 71 summaries do not include separate `## Threat Flags` sections; their security-relevant notes map to the plan-time threat register entries above.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-04 | 9 | 9 | 0 | gsd-secure-phase |

---

## Verification Evidence

| Command / Evidence | Result |
|--------------------|--------|
| `mix test test/chimeway/admin_test.exs --warnings-as-errors` | Passed in `71-01-SUMMARY.md`. |
| `cd chimeway_admin && mix test test/chimeway_admin/live/privacy_leak_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs test/chimeway_admin/live/recovery_live_test.exs --warnings-as-errors` | Passed in `71-01-SUMMARY.md`. |
| `cd chimeway_admin && mix test test/chimeway_admin/components/status_test.exs test/chimeway_admin/live/definitions_live_test.exs test/chimeway_admin/live/trace_search_live_test.exs --warnings-as-errors` | Passed in `71-02-SUMMARY.md` and `71-REVIEW.md`. |
| `mix test test/chimeway/admin_test.exs test/chimeway/traces_test.exs --warnings-as-errors` | Passed in `71-02-SUMMARY.md` and `71-REVIEW.md`. |
| `cd chimeway_admin && mix test --warnings-as-errors` | Passed in `71-02-SUMMARY.md` and `71-REVIEW.md`. |
| `rg "values: \\[:pending, :dispatched, :succeeded, :failed, :suppressed, :cancelled, :digested\\]" lib/chimeway/delivery.ex` | Matched unchanged durable status enum at `lib/chimeway/delivery.ex:23`. |
| `git diff -- mix.exs mix.lock chimeway_admin/mix.exs chimeway_admin/mix.lock` | No diff. |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-04
