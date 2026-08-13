---
status: investigating
trigger: "Phase 98 release proof regressions: Core proof invalid timeline_events; Mailglass and Accrue generated proof assertions fail after SafeEvidence privacy projection changes."
created: 2026-08-13T00:00:00-04:00
updated: 2026-08-13T00:31:00-04:00
---

## Current Focus

hypothesis: "Phase 98 now stores recipient identity through SafeEvidence.recipient_reference/1, but workflow signal matching still compares the raw host actor identity directly against the stored opaque recipient reference."
test: "Normalize the signal actor with the same named recipient-reference projection before the tenant-scoped workflow lookup; add a regression covering an email-shaped host actor and opaque stored recipient reference."
expecting: "The completed chimeway_signals job matches the wait_until run and writes the existing signal_received state and transition."
next_action: "Release proof and focused privacy verification complete."

## Symptoms

expected: "Core, Mailglass, Accrue, and packaged Accrue release proofs emit complete closed evidence including timeline lifecycle facts."
actual: "Core proof raises invalid timeline_events; generated Mailglass and Accrue scripts assert false; packaged Accrue proof fails."
errors: "artifact consumer Core proof emitted invalid timeline_events; prove_mailglass.exs line 21 false; prove_accrue.exs line 78 false"
reproduction: "scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs:<line> --warnings-as-errors"
started: "After Phase 98 privacy-safe SafeEvidence projection changes."

## Eliminated

## Evidence

- timestamp: 2026-08-13T00:00:00-04:00
  checked: "SafeEvidence.proof/1 and artifact consumer fixture source"
  found: "proof/1 delegates whole-map processing to Privacy.redact/1; all release proof builders subsequently Map.fetch! required fields including timeline_events."
  implication: "A projection-key classification mismatch can remove valid categorical proof fields independently of release consumer setup."
- timestamp: 2026-08-13T00:01:00-04:00
  checked: "Core release proof exact reproduction"
  found: "The test completed its isolated artifact-consumer lifecycle and failed only in validate_proof_evidence!/4 at the exact timeline comparison after 39.8 seconds."
  implication: "The environment and package-consumer setup reached the proof parser; the next discriminator is the concrete timeline delta."
- timestamp: 2026-08-13T00:11:00-04:00
  checked: "Temporary Core and generated Mailglass diagnostics"
  found: "Core emitted the established categorical sequence ending in webhook_received; Mailglass generated script line 21 was the channel assertion and failed because explanation.channel was nil."
  implication: "The defects are typed projection/schema omissions, not consumer database setup or raw-value privacy filtering."
- timestamp: 2026-08-13T00:23:00-04:00
  checked: "Generated Accrue consumer after invoice.paid signal and chimeway_signals Oban drain"
  found: "The signal job completed with event_name invoice.paid, tenant and email actor matching the integration contract; its run remained waiting with pending_signals [] and wait_until status_context, while the stored notification recipient reference was opaque."
  implication: "The wait_until fallback predicate was eligible, but raw actor identity could not equal the Phase-98 opaque recipient reference, so no route transition was written."

## Resolution

root_cause: "SafeEvidence.trace/1 applied generic safe_code/1 to the channel field, rejecting the valid channel enum email; the Core proof validator's exact timeline schema omitted the existing safe webhook_received lifecycle event; workflow signal routing compared raw actor identity to the Phase-98 opaque recipient reference."
fix: "Project trace channels through safe_channel/1, include webhook_received in the Core exact proof timeline schema, and normalize signal actors through the same named recipient-reference projection before workflow lookup."
verification: "Core :1015 (1 test, 0 failures); Mailglass :1084 (1 test, 0 failures); released Accrue :1600 (1 test, 0 failures); compatibility Accrue :1625 (1 test, 0 failures); packaged Accrue :1805 (1 test, 0 failures); Phase 98 focused privacy suites (57 tests, 0 failures); format check passed."
files_changed: ["lib/chimeway/safe_evidence.ex", "lib/chimeway/workflows.ex", "priv/adoption_proof/artifact_consumer_fixture.ex", "test/chimeway/release_gate_contract_test.exs", "test/chimeway/workflows_test.exs"]
