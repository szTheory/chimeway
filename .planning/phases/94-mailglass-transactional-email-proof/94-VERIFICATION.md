---
phase: 94-mailglass-transactional-email-proof
verified: 2026-08-09T15:44:09Z
status: gaps_found
score: 8/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "MAIL-01: One consumer-owned repo migrates both Chimeway and Mailglass through normal Ecto migrations and the public Mailglass migration wrapper."
    status: failed
    reason: "The generated consumer configures and starts ArtifactConsumer.Repo for Mailglass but configures Chimeway to use the separate Chimeway.Repo module. Both target the same database configuration, but they are distinct Ecto repos and ownership is not the claimed one-repo architecture."
    artifacts:
      - path: "test/support/artifact_consumer_fixture.ex"
        issue: "config_exs/1 sets config :chimeway, Chimeway.Repo and repo: Chimeway.Repo (lines 305-306), while config :mailglass uses ArtifactConsumer.Repo (line 309); application_ex/0 explicitly starts ArtifactConsumer.Repo while stating Chimeway.Application owns Chimeway.Repo (lines 324-328)."
    missing:
      - "Configure Chimeway's generated consumer migration/runtime path and Mailglass to the same host-owned repo, or correct the phase contract and guidance with an accepted override if two repo modules are intentional."
  - truth: "MAIL-02: The canonical guide accurately states that one host-configured, consumer-owned ArtifactConsumer.Repo owns both Chimeway and Mailglass persistence in this proof."
    status: failed
    reason: "The guide and its doc contract repeat a one-repo claim contradicted by the generated proof configuration."
    artifacts:
      - path: "guides/introduction/mailglass-integration.md"
        issue: "Lines 45 and 169 describe one consumer-owned ArtifactConsumer.Repo for both libraries, but the executable fixture uses separate ArtifactConsumer.Repo and Chimeway.Repo modules."
      - path: "test/chimeway/doc_contract_test.exs"
        issue: "The contract only requires the prose phrase; it does not verify it against the generated consumer configuration."
    missing:
      - "Make the guide and contract match the actual supported topology after resolving the MAIL-01 repository ownership gap."
---

# Phase 94: Mailglass Transactional-Email Proof Verification Report

**Phase Goal:** Prospective adopters can evaluate the existing Mailglass transactional-email path in the clean consumer and see its public delivery evidence and exact boundary.
**Verified:** 2026-08-09T15:44:09Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An adopter can run the clean-consumer Mailglass proof and obtain a deterministic host mailable/render-key outcome. | ✓ VERIFIED | The serialized artifact test calls `prove_mailglass!/2`; the generated notifier uses the stable email render key, config maps it to `ArtifactConsumer.Mailers.MailglassProofEmail`, and the generated proof asserts one Fake delivery. The declared end-to-end test passed. |
| 2 | The proof emits sanitized public explainability evidence for the Mailglass adapter and attempt. | ✓ VERIFIED | The generated script calls `Chimeway.Traces.explain_delivery/1` once, projects a fixed 12-field line, and the integration contract rejects direct repo/content/recipient data in serialized output. |
| 3 | Guidance accurately limits Fake proof to local composition/orchestration and excludes live-provider behavior. | ✓ VERIFIED | The canonical guide states all six exclusions; doc contracts require them and reject specified live-delivery/Hex-consumer overclaims. |
| 4 | MAIL-01: One consumer-owned repo migrates both Chimeway and Mailglass through normal Ecto migrations and the public Mailglass wrapper. | ✗ FAILED | The fixture configures `Chimeway.Repo` for Chimeway and `ArtifactConsumer.Repo` for Mailglass; its own generated application comment confirms the two-repo split. |
| 5 | Lifecycle evidence is public-trace-only, with Fake records retained as private proof assertions. | ✓ VERIFIED | `priv/prove_mailglass.exs` has one `explain_delivery/1` call and one private `Fake.deliveries()` count; the serialized output has no repo query or prohibited sensitive fields. |
| 6 | The sole proof line labels `transport=fake` and contains exactly the safe allowlist. | ✓ VERIFIED | `parse_mailglass_evidence!/1` requires one prefix line, the exact allowlist, and `transport == "fake"`; contract test exercises success and rejection. |
| 7 | Unknown, duplicate, missing, malformed, repeated-prefix, and unsafe fields fail closed without atom creation. | ✓ VERIFIED | Parser uses compile-time string-key maps and `Map.fetch`; contract tests reject every category and prove a randomized key remains unavailable to `String.to_existing_atom/1`. |
| 8 | MAIL-02 guide accurately describes one consumer-owned repo for both libraries. | ✗ FAILED | The guide’s one-repo ownership statement is contradicted by executable consumer configuration. Its documentation test proves the phrase, not the topology. |
| 9 | The guide distinguishes Fake recording from a successful Mailglass adapter attempt and lists live-provider exclusions. | ✓ VERIFIED | `mailglass-integration.md` uses the required distinction and explicit exclusions; `doc_contract_test.exs` locks both. |
| 10 | The guide links the focused blueprint and labels `mix verify.mailglass` as a repository-maintainer suite. | ✓ VERIFIED | The guide has the blueprint link and maintainer-only label; documentation tests assert both. |

