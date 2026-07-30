# 89-05 Summary — ci.test warnings-as-errors parity

**Status:** COMPLETE (commit `10a674f`) · **Requirements:** CONC-03

## What landed
- `mix.exs` `ci.test` alias: appended `--warnings-as-errors` (parity with every `verify.*` alias).
- **No test-file warnings needed fixing** — the suite compiled clean under the flag (the codebase was already warning-clean; `verify.*` lanes had kept adjacent files disciplined).

## Negative proof (the gate actually bites)
Injected an unused local binding (`unused_proof_binding = …`) into a `signal_test.exs` test body and forced test compilation under `--warnings-as-errors`:
- **With inject:** `warning: variable "unused_proof_binding" is unused` → `mix test --warnings-as-errors` exited **1** (gate fired).
- **After `git checkout`:** tree clean (`git diff --quiet` on `test/` + `mix.exs` = yes), `signal_test.exs` restored.

This is a one-time documented proof, not a permanent test (per 89-VALIDATION.md).

## Guard — no lane-structure drift
`release_gate_contract_test.exs` + `ci_observability_contract_test.exs`: **131 tests, 0 failures**. The `mix.exs`-only change touched no `ci.yml` lane structure; `ci_observability_contract_test.exs` already anticipated/exempted this CONC-03 addition from its build-lane refute.

## Full-lane verification
`mix ci.test` (with the flag): exit 0, 1229 tests, 0 failures.
