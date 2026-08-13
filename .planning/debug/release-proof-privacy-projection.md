---
status: investigating
trigger: "Phase 98 release proof regressions: Core proof invalid timeline_events; Mailglass and Accrue generated proof assertions fail after SafeEvidence privacy projection changes."
created: 2026-08-13T00:00:00-04:00
updated: 2026-08-13T00:11:00-04:00
---

## Current Focus

hypothesis: "Trace channel projection used the generic code grammar, which deliberately rejects `email`; release-proof timelines also omitted the established safe `webhook_received` event from Core's exact schema."
test: "Use the named channel validator in trace projection and include the already public categorical webhook event in Core's exact proof schema."
expecting: "Core and Mailglass release consumers will retain their complete safe categorical evidence without a generic binary fallback."
next_action: "Format and rerun exact Core and Mailglass release proof cases."

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

## Resolution

root_cause: "SafeEvidence.trace/1 applied generic safe_code/1 to the channel field, rejecting the valid channel enum email; the Core proof validator's exact timeline schema omitted the existing safe webhook_received lifecycle event."
fix: "Project trace channels through safe_channel/1 and include webhook_received in the Core exact proof timeline schema."
verification:
files_changed: []
