---
phase: "106"
slug: idempotent-seen-lifecycle-workflow-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-09-13"
validated: "2026-09-13T03:37:48Z"
---

# Phase 106 — Validation Strategy

> Retroactive Nyquist audit of the authorized visible-seen lifecycle and mounted workflow proof.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir 1.19.5 / OTP 27 |
| **Config files** | `mix.exs`, `chimeway_inbox/mix.exs`, `examples/chimeway_demo_host/mix.exs` |
| **Quick run command** | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs test/chimeway_inbox/pub_sub_publisher_test.exs --warnings-as-errors` |
| **Full suite command** | `mix verify.inbox` |
| **Observed runtime** | ~2 seconds focused; ~18 seconds named gate |

---

## Sampling Rate

- **After inbox lifecycle changes:** Run the focused optional-package command.
- **After workflow journey changes:** Run `cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors`.
- **Before phase or release verification:** Run `mix verify.inbox`.
- **Max observed feedback latency:** 18 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 106-01-01 | 01 | 1 | INT-03 | Closed mount writes nothing; authorized open marks only scoped page-one rows; toggle authorization drift redirects before any seen write; a stale row failure is contained and the remaining visible row reconciles from durable state. | LiveView integration | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 106-01-02 | 01 | 1 | INT-03 | Load-more marks only newly revealed rows; a forged closed load-more and load-more auth drift write nothing; relevant reload engages only while open; remount starts closed and preserves the exact first timestamp and signal count; sender-excluded publication preserves loaded pagination. | LiveView/PubSub integration | `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs test/chimeway_inbox/pub_sub_publisher_test.exs --warnings-as-errors` | ✅ | ✅ green |
| 106-02-01 | 02 | 2 | INT-04 | Opening the mounted demo bell creates the first seen fact, drains the real Oban signal queue, activates the exact eligible run, and records one `signal_received` transition. | End-to-end integration | `cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | ✅ | ✅ green |
| 106-02-02 | 02 | 2 | INT-04 | An explicit same-scope signal replay cannot add a second transition; wrong tenant, wrong recipient, and post-mount authorization change leave the waiting workflow unchanged. | End-to-end negative integration | `cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | ✅ | ✅ green |

### Requirement-Level Evidence

| Requirement | Behavioral Evidence | Result |
|-------------|---------------------|--------|
| INT-03 | `bell_dropdown_live_test.exs` exercises closed/open/reopen, 20-of-21 visibility, pagination, closed-forged events, open/closed reload, toggle/load-more/stream auth drift, reconnect/remount idempotence, stale-row failure containment, exact persisted timestamps, and exact seen-signal counts. `pub_sub_publisher_test.exs` proves opaque scoped delivery to other subscribers while `broadcast_from/4` excludes the publisher; the loaded-page assertion proves publisher echoes do not collapse pagination. | ✅ green |
| INT-04 | `inbox_bell_proof_test.exs` mounts `/inbox`, opens the real bell, drains `:chimeway_signals`, and checks durable run state and transition count. It also submits an explicit replay and exercises wrong-tenant, wrong-recipient, and changed-authorization denials. Core `inbox_state_transition_test.exs` and `workflows_test.exs` independently prove first-transition signal idempotence and exact waiting-run matching. | ✅ green |

---

## Wave 0 Requirements

Existing infrastructure and committed behavioral tests cover all phase requirements. No Wave 0 stubs remain.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Audit 2026-09-13

| Metric | Count |
|--------|-------|
| Gaps found | 5 |
| Resolved | 5 |
| Escalated | 0 |

### Tests Added or Strengthened

| Gap | Behavioral proof | File | Result |
|-----|------------------|------|--------|
| Reconnect/remount behavior was claimed but not directly exercised. | A second mount starts closed; opening it preserves the original `seen_at` and signal count. | `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` | ✅ green |
| Load-more authorization drift was inferred from other handlers. | Tenant drift before `load_more` redirects and leaves the 21st row unseen with no additional signal. | `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` | ✅ green |
| Partial seen-write failure containment had no executable edge. | Deleting one row after mount makes its mark return not-found while the other visible row is marked and the panel remains usable. | `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` | ✅ green |
| Replay was represented by repeat UI actions rather than an actual repeated signal. | An explicit same-scope `chimeway.notification.seen` replay is drained after activation and cannot add a transition. | `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | ✅ green |
| Demo authorization change was covered only compositionally. | Post-mount recipient drift redirects before opening and leaves both notification and waiting workflow unchanged. | `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | ✅ green |

### Commands Executed

| Command | Observed Result |
|---------|-----------------|
| `cd chimeway_inbox && mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs test/chimeway_inbox/pub_sub_publisher_test.exs --warnings-as-errors` | 27 tests, 0 failures |
| `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/inbox_state_transition_test.exs test/chimeway/workflows_test.exs --warnings-as-errors` | 33 tests, 0 failures |
| `cd examples/chimeway_demo_host && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | 6 tests, 0 failures |
| `mix verify.inbox` | Root 75, optional package 29, admin 9, gate parity 41, demo 5; all 159 executed tests passed |

The named gate completed successfully. Dependency-resolution advisory output and optional demo configuration warnings were emitted but did not alter test execution or phase behavior.

---

## Validation Sign-Off

- [x] All tasks have executable automated verification.
- [x] Sampling continuity has no uncovered task boundary.
- [x] Every roadmap success criterion maps to a behavioral test.
- [x] No watch-mode flags are present.
- [x] Focused and named gates ran green during this audit.
- [x] `nyquist_compliant: true` is set in frontmatter.

**Approval:** approved 2026-09-13
