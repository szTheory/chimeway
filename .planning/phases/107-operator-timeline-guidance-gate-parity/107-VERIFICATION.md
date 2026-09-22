---
phase: 107-operator-timeline-guidance-gate-parity
verified: 2026-09-22T09:31:00Z
status: passed
score: 9/9 must-haves verified
covered_files:
  - .planning/REQUIREMENTS.md
  - .planning/phases/107-operator-timeline-guidance-gate-parity/107-01-PLAN.md
  - .planning/phases/107-operator-timeline-guidance-gate-parity/107-01-SUMMARY.md
  - .planning/phases/107-operator-timeline-guidance-gate-parity/107-02-PLAN.md
  - .planning/phases/107-operator-timeline-guidance-gate-parity/107-02-SUMMARY.md
  - MAINTAINING.md
  - chimeway_admin/lib/chimeway_admin/components/timeline_event.ex
  - chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs
  - chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex
  - chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs
  - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
  - guides/introduction/inbox-integration.md
  - guides/reference/apns-api-coverage.md
  - lib/chimeway/safe_evidence.ex
  - lib/chimeway/traces.ex
  - mix.exs
  - test/chimeway/apns/api_coverage_test.exs
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/orchestration/deferred_resume_test.exs
  - test/chimeway/orchestration/traces_deferral_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/safe_evidence_test.exs
  - test/chimeway/traces_test.exs
covered_digest: "v1:sha256:9d6f76e520a5308ac65b5cc5077e595780b6aa14aa671b9db97da9d7ed3d16f0"
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 0
  total: 0
  not_honored: []
behavior_unverified_items: []
human_verification: []
---

# Phase 107: Operator Timeline, Guidance & Gate Parity Verification Report

**Phase Goal:** Adopters and operators can understand and continuously verify the complete arrival-to-seen-to-read path.
**Verified:** 2026-09-22T09:31:00Z
**Status:** passed
**Re-verification:** Yes — re-verified 2026-09-22 at HEAD ac2046c0 after the fingerprint went stale.

