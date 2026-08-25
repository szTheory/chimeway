---
phase: 102-alpha-digital-twin-hermetic-gate
reviewed: 2026-08-25T22:05:20Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - .github/workflows/ci.yml
  - lib/chimeway/adapters/apns.ex
  - lib/chimeway/clock.ex
  - lib/chimeway/delivery_targets.ex
  - lib/chimeway/mobile_proof/extension.ex
  - lib/mix/tasks/verify.alpha_twin.ex
  - lib/mix/tasks/verify.physical_proof_contract.ex
  - mix.exs
  - priv/alpha_twin/scenario-ledger.json
  - scripts/prove-alpha-twin.exs
  - test/chimeway/alpha_twin_provenance_test.exs
  - test/chimeway/alpha_twin_runner_test.exs
  - test/chimeway/mobile_proof_extension_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - test/fixtures/alpha_twin/config/config.exs
  - test/fixtures/alpha_twin/lib/alpha_twin/application.ex
  - test/fixtures/alpha_twin/lib/alpha_twin/clock.ex
  - test/fixtures/alpha_twin/lib/alpha_twin/proof_summary.ex
  - test/fixtures/alpha_twin/lib/alpha_twin/registry.ex
  - test/fixtures/alpha_twin/lib/alpha_twin/runner.ex
  - test/fixtures/alpha_twin/lib/alpha_twin/scripted_apns_transport.ex
  - test/fixtures/alpha_twin/mix.exs
  - test/fixtures/alpha_twin/test/alpha_twin_test.exs
  - test/fixtures/alpha_twin_physical_proof/negative-corpus.json
  - test/fixtures/alpha_twin_physical_proof/valid.json
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 102: Code Review Report

**Reviewed:** 2026-08-25T22:05:20Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

The CI lane is wired into both aggregate gates, but its two proof commands do not validate the claimed Alpha-twin behavior or bind the physical-proof fixture to the package produced in that run. Both failures let the required gate pass after the implementation under test has regressed.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: The Alpha-twin gate never runs the AlphaTwin fixture suite

**File:** `scripts/prove-alpha-twin.exs:16-35`

**Issue:** `mix verify.alpha_twin` builds and validates a package archive, clones CrossWake, copies package migrations into a temporary directory, and emits a hard-coded proof line. It never invokes `test/fixtures/alpha_twin/mix.exs`, `mix test` in that fixture, `AlphaTwin.Runner.run/1`, or any adapter scenario. The fixture suite is also excluded from ordinary root test discovery by `mix.exs:12`. Consequently, changing the fixture runner, registry, clock, APNs transport, or every scenario assertion cannot make `.github/workflows/ci.yml:345` fail; the required gate provides no executable evidence for the advertised twin.

**Fix:** After unpacking the archive and checking out the pinned CrossWake revision, run the fixture project explicitly with the unpacked package path and checked-out CrossWake path, and fail on its test result. For example:

```elixir
System.cmd("mix", ["test"],
  cd: fixture_root,
  env: [
    {"CHIMEWAY_PACKAGE_PATH", package_root},
    {"CROSSWAKE_PATH", crosswake_root}
  ],
  stderr_to_stdout: true
)
|> case do
  {_output, 0} -> :ok
  _ -> raise "alpha twin fixture failed"
end
```

Make the emitted proof derive from the successful fixture result rather than fixed literals, and add a regression test that breaks a fixture assertion and verifies `mix verify.alpha_twin` exits non-zero.

### CR-02: Physical-proof validation accepts a placeholder digest instead of the built artifact

**File:** `lib/mix/tasks/verify.physical_proof_contract.ex:10-17`

**Issue:** The task validates only the repository fixture. Although `Extension.validate/2` has an `:artifact_sha256` comparison hook, this caller never supplies it. The accepted fixture carries the constant all-`a` digest at `test/fixtures/alpha_twin_physical_proof/valid.json:5`, so `mix verify.physical_proof_contract` succeeds without building or hashing any Chimeway package. A proof remains accepted even when it is unrelated to the artifact that CI compiled, defeating the artifact-provenance claim.

**Fix:** Build/hash the same package artifact in this task (or have `verify.alpha_twin` write a verified digest to a private temporary handoff), then pass that digest into every positive validation:

```elixir
with {:ok, artifact_sha256} <- build_and_hash_package(),
     {:ok, _} <- Extension.validate(valid,
       artifact_sha256: artifact_sha256,
       canonical_validator: validator
     ) do
  # verify negative corpus
end
```

Generate the positive proof fixture from that run or treat it solely as a schema test; do not use a static placeholder as the CI proof of a real artifact.

---

_Reviewed: 2026-08-25T22:05:20Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
