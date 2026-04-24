# Chimeway — admin UI and operator information architecture

> **Purpose:** Shape the **optional** operator experience: debugging, support, and confidence—not generic CRUD. Pattern-level borrow from sibling “operator IA” docs (`rulestead-admin-ux-and-operator-ia.md`, `lockspire-operator-admin-ia-and-workflows.md`); **no** OAuth-server product scope.

## Headline job

Answer **“Why didn’t this user get notified?”** with a **defensible trace**: trigger → policy decisions → recipient resolution → channel selection → enqueue → attempt → provider response (redacted).

## Primary personas

- **Support engineer:** searches by user id, email, or correlation id; reads timeline; copies safe summary for ticket.
- **Owner / admin:** configures defaults, sees health (queue depth, failure rate), does not need raw PII in lists.
- **Developer (self-hosted):** uses the same UI in staging with test adapters.

## IA pillars (conceptual routes)

1. **Trace lookup** — single notification or delivery id: timeline, state machine, last error, retry count, links to Oban job if applicable.
2. **Inbox / feed (optional)** — per-user or per-tenant filtered list for debugging (not a full product inbox unless intentional).
3. **Definitions / registry (read-mostly)** — which `notification_key`s exist, which channels they map to, version skew warnings if code removed keys still in DB.
4. **Health** — aggregates: failure rate by channel, stuck deliveries, adapter timeouts; links to telemetry docs.

## UX rules

- **Redaction by default** in list views: no full bodies, no secrets, tokenize phone/email where shown.
- **Role gate:** host app owns auth; Chimeway exposes a **behaviour** or callback for “can this actor open admin?” (sigra / lockspire pattern: host-owned policy).
- **Safe deep links** from logs: correlation id opens trace view without guessing primary keys.
- **LiveView** is the natural Phoenix fit; keep deps behind optional package or compile flag so API-only users do not pay.

## Non-goals for early milestones

- Not a marketing campaign manager, not a full CRM, not end-user notification preferences UI unless scoped explicitly (preferences may start as code/API-first).

## Verification hooks

- Doc-contract: admin nav labels match real routes when they exist.
- Later: Playwright smoke on mounted router (sigra / accrue precedent) once UI stabilizes.
