# Phase 2: First Outbound Delivery Slice - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove end-to-end outbound delivery from planned rows through attempt outcomes using one adapter seam, while preserving durable explainability and adapter replaceability. This phase defines delivery/attempt persistence, sync dispatch flow, and adapter contracts. Broad provider matrix, async queue policy hardening, and advanced operator UX remain outside this boundary.

</domain>

<decisions>
## Implementation Decisions

### Recipient and channel planning contract
- **D-01:** Keep canonical per-recipient notification rows as the stable core record (`event -> notification`), then expand channel-specific delivery rows in a planner step (`notification -> delivery`).
- **D-02:** Introduce a hybrid intent model: notifier modules declare recipient-level intent plus channel intent, but channel expansion/classification happens in core planner/dispatcher logic, not inside adapters.
- **D-03:** Prevent least-surprise violations by preserving deterministic planning and idempotency around canonical records before outbound side effects.

### Outbound seam scope for this phase
- **D-04:** Ship `Test` + `Logger` adapters in Phase 2 as the first outbound seam.
- **D-05:** Lock a Swoosh-ready adapter contract now (input/output shapes, metadata expectations, error classes) so a real email adapter can be added without rewriting dispatcher or persistence flow.
- **D-06:** Keep provider-specific concerns behind behaviour boundaries and runtime config so core remains provider-agnostic and easy to adopt.

### Delivery schema evolution strategy
- **D-07:** Add `suppression_reason` (nullable) and `delay_fallback` (boolean default false) in the initial `chimeway_deliveries` migration.
- **D-08:** Treat these fields as schema-ready but behavior-limited in Phase 2; strict semantic activation (policy taxonomy and delayed-read gating) is formalized in Phase 3.
- **D-09:** Prefer additive-forward Ecto migrations that minimize upgrade churn for OSS consumers and reduce later alter-migration risk.

### Attempt outcome contract and diagnostics
- **D-10:** Require canonical classified outcomes across adapters (for example: `:temporary`, `:permanent`, `:bounced`) so retries, suppression logic, and traces stay consistent.
- **D-11:** Persist compact, redacted canonical provider metadata for every attempt; never persist raw unbounded provider payloads by default.
- **D-12:** Support optional deeper provider diagnostics only as a controlled extension (explicit redaction allowlist, size/retention guardrails), keeping canonical fields authoritative for cross-adapter behavior.
- **D-13:** Keep outcome classification in dispatcher/context logic rather than adapter implementations to avoid drift and preserve replaceability.

### Claude's Discretion
- Exact callback naming and struct shape for channel intents (for example `channels/2` vs `delivery_intents/2`) as long as decisions D-01 through D-03 hold.
- Final field/type representation (`Ecto.Enum` vs validated string fields) for delivery/attempt outcomes, provided queries remain explicit and operator-friendly.
- Exact metadata allowlist, truncation limits, and retention mechanics for optional deep diagnostics, as long as canonical redacted fields remain primary.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract and scope
- `.planning/ROADMAP.md` - Phase 2 goal, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` - Locked requirement set (`DLVR-01`, `DLVR-02`, `DLVR-03`, `INTG-01`, `INTG-02`).
- `.planning/PROJECT.md` - Core value, constraints, and non-negotiable architecture principles.
- `.planning/phases/02-first-outbound-delivery-slice/PHASE.md` - Phase-local sequencing and design decisions.

### Research and ecosystem guidance
- `.planning/phases/02-first-outbound-delivery-slice/RESEARCH.md` - Detailed Phase 2 architecture/options analysis and pitfalls.
- `.planning/research/ARCHITECTURE.md` - Plan-then-dispatch model and durable lifecycle architecture.
- `.planning/research/STACK.md` - Elixir/Ecto/adapter stack guidance and dependency strategy.
- `.planning/research/PITFALLS.md` - Failure patterns to explicitly prevent in delivery/attempt work.
- `.planning/research/SUMMARY.md` - Cross-phase rationale and risk ordering for roadmap consistency.

### Existing implementation constraints
- `.planning/phases/01-durable-core-spine/01-CONTEXT.md` - Locked Phase 1 decisions that this phase extends.
- `lib/chimeway/trigger.ex` - Current deterministic normalization, transaction flow, and redaction baseline.
- `lib/chimeway/notifier.ex` - Existing notifier behaviour contract to evolve without surprise.
- `lib/chimeway/notifications/notification.ex` - Canonical per-recipient record semantics.
- `priv/repo/migrations/20260424023200_create_chimeway_events.exs` - Existing event identity/idempotency persistence contract.
- `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs` - Existing notification FK/index pattern to mirror for deliveries.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Chimeway.Trigger` transaction flow (`Ecto.Multi`) can be extended to include delivery planning and attempt writes while preserving atomicity guarantees.
- `Chimeway.Notifier` behaviour already enforces explicit callback contracts; this is the natural seam for adding channel-intent callbacks.
- Existing migration/schema patterns (`events`, `notifications`) provide naming, UUID, and index conventions to reuse for `deliveries` and `attempts`.
- Existing test style (`test/chimeway/*`) already validates deterministic output and transactional rollback; this can directly host delivery/attempt contract tests.

### Established Patterns
- Deterministic normalization before writes is already a core pattern (`normalize_recipients/1`) and should remain central to delivery planning.
- Explicit tagged return values (`{:ok, ...}` / `{:error, ...}` / `{:duplicate, ...}`) are the established API style and should continue for dispatcher/adapter contracts.
- Redaction as default behavior is already present in trigger payload handling and should be mirrored in attempt/provider metadata persistence.

### Integration Points
- Delivery planning integrates immediately after notifications are persisted in trigger flow.
- Dispatch behaviour seam (`sync now, async later`) should connect Phase 2 to Phase 3 Oban work without call-site rewrites.
- Attempt persistence and delivery state transitions should share transactional boundaries with dispatch results to preserve explainability.

</code_context>

<specifics>
## Specific Ideas

- Keep the architecture coherent with successful notification systems: canonical records first, channel execution second, attempts always durable.
- Optimize for principle of least surprise for Elixir developers: explicit behaviours, explicit state transitions, explicit suppression reasons.
- Prioritize DX for adopters and maintainers: deterministic defaults, test adapters first, clear migration path to real providers, minimal rewrites across phases.
- Use a "stable contract now, richer providers later" strategy so early users can trust data semantics before depending on provider breadth.

</specifics>

<deferred>
## Deferred Ideas

- Full Swoosh adapter implementation as production-default outbound channel is deferred until the seam contract is proven stable in this slice.
- Provider-specific deep diagnostic blob policy hardening (retention windows, size caps, and export policy) can be expanded in later observability-focused work.
- Broader multi-channel routing ergonomics (advanced DSL or channel-specific orchestration UX) remain future work once base contracts are validated.

</deferred>

---

*Phase: 02-first-outbound-delivery-slice*
*Context gathered: 2026-04-24*
