# Phase 51: Journey & Admin Proof — Research

**Researched:** 2026-05-29
**Domain:** Demo-host journey CI + admin LiveView trace proofs (JOUR-06..08)
**Confidence:** HIGH

## Summary

Phase 51 is a **test-only extension** of the v1.6 journey suite. No `lib/chimeway/*` behavioral changes — all three requirements ship as tagged ExUnit tests in `examples/chimeway_demo_host`, picked up by existing `mix verify.journeys` (`mix test --only journey`).

JOUR-06 closes the gap JOUR-03 deliberately left open (Phase 50 scope fence): prove read-cancel prevents email escalation before `due_at`, and prove complementary time-fallback creates exactly one email delivery when unread. JOUR-07 and JOUR-08 mirror JOUR-04's admin LiveView pattern for the remaining SEED-004 personas (Sam suppression, Morgan escalation).

**Primary recommendation:** Two parallel plans — `51-01` (JOUR-06 in `journey_test.exs`) and `51-02` (JOUR-07 + JOUR-08 in `admin_trace_live_test.exs`). Use direct `Progression.progress_run/2` with injected `now` for time-fallback (CR-01 pattern), not `WorkflowProgressionWorker` drain.

## Standard Stack

### Core

| Component | Location | Purpose |
|-----------|----------|---------|
| Journey tests | `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` | JOUR-01..03 today; JOUR-06 extends escalation |
| Admin trace tests | `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | JOUR-04 today; JOUR-07/08 extend |
| Demo seeds | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | `sam_identity/0`, `morgan_identity/0`, scenario triggers |
| Payment workflow | `examples/chimeway_demo_host/lib/demo_host/notifiers/payment_reminder.ex` | `initial_notice` → `wait_until` → `email_escalation` |
| Progression seam | `lib/chimeway/workflows/progression.ex` | `progress_run/2` with `now:` option |
| Unit reference | `test/chimeway/orchestration/workflow_progression_test.exs` | CR-01 past-due advance; mark_read resume |

### Verification

| Command | Scope |
|---------|-------|
| `mix test --only jour_06` | JOUR-06 only |
| `mix test --only jour_07` | JOUR-07 only |
| `mix test --only jour_08` | JOUR-08 only |
| `mix verify.journeys` | All 8 journey tests (JOUR-01..08) |

### Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17+) |
| Config | `examples/chimeway_demo_host/config/test.exs` — Oban manual mode |
| Journey gate | Root `mix.exs` alias `verify.journeys` → `cd examples/chimeway_demo_host && mix test --only journey` |
| Admin mount | `/admin/chimeway` — `ChimewayAdmin.Live.TraceSearchLive` / `TraceDetailLive` |

## Architecture Patterns

### JOUR-06 — Read-cancel path (D-01)

**Base:** JOUR-03 (`journey_test.exs:46-85`) — seed → `:waiting` → `mark_read` → drain `:chimeway_signals` → `:active` + `signal_received`.

**Extensions beyond JOUR-03:**

1. **No email delivery** — query `Delivery` rows for `workflow_run_id` + `channel == "email"`; count must be 0.
2. **Still on `initial_notice`** — after resume, `Chimeway.Workflows.get_current_step!(run).step_key == "initial_notice"` (not `email_escalation`).
3. **Before `due_at`** — optional sanity: parse `run.status_context["due_at"]` and assert `DateTime.compare(DateTime.utc_now(), due_at) == :lt` OR simply never call `progress_run` with past `now` in this test.

**Engine contract (read-only):** `route_signal/1` resumes `:waiting` → `:active` without advancing to `to_step` (Phase 48 D-07). Email only via `advance_after_wait` when `now >= due_at`.

### JOUR-06 — Time-fallback path (D-02)

**Pattern:** `workflow_progression_test.exs:448-501` (CR-01 regression).

1. Fresh `DemoHost.Seeds.escalation_waiting!/0` — **do not** call `mark_read`.
2. Load `:waiting` run; parse `due_at` from `status_context["due_at"]`.
3. `past_due_now = DateTime.add(due_at, 1, :second)`.
4. `Progression.progress_run(run.id, now: past_due_now)` → `{:ok, {:advanced, advanced_run, [next_delivery]}}`.
5. Assert `advanced_run.current_step_id` points to `email_escalation` step.
6. Assert exactly one email delivery for the notification (`channel == "email"`).

**Recommendation:** Separate `@tag :jour_06` test (e.g. `"JOUR-06b unread time-fallback advances to email_escalation"`) from read-cancel test — shared tag, distinct test names. Avoid combining both paths in one test (state pollution).

### JOUR-07 — Sam suppression admin trace (D-03)

**Mirror:** JOUR-04 (`admin_trace_live_test.exs:9-36`).

| Step | Value |
|------|-------|
| Seed | `DemoHost.Seeds.seed_password_reset/0` |
| Search query | `DemoHost.Seeds.sam_identity()` → `"user:sam@teampulse.test"` |
| Detail assertions | `suppressed`, `channel_disabled`, `teampulse.password_reset` |
| Correlation | `teampulse-seed-reset-corr` (optional, strengthens trace) |

Password reset is email-only (`PasswordReset.channels/2` → `[:email]`). Suppressed delivery is the sole delivery — search results should surface it directly.

**Status rendering:** `TraceDetailLive` renders `{@explanation.status}` — atom `:suppressed` appears as `suppressed` in HTML.

### JOUR-08 — Morgan escalation admin trace (D-04)

**Mirror:** JOUR-04 with escalation seed.

| Step | Value |
|------|-------|
| Seed | `DemoHost.Seeds.escalation_waiting!/0` |
| Search query | `DemoHost.Seeds.morgan_identity()` |
| Detail assertions | `teampulse.payment_reminder`, `teampulse-seed-payment-corr` |
| Timeline | `workflow_waiting` or `Workflow waiting` in timeline HTML (humanized from `:workflow_waiting`) |

**Discretion (CONTEXT):** Pre-`mark_read` state shows `:waiting` workflow — sufficient for "explainable escalation trace." Optional `mark_read` + signal drain can add `signal_received` / `Workflow progressed` but is not required if `:waiting` timeline entry is visible.

**Delivery selection:** Prefer in_app delivery from seed `delivery_ids` (like JOUR-03) for detail navigation — escalation story is on the in_app notice.

## Helper Patterns

### Email delivery count (journey_test.exs)

Adapt from `workflow_progression_test.exs:909-918`:

```elixir
defp email_deliveries_for_run(run_id) do
  from(d in Delivery, where: d.workflow_run_id == ^run_id and d.channel == "email")
  |> Repo.all()