> **Why it went stale.** Eight of the 24 covered inputs drifted after the 2026-09-13 verification, across 19 commits of
> post-107 release and hardening work: `test/chimeway/release_gate_contract_test.exs` (9 commits), `mix.exs` (5),
> `test/chimeway/doc_contract_test.exs` (3), `MAINTAINING.md`, `chimeway_inbox/.../bell_dropdown_live_test.exs`,
> `examples/.../inbox_bell_proof_test.exs`, `guides/introduction/inbox-integration.md` (2 each), and `lib/chimeway/traces.ex` (1).
> The last two of those commits are quick task 260921-rjh (56483d6c, 26350c44). No phase truth was invalidated —
> the digest correctly flagged that the evidence had not been re-executed against the drifted files.
>
> **Re-verification evidence (2026-09-22, HEAD ac2046c0).** `mix verify.inbox` re-executed all five declared layers
> with a true (unpiped) exit code of 0: 76 root + 29 inbox package + 9 admin + 41 docs/release contracts + 7 demo
> = **162 tests, 0 failures** (was 154 at initial verification; every layer held or grew, none shrank), which re-establishes
> truths 1–4 and 6–9 on their own declared commands. Truth 5's Phoenix-optional source/dependency contract is inside the
> green 41-test release-contract layer. Independently, the full local `mix ci` is green at 1612 tests, 0 failures with
> Credo clean, and on `d188e410` CI reports `Release gate contract`, `Optional APNs adapter gate` and `ci-gate` = success
> on push run 35678709523 and dispatch run 35679756564, with `nightly-gate` and `Admin integration gate` = success on the dispatch.
>
> Commit-claim reconciliation (#3968) also re-checked: 107-01 claims 5 commits and measures 6 (the SUMMARY commit lands
> after the executor measures — the documented consistent case); 107-02 claims 6 and measures exactly 6 plan commits.
> No `commit_claim_mismatch`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Every correlated delivery explanation can include independent notification-seen and notification-read facts from the parent notification, with authoritative timestamps and closed empty detail that excludes recipient identity, caller metadata, notification content, signal payload, publisher data, and tenant data. | ✓ VERIFIED | `Traces.explain_delivery/2` tenant-qualifies delivery, notification, and event joins; `notification_lifecycle_entries/1` reads only `notification.seen_at` and `notification.read_at`; final output passes through `SafeEvidence.trace/1`. The focused core run passed 52/52 tests, including absent, seen-only, read-only, both, sibling equality, exact shape, unknown-event rejection, and hostile-sentinel negatives. |
| 2 | The explanation timeline is globally timestamp-first, with the closed event rank used only for ties and notification-seen ordered before notification-read at an equal timestamp. | ✓ VERIFIED | `timeline_sort_key/1` returns `{DateTime.to_unix(at, :microsecond), timeline_rank(event)}` and ranks seen before read. A non-vacuous inverted-time test and an exact-tie test passed in the 52-test core run; the three post-review chronology regression files also passed 28/28 tests. |
| 3 | The optional admin timeline renders both lifecycle facts distinctly while preserving ISO timestamps, detail markup, generic event behavior, outcome/suppression semantics, and defense-in-depth redaction. | ✓ VERIFIED | `TimelineEvent.timeline/1` renders exact labels and `data-cw-timeline-event`, retains `<time>` and `<dl>`, and sends detail through `Redaction.safe_timeline_detail/1`. Focused component/redaction evidence passed 9/9 tests. |
| 4 | The mounted demo journey composes durable arrival, visible first-seen, one workflow progression, explicit read, replay idempotency, authorized Trace Detail, and scope/privacy denials end to end. | ✓ VERIFIED | `DemoHostWeb.InboxBellProofTest` drives the real `/inbox` and `/admin/chimeway/deliveries/:id` mounts, persists and rechecks both timestamps, drains the real signal queue, asserts one transition, verifies labels/hooks, and rejects hostile sentinels. The focused demo run passed 5/5 tests. The post-review closed-panel `load_more` guard is wired and its package regression is included in the green 154-test alias. |
| 5 | Core remains Phoenix-free, `chimeway_admin` remains optional and host-mounted, and no schema, durable identity, or lifecycle authority moved. | ✓ VERIFIED | Phase production changes add only a projection in core and presentation hooks in the optional admin package. The root package has no Phoenix dependency/reference; the named root gate includes the executable Phoenix-optional source/dependency contract. No migration, schema, public function, or dependency was added for the lifecycle projection. |
| 6 | The canonical inbox guide gives source-valid publisher, PubSub, secret, recipient-auth, and tenant-auth configuration; assigns core/package/host ownership; and separates arrival, seen, read, archive, provider handoff, presentation, protected activation, engagement, reconnect, and reload semantics. | ✓ VERIFIED | The guide contains the working config/auth shapes, opaque `cw_*` identity examples, current reauthorization rules, an explicit responsibility split, and a full non-implication table. Positive, ordering, stale-copy, raw-recipient, caller-metadata, and notification-content contracts passed as part of the 41-test focused docs/gate run. |
| 7 | Every recursive cleanup in the release-gate contract is restricted to allocator-owned, non-symlink, immediate children of the system temp root and refuses unsafe or forged paths. | ✓ VERIFIED | `owned_temp_directory!/1` atomically allocates and registers a random root plus marker/identity; `remove_owned_temp_dir!/1` checks expanded parent, closed prefix, marker token, registry ownership, final `lstat`, and inode/device identity before the module's sole `File.rm_rf!/1`. Acceptance, root/nested/outside/unowned refusal, concurrency, failed-build cleanup, and structural exclusivity passed 5/5 tests. |
| 8 | `mix verify.inbox` owns the five required evidence layers in cheapest-to-broadest order and executes the complete inbox proof surface warning-strictly. | ✓ VERIFIED | `mix.exs` contains the exact root → inbox package → focused admin → docs/release contracts → demo order. Mutation contracts reject command deletion/reordering. Independent execution passed all five layers: 74 root + 25 inbox + 9 admin + 41 contracts + 5 demo = 154 tests, 0 failures. |
| 9 | One `verify_inbox` CI job invokes the alias, both `pr-gate` and `ci-gate` consume exactly the same result, nightly-only work stays outside the release aggregates, and maintainer instructions describe the same contract. | ✓ VERIFIED | `.github/workflows/ci.yml` has one `mix verify.inbox` invocation; both aggregate `needs`, result env, and script arguments contain the single lane; nightly jobs are excluded. Mutation tests and exact maintainer-copy assertions passed in the focused gate run. |