**Score:** 8/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `test/support/artifact_consumer_fixture.ex` | Artifact-consumer proof, generated host modules/config/migration/script, strict parser | ⚠️ PARTIAL | Exists (665 lines), substantive and invoked. The proof path and parser are real, but its generated configuration fails the one-host-repo requirement. |
| `test/chimeway/release_gate_contract_test.exs` | Serialized proof plus provenance, evidence, parser, and cleanup contracts | ✓ VERIFIED | Exists (1,524 lines), imports the fixture and invokes `prove_mailglass!/2`; focused run passed. It misses the repo-ownership assertion. |
| `guides/introduction/mailglass-integration.md` | Canonical proof boundary and blueprint/maintainer guidance | ⚠️ PARTIAL | Exists (223 lines) and is contract-wired; Fake/live boundary is correct, but the claimed one-repo topology is not. |
| `test/chimeway/doc_contract_test.exs` | Positive/negative MAIL-02 document contracts | ⚠️ PARTIAL | Exists (1,778 lines), reads the guide and validates phrases. It locks the incorrect ownership sentence rather than verifying it against the artifact fixture. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `release_gate_contract_test.exs` | `artifact_consumer_fixture.ex` | `ArtifactConsumerFixture.prove_mailglass!/2` | ✓ WIRED | Imported at line 4 and called at line 1050. |
| Generated notifier `rendering/2` | Generated host Mailglass mailable | Stable render key and `channel_adapter_configs` map | ✓ WIRED | The notifier emits `artifact_consumer.mailglass_proof.email`; generated config maps that exact key to `{ArtifactConsumer.Mailers.MailglassProofEmail, :mailglass_proof_email}`. |
| Generated proof script | `Chimeway.Traces.explain_delivery/1` | One call then fixed safe projection | ✓ WIRED | `mailglass_proof_ex/0` contains exactly one public-trace call, asserts adapter/attempt state, then serializes the projection. |
| Canonical guide | Blueprint guide | Markdown cross-reference | ✓ WIRED | The guide links `../recipes/mailglass-integration-blueprint.md`; the blueprint links back to the introduction guide. |
| Document contract | Canonical guide | Required and forbidden phrase checks | ✓ WIRED | `@mailglass_integration_guide` resolves the guide and the Mailglass describe block checks positive and negative boundary phrases. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| Generated proof script | `explanation` and serialized `evidence` | `Chimeway.trigger/3` → delivery ID → `Chimeway.Traces.explain_delivery/1` | Yes — end-to-end artifact test runs the generated consumer against PostgreSQL and Fake transport | ✓ FLOWING |
| Mailglass guide | Required boundary phrases | Authored canonical content read by doc-contract test | Yes — contract suite reads the actual guide file | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Artifact Mailglass proof, parser, cleanup, and guide contracts | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | Exit 0; all selected tests passed. The process logged unrelated Threadline sandbox ownership errors but ExUnit did not fail. | ✓ PASS |
| Release/doc gate with project-scoped PostgreSQL container | `mix ci.verify_gates` | Exit 0; `chimeway-test-postgres-1` reported healthy and the suite passed. | ✓ PASS |
| One consumer-owned repo for both systems | Source/config trace | Failed: generated config has separate `Chimeway.Repo` and `ArtifactConsumer.Repo` modules. | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| MAIL-01 | 94-01 | Configured transactional-email orchestration and trace evidence in clean consumer | ✗ BLOCKED | The runnable mail path and public trace are proven, but the required one consumer-owned repo/migration topology is absent. |
| MAIL-02 | 94-01, 94-02 | Truthful Fake-versus-live-provider proof output and guidance | ✗ BLOCKED | Fake label, safe parser, exclusions, and documentation guards work; however the guidance’s asserted clean-consumer ownership model is factually false. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `test/support/artifact_consumer_fixture.ex` | 305-309, 327 | Contradictory two-repo configuration | 🛑 Blocker | Defeats the phase’s explicit one-repo host-ownership truth while tests remain green. |
| `guides/introduction/mailglass-integration.md` | 45, 169 | Documentation claim contradicts executable fixture | 🛑 Blocker | Adopters receive an inaccurate architectural boundary. |
| `test/chimeway/release_gate_contract_test.exs` | 1046-1111 | Test checks output but not generated repo ownership | ⚠️ Warning | A passing proof can mask the topology mismatch. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers were found in Phase 94’s modified source/docs.

### Gaps Summary

The executor delivered a real artifact-only Mailglass proof, strict redaction parser, and truthful Fake/live-provider boundary. But the central clean-consumer ownership claim is false in code: Mailglass uses `ArtifactConsumer.Repo`, while Chimeway is configured and supervised as `Chimeway.Repo`. The phase documentation and phrase-only contract codify the false claim. This is observable absence, not uncertainty, so it is a blocking gap despite both declared test commands passing.

No later roadmap phase explicitly owns correction of Phase 94’s Mailglass repository topology or its canonical guidance; the item is not deferred.

---

_Verified: 2026-08-09T15:44:09Z_
_Verifier: the agent (gsd-verifier)_