end
```

### ISO8601 due_at parse

```elixir
defp parse_due_at!(%{"due_at" => iso}) do
  {:ok, dt, _} = DateTime.from_iso8601(iso)
  dt
end
```

### Oban drain (existing in journey_test.exs)

`drain_oban!(:chimeway_signals)` — reuse for read-cancel path.

## Scope Fences (MUST NOT)

| Fence | Rationale |
|-------|-----------|
| No `lib/chimeway/*` changes | CONTEXT + Phases 48–50 locked engine behavior |
| No GATE-03 / MAINTAINING.md updates | Phase 52 |
| No README webhook fix | Phase 52 DOCS-04 |
| No Playwright / browser automation | INV-004 deferral |
| Do not modify JOUR-03 assertions | JOUR-06 is additive new test(s) |
| Optional `mention-escalation.md` line 90 scope-fence removal | Defer to Phase 52 unless trivial |

## Validation Architecture

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| JOUR-06 | `mark_read` before `due_at` → no email delivery; run on `initial_notice` | journey | `mix test --only jour_06` (read-cancel test) | ❌ Wave 1 |
| JOUR-06 | Unread past `due_at` → exactly one `email_escalation` delivery | journey | same tag, separate test | ❌ Wave 1 |
| JOUR-07 | Admin search/detail shows Sam suppression | journey | `mix test --only jour_07` | ❌ Wave 1 |
| JOUR-08 | Admin search/detail shows Morgan escalation trace | journey | `mix test --only jour_08` | ❌ Wave 1 |
| Regression | JOUR-01..05 unchanged | journey | `mix verify.journeys` | ✅ |
| Regression | Engine progression unit tests | integration | `mix test workflow_progression_test.exs` | ✅ no changes |

### Sampling Rate

- **Per task commit:** targeted `--only jour_06` / `jour_07` / `jour_08`
- **Plan merge:** `mix verify.journeys` (expect 8 tests)
- **Phase gate:** `mix verify.journeys` green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `journey_test.exs` — JOUR-06 read-cancel + time-fallback tests
- [ ] `admin_trace_live_test.exs` — JOUR-07 + JOUR-08 tests
- [ ] `@moduledoc` updates listing JOUR-01..08

## Recommended Plan Breakdown

| Plan | Wave | Scope | Requirements | Verification |
|------|------|-------|--------------|--------------|
| **51-01** | 1 | JOUR-06 tests in `journey_test.exs` | JOUR-06 | `mix test --only jour_06` then `mix verify.journeys` |
| **51-02** | 1 | JOUR-07 + JOUR-08 in `admin_trace_live_test.exs` | JOUR-07, JOUR-08 | `mix test --only jour_07` / `jour_08` then `mix verify.journeys` |

Plans 51-01 and 51-02 are **parallel** (disjoint files).

## Pitfalls

| Pitfall | What goes wrong | Avoid |
|---------|-----------------|-------|
| Asserting zero email in JOUR-03 | Breaks Phase 50 contract | New JOUR-06 test only |
| Reusing run after `mark_read` for time-fallback | State already mutated | Fresh seed per test |
| Using worker drain for time-fallback | Non-deterministic timing | `Progression.progress_run/2` + `now:` |
| Searching wrong delivery for JOUR-08 | Email step not seeded yet | Open in_app delivery detail |
| Expecting `:stopped` after read | Not engine semantics | Assert `:active` on `initial_notice`, no email |

## RESEARCH COMPLETE
