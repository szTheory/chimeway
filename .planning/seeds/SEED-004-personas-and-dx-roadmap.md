---
id: SEED-004
status: deferred
planted: 2026-04-29T15:34:12Z
planted_during: Milestone v1.3 initialization
trigger_when: Adoption, operator experience, or persona-specific DX becomes the next highest-leverage milestone theme.
scope: large
shipped_by: v1.5-v1.9
remaining:
  - INT-02 inbox-read signal projection onto delivery timeline UI
  - INT-03 mark_seen progression E2E and BellDropdownLive mark_seen wiring
  - INBX-03 real-time PubSub bell badge updates
  - ADPT-01 greenfield phx.new plus Hex dependency install smoke in CI
---

# Personas, JTBD & DX Roadmap (v1.5+)

**Domain:** Product Strategy, User Experience, and Developer Experience
**Status:** Deferred after v1.9 persona/DX foundation

## Core Product Philosophy
**"Explainable & Local-First"**
Chimeway is embedded infrastructure. It lives inside the host app's PostgreSQL database and uses Oban for transactional, durable processing.
- **Local-First Data Ownership:** No syncing user data to a 3rd party. The host app is the source of truth.
- **Total Explainability:** Every decision (send, fail, defer, suppress, digest) is recorded as a trace. Operators can answer exactly *why* something happened.

## Outcome / Remaining Work

The persona and DX foundation shipped across v1.5-v1.9:

- Feature Developer path: installer, golden-path docs, reference recipes, demo seeds, and copyable integration guides.
- Support Operator path: optional admin surface, trace inspection, demo host proof, and explainable lifecycle records.
- Product Manager path: workflow journeys, channel feedback, read-cancel progression, Accrue dunning, and inbox UI foundations.

Remaining optional polish is deferred beyond v1.10: INT-02, INT-03, INBX-03, and ADPT-01.

## Personas & Jobs-To-Be-Done (JTBD)

### 1. The Feature Developer
* **JTBD:** "I need to add an 'invite sent' notification to my new feature."
* **Needs:** Simple, predictable trigger APIs (like `Chimeway.trigger/3`), clear test fixtures, and reliable local development. They want to fire the event and get back to business logic.

### 2. The Support Operator
* **JTBD:** "A user says they didn't get their password reset email. Why?"
* **Needs:** Timeline traces and outcome explainability. This is Chimeway's superpower. They need to see if it was suppressed by a policy, failed at the provider, or is deferred in a digest.

### 3. The Product Manager
* **JTBD:** "If they don't open the email in 2 hours, send them a push notification."
* **Needs:** Workflow Journeys (v1.3) and Feedback-Driven progression (v1.4). They need the system to understand business logic surrounding time and state.

---

## The Road Ahead: Making it "Batteries Included" (v1.5+)
Chimeway has an incredibly robust engine block. The next phase (v1.5 Adoption Surface) is about putting the car body around it so a Phoenix developer can drive it off the lot instantly.

### 1. Reference Flows & Blueprints
Providing drop-in examples for the most common SaaS flows (e.g., Magic Link Login, Drip Campaigns, Escalation policies). See `SEED-003` for integration blueprints with libraries like Accrue and Sigra.

### 2. Time & Outcome Progression Polish
Currently, the engine handles terminal feedback. Next is making it trivial to write rules like: *"Wait 24h, if Delivery state is still `unread`, trigger SMS Adapter."* (Read/unread tracking is currently deferred, but is the holy grail for product teams).

### 3. Operator UI (LiveView Dashboard)
Chimeway has amazing data traces in the DB. Building an optional `ChimewayLiveDashboard` (similar to Oban Pro or Phoenix LiveDashboard, or Mailglass Admin) where support staff can search a User ID and see a visual timeline of every notification decision, suppression, and delivery attempt.

### 4. In-App Notification Center
Providing a headless API or unstyled LiveView components for the classic "Bell Icon" dropdown (inbox state, read receipts) that every SaaS needs.
