# Phase 71: Redaction and Explainability Contracts - Context

**Gathered:** 2026-06-04 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 71 proves that the admin DTO and rendered-HTML boundaries preserve privacy while improving operator explanation quality. It covers PRIV-01, PRIV-02, EXPL-01, and EXPL-02: rendered LiveView HTML must not expose raw payloads, render data, provider bodies, secrets, tokens, auth codes, or full recipient PII; admin DTOs must expose only stable explainability fields; trace/detail/status language must distinguish sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure states; and Definitions must communicate DB-inferred key/version history without overclaiming code-registry skew detection. It should not pull in Phase 72 admin docs, `mix verify.admin`, CI parity, or browser-smoke gate composition except where those later phases need stable privacy and explanation contracts.
</domain>

<decisions>
## Implementation Decisions

### Boundary Strategy

- **D-01:** Keep redaction as a two-layer contract: core `Chimeway.Admin` DTOs expose only stable explainability fields, while `chimeway_admin` LiveViews/components own display masking for recipient identities and timeline details.
- **D-02:** Do not move raw Ecto schemas, payloads, render snapshots/data, provider responses/bodies, session params, auth codes, tokens, secrets, or full PII into admin UI assigns as an implementation shortcut.

### DTO Contract

- **D-03:** Tighten `Chimeway.Admin` DTO tests around explicit allowlists for each admin read model: command center, recent problem deliveries, definitions, feed, recovery candidates, and outcome totals.
- **D-04:** Do not remove `recipient_id` from every DTO by default in Phase 71; preserve it where it is needed for operator filtering, recovery facts, and trace lookup, but require rendered HTML to mask full recipient PII.
- **D-05:** Treat redacted recipient display fields as an acceptable implementation-local improvement if planners find it simplifies testability, but do not make broad public API churn the default.

### Rendered HTML Leak Tests

- **D-06:** Add rendered LiveView HTML leak tests for dashboard, trace detail, feed, recovery, and definitions because those pages render sensitive-adjacent facts.
- **D-07:** Leak fixtures must include raw payloads, notification render assigns, delivery render data, provider responses/bodies, metadata, session/params, tokens, secrets, auth codes, and full recipient PII.
- **D-08:** Rendered tests should assert both absence of raw sensitive values and presence of useful redacted/explainable operator facts, so privacy hardening does not erase explainability.

### Explanation Language

- **D-09:** Centralize operator-facing lifecycle labels in `ChimewayAdmin.Components.Status` or a nearby presenter instead of changing durable core status atoms.
- **D-10:** Distinguish sent, provider accepted, delivered, suppressed, retryable failure, and terminal failure states using existing status, attempt outcome, error class, webhook/workflow facts, and suppression reason data where available.
- **D-11:** Keep lifecycle copy honest when Chimeway only knows provider acceptance or internal success; do not label a notification delivered unless durable feedback proves delivery.

### Definitions Copy

- **D-12:** Keep Definitions as DB-inferred durable notification key/version history.
- **D-13:** Add rendered-copy/tests that prevent code-registry, source-code skew detection, or notifier module discovery claims from appearing unless that capability is actually implemented.

### the agent's Discretion

Downstream agents may choose the narrowest implementation shape that satisfies the decisions above, keeps `chimeway_admin` optional and host-mounted, and follows existing core DTO plus LiveView test patterns.

### Folded Todos

None.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/METHODOLOGY.md`
- `.planning/phases/68-admin-truth-alignment/68-CONTEXT.md`
- `.planning/phases/69-console-design-system/69-CONTEXT.md`
- `.planning/phases/70-recovery-auth-and-tenancy-hardening/70-CONTEXT.md`
- `lib/chimeway/admin.ex`
- `lib/chimeway/traces.ex`
- `lib/chimeway/deliveries.ex`
- `lib/chimeway/delivery.ex`
- `chimeway_admin/lib/chimeway_admin/redaction.ex`
- `chimeway_admin/lib/chimeway_admin/components/status.ex`
- `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`
- `chimeway_admin/lib/chimeway_admin/live/dashboard_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/feed_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/definitions_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/health_live.ex`
- `chimeway_admin/lib/chimeway_admin/live/recovery_live.ex`
- `test/chimeway/admin_test.exs`
- `test/chimeway/traces_test.exs`
- `chimeway_admin/test/chimeway_admin/redaction_test.exs`
- `chimeway_admin/test/chimeway_admin/live/trace_search_live_test.exs`
- `chimeway_admin/test/chimeway_admin/live/recovery_live_test.exs`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Chimeway.Admin` already returns small DTO maps for command center, recent problems, definitions, feed, recovery candidates, and outcome totals instead of raw Ecto schemas.
- `test/chimeway/admin_test.exs` already asserts admin read models omit payload, render data, and provider response fields.
- `ChimewayAdmin.Redaction` already masks recipient identities, sanitizes provider error classes, and whitelists safe timeline detail keys.
- `TraceDetailLive`, `FeedLive`, and `DashboardLive` already call `Redaction.redact_recipient/1` before rendering recipient identities.
- `TimelineEvent.timeline/1` already routes timeline details through `Redaction.safe_timeline_detail/1`.
- `RecoveryLiveTest` already has a narrow rendered leak check for session secrets on recovery candidate review.

### Established Patterns

- Core stays Phoenix-free and owns stable admin read models; the optional `chimeway_admin` package owns LiveView rendering and display formatting.
- Admin surfaces consume DTO maps and explanation structs rather than raw lifecycle schemas when possible.
- Prior Phase 68 locked Definitions as DB-inferred durable key/version usage, not source-code registry or skew detection.
- Prior Phase 70 locked recovery metadata to safe operator/action facts and explicitly excluded raw session, params, payloads, provider bodies, secrets, tokens, auth codes, and full PII.

### Integration Points

- `Chimeway.Traces.explain_delivery/2` feeds trace detail with status, attempt summary, render identity, suppression reason, planning reason, and timeline facts.
- `Chimeway.Traces.aggregate_outcomes/1` already maps durable states into operator outcome buckets such as `sent`, `suppressed`, `delayed`, `digested`, `failed`, and `exhausted`.
- `ChimewayAdmin.Components.Status.status_badge/1` is the current shared label/styling point for statuses and is the natural place, or adjacent presenter, to centralize clearer operator status copy.
- `Chimeway.Admin.definitions/1` groups persisted events/deliveries by durable key and version; `DefinitionsLive` renders those inferred facts.
</code_context>

<specifics>
## Specific Ideas

- Add DTO allowlist assertions that fail if admin maps gain `:payload`, `:render_assigns`, `:render_data`, `:provider_response`, `:provider_body`, `:metadata`, `:session`, `:params`, `:token`, `:secret`, `:auth_code`, or full PII fields.
- Create rendered HTML leak fixtures with distinctive strings such as raw payload secret, render-data secret, provider body secret, auth code, bearer token, and full email/phone identities, then assert they do not appear in LiveView output.
- Add positive assertions for masked recipient output so tests prove the UI remains useful after redaction.
- Add status/presenter tests that lock labels for internal sent/provider accepted versus externally delivered where feedback exists.
- Add Definitions rendered-copy tests that require DB-inferred language and forbid skew/registry/module-discovery claims.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within phase scope.

### Reviewed Todos (not folded)

None.
</deferred>
