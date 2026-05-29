# Phase 51: Journey & Admin Proof - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend journey CI to prove READ cancel semantics end-to-end and cover all three SEED-004 personas in admin trace surfaces — completing the adoption-evidence tail for v1.7 READ.

**In scope:** JOUR-06 journey test (read-cancel before `due_at` + complementary unread time-fallback); JOUR-07 admin LiveView test for Sam password-reset suppression; JOUR-08 admin LiveView test for Morgan payment-escalation workflow trace; demo-host test tags (`:jour_06`..`:jour_08`).

**Out of scope:** Engine changes to `route_signal/1` or progression post-match behavior (Phases 48–50 locked); GATE-03 / `MAINTAINING.md` quintet expansion (Phase 52); README webhook-contradiction fix (Phase 52 DOCS); Playwright browser automation (INV-004 deferral).

</domain>

<decisions>
## Implementation Decisions

### JOUR-06 — Read-cancel + time-fallback proof
- **D-01:** Add `@tag :jour_06` test in `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` extending the escalation scenario with assertions JOUR-03 deliberately omitted: after `mark_read` before persisted `due_at`, assert no `email` delivery exists for the workflow run and the run resumes `:active` on `initial_notice` (not advanced to `email_escalation`).
- **D-02:** Complementary unread path in the same or paired test: without `mark_read`, call `Chimeway.Workflows.Progression.progress_run/2` with `now` past the persisted `due_at` (pattern from `workflow_progression_test.exs` CR-01 describe) → exactly one `email_escalation` delivery is created. Together D-01 + D-02 prove "email fires only when unread."

### JOUR-07 — Sam suppression admin trace (Support Operator)
- **D-03:** Add `@tag :jour_07` test in `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` mirroring JOUR-04: `DemoHost.Seeds.seed_password_reset/0` → search by `DemoHost.Seeds.sam_identity()` → detail page shows `suppressed` status, `channel_disabled` suppression reason, and `teampulse.password_reset` notification key.

### JOUR-08 — Morgan escalation admin trace (Product Manager)
- **D-04:** Add `@tag :jour_08` test in `admin_trace_live_test.exs`: `DemoHost.Seeds.escalation_waiting!/0` → search by `DemoHost.Seeds.morgan_identity()` → detail shows `teampulse.payment_reminder`, `teampulse-seed-payment-corr` correlation id, and workflow-relevant timeline content (e.g. `:waiting` or `signal_received` transition visible after optional `mark_read` drain).

### Scope fences & test placement
- **D-05:** All three journeys live in the demo host, tagged `:journey` for `mix verify.journeys`. No engine behavioral changes — read-cancel is proven at journey level via "resume `:active` without advancing to `to_step`" plus negative email-delivery assertion (existing `route_signal/1` contract from Phase 48 D-07).
- **D-06:** GATE-03 (`mix verify.journeys` count documentation, MAINTAINING.md quintet update) is Phase 52 — Phase 51 only adds the three tests; Phase 52 wires gate documentation.

### Claude's Discretion
- Whether JOUR-06 read-cancel and time-fallback are one test or two tagged tests in the same file.
- Exact JOUR-08 timeline assertions (pre- vs post-`mark_read`) as long as Morgan escalation workflow trace is explainable in admin detail.
- Whether JOUR-06 time-fallback uses direct `Progression.progress_run/2` with injected `now` vs `WorkflowProgressionWorker` drain (prefer direct `progress_run` for determinism, matching unit-test pattern).
- Optional update to `mention-escalation.md` scope-fence line 90 once JOUR-06 ships (may defer to Phase 52 doc pass).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` — Phase 51 goal, success criteria (JOUR-06..08)
- `.planning/REQUIREMENTS.md` — JOUR-06, JOUR-07, JOUR-08 acceptance criteria
- `.planning/PROJECT.md` — v1.7 READ milestone, SEED-004 personas, journey CI posture

### Prior phase context
- `.planning/phases/48-wait-until-pending-signals/48-CONTEXT.md` — `cancel_signals` → `pending_signals`, D-07 route_signal unchanged
- `.planning/phases/49-inbox-read-signal/49-CONTEXT.md` — `mark_read` signal emission, JOUR-06 scope fence
- `.planning/phases/50-natural-escalation-demo/50-CONTEXT.md` — JOUR-03 READ path, deferred JOUR-06/07/08

### Demo host — primary change seams
- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — JOUR-06 (extend escalation scenario)
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` — JOUR-07, JOUR-08 (mirror JOUR-04)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — Sam/Morgan seed helpers and identities
- `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` — escalation workflow shape
- `examples/chimeway_demo_host/lib/demo_host/notifiers/password_reset.ex` — suppression scenario notifier

### Engine (read-only — no behavioral changes)
- `lib/chimeway/workflows.ex` — `route_signal/1` (`:waiting` → `:active`, `signal_received`)
- `lib/chimeway/workflows/progression.ex` — `advance_after_wait/5`, `maybe_reactivate_due/3`
- `test/chimeway/orchestration/workflow_progression_test.exs` — CR-01 past-due advance pattern; mark_read resume pattern

### Docs & recipes
- `guides/recipes/mention-escalation.md` — read-cancel + time-fallback pattern (JOUR-06 proof target)
- `guides/recipes/password-reset-support-trace.md` — Support Operator suppression diagnostic (JOUR-07 persona)

### Admin UI
- `chimeway_admin/lib/chimeway_admin/live/trace_search_live.ex` — search form (`#trace-search-form`)
- `chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex` — suppression_reason + timeline rendering

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- JOUR-03 escalation test — seed → `:waiting` → `mark_read` → `signal_received` (base for JOUR-06 extensions).
- JOUR-02 `password_reset_explanation/0` — programmatic suppression proof Sam scenario.
- JOUR-04 admin LiveView test — search + detail navigation pattern for JOUR-07/08.
- `workflow_progression_test.exs` — `progress_run(now: past_due_now)` for time-fallback; mark_read resume assertions.

### Established Patterns
- Journey tests tagged `:journey` + `:jour_XX` for `mix verify.journeys` (currently 5 tests: JOUR-01..05).
- Admin tests use `Phoenix.LiveViewTest` with host-mounted `chimeway_admin` at `/admin/chimeway`.
- Read-cancel semantics: `route_signal/1` resumes to `:active` without advancing to `to_step` — email only via `advance_after_wait` past `due_at`.
- Phase 50 scope fence: JOUR-03 must NOT assert zero email deliveries; that is JOUR-06.

### Integration Points
- `DemoHost.Seeds` identities (`sam_identity/0`, `morgan_identity/0`) → admin recipient search.
- `Chimeway.Traces.explain_delivery/1` fields → admin detail rendering (`status`, `suppression_reason`, `timeline`).
- `Progression.progress_run/2` with injected `now` → deterministic time-fallback without waiting 7200s.

</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as-is.

</specifics>

<deferred>
## Deferred Ideas

- **GATE-03 documentation** — `MAINTAINING.md` pre-ship quintet update for 8 journey tests (Phase 52).
- **README webhook contradiction** — demo host README TraceDemo vs TeamPulse narrative (Phase 52 DOCS).
- **mention-escalation.md scope-fence removal** — line 90 "JOUR-06 (Phase 51)" caveat can be updated when test ships (optional Phase 51 or Phase 52).

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 51-Journey & Admin Proof*
*Context gathered: 2026-05-29 (assumptions mode)*
