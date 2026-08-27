---
status: investigating
trigger: "Diagnose and fix seven Phase 98 Wave 7 post-merge mix test failures: render channel expectations, Mailglass evidence identifiers, Sigra integration load, Trigger result projection, and atom-count subprocess assertion."
created: 2026-08-13T00:00:00-04:00
updated: 2026-08-13T00:00:00-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

hypothesis: "The tenant-consistent fixture reaches the trace; the remaining KeyError is a stale assertion because Phase 98 intentionally omits provider_message_id and adapter_module from webhook timeline projection."
test: "Assert the trace retains the safe succeeded outcome while upstream persisted feedback-attempt assertions continue to prove opaque correlation and adapter identity."
expecting: "The Mailglass pipeline test passes without restoring private provider data to trace output."
next_action: "Commit the tenant-consistent Mailglass fixture and privacy-safe trace assertions; release-gate test remains intentionally excluded from this fast verification bundle."
bug_class: bohrbug
reasoning_checkpoint:
  hypothesis: "e227692 loses valid Mailglass correlation because raw external provider_message_id values fail opaque_ref/2 and make Executor discard all attempt facts; a deterministic opaque projection at the adapter-result boundary preserves correlation without retaining raw provider text."
  confirming_evidence:
    - "SafeEvidence.opaque_ref/2 accepts only cw_ provider references, while Mailglass emits provider-controlled IDs and Executor replaces unsafe attempt attrs with an empty fact set."
    - "Mailglass resolve_delivery/1 returns the raw webhook message ID, so the outbound attempt and inbound lookup have no common valid durable value."
  falsification_test: "If a projected outbound provider ID and projected inbound webhook ID still differ, or SafeEvidence rejects the projected ID, the hypothesis is false."
  fix_rationale: "Projecting the same bounded raw ID into a deterministic cw_ opaque reference before every durable boundary retains the correlation key while preventing raw provider text from being stored."
  blind_spots: "Other adapters with inbound raw provider IDs are not exercised by these Mailglass tests; their integration paths may need the same adapter-side projection separately."
  candidate_causes:
    - "code: Executor passes unprojected provider IDs into strict SafeEvidence."
    - "config: Hex Sigra lacks the optional Chimeway integration supplied by the local SIGRA_PATH verification lane."
    - "environment: globally shared atom count and PostgreSQL connections are affected by concurrent VM/test activity."
    - "data: old tests assert public recipients/raw adapter detail that the Phase 98 projection no longer exposes."
  and_gate: "no — each failure maps to an independent code, configuration, environment, or obsolete-contract condition; the Mailglass correlation failure itself needs only the raw external ID condition and strict persistence boundary."

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: "The post-merge test gate passes while maintaining Phase 98 privacy-safe delivery evidence contracts."
actual: "Seven named tests fail: render_channels includes email; Mailglass IDs/adapter evidence are missing; Sigra module is not loaded; Trigger result recipients are absent; release-gate atom count rises by 90."
errors: "Assertion failures in Chimeway.Rendering.RenderIdentityIntegrationTest, Chimeway.Adapters.MailglassWebhookPipelineTest, Chimeway.Dispatch.ExecutorMailglassAdapterTest, Chimeway.Integrations.SigraAuthHarnessTest, Chimeway.TriggerPipelineTest (two), and Chimeway.ReleaseGateContractTest."
reproduction: "Run the named post-merge test gate, or the seven targeted test files together."
started: "After Phase 98 Wave 7 post-merge integration."

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-13T00:00:00-04:00
  checked: "Phase 98 plans 08 and 09 summaries"
  found: "Plan 08 intentionally makes rendered payload data private/transient and persists only render identity; Plan 09 intentionally omits duplicate/ambiguous evidence."
  implication: "Assertions against public rendered content or selected ambiguous evidence may be stale, but valid singleton adapter facts must remain available."
- timestamp: 2026-08-13T00:01:00-04:00
  checked: "SafeEvidence and Trigger implementation"
  found: "SafeEvidence.render_channels/1 persists only render_key/render_version singleton identity maps; Trigger public result normalization is the likely projection boundary."
  implication: "Tests must not restore raw rendering or recipient data to satisfy legacy assumptions."
- timestamp: 2026-08-13T00:02:00-04:00
  checked: "Baseline focused test execution"
  found: "The exact command reproduces six named failures: email render identity retained, Sigra integration module absent, adapter detail and provider ID absent, and both public recipient assertions raise KeyError."
  implication: "The public-recipient and adapter-detail expectations conflict with the 98-08/98-03 projection contract; outbound Mailglass correlation is separately broken."
- timestamp: 2026-08-13T00:03:00-04:00
  checked: "Mailglass, SafeEvidence, and locked dependency sources"
  found: "Executor e227692 routes raw Mailglass provider_message_id through opaque_ref/2, which only accepts cw_ references and replaces the whole attempt fact set on rejection. Hex Sigra 1.20.0 has no Sigra.Integrations.Chimeway source; the lifecycle test already guards on that module."
  implication: "Hash/project raw provider IDs before attempt persistence and inbound resolution; guard the harness the same way as lifecycle coverage rather than requiring an unavailable optional integration."
