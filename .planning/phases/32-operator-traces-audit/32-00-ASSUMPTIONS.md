# Phase 32: Operator Traces & Audit — Architectural Decisions

Based on ecosystem best practices, the principle of least surprise, and idiomatic Elixir/Ecto patterns, the following deep recommendations resolve the architectural gray areas for Phase 32.

## 1. Linkage: Explicit DB Link vs. Implicit Deduction

**Decision: Explicit DB Link**

*   **Approach:** We will persist the `delivery_id` directly on the `Chimeway.Workflows.WorkflowTransition` row, populating it from the normalized webhook signal payload during `route_signal/1`.
*   **Rationale & Ecosystem context:** In distributed Elixir systems (like Oban, Broadway, or Commanded), implicit linkage via timestamps is a massive footgun. Webhooks arrive concurrently, get retried, and can have identical timestamps. Deducing relationships post-hoc leads to flaky trace outputs and brittle test suites. By persisting the `delivery_id` as an explicit foreign-key relationship on the transition, Ecto queries become simple `join`s.
*   **Ergonomics:** Traces are 100% deterministic. The query layer never has to guess which webhook triggered which progression step.

## 2. Timeline Surface: Flat Timeline vs. Separate Timeline

**Decision: Flat Timeline**

*   **Approach:** We will project workflow transitions directly into the existing `Chimeway.Traces.Explanation` flat `:timeline` list.
*   **Rationale & Ecosystem context:** Operators debugging a system want a unified chronological narrative. Tools like Stripe's event timeline or GitHub Actions logs weave discrete sub-systems into a single pane of glass. Forcing developers to visually diff a "delivery timeline" against a "workflow timeline" degrades the UX.
*   **Ergonomics:** We append new event atoms (e.g., `:workflow_progressed`, `:escalated`) alongside existing events (`:delivery_planned`, `:attempt_recorded`). The struct shape (`%{at: DateTime.t(), event: atom(), detail: map()}`) remains identical, meaning host app UI components require zero structural changes to render the new workflow events.

## 3. Payload Safety Boundary: Strict Boundary vs. Summary Fields

**Decision: Strict Boundary**

*   **Approach:** The raw, un-sanitized third-party webhook payload will live exclusively in the `DeliveryAttempt` record. The workflow context will NOT duplicate or summarize this payload, recording only the abstract signal (e.g., `chimeway.delivery.bounced`) and the `delivery_id` pointer.
*   **Rationale & Ecosystem context:** Notification payloads frequently contain PII (password reset tokens, auth codes, personal messages). Best-in-class libraries (like Sentry or Vercel's logging) default to aggressive PII isolation. If we summarize webhook payloads into the workflow spine, we risk leaking PII into structural trace outputs, violating cross-tenant isolation and security constraints established in earlier phases.
*   **Ergonomics:** The separation of concerns remains pristine. The workflow engine knows *that* a bounce happened, but the actual diagnostic payload of *why* the bounce happened is safely siloed in the delivery attempt where it belongs.

## Conclusion

These three decisions are cohesive: an **Explicit DB Link** allows a **Strict Boundary** without losing context, and the **Flat Timeline** synthesizes that cleanly separated data into a unified, developer-friendly output.