**Score:** 9/9 truths verified (0 present but behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | Parent lifecycle projection and timestamp-first ordering | ✓ VERIFIED | Exists, substantive, called by the public explanation path, and exercised against persisted rows. |
| `lib/chimeway/safe_evidence.ex` | Closed admission of seen/read with empty detail | ✓ VERIFIED | Both atoms are admitted; no new detail field exists; unknown events and hostile detail are dropped. |
| `test/chimeway/traces_test.exs` | State, sibling, chronology, scope, and privacy proof | ✓ VERIFIED | Value- and behavior-level assertions run green. |
| `test/chimeway/safe_evidence_test.exs` | Closed-vocabulary proof | ✓ VERIFIED | Exact safe output and unknown-event rejection run green. |
| `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` | Exact labels and stable event hook | ✓ VERIFIED | Wired through `TraceDetailLive`; component test run green. |
| `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` | Timestamp, label, hook, markup, and redaction proof | ✓ VERIFIED | Focused assertions run green. |
| `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | Mounted arrival-to-operator journey | ✓ VERIFIED | Real routes, durable rows, signal queue, idempotency, and privacy are exercised. |
| `guides/introduction/inbox-integration.md` | Canonical ownership, isolation, reconnect, and semantics guidance | ✓ VERIFIED | Source-valid guide is substantive and contract-tested. |
| `test/chimeway/doc_contract_test.exs` | Positive and unsafe/stale-negative documentation contract | ✓ VERIFIED | Focused tagged contract passed. |
| `test/chimeway/release_gate_contract_test.exs` | Cleanup safety plus alias/job/aggregate mutation contracts | ✓ VERIFIED | Both focused tags passed; one guarded recursive deletion call exists. |
| `mix.exs` | Single ordered `verify.inbox` composition | ✓ VERIFIED | Exact five-command composition executed successfully. |
| `MAINTAINING.md` | Complete evidence inventory and equal-consumer statement | ✓ VERIFIED | Exact prose is mutation-locked by the release contract. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | `lib/chimeway/notifications/notification.ex` | Tenant-scoped preload reads persisted `seen_at` / `read_at` | ✓ WIRED | Query and runtime tests confirm the parent row is the sole lifecycle source. |
| `lib/chimeway/traces.ex` | `lib/chimeway/safe_evidence.ex` | Timeline detail and final trace projection | ✓ WIRED | Exact lifecycle entries survive; unknown events and unsafe fields do not. |
| `chimeway_admin/.../timeline_event.ex` | `lib/chimeway/safe_evidence.ex` | Safe explanation plus admin re-redaction | ✓ WIRED | `TraceDetailLive` passes `@explanation.timeline`; component applies its own allowlist. |
| Demo inbox journey | Admin Trace Detail route | Authorized LiveView mount after seen/read transitions | ✓ WIRED | Mounted end-to-end test passed. |
| Inbox guide | Demo config and auth | Copied publisher/PubSub/secret/callback shape | ✓ WIRED | Contract and source inspection agree. |
| `mix.exs` | Root/package/admin/docs/demo tests | Five alias commands | ✓ WIRED | All layers executed by one alias. |
| `.github/workflows/ci.yml` | `mix.exs` | Sole `mix verify.inbox` invocation | ✓ WIRED | Exact command asserted structurally. |
| `.github/workflows/ci.yml` | `scripts/ci/aggregate-gate.sh` | `needs.verify_inbox.result` in both aggregates | ✓ WIRED | Both fail-closed edges are mutation-tested. |
| `MAINTAINING.md` | Alias and CI topology | Contracted evidence inventory | ✓ WIRED | Focused maintainer-copy assertion passed. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/traces.ex` | lifecycle timeline entries | Tenant-qualified Ecto query → persisted `Notification.seen_at` / `read_at` | Yes | ✓ FLOWING |
| `TraceDetailLive` → `TimelineEvent` | `@explanation.timeline` | `Traces.explain_delivery/2` → `SafeEvidence.trace/1` | Yes | ✓ FLOWING |
| `BellDropdownLive` | visible inbox rows and transition timestamps | Host-reauthorized `Chimeway.list_for_recipient/2`, `mark_seen/3`, and `mark_read/3` against durable rows | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Lifecycle projection, privacy, and ordering | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` | 52 tests, 0 failures | ✓ PASS |
| Admin labels/hooks/redaction | `cd chimeway_admin && mix deps.get && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` | 9 tests, 0 failures | ✓ PASS |
| Mounted arrival-to-seen-to-read journey | `cd examples/chimeway_demo_host && mix deps.get && mix test test/demo_host_web/inbox_bell_proof_test.exs --include inbox --warnings-as-errors` | 5 tests, 0 failures | ✓ PASS |
| Guide and CI topology parity | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | 41 tests, 0 failures | ✓ PASS |
| Recursive cleanup invariant | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only release_cleanup_safety --warnings-as-errors` | 5 tests, 0 failures | ✓ PASS |
| Complete named inbox gate | `mix verify.inbox --warnings-as-errors` | 154 tests across five layers, 0 failures | ✓ PASS |
| Post-review chronology regression | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/orchestration/deferred_resume_test.exs test/chimeway/orchestration/traces_deferral_test.exs --warnings-as-errors` | 28 tests, 0 failures | ✓ PASS |

### Probe Execution

No migration/tooling probe was declared or implied by either plan; no `probe-*.sh` path is referenced. The executable Mix/ExUnit gates above are the phase's declared evidence.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| INT-02 | 107-01 | Stable, timestamped, allowlisted seen/read facts without recipient or caller metadata | ✓ SATISFIED | Persisted projection, SafeEvidence, admin rendering, mounted trace, and privacy negatives all passed. |
| DOCS-03 | 107-02 | Complete publisher/ownership/isolation/lifecycle/reconnect guidance | ✓ SATISFIED | Canonical guide and 37 focused documentation assertions within the 41-test contract run passed. |
| GATE-03 | 107-01, 107-02 | Named local and aggregate gates prove the packaged and mounted full journey plus Phoenix-optional core | ✓ SATISFIED | Five-layer alias passed 154 tests; exact CI and aggregate edges passed mutation contracts. |

No Phase 107 requirement is orphaned: all three roadmap-mapped IDs appear in plan frontmatter and have executable evidence.

### Decision Coverage

No trackable decisions in CONTEXT.md were recognized by the automated decision-coverage query (`skipped: true`, `total: 0`). Direct verification nevertheless covered each locked implementation, ownership, guidance, and gate-parity decision in the observable truths above.

### Test Quality Audit

| Test File / Group | Linked Req | Active Evidence | Skipped | Circular | Assertion Level | Verdict |
| --- | --- | ---: | ---: | --- | --- | --- |
| `traces_test.exs` + `safe_evidence_test.exs` | INT-02 | 52 passing | 0 | No | Behavioral + exact value + negative privacy | ✓ STRONG |
| Admin component + redaction tests | INT-02 | 9 passing | 0 | No | Rendered value + negative privacy | ✓ STRONG |
| Inbox package suite | GATE-03 | 25 passing | 0 | No | Mounted state transitions + authorization | ✓ STRONG |
| Demo inbox proof | INT-02, GATE-03 | 5 passing | 0 | No | End-to-end mounted workflow | ✓ STRONG |
| Inbox guide contract | DOCS-03 | 37 passing | 0 | No | Exact content/order + mutation negatives | ✓ STRONG |
| Inbox parity contract | GATE-03 | 4 passing | 0 | No | Exact topology + deletion/reorder mutations | ✓ STRONG |
| Cleanup safety contract | GATE-03 | 5 passing | 0 | No | Filesystem behavior + refusal + failure cleanup | ✓ STRONG |

The disabled-test scan found no actual skipped requirement test; apparent `xit(` matches were ordinary `on_exit(` callbacks. No expected value is generated by the system under test, and each behavior-dependent truth has a passing behavioral test.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | ---: | --- | --- | --- |
| `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` | 472 | Stale comment says the bell does not invoke `mark_seen`, contradicting the now-tested implementation | ⚠️ Warning | Misleads maintainers only; runtime, public guide, and executable evidence are correct. Remove during the planned repository-hygiene pass. |

No `TBD`, `FIXME`, or `XXX` debt marker, stub implementation, disabled requirement test, hollow data source, or unguarded recursive deletion was found in the phase-owned surface. Dependency preparation emits existing advisory notices for locked optional/demo dependencies; Phase 107 changed no dependency and the release-hygiene batch should own remediation.

### Human Verification Required

N/A — all acceptance criteria are objective and exercised by executable tests. Per repository instructions, no conversational UAT is created for this phase.

### Gaps Summary

No blocking or behavior-unverified gap remains. All roadmap success criteria, plan must-haves, artifacts, key links, and mapped requirements are verified against current code and current-run evidence. There are no later milestone phases against which to defer an unmet item.

---

_Verified: 2026-09-13T03:28:36Z_
_Verifier: the agent (gsd-verifier)_
