---
phase: 21-template-versioning-rendering-contracts
verified: 2026-04-28T19:41:06Z
status: passed
score: 14/14 must-haves verified
overrides_applied: 0
---

# Phase 21: Template Versioning & Rendering Contracts Verification Report

**Phase Goal:** Make notification content versioned, channel-aware, and previewable without coupling durable history to notifier module changes.
**Verified:** 2026-04-28T19:41:06Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Notification content versions are persisted as durable rendering identity separate from notifier module names. | ✓ VERIFIED | Migration adds `render_assigns`, `render_key`, `render_version`, and `render_data` in durable tables; schemas expose them in [priv/repo/migrations/20260428123000_add_rendering_contract_fields.exs](/Users/jon/projects/chimeway/priv/repo/migrations/20260428123000_add_rendering_contract_fields.exs:4), [lib/chimeway/notifications/notification.ex](/Users/jon/projects/chimeway/lib/chimeway/notifications/notification.ex:16), and [lib/chimeway/delivery.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery.ex:16). Integration coverage proves `delivery.render_key != event.notification_key` in [test/chimeway/rendering/render_identity_integration_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/render_identity_integration_test.exs:97). |
| 2 | Notifier content declarations normalize into one explicit rendering contract before planning-time channel work begins. | ✓ VERIFIED | `Notifier.resolve_rendering/3` delegates to `Rendering.resolve_declaration/3` in [lib/chimeway/notifier.ex](/Users/jon/projects/chimeway/lib/chimeway/notifier.ex:242), and normalization plus `build/2` fallback live in [lib/chimeway/rendering.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering.ex:26). Contract tests cover explicit declarations, fallback, and invalid declarations in [test/chimeway/notifier_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/notifier_contract_test.exs:153). |
| 3 | Durable render identity is regression-protected before downstream rendering and preview slices build on it. | ✓ VERIFIED | Render identity regression tests cover notification fields, delivery fields, trigger persistence, and planning-time identity stamping in [test/chimeway/rendering/render_identity_integration_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/render_identity_integration_test.exs:56). |
| 4 | Structured render inputs persist once per notification. | ✓ VERIFIED | Trigger persistence resolves rendering once per recipient, sanitizes assigns, and writes the same durable map to `metadata` and `render_assigns` in [lib/chimeway/trigger.ex](/Users/jon/projects/chimeway/lib/chimeway/trigger.ex:141). Trigger integration confirms secrets are stripped and the persisted assigns are reused in [test/chimeway/rendering/render_identity_integration_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/render_identity_integration_test.exs:141). |
| 5 | New canonical delivery rows are created with render identity already present. | ✓ VERIFIED | Planner resolves render results before insert and passes `render_key`, `render_version`, and `render_data` into `Deliveries.plan_delivery/3` in [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:77) and [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:43). Verified by planning tests in [test/chimeway/rendering/render_identity_integration_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/render_identity_integration_test.exs:169). |
| 6 | Repeated planning preserves the same render identity for the same notification and channel. | ✓ VERIFIED | Planner reuses persisted `notification.render_assigns` and only updates delivery rows when render facts drift in [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:270) and [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:372). Regression coverage is in [test/chimeway/orchestration/delivery_planning_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:289). |
| 7 | Channel-specific rendering inputs and outputs are explicit, validated, and covered by contract tests. | ✓ VERIFIED | `Rendering.render_delivery/4` routes only supported channels through dedicated validators in [lib/chimeway/rendering.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering.ex:53). `InApp.validate/1` and `Email.validate/1` enforce explicit runtime payload shapes in [lib/chimeway/rendering/channels/in_app.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering/channels/in_app.ex:16) and [lib/chimeway/rendering/channels/email.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering/channels/email.ex:16). Contract tests are in [test/chimeway/rendering/channel_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/channel_contract_test.exs:6). |
| 8 | In-app rendering uses an explicit validated payload contract. | ✓ VERIFIED | `headline`, `body`, and nested `primary_action` are required and normalized to string-keyed payloads in [lib/chimeway/rendering/channels/in_app.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering/channels/in_app.ex:8). Positive coverage is in [test/chimeway/rendering/channel_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/channel_contract_test.exs:7). |
| 9 | Email rendering uses an explicit validated payload contract. | ✓ VERIFIED | `subject`, `html_body`, and `text_body` are required in [lib/chimeway/rendering/channels/email.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering/channels/email.ex:8). Positive coverage is in [test/chimeway/rendering/channel_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/channel_contract_test.exs:31). |
| 10 | Malformed channel payloads fail through runtime validation instead of silently passing. | ✓ VERIFIED | `render_delivery/4` wraps validator failures as tagged `{:rendering_failed, ...}` errors in [lib/chimeway/rendering.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering.ex:71). Negative-path contract tests are in [test/chimeway/rendering/channel_contract_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/channel_contract_test.exs:55) and [test/chimeway/rendering/preview_pipeline_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/preview_pipeline_test.exs:154). |
| 11 | Canonical delivery rows hold validated channel render output before dispatch. | ✓ VERIFIED | Planner computes `render_result`, persists it on insert, and reapplies it on reused rows in [lib/chimeway/delivery_planning.ex](/Users/jon/projects/chimeway/lib/chimeway/delivery_planning.ex:89) and [lib/chimeway/deliveries.ex](/Users/jon/projects/chimeway/lib/chimeway/deliveries.ex:258). Delivery-planning tests assert `render_data` exists while status is still `:pending` in [test/chimeway/orchestration/delivery_planning_test.exs](/Users/jon/projects/chimeway/test/chimeway/orchestration/delivery_planning_test.exs:317). |
| 12 | Adapters consume pre-rendered delivery content without late notifier or renderer callbacks. | ✓ VERIFIED | Integration test proves render callbacks fire during planning, not adapter delivery, and the adapter receives the stored `render_data` in [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:959). |
| 13 | Explainability surfaces show render identity without leaking rendered body content. | ✓ VERIFIED | `Traces.explain_delivery/2` projects `render_key` and `render_version` only in [lib/chimeway/traces.ex](/Users/jon/projects/chimeway/lib/chimeway/traces.ex:112), and the explanation struct has no `render_data`/body fields in [lib/chimeway/traces/explanation.ex](/Users/jon/projects/chimeway/lib/chimeway/traces/explanation.ex:39). Negative leak checks are in [test/chimeway/integration/delivery_lifecycle_test.exs](/Users/jon/projects/chimeway/test/chimeway/integration/delivery_lifecycle_test.exs:992). |
| 14 | Developers can preview or verify rendered notification content locally before provider delivery, through the same production pipeline and a thin Mix wrapper. | ✓ VERIFIED | `Chimeway.preview_rendering/3` delegates to `Preview.preview/3` in [lib/chimeway.ex](/Users/jon/projects/chimeway/lib/chimeway.ex:17). `Preview.preview/3` resolves notifier rendering and calls `Rendering.render_delivery/4` directly in [lib/chimeway/rendering/preview.ex](/Users/jon/projects/chimeway/lib/chimeway/rendering/preview.ex:18). The Mix task only parses inputs and delegates to `Chimeway.preview_rendering/3` in [lib/mix/tasks/preview_rendering.ex](/Users/jon/projects/chimeway/lib/mix/tasks/preview_rendering.ex:22). Parity and CLI tests are in [test/chimeway/rendering/preview_pipeline_test.exs](/Users/jon/projects/chimeway/test/chimeway/rendering/preview_pipeline_test.exs:100). |