- timestamp: 2026-08-13T00:04:00-04:00
  checked: "Focused release-gate startup"
  found: "The isolated release test could not start because PostgreSQL returned FATAL 53300 too_many_connections after overlapping prior test VM activity."
  implication: "The atom-count assertion will be rerun sequentially after connections recover; global atom-count equality is not a valid per-key oracle in a concurrently initialized VM."
- timestamp: 2026-08-13T00:05:00-04:00
  checked: "PostgreSQL activity after the failed rerun"
  found: "A separate active mix test VM and child migration process hold 55 idle project connections (25 Chimeway plus 10 for each partner repo), exhausting PostgreSQL's 100-connection limit before this test VM can initialize."
  implication: "Focused verification is blocked by concurrent shared-worktree test activity, not a code-test failure; do not terminate another agent's process."
- timestamp: 2026-08-13T00:06:00-04:00
  checked: "No-start pure SafeEvidence and Mailglass resolver probes"
  found: "The same raw postmark message ID projects to cw_provider_message_id_aeb0010d02d4215dd1cad5183be3aec5 in both boundaries; attempt_attrs/1 accepts that reference and stores an empty provider_response."
  implication: "The confirmed Mailglass fix preserves deterministic correlation while keeping raw provider text and adapter detail out of durable attempt evidence."
- timestamp: 2026-08-13T00:07:00-04:00
  checked: "Mailglass pipeline fixture and Traces.explain_delivery/2 tenant query"
  found: "The fixture's helper accepts tenant_id and creates Event, Notification, and Delivery under it. The old test created the first two under default then changed only Delivery to test-tenant; Traces rejects mixed-tenant joins and defaults to the compatibility tenant without an explicit option."
  implication: "Keep Traces fail-closed; correct the fixture to create a coherent tenant graph and invoke the explicit tenant-scoped trace API."
- timestamp: 2026-08-13T00:08:00-04:00
  checked: "Tenant-consistent Mailglass pipeline rerun"
  found: "The trace now resolves, but its webhook detail is %{outcome: :succeeded, signal_event_name: nil}; provider_message_id and adapter_module are omitted. The test had already found the persisted feedback attempt by opaque provider reference and Mailglass adapter module."
  implication: "Trace omission is intentional privacy projection, not a failed feedback correlation; retain the upstream persistence assertion and update only the trace assertion."
- timestamp: 2026-08-13T00:09:00-04:00
  checked: "Mailglass pipeline test after tenant and trace projection updates"
  found: "1 test passed with warnings as errors."
  implication: "The test proves opaque outbound-to-inbound correlation, feedback attempt persistence, signal emission, tenant-scoped trace resolution, and trace privacy projection."
- timestamp: 2026-08-13T00:10:00-04:00
  checked: "Affected non-release regression suite"
  found: "36 tests passed with warnings as errors across render identity, Mailglass adapter/executor, Sigra harness, and Trigger pipeline suites."
  implication: "All six non-release post-merge failures, including the two Trigger assertions, are resolved without relaxing privacy or tenant isolation."

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "Seven independent post-merge contract mismatches: (1) two stale public Trigger recipient assertions, (2) one stale render-channel expectation after the Plan 98-09 email-channel correction, (3) stale raw adapter-detail and webhook-trace assertions, (4) e227692's raw provider ID rejection breaks Mailglass correlation, (5) a mixed-tenant Mailglass fixture that Traces correctly hides, (6) a Hex-vs-local optional Sigra integration assumption, and (7) a global atom-count assertion that races unrelated VM atom creation."
fix: "Project bounded raw provider IDs to deterministic cw_ references at Executor and Mailglass inbound resolution; make the Mailglass fixture tenant-consistent and query its trace explicitly; update tests to assert private Trigger result, identity-only safe evidence, available Sigra integration only, and specific unknown-key atom safety."
verification: "target_test: pass (Mailglass webhook pipeline, 1 test); adjacent_tests: pass (36 affected non-release tests, warnings as errors); release_gate: intentionally not rerun in this fast bundle; mutation_check: skipped (no Stryker configured); no_op_deletion: pass; revert_and_reconfirm: not run (shared branch must not be reverted while other agents work)."
files_changed: ["lib/chimeway/safe_evidence.ex", "lib/chimeway/dispatch/executor.ex", "lib/chimeway/adapters/mailglass.ex", "test/chimeway/rendering/render_identity_integration_test.exs", "test/chimeway/adapters/mailglass_adapter_test.exs", "test/chimeway/adapters/mailglass_webhook_pipeline_test.exs", "test/chimeway/dispatch/executor_mailglass_adapter_test.exs", "test/chimeway/trigger_pipeline_test.exs", "test/chimeway/integrations/sigra_auth_harness_test.exs", "test/chimeway/release_gate_contract_test.exs"]
