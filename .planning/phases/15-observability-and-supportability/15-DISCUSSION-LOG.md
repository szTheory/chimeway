# Phase 15: Observability & Supportability — Discussion Log

## Assumptions Approved

**1. Telemetry & PII Redaction**
- **Assumption:** PII protection is enforced exclusively via an explicit allowlist of safe telemetry keys, rather than deep scanning or dynamic masking of payloads.
- **Evidence:** `lib/chimeway/telemetry.ex` uses a strict `@allowed_meta_keys` list and a `safe_meta/1` function to silently drop unapproved keys before they reach `:telemetry.span/3`.
- **Status:** Approved by user.

**2. Host-App Correlation & Tenancy**
- **Assumption:** The `correlation_id` string acts as the universal hook for host-app context, absorbing both request tracing and multi-tenant isolation without dedicated domain columns.
- **Evidence:** `correlation_id` is defined on events but there is no `tenant_id` field. Operator surfaces rely on `find_traces_by_correlation_id/1` for cross-boundary searches.
- **Status:** Approved by user.

**3. Asynchronous Lifecycle Tracing**
- **Assumption:** Tracing context across the asynchronous worker boundary relies on denormalizing identifiers into `jsonb` metadata rather than doing relational joins at runtime telemetry emission.
- **Evidence:** Locked in Phase 10 (Decision D-02). `lib/chimeway/dispatch/oban.ex` fetches `Map.get(delivery.metadata || %{}, "notification_key")` to populate worker spans without querying parent rows.
- **Status:** Approved by user.

**4. Operator Trace Assembly**
- **Assumption:** Trace explanations and full event timelines are assembled dynamically on read via Ecto preloads against live transactional tables, rather than using a separate materialized trace projection table.
- **Evidence:** `lib/chimeway/traces.ex` implements `explain_delivery/1` and `get_trace/1` by preloading deep associations and functionally mapping them into an in-memory timeline list.
- **Status:** Approved by user.

**Conclusion:** The discuss phase is complete. The assumptions are sound and have been confirmed. Proceeding to planning.
