---
phase: 89
slug: test-lane-concurrency
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-29
---

# Phase 89 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Note: this phase converts existing tests to `async: true` and tunes config — the "tests" it
> validates are the **existing suite itself**, run repeatedly under new concurrency, not new test
> files. Verification is therefore suite-level (integration) + one deliberate-warning negative proof.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (bundled with Elixir 1.19.5) |
| **Config file** | `test/test_helper.exs` (`Sandbox.mode(Chimeway.Repo, :manual)` — required for async sandboxing) |
| **Quick run command** | `mix test <changed_file> --seed 0` |
| **Full suite command** | `mix ci.test` |
| **Estimated runtime** | ~300s serial today; target lower under async |

---

## Sampling Rate

- **After every task commit (per-file async flip):** Run `mix test <changed_file> --seed 0` — fast, isolated proof the flipped module still passes standalone under async.
- **After every plan wave (all flips + pool_size + alias together):** Run the full `mix ci.test`.
- **Before `/gsd-verify-work`:** 3 consecutive default-random-seed `mix ci.test` runs + 1 `mix ci.test --seed 0` run, all green with identical pass/fail; plus the CONC-03 deliberate-warning negative proof executed once and reverted.
- **Max feedback latency:** per-file run ~seconds; full-suite run ~minutes.

---

## Per-Task Verification Map

| Task ID | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 89-xx (async flips) | 1 | CONC-01 | 20 vetted `DataCase` modules pass under `async: true`; app-env/prefix mutators + `telemetry_correlation_test` stay `async: false`; no data races | integration (suite-level, 3 runs) | `mix ci.test` ×3, identical pass/fail | ✅ existing files, tag-only edit | ⬜ pending |
| 89-xx (pool_size) | 1 | CONC-02 | No `DBConnection` ownership/queue timeouts under async load | integration (suite-level + log grep) | `mix ci.test 2>&1 \| grep -E "OwnershipError\|owned the connection for longer than\|queue"` → no matches, ×3 | ✅ config edit, no new file | ⬜ pending |
| 89-xx (ci.test flag) | 1 | CONC-03 | Lane fails on any test-file compiler warning, at `verify.*` parity | smoke (deliberate negative proof) | Introduce an unused var in a `_test.exs`, `mix ci.test` → non-zero exit, then revert | ✅ one-time proof, documented as evidence | ⬜ pending |
| 89-xx (seed proof) | 1 | CONC-04 | Identical pass/fail across randomized seeds and one ordered `--seed 0` run | integration (suite-level, repeated) | `mix ci.test` ×3 (random) + `mix ci.test --seed 0` ×1; diff pass/fail sets | ✅ existing suite, no new file | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure (ExUnit, `Chimeway.DataCase`, `mix ci.test`, `test_helper.exs` manual sandbox) covers all four phase requirements. No new test files, fixtures, or framework installs needed — this phase edits `async:` tags, one `pool_size` config value, and one alias line.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `ci.test` fails on a compiler warning | CONC-03 | A permanent always-warning test would break the suite; the proof is a one-time inject/revert | Add an unused variable to any `_test.exs`, run `mix ci.test`, confirm non-zero exit + warning-as-error message, `git checkout` the file |
| No cross-run ordering coupling | CONC-04 | Requires observing multiple full CI runs' pass/fail sets, which CI produces over time | Compare 3 consecutive push-triggered `ci.test` runs + the `--seed 0` run on the run pages |

---

## Validation Sign-Off

- [ ] All tasks have automated verify (suite-level) or one-time documented proof (CONC-03)
- [ ] Sampling continuity: every async-flip task has a per-file `--seed 0` check
- [ ] Wave 0 covers all MISSING references (none — existing infra suffices)
- [ ] No watch-mode flags
- [ ] Feedback latency acceptable (per-file seconds, suite minutes)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
