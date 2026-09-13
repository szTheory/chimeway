---
status: resolved
trigger: "release_gate_contract_test VM-exit deadlock"
created: "2026-08-13T01:05:00Z"
updated: "2026-08-13T02:18:00Z"
---

## Current Focus

hypothesis: The reported release-contract VM-exit deadlock is disproven for the bounded paths: neither a simple release-contract selection nor the artifact-consumer proof remained alive or emitted `:elixir_config`/`:noproc` after summary.
test: Record the bounded comparison and distinguish the independent artifact `ecto.migrate` failure from the unconfirmed full-run CLI exception.
expecting: No lifecycle source change is warranted without a targeted reproduction of the runtime exception.
next_action: Close this shutdown-focused investigation as no confirmed application lifecycle defect; hand the separately reproducible artifact migration failure to the release-gate failure investigation.
bug_class: bohrbug
reasoning_checkpoint: null
tdd_checkpoint: null

## Symptoms

expected: `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` completes its tests and exits zero.
actual: The suite emits test progress/output but the BEAM VM remains alive for more than five minutes, retaining PostgreSQL connections and blocking subsequent Phase 98 gates.
errors: Subsequent test invocations fail during partner TestRepo bootstrap with PostgreSQL `FATAL 53300 (too_many_connections)`; terminating the hung VM is not accepted as green evidence.
reproduction: Run the release gate contract test directly. The hang reproduces even with `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1`; privacy-only tests exit normally under that isolation.
started: First observed during Phase 98 Plan 06 verification on 2026-08-12/13; whether the underlying lifecycle bug predates Phase 98 is unknown.

## Eliminated

- hypothesis: Partner TestRepo provisioning alone causes the VM-exit hang.
  evidence: The release contract suite still hangs with `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1`, while privacy-only tests exit normally.
  timestamp: "2026-08-13T01:05:00Z"

- hypothesis: An explicit root-project VM-stop or signal-trapping call terminates Elixir configuration before the parent release-contract ExUnit VM exits.
  evidence: No `init.stop`, `Application.stop(:elixir)`, `:erlang.halt`, `System.trap_signal`, or `:trap_exit` call exists in the searched project paths. The only relevant `System.halt` runs in an Accrue script launched via `System.cmd` in a child BEAM process; unrelated Sigra/demo scripts are not on the release-contract parent path.
  timestamp: "2026-08-13T01:49:00Z"

## Evidence

- timestamp: "2026-08-13T01:05:00Z"
  checked: Repeated clean reruns and process/PostgreSQL inspection during Phase 98 execution.
  found: The suite remains alive after test output with no child command present; BEAM sampling shows scheduler/poll waits and idle PostgreSQL pools remain open.
  implication: The blocker is a VM/application shutdown lifecycle defect, not an active nested `System.cmd` or a failing privacy assertion.

- timestamp: "2026-08-13T01:13:00Z"
  checked: test/test_helper.exs and release_gate_contract_test.exs lifecycle/external-command call sites.
  found: With CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1, test_helper still starts the primary Chimeway OTP application and its SQL sandbox; the release-gate test itself launches several nested Mix/Elixir commands, including package-build and adoption proof paths.
  implication: Candidate branches are test-helper application lifetime (code/config) and a specific release-contract nested command (code/environment); direct subset testing can distinguish them.

- timestamp: "2026-08-13T01:22:00Z"
  checked: concurrent bounded diagnostic runs and their OS process trees.
  found: Both still-running parent test VMs had active descendant BEAM processes executing `mix chimeway.gen.migrations` inside unique artifact-consumer temporary roots; a fast, isolated `:adoption_archive_security` subset printed `Finished` and exited normally.
  implication: The prior lifecycle-only hypothesis is not supported. The failure is deterministic in the artifact-consumer/package-proof path, but overlapping diagnostics introduced compile contention and cannot establish a final cause.

- timestamp: "2026-08-13T01:27:00Z"
  checked: a clean, single-process invocation of the Core artifact-consumer test at release_gate_contract_test.exs:1015, sampled while running and after its nested command completed.
  found: Before the test emitted its dot, the parent ExUnit VM had a live descendant running `mix chimeway.gen.migrations` in its unique temporary artifact-consumer project. After that nested work completed, the timeout wrapper, root BEAM, and child setup process all exited; no idle parent VM remained.
  implication: The exact artifact path demonstrably terminates normally. A full release-gate test contains several similarly expensive proof paths, so elapsed wall-clock time alone is not evidence of a VM-exit defect.

