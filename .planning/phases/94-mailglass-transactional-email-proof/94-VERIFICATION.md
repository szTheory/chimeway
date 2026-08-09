---
phase: 94-mailglass-transactional-email-proof
verified: 2026-08-09T16:22:59Z
status: gaps_found
score: 7/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/10
  gaps_closed:
    - "MAIL-01: One consumer-owned repo migrates both Chimeway and Mailglass through normal Ecto migrations and the public Mailglass migration wrapper."
    - "MAIL-02: The canonical guide accurately states that one host-configured, consumer-owned ArtifactConsumer.Repo owns both Chimeway and Mailglass persistence in this proof."
  gaps_remaining: []
  regressions: []
gaps:
  - truth: "The Mailglass proof output is a trustworthy sanitized, trace-derived evidence boundary that fails closed for unsafe fields."
    status: failed
    reason: "parse_mailglass_evidence!/1 validates only field names, completeness, duplicates, non-empty values, and transport=fake. It accepts forged or sensitive values beneath allowlisted field names, so an untrusted subprocess line can spoof lifecycle facts or disclose data as delivery_id."
    artifacts:
      - path: "test/support/artifact_consumer_fixture.ex"
        issue: "Lines 524-567 do not validate delivery_id, status, adapter_module, versions, attempt number, or timeline values after parsing."
      - path: "test/chimeway/release_gate_contract_test.exs"
        issue: "Lines 1224-1300 test unknown keys and transport only; no test mutates an allowlisted value to a sensitive or invalid value."
    missing:
      - "Validate the complete Mailglass evidence schema, including fixed expected lifecycle values, numeric fields, UUID-shaped delivery IDs, and an allowed ordered timeline."
      - "Add negative contracts for sensitive and forged values under every relevant allowlisted key."
---

# Phase 94: Mailglass Transactional-Email Proof Verification Report

**Phase Goal:** Prospective adopters can evaluate the existing Mailglass transactional-email path in the clean consumer and see its public delivery evidence and exact boundary.
**Verified:** 2026-08-09T16:22:59Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can run the clean-consumer Mailglass proof and obtain deterministic host-mailable/render-key orchestration. | ✓ VERIFIED | `prove_mailglass!/2` scaffolds and runs an unpacked consumer; the focused release contract passed and asserts the stable render key, host mailable map, Fake record, and succeeded adapter attempt. |
| 2 | The proof emits sanitized public explainability evidence for the Mailglass adapter and delivery attempt. | ✗ FAILED | Direct probe accepted `delivery_id=recipient@example.test status=failed adapter_module=provider-secret` under allowed keys. The parser cannot establish that returned evidence is sanitized or truthful. |
| 3 | Guidance limits Fake proof to local composition/orchestration and excludes live-provider behavior. | ✓ VERIFIED | The guide states the bounded Fake/attempt claim and provider exclusions; the focused documentation contracts and `mix ci.verify_gates` passed. |
| 4 | MAIL-01: One consumer-owned repo migrates both Chimeway and Mailglass through normal Ecto migrations and the public Mailglass wrapper. | ✓ VERIFIED | Generated config sets both `:chimeway` and `:mailglass` to `ArtifactConsumer.Repo`; the generated proof asserts the active dynamic repo, live process, and absence of `Chimeway.Repo`; the migration delegates to `Mailglass.Migration`. |
| 5 | Lifecycle evidence is public-trace-only, with Fake records retained as private proof assertions. | ✓ VERIFIED | Generated `prove_mailglass.exs` calls `Chimeway.Traces.explain_delivery/1` once, asserts `Fake.deliveries()` privately, and serializes only its projection. |
| 6 | The sole proof line labels `transport=fake` and contains an exact safe allowlist. | ✗ FAILED | The key set and fake label are enforced, but values in allowlisted fields are unconstrained; a sensitive recipient can be accepted as `delivery_id`, so the purported safe allowlist is not safe. |
| 7 | Unknown, duplicate, missing, malformed, repeated-prefix, and unsafe proof fields fail closed without atom creation. | ✗ FAILED | Unknown-key and atom-safety checks pass, but unsafe values under known keys are accepted. This is observable failure of the unsafe-field portion of the truth. |
| 8 | MAIL-02 guide accurately describes one consumer-owned repo for both libraries. | ✓ VERIFIED | Guide lines 49-73 specify `ArtifactConsumer.Repo` for Ecto, Chimeway, and Mailglass; doc contract compares that text with `mailglass_repo_topology/0`. |
| 9 | The guide distinguishes Fake recording from a successful Mailglass adapter attempt and lists live-provider exclusions. | ✓ VERIFIED | Guide lines 193-203 and doc contracts preserve the distinction and all required exclusions. |
| 10 | The guide links the focused blueprint and labels `mix verify.mailglass` as a repository-maintainer suite. | ✓ VERIFIED | Guide lines 199 and 203 provide both; documentation contracts passed. |

