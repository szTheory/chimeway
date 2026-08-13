---
status: resolved
trigger: "migration 034 artifact-consumer prefix rendering"
created: "2026-08-12"
updated: "2026-08-12"
---

# Debug Session: Migration 034 Artifact Consumer Prefix Rendering

## Symptoms

- expected_behavior: Migration 034 copied into generated/artifact-consumer hosts renders the configured static Chimeway storage prefix as `"chimeway"`, and renders `false` for legacy public mode, with no unresolved installer sentinel.
- actual_behavior: The migration 034 artifact-consumer/generated-copy path does not correctly render the prefix contract; repository inspection shows the canonical migration contains `__CHIMEWAY_PREFIX__` while the planned repository and golden copies/contracts are not yet present.
- errors: No user-supplied error text. Reproduce from focused migration installer/artifact-consumer contract tests and inspect the first failing assertion or compile error.
- timeline: Observed while implementing Phase 98 Plan 06; migration 034 is newly added and has not previously had a green copied-host prefix contract.
- reproduction: Run the focused migration/installer tests for migration 034, then exercise the artifact-consumer/generated host in both prefixed and public modes. Prefer the narrowest existing tests before broader gates.

## Current Focus

- bug_class: bohrbug (the copied migration output is deterministic for each configured mode)
- fault_tree: "OR: canonical template absent from installer manifest; renderer does not substitute `__CHIMEWAY_PREFIX__`; artifact fixture/golden contract omits migration 034; generated host configuration passes the wrong prefix or legacy flag. AND-gate candidate: template plus consumer contract may both be incomplete."
- hypothesis: The original defect was incomplete migration-034 installer parity: the canonical migration was introduced before all generated-copy/golden count contracts were updated. The completed commits now supply the canonical migration, both rendered goldens, and 34-file contract counts.
- test: Historical commit inspection plus focused current tests and direct golden-copy inspection.
- expecting: The current tree will preserve correct static prefixed/public literals and execute all 34 copied migrations in both generated modes.
- next_action: resolved by executable generated-host verification in both modes; archive the session with the migration-034 regression contract.
- reasoning_checkpoint:
  hypothesis: "Migration 034 was initially incomplete across installer parity artifacts; the canonical sentinel template alone could not establish the artifact-consumer contract until both rendered golden copies and all 34-file count/slug contracts were included."
  confirming_evidence:
    - "Git history shows `06df791` added failing migration-034 coverage, `54e02dd` added the canonical template and prefixed/public golden copies, and `d585ac5` corrected remaining installer parity counts."
    - "The current focused installer/prefix/generated-migration tests exit 0 and create migration 034 as the 34th generated file."
    - "Direct inspection shows the prefixed golden contains `@chimeway_prefix \"chimeway\"`, the public golden contains `@chimeway_prefix false`, and neither contains `__CHIMEWAY_PREFIX__`."
  falsification_test: "A present-tree focused test failure or golden copy containing the sentinel/wrong literal would disprove that the parity fix fully resolves this contract."
  fix_rationale: "Adding migration 034 to the canonical template set, generated prefixed/public goldens, and every 34-file parity contract makes the renderer output and artifact-consumer fixtures agree on the static prefix semantics."
  blind_spots: "A full packaged artifact-consumer run was not executed in this debugging continuation; focused generated-mode Ecto migration proof passed."
  candidate_causes:
    - "code: canonical migration template needed sentinel-aware relation helpers"
    - "config: installer fixture cardinality/manifest contracts still expected 33 migrations"
    - "data: copied golden fixture sets did not initially include migration 034"
  and_gate: "no — any missing parity artifact individually causes the observed contract gap; the final remedy covers the independently necessary template and fixture/contract synchronization."
- tdd_checkpoint:

## Evidence

- timestamp: "2026-08-12"
  checked: "New generated-host migration-034 exact-prefix assertion"
  found: "The first run failed only because the assertion anchored `@chimeway_prefix` at column zero, while the generated migration intentionally indents the module attribute by two spaces. Direct inspection confirms one correctly rendered static literal in each golden mode."
  implication: "The failure is in the newly written test's whitespace matcher, not the artifact-consumer prefix renderer."

- timestamp: "2026-08-12"
  checked: "Real generated-host migration generation in default-prefixed and explicit-public modes"
  found: "`env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors` passed. Each mode scaffolds a fresh host, obtains dependencies from the current tree, executes `mix chimeway.gen.migrations`, and now asserts migration 034 has exactly one expected static prefix line and no `__CHIMEWAY_PREFIX__` sentinel."
  implication: "The implementation SHA generates the required migration 034 prefix contract in both consumer modes without relying on human verification."