- timestamp: "2026-08-13T01:39:00Z"
  checked: one clean, non-overlapping full release-contract invocation with CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1, tracked for 366.9 seconds and process-sampled throughout.
  found: The run had live nested `mix hex.build`, `mix chimeway.gen.migrations`, and packaged `mix run --no-start scripts/prove-accrue-consumer.exs` BEAM descendants during every long interval, then printed `Finished in 366.9 seconds` with `108 tests, 5 failures`. The terminal log immediately contained an Elixir CLI exception: `:gen_server.call(:elixir_config, ..., :infinity)` exited with `:noproc`.
  implication: The reported five-minute state is active test execution, not a VM-exit deadlock. A distinct post-summary shutdown/config-server failure may exist, but the root project also has five test failures that must be addressed separately before a green release gate can be claimed.

- timestamp: "2026-08-13T01:49:00Z"
  checked: Bounded root-project search of `test/`, `test/support/`, `scripts/`, `lib/`, `config/`, and `mix.exs` for `System.halt`, `:init.stop`, `Application.stop(:elixir)`, `:erlang.halt`, `System.trap_signal`, and `Process.flag(:trap_exit, ...)`, followed by context inspection of every exact match.
  found: There are no `init.stop`, `Application.stop(:elixir)`, `:erlang.halt`, `System.trap_signal`, or `:trap_exit` calls. `System.halt` appears only in an unrelated standalone Sigra proof runner, a demo seed script, and `scripts/prove-accrue-consumer.exs`. The release-contract test invokes the Accrue script only through `System.cmd("mix", ["run", "--no-start", "scripts/prove-accrue-consumer.exs", ...], cd: root)`, so its halt terminates that child BEAM process, not the parent ExUnit VM; the Sigra runner is only asserted as a CI-script marker, not required by this test.
  implication: The explicit root-project VM-stop/signal-trap hypothesis is eliminated for the post-summary parent `:elixir_config` crash. The full release test should not be reclassified as a deadlock; remaining investigation must target the Elixir runtime shutdown path or external signal/environment behavior, independently from the five ordinary test failures.

- timestamp: "2026-08-13T02:07:00Z"
  checked: Sequential timeout-bounded targeted release-contract runs with `CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test`: the simple doc-contract selection at line 53 and the unpacked Core artifact-consumer proof at line 1015, including shell exit-code and post-command process inspection.
  found: The simple selection completed `37 tests, 0 failures` in 0.5s with exit code 0 and no `:elixir_config`/`:noproc` trace. The artifact proof completed (rather than remaining alive) in 26.3s with exit code 2 because its child `ecto.migrate` hit `Postgrex.Error 42P01`: migration `PrivacySafeDeliveryEvidence` executes unqualified `UPDATE "chimeway_events"`, while the consumer schema created the table as `chimeway.chimeway_events`; there was no `:elixir_config`/`:noproc` terminal trace and no remaining BEAM child after completion.
  implication: The reported full-suite state is not a deadlock in the bounded artifact path, and the post-summary exception is not reproduced by either control. The new directly reproducible release-gate defect is the schema-prefix migration failure; it is independent of the unconfirmed full-run CLI exception.

- timestamp: "2026-08-13T02:13:00Z"
  checked: Canonical installer template and artifact fixture configuration against the child migration trace.
  found: The source template `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` is designed to render schema-qualified relations when `@chimeway_prefix` is `"chimeway"`, and the fixture config sets `config :chimeway, prefix: "chimeway"`; nevertheless, the child migration trace showed an unqualified relation. The bounded run establishes the artifact migration failure but does not establish why the generated child migration used the public/unprefixed relation.
  implication: Do not claim a source-level prefix implementation root cause or apply a speculative migration fix in this shutdown-focused session. The only supported conclusion here is that the VM-exit symptom is not reproduced and was not a deadlock in the bounded paths.

## Resolution

root_cause: No confirmed root-project lifecycle defect for the reported post-summary `:elixir_config` `:noproc` exception. The bounded controls terminated normally and did not reproduce it; the original five-minute observation was active nested release-proof work, not a VM-exit deadlock.
fix: No lifecycle fix applied; changing shutdown behavior would be speculative. A separate release-gate defect remains reproducible in the artifact consumer's `ecto.migrate`, but its prefix-rendering cause is not yet established.
verification: Bounded simple release-contract selection exited 0 after 37 passing tests; bounded Core artifact proof exited 2 after an ordinary child migration failure and left no BEAM child, with no `:elixir_config`/`:noproc` trace. This disproves the reported shutdown symptom only for these targeted paths, not every full-suite topology.
oracle_type: derived
files_changed: []
