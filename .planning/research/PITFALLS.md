# Domain Pitfalls

**Domain:** Embedded notification workflow orchestration (Channel & Feedback Expansion)
**Researched:** 2026-04-30

## Critical Pitfalls

### Pitfall 1: Webhook Security & Verification
**What goes wrong:** Malicious actors forge delivery receipts, manipulating workflow progression or injecting spam data.
**Why it happens:** Webhooks are exposed public endpoints.
**Consequences:** Workflows terminate early, escalate improperly, or pollute timeline traces with fake data.
**Prevention:** The webhook ingestion seam MUST enforce signature verification contracts before touching database rows. Provide helpers but enforce the check.

### Pitfall 2: Out-of-Order Callbacks
**What goes wrong:** A `delivered` webhook arrives *before* the `dispatched` state is fully persisted by Oban.
**Why it happens:** Asynchronous provider speeds outpace internal queue transaction bounds (e.g., Oban takes 200ms to ack, but Twilio fires the webhook in 50ms).
**Consequences:** State machine exceptions or overwritten outcomes if the DB row isn't ready.
**Prevention:** The canonical delivery row must handle upsert-style state convergence safely (e.g., storing the final outcome even if the dispatch job hasn't cleared, or enqueuing a delayed processor for the webhook).

## Moderate Pitfalls

### Pitfall 3: Payload Bloat
**What goes wrong:** Storing the entire raw webhook payload in the `Delivery` metadata or `Trace`.
**Prevention:** Normalize the data. Store only the provider's canonical ID, the normalized outcome, and the specific string error reason. Discard the rest of the HTTP payload.

### Pitfall 4: Channel Configuration Atom Exhaustion
**What goes wrong:** Dynamically converting provider channel names from webhooks into Atoms.
**Prevention:** Always use safe string-keyed maps or `String.to_existing_atom` when bridging from webhook payloads to internal identifiers, matching Phase 11's string-safe adapter lookup.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Inbound Normalization | Hardcoding vendor rules | Use a `Normalizer` behaviour |
| Feedback Progression | Race conditions with Oban retries | Ensure delivery terminal state cancels pending Oban retries |

## Sources
- Chimeway `.planning/STATE.md` (Decision: String-safe adapter lookup) (HIGH confidence)
- General Webhook architecture best practices (HIGH confidence)