**Score:** 14/14 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `priv/repo/migrations/20260428123000_add_rendering_contract_fields.exs` | Notification and delivery rendering columns | ✓ VERIFIED | Adds `render_assigns` on notifications and `render_key`/`render_version`/`render_data` on deliveries; used by current schemas and tests. |
| `lib/chimeway/rendering.ex` | Normalized notifier rendering declaration seam and shared render dispatch | ✓ VERIFIED | Resolves notifier declarations, validates channels, provides `build/2` fallback, and dispatches channel rendering. |
| `test/chimeway/rendering/render_identity_integration_test.exs` | Runnable regression coverage for durable render identity | ✓ VERIFIED | Covers schema acceptance, trigger persistence, planning-time identity stamping, and durable separation from notification identity. |
| `lib/chimeway/trigger.ex` | Trigger-time render assigns persistence | ✓ VERIFIED | Persists sanitized `render_assigns` once per recipient row. |
| `lib/chimeway/delivery_planning.ex` | Planning-time render identity insertion, render-data materialization, and sync | ✓ VERIFIED | Resolves render facts before insert and updates canonical rows only when persisted render data differs. |
| `lib/chimeway/deliveries.ex` | Canonical delivery helpers for render identity and render-data persistence | ✓ VERIFIED | Accepts render fields on insert and exposes `apply_render_identity/2` and `apply_render_result/2`. |
| `lib/chimeway/rendering/channels/in_app.ex` | Validated in-app output contract | ✓ VERIFIED | Runtime validation of inbox payload fields and nested action data. |
| `lib/chimeway/rendering/channels/email.ex` | Validated email output contract | ✓ VERIFIED | Runtime validation of subject/html/text fields. |
| `test/chimeway/rendering/channel_contract_test.exs` | Channel render contract tests | ✓ VERIFIED | Positive and negative-path coverage for `:in_app` and `:email`. |
| `lib/chimeway/traces/explanation.ex` | Payload-safe render identity projection | ✓ VERIFIED | Explanation struct includes render identity, omits render bodies. |
| `lib/chimeway/rendering/preview.ex` | Pure preview API over the production rendering path | ✓ VERIFIED | Produces stable preview structs without persistence or dispatch. |
| `lib/mix/tasks/preview_rendering.ex` | CLI wrapper for local preview verification | ✓ VERIFIED | Delegates to the preview API and prints stable identity plus payload output. |
| `test/chimeway/rendering/preview_pipeline_test.exs` | Parity tests between preview and production render artifacts | ✓ VERIFIED | Confirms preview equals production render result and CLI output mirrors API output. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/chimeway/notifier.ex` | `lib/chimeway/rendering.ex` | optional rendering callback normalized through one resolver | ✓ WIRED | `Notifier.resolve_rendering/3` delegates to `Rendering.resolve_declaration/3`. |
| `lib/chimeway/trigger.ex` | `lib/chimeway/rendering.ex` | one-time render declaration resolution per recipient | ✓ WIRED | `notifications_attrs/4` calls `Notifier.resolve_rendering/3` before persistence. |
| `lib/chimeway/delivery_planning.ex` | `lib/chimeway/deliveries.ex` | insert path carries render identity and render data | ✓ WIRED | `plan_one_channel/5` passes render facts to `Deliveries.plan_delivery/3` and `maybe_apply_render_result/2` persists reused-row updates. |
| `lib/chimeway/rendering.ex` | `lib/chimeway/rendering/channels/in_app.ex` | channel-specific render dispatch | ✓ WIRED | `channel_module("in_app")` resolves to `InApp` and `validate_channel_payload/3` invokes `InApp.validate/1`. |
| `lib/chimeway/rendering.ex` | `lib/chimeway/rendering/channels/email.ex` | channel-specific render dispatch | ✓ WIRED | `channel_module("email")` resolves to `Email` and `validate_channel_payload/3` invokes `Email.validate/1`. |
| `lib/chimeway/delivery_planning.ex` | `lib/chimeway/rendering.ex` | planning calls shared render pipeline before dispatch | ✓ WIRED | `resolve_render_result/4` calls `Rendering.render_delivery/4` before policy evaluation or digest accumulation. |
| `lib/chimeway/traces.ex` | `lib/chimeway/traces/explanation.ex` | render identity projection without render bodies | ✓ WIRED | `explain_delivery/2` populates `Explanation.render_key` and `render_version`; struct has no render body fields. |
| `lib/chimeway/rendering/preview.ex` | `lib/chimeway/rendering.ex` | shared production render pipeline | ✓ WIRED | `Preview.preview/3` delegates to `Rendering.render_delivery/4`. |
| `lib/mix/tasks/preview_rendering.ex` | `lib/chimeway/rendering/preview.ex` | thin wrapper delegation | ✓ WIRED | Mix task delegates to `Chimeway.preview_rendering/3`, which delegates to `Preview.preview/3`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/chimeway/trigger.ex` | `render_assigns` | `Notifier.resolve_rendering/3` -> sanitized notifier assigns | Yes; persisted into notification rows via `insert_all` | ✓ FLOWING |
| `lib/chimeway/delivery_planning.ex` | `render_result` | `Notifier.resolve_rendering/3` -> `Rendering.render_delivery/4` -> `Deliveries.plan_delivery/3`/`apply_render_result/2` | Yes; validated per-channel payload stored on delivery rows before dispatch | ✓ FLOWING |
| `lib/chimeway/traces.ex` | `render_key`, `render_version` | persisted delivery row fields loaded from Repo | Yes; explanation struct projects durable render identity only | ✓ FLOWING |
| `lib/chimeway/rendering/preview.ex` | preview struct fields | `Notifier.resolve_rendering/3` -> `Rendering.render_delivery/4` | Yes; same validated production render result becomes preview output | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 21 targeted rendering and lifecycle coverage passes | `mix test test/chimeway/notifier_contract_test.exs test/chimeway/rendering/render_identity_integration_test.exs test/chimeway/orchestration/delivery_planning_test.exs test/chimeway/rendering/channel_contract_test.exs test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/rendering/preview_pipeline_test.exs --trace` | `43 tests, 0 failures` | ✓ PASS |
| Mix preview surface is exposed locally | `mix preview.rendering --help` | Usage text printed with required flags `--notifier`, `--params`, `--recipient`, `--channel` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `TMPL-01` | `21-01`, `21-02`, `21-04` | Notification content can be versioned independently from notifier module names so rendering changes remain durable and traceable. | ✓ SATISFIED | Durable render fields on notifications/deliveries, planner persistence, and integration coverage in `render_identity_integration_test` and `delivery_lifecycle_test`. |
| `TMPL-02` | `21-01`, `21-02`, `21-03`, `21-04`, `21-05` | Channel-specific rendering contracts are explicit and testable, including structured assigns for in-app and outbound channels. | ✓ SATISFIED | `Rendering.resolve_declaration/3`, channel validators, `render_delivery/4`, planner persistence, preview parity, and dedicated contract tests. |
| `TMPL-03` | `21-05` | Developers can preview or verify rendered notification content before provider delivery. | ✓ SATISFIED | `Chimeway.preview_rendering/3`, `Rendering.Preview.preview/3`, Mix wrapper, and preview parity/CLI tests. |

No orphaned Phase 21 requirements were found in `.planning/REQUIREMENTS.md`; all requested IDs (`TMPL-01`, `TMPL-02`, `TMPL-03`) appear in plan frontmatter and are accounted for above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | — | No TODO/FIXME/placeholder stub patterns found in phase artifacts or associated tests. | — | No blocker or warning-level anti-patterns detected. |

### Human Verification Required

None.

### Gaps Summary

No implementation or wiring gaps were found against the merged roadmap and plan must-haves. The phase goal is achieved in code: render identity is durable and decoupled from notifier modules, channel contracts are explicit and runtime-validated, delivery rows carry validated render artifacts before dispatch, traces expose safe render identity, and preview tooling reuses the same production render path.

---

_Verified: 2026-04-28T19:41:06Z_  
_Verifier: Claude (gsd-verifier)_