- timestamp: "2026-08-12"
  checked: "Repository installer/migration regression gate"
  found: "`env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix verify.install_golden` passed, covering generated-host golden parity, installer idempotency, prefix contract checks, and public/prefixed Ecto migration execution. Threadline sandbox cleanup emitted ownership errors after test processes completed, but the command exited successfully."
  implication: "The focused recurrence guard and adjacent installer/migration contracts are green."

- timestamp: "2026-08-12"
  checked: "Persistent debug session and repository migration inventory"
  found: "Canonical `priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs` exists. `Chimeway.Install.Migrations.render_template/3` replaces `__CHIMEWAY_PREFIX__` with `\"chimeway\"` for `:chimeway` and `false` for `:public`; `migrations_test.exs` declares 34 templates; both prefixed and public golden trees include the 034 file."
  implication: "The recorded absence is not true of the present worktree; only an execution-level failure or an insufficient consumer contract remains plausible."

- timestamp: "2026-08-12"
  checked: "Focused installer, prefix-contract, and generated migration test set"
  found: "`mix test test/chimeway/install/migrations_test.exs test/chimeway/install/prefix_contract_test.exs test/chimeway/migration_contract_test.exs` exited 0. It generated migration 034 as the 34th file in the temporary host. Background Threadline sandbox ownership logs appeared but did not fail the command."
  implication: "The deterministic omission/unrendered-sentinel hypotheses are not reproduced by focused test execution; inspect exact goldens to verify the reported artifact contract rather than making a code change."

- timestamp: "2026-08-12"
  checked: "Direct prefixed/public migration-034 golden contents, prefix contract source, and relevant git history"
  found: "The prefixed golden's module is `InstallerHost.Repo.Migrations.PrivacySafeDeliveryEvidence` with `@chimeway_prefix \"chimeway\"`; its public counterpart has the same host namespace with `@chimeway_prefix false`; neither retains `__CHIMEWAY_PREFIX__`. `prefix_contract_test.exs` checks every one of 34 prefixed golden files for the static prefix. Commit `54e02dd` introduced the canonical/golden migration artifacts and `d585ac5` corrected the remaining 33→34 parity assertion."
  implication: "The root cause was repository parity incompleteness during the rollout, not a current renderer defect. The current implementation has the required fix already applied."

- timestamp: "2026-08-12"
  checked: "SBFL eligibility"
  found: "SBFL skipped: the focused suite has no failing test and no per-test coverage spectrum."
  implication: "No Ochiai ranking can be computed; direct deterministic reproduction was used instead."

## Eliminated

- hypothesis: "Migration 034 is omitted from the installer manifest or generated copy."
  evidence: "The focused tests pass and runtime output lists `created ..._privacy_safe_delivery_evidence.exs` as the 34th generated file."
  timestamp: "2026-08-12"

- hypothesis: "The current renderer leaves `__CHIMEWAY_PREFIX__` unresolved or renders the incorrect literal in checked-in artifact copies."
  evidence: "Both exact golden copies contain the expected static literals and the focused tests exit 0."
  timestamp: "2026-08-12"


## Resolution

- root_cause: "Incomplete migration-034 installer parity during rollout: the canonical sentinel template was not yet synchronized with generated prefixed/public golden copies and all 34-file installer contracts."
- fix: "Already applied before this continuation in commits `54e02dd` (canonical migration plus rendered goldens) and `d585ac5` (33→34 installer parity counts). No new source change was required."
- verification: "target_test: pass (`env MIX_ENV=test mix test test/chimeway/install/golden_diff_test.exs --warnings-as-errors`) in real generated hosts for default-prefixed and explicit-public modes; per-mode migration-034 assertion: pass (exactly one `@chimeway_prefix \"chimeway\"` or `@chimeway_prefix false`, respectively, and no `__CHIMEWAY_PREFIX__`); mutation_check: skipped (the semantic fix predates this continuation; this continuation adds a regression assertion only); no_op_deletion: pass (additive assertion-only diff); adjacent_tests: pass (`env CHIMEWAY_SKIP_OBAN=1 MIX_ENV=test mix verify.install_golden`); revert_and_reconfirm: skipped (the source fix predates this continuation and shared-worktree safety precludes reverting historic commits); guardrail_verdict: accepted."
- files_changed: ["priv/chimeway_migrations/034_privacy_safe_delivery_evidence.exs (pre-existing)", "test/fixtures/installer_golden_prefixed/tree/priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs (pre-existing)", "test/fixtures/installer_golden_public/tree/priv/repo/migrations/TIMESTAMP_privacy_safe_delivery_evidence.exs (pre-existing)", "test/chimeway/install/prefix_contract_test.exs (pre-existing)", "test/chimeway/install/golden_diff_test.exs (new executable migration-034 regression assertion)"]
