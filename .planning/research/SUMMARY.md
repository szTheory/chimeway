# Research Summary: v1.11 Operator Console Polish & Hardening

**Date:** 2026-06-04
**Milestone:** v1.11 Operator Console Polish & Hardening

## Scope Thesis

Chimeway's admin surface should be an embedded Phoenix operator console for explainable notification delivery, not a generic model-admin, SaaS control plane, or campaign-management UI. The primary job is to help a support operator answer what happened, why it happened, and what safe recovery action is available.

## Personas and Jobs

- **Support Operator:** explain a recipient complaint, inspect suppression/failure reasons, and retry or recover only when safe.
- **Feature Developer:** confirm a notifier key/version, route, policy, and adapter behaved as authored.
- **SRE/On-call:** understand whether failures are isolated, provider/channel-specific, retryable, or systemic.
- **Product/Compliance Admin:** inspect preferences, suppression, and lifecycle outcomes without exposing sensitive payloads.

## Recommended Patterns

- Use a host-mounted LiveView router macro, following Phoenix LiveDashboard and Oban Web ergonomics.
- Keep `chimeway_admin` optional; core `chimeway` owns durable read models and recovery APIs.
- Use explicit Ecto query projections/DTO maps for admin data; never pass raw schemas or payload blobs to UI.
- Use filter-first investigation: recipient, notification key/version, tenant, channel, status, suppression reason, provider, correlation ID, idempotency key, and time range.
- Make the detail page an explanation timeline: event, notification resolution, policy/preference checks, suppression/dedupe, delivery creation, attempts, provider outcomes, and recovery evidence.
- Make recovery narrow and local to eligible rows; re-authorize mutating LiveView events and require confirmation.
- Use scoped design tokens for Chimeway admin CSS, with light/dark/system support and WCAG AA contrast targets.
- Use subtle, purposeful CSS transitions for hover/focus/state changes; respect `prefers-reduced-motion`.

## Patterns to Avoid

- Generic CRUD over Chimeway tables as the primary UI.
- `forward`-based LiveView mounting when relying on `live_session` and `on_mount`.
- Core package Phoenix/LiveView dependency creep.
- Raw payload, render data, provider body, token, secret, auth code, or full PII rendering.
- Mount-only authorization for recovery actions.
- Bulk resend/delete as an early default.
- Dashboard-only metrics without direct drilldown to affected records.
- External control-plane assumptions or SaaS-style export requirements.

## Recommended Milestone Shape

v1.11 should reconcile the already-implemented admin console into durable planning artifacts, then harden it across five dimensions:

1. **Truth alignment:** docs, route map, and requirements match the real multi-page console.
2. **UI/IA polish:** command center, navigation, themes, components, accessibility, and microcopy become a coherent Chimeway design system.
3. **Safety contracts:** recovery, auth, tenancy, stale-state handling, and action evidence are proved.
4. **Privacy contracts:** redaction is tested at DTO and rendered-HTML boundaries.
5. **Verification:** admin docs, doc contracts, `mix verify.admin`, CI parity, and browser smoke make the operator console shippable.

## Sources and Evidence

- Phoenix LiveDashboard: mountable embedded dashboard, telemetry metrics, custom pages, and host auth model.
- Phoenix LiveView: direct live routes and `on_mount` auth boundaries; avoid `forward` for LiveView sessions.
- Oban Web: app-hosted operational dashboard with action-bearing job controls.
- Ecto: explicit query projections and structured read models.
- Plug.Static: dependency assets served from application tuples.
- Django Admin, ActiveAdmin, Laravel Nova/Horizon/Telescope, Sidekiq Web: filters, stateful operations, and the risks of generic admin/action sprawl.
- Sentry, Datadog, Courier, Knock, Postmark: investigation timelines, facets, delivery-state ambiguity, and provider-status language.
- WCAG 2.2, MDN `prefers-color-scheme`, and motion guidance from Emil Kowalski: contrast, focus, reduced motion, fast purposeful animations, and system theme support.
