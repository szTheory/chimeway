---
phase: 103
slug: physical-iphone-adoption-truth
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-26
---

# Phase 103 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix verify.physical_proof_contract` |
| **Full suite command** | `mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract` |
| **Estimated runtime** | Measure during Wave 0 and keep below the CI job timeout |

---

## Sampling Rate

- **After every task commit:** Run the task's focused ExUnit or contract command.
- **After every plan wave:** Run `mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract`.
- **Before phase verification:** The full suite must be green; do not route machine-testable evidence through conversational UAT.
- **Max feedback latency:** One focused contract command per task; split slower external compatibility checks into their own explicit task.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 103-01-01 | 01 | 1 | TWIN-03 | T-103-01..03 | Complete CrossWake module, fixture, and focused tests precede one canonical commit; only after local green, authorized publication, remote reachability, and fresh-detached green is its SHA recorded | auto/integration | `bash -lc 'authority=priv/mobile_proof/crosswake-selected-sha && test -f "$authority" && sha=$(tr -d "\r\n" < "$authority") && [[ "$sha" =~ ^[0-9a-f]{40}$ ]] && test "$(git ls-remote https://github.com/szTheory/crosswake.git refs/heads/phase-103-chimeway-notification-proof | cut -f1)" = "$sha" && tmp=$(mktemp -d) && trap "rm -rf -- $tmp" EXIT && git clone --quiet --no-checkout https://github.com/szTheory/crosswake.git "$tmp" && git -C "$tmp" fetch --quiet origin refs/heads/phase-103-chimeway-notification-proof && git -C "$tmp" checkout --quiet --detach "$sha" && test "$(git -C "$tmp" rev-parse HEAD)" = "$sha" && test -z "$(git -C "$tmp" status --porcelain)" && module="$tmp/lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex" && fixture="$tmp/test/fixtures/proof_lane/chimeway-notification-physical-proof.json" && focused="$tmp/test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs" && test -f "$module" && test -f "$fixture" && test -f "$focused" && rg -q "^defmodule Crosswake\.ProofLane\.ChimewayNotificationPhysicalProof" "$module" && rg -q "Evidence\.check" "$module" && rg -q "def schema_version\(" "$module" && rg -q "def assertions\(" "$module" && rg -q "def validate_report\(" "$module" && rg -q "def validate_source_bound\(" "$module" && rg -q "validate_source_bound" "$focused" && cd "$tmp" && mix test test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs --max-failures 1'` | ✅ planned in task | ⬜ pending |
| 103-02-01 | 02 | 2 | TWIN-03 | T-103-04..07 | One immutable artifact reaches one no-replace bundle through the final authority-file CrossWake revision, with every consumer rerunning fresh-detached source and focused-test proof | auto/integration | `mix test test/chimeway/mobile_physical_proof_test.exs --max-failures 1 --warnings-as-errors && mix verify.physical_proof_contract` | ✅ planned in task | ⬜ pending |
| 103-02-02 | 02 | 2 | TWIN-03 | T-103-04..07 | Exact key/order/owner/revision/digest/privacy/attestation/no-replace failures reject without echo and hermetic Extension v1 remains immutable | unit/contract | `mix test test/chimeway/mobile_proof_extension_test.exs test/chimeway/mobile_physical_proof_test.exs --max-failures 1 --warnings-as-errors && mix verify.physical_proof_contract && git diff --exit-code -- lib/chimeway/mobile_proof/extension.ex test/fixtures/alpha_twin_physical_proof/valid.json test/fixtures/alpha_twin_physical_proof/negative-corpus.json` | ✅ planned in task | ⬜ pending |
| 103-03-01 | 03 | 3 | TWIN-03, DOCS-01 | T-103-08..10 | Two-threshold runner stays fail-closed and Threshold A remains credential-free with exact selected-SHA local/CI parity | integration/contract | `mix test test/chimeway/mobile_physical_proof_runner_test.exs test/chimeway/release_gate_contract_test.exs --max-failures 1 --warnings-as-errors && mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract` | ✅ planned in task | ⬜ pending |
| 103-03-02 | 03 | 3 | DOCS-01 | T-103-11..13 | Canonical guide roles, commands, vocabulary, links, pending wording, and non-goals do not drift | doc contract | `mix test test/chimeway/doc_contract_test.exs --max-failures 1 --warnings-as-errors && mix ci.verify_gates` | ✅ planned in task | ⬜ pending |
| 103-04-01 | 04 | 4 | TWIN-03 | T-103-14..20 | Signed-device run promotes only fresh-source-bound machine proof plus separately supplied observed attestation | physical/integration | `mix chimeway.mobile_physical_proof --verify-promoted --json && mix verify.physical_proof_contract && mix verify.alpha_twin` | ✅ runner created in 103-03-01 | ⬜ pending |
| 103-04-02 | 04 | 4 | TWIN-03, DOCS-01 | T-103-19..20 | Public/planning truth changes only from the validated completion-bound promoted snapshot | doc/release contract | `mix chimeway.mobile_physical_proof --verify-promoted --json && mix ci.verify_gates && mix verify.alpha_twin && mix verify.physical_proof_contract` | ✅ contracts created in 103-03 | ⬜ pending |

*Task and plan IDs are final and match 103-01 through 103-04. CrossWake authority completion/publication is isolated from all Chimeway consumers, and no implementation task lacks a same-task executable test contract.*

---

## Wave 0 Requirements

- [x] 103-01-01 creates and fully tests the CrossWake source authority before publishing and recording the sole selected SHA.
- [x] 103-02-01/02 create and exercise the Chimeway physical bundle, fixtures, selected-SHA source-bound validation, attestation boundary, and hermetic regression without changing selected CrossWake files.
- [x] 103-03-01 creates the runner/release contracts before Threshold-A gate wiring completes.
- [x] 103-03-02 creates the canonical-guide doc contract in the same task as the guide/navigation changes.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| A visible notification alert appeared on the physical iPhone | TWIN-03 | The display observation is subjective and has no trustworthy machine-readable signal | On the dated sandbox run, the named observer records only the bounded `observed` attestation after seeing the alert; every provider, digest, protected-open, and no-replace assertion remains executable evidence. |

CrossWake repository-owner approval/push authority is an external publication prerequisite for Plan 103-01, never evidence of reachability or correctness; the exact remote SHA and focused test remain machine-verified. Apple signing credentials, a registered physical device, and sandbox APNs availability are external prerequisites, not conversational acceptance gates. Threshold A must remain executable and credential-free while Threshold B stays explicitly pending until those prerequisites are available.

---

## Validation Sign-Off

- [x] All tasks have executable `<automated>` verification or explicit prior-plan test dependencies.
- [x] Sampling continuity: every task has an automated verification command.
- [x] Wave 0 covers every missing test or command above.
- [x] No watch-mode flags are used.
- [x] Machine-testable tracer-role and acceptance work is `auto`; only the bounded visible-alert state is subjective.
- [x] `nyquist_compliant: true` is set and this map matches the final plans.

**Approval:** planned — execution evidence pending