**Score:** 7/10 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/support/artifact_consumer_fixture.ex` | Generated consumer, topology assertion, strict evidence parser | ✗ PARTIAL | Exists (665 lines), substantive, and invoked by contracts. Topology is correct; Mailglass parser does not validate allowed-key values. |
| `test/chimeway/release_gate_contract_test.exs` | Runtime Mailglass/topology/evidence contracts | ⚠️ PARTIAL | Executes the generated consumer and confirms the good path, but omits forged-value contracts at the untrusted output boundary. |
| `guides/introduction/mailglass-integration.md` | Canonical topology and Fake/live boundary | ✓ VERIFIED | Exists, substantive, and read by documentation contracts; topology and boundary text match the executable fixture. |
| `test/chimeway/doc_contract_test.exs` | Fixture-coupled topology and guidance contracts | ✓ VERIFIED | Imports `ArtifactConsumerFixture.mailglass_repo_topology/0` and checks the canonical guide’s concrete configuration. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `release_gate_contract_test.exs` | `artifact_consumer_fixture.ex` | `ArtifactConsumerFixture.prove_mailglass!/2` | ✓ WIRED | Alias is loaded and `prove_mailglass!/1` is called at line 1050. |
| Generated notifier `rendering/2` | Generated host mailable | Stable render key and `channel_adapter_configs` map | ✓ WIRED | Exact `artifact_consumer.mailglass_proof.email` value appears in generated rendering and map. |
| Generated proof script | `Chimeway.Traces.explain_delivery/1` | One trace call then fixed projection | ✓ WIRED | `mailglass_proof_ex/0` invokes it once at line 451 before serializing the proof line. |
| `doc_contract_test.exs` | Fixture topology | `ArtifactConsumerFixture.mailglass_repo_topology/0` | ✓ WIRED | The contract calls the shared helper at line 646 and compares its fields with guide config text. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated proof script | `explanation` → `evidence` | `Chimeway.trigger/3` → delivery ID → `Chimeway.Traces.explain_delivery/1` | Yes — focused end-to-end artifact consumer contract passed against PostgreSQL and Fake transport. | ✓ FLOWING |
| Public evidence parser | Parsed `evidence` map | Untrusted subprocess stdout | No safe validation — arbitrary allowed-key values flow through unchanged. | ✗ HOLLOW / UNSAFE |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Mailglass proof, topology, parser, and guide contracts | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | Exit 0; tests passed. Pre-existing Threadline sandbox-ownership logs appeared during teardown. | ✓ PASS |
| Release/doc gate | `mix ci.verify_gates` | Exit 0; project PostgreSQL container became healthy and suite passed. | ✓ PASS |
| Allowed-key value validation | `MIX_ENV=test mix run --no-start -e '...parse_mailglass_evidence!(forged_line)...'` | Exit 0, printed `accepted_delivery_id=recipient@example.test status=failed adapter=provider-secret`. | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| MAIL-01 | 94-01, 94-03 | Configured transactional-email orchestration and trace evidence in the clean consumer | ✓ SATISFIED | Executed artifact proof and runtime topology assertions establish one active host-owned repo, migrations, render-key/mailable routing, Fake result, and trace. |
| MAIL-02 | 94-01, 94-02, 94-03 | Fake behavior and proof output accurately distinguish local test behavior from live-provider delivery and feedback | ✗ BLOCKED | Guide wording is accurate, but its required sanitized proof output boundary is false for forged values under approved keys. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/support/artifact_consumer_fixture.ex` | 524-567 | Allowlist checks only keys, not values | 🛑 Blocker | Allows evidence spoofing and sensitive-value disclosure at the public proof boundary. |
| `test/chimeway/release_gate_contract_test.exs` | 1224-1300 | Happy-path/parser-key tests omit allowed-value adversarial cases | ⚠️ Warning | Passing contracts do not detect the blocker. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 94’s modified files. The apparent `placeholder` matches in `doc_contract_test.exs` are assertions against unrelated documentation, not implementation debt.

### Gaps Summary

The original two-repo topology gaps are closed: the generated host configures, migrates, supervises, and dynamically routes Chimeway and Mailglass through one `ArtifactConsumer.Repo`, while the guide is mechanically coupled to that topology.

However, the phase goal also requires an explainable, sanitized evidence boundary. The parser treats stdout as untrusted but only validates field names. It accepts a recipient address as `delivery_id` and forged lifecycle/adapter values under approved keys. This is a blocker, not uncertainty: the failing input was executed directly. No later roadmap phase specifically owns repairing the Mailglass proof parser, so it is not deferred.

---

_Verified: 2026-08-09T16:22:59Z_
_Verifier: the agent (gsd-verifier)_
