# Phase 89: Test-Lane Concurrency - Context

**Gathered:** 2026-07-29 (grounded inline from the live suite; no separate discuss-phase)
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert the pure-DB portion of the core `Chimeway.DataCase` test suite from serial to safe
parallel execution (`async: true`), size the `Chimeway.Repo` connection pool for that new
concurrency, bring the `ci.test` lane to `--warnings-as-errors` parity with the `verify.*` lanes,
and prove the conversion introduced zero test-ordering coupling. This is the phase that actually
moves the warm `ci-gate` toward the milestone's <3 min target — Phase 88 proved the remaining wall
clock is **test-execution-bound** (`mix ci.test` ~321s, `install_golden` ~344s, Accrue ~344s), not
a caching problem.

**In scope:** per-file `async: true` flips on vetted pure-DB test modules; `config/test.exs`
`Chimeway.Repo` `pool_size`; the `ci.test` mix alias (`mix.exs`); a `--seed 0` ordering-shakeout
proof. **Test/config-only — no runtime `lib/` behavior changes.**

**Explicitly OUT of scope (do NOT fold in):**
- **`--partitions` / `MIX_TEST_PARTITION` sharding** — deliberately skipped this milestone (4-core
  runner; the partition scaffolding in `config/test.exs` DB names stays but is not activated). A
  milestone-level decision already recorded; do not reopen.
- **Flipping the app-env or `:prefix` mutators** to async — they must stay serial (see D-02/D-03).
- **Partner-repo async** (accrue/threadline/sigra/mailglass DataCases) — separate case templates,
  own pools, own `allow/3` wiring; not this phase.
- **Nightly tiering / OTP-matrix / Playwright relocation** → Phase 90 (TIER-*).
- **No runtime library behavior changes.**
</domain>

<grounded_facts>
## Live-suite facts (measured 2026-07-29, cite don't re-measure)

- **88** `*_test.exs` files total. **24** already `async: true`. **57** use `Chimeway.DataCase`; of
  those **46** are `async: false`, **11** already `async: true`.
- The 46 `async: false` DataCase files partition into: **24 app-env mutators**
  (`Application.put_env`/`delete_env`), **4 `:prefix`/dynamic-repo mutators**, and **~21 pure-DB
  candidates** touching neither (overlap explains 24+4+21 > 46). The 21 candidates are enumerated in
  D-01. **3** files carry no `async:` marker at all (inherit their case default).
- **`test/support/data_case.ex` is textbook-correct:** `setup` does
  `Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])`. So flipping a file to
  `async: true` **drops shared-mode** for that module — which is safe **only if** the module never
  reaches `Chimeway.Repo` from a process it spawns without an explicit
  `Ecto.Adapters.SQL.Sandbox.allow/3`. This is the third safety axis beyond app-env/prefix.
- **`config/test.exs` sets NO explicit `pool_size` on `Chimeway.Repo`** → it defaults to **10**.
  (For contrast, `Mailglass.TestRepo` already pins `pool_size: 10` at `config/test.exs:52`.) 10 is
  the exact knob CONC-02 must raise, or async cases will starve the pool and hit ownership timeouts.
- **`ci.test` (`mix.exs:76`) currently runs**
  `env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra`
  — **no `--warnings-as-errors`.** It is the ONLY test-running lane missing the flag; every
  `verify.*` alias already carries it. `ci.lint` catches *compile* warnings via
  `compile --warnings-as-errors`, but the test lane does not fail on warnings surfaced during
  **test compilation** — that is the CONC-03 gap. The lane is invoked at `ci.yml:217` (`mix ci.test`).
</grounded_facts>

<decisions>
## Implementation Decisions

### Async conversion (CONC-01)
- **D-01:** Flip `async: false` → `async: true` **per file**, on the vetted pure-DB candidate set
  only. Do **NOT** change `Chimeway.DataCase`'s default — async stays an explicit per-module opt-in
  so the serial mutators remain obviously serial. Starting candidate set (21, each still to be
  independently vetted against D-02 before flipping):
  `workflows_inspection_test`, `inbox_state_transition_test`, `telemetry_correlation_test`,
  `inbox_pagination_test`, `workflows_test`, `inbox_query_test`, `idempotency_constraint_test`,
  `trigger_sanitization_test`, `persistence_transaction_test`, `inbox_integration_test`,
  `signal_test`, `integration/trigger_explain_test`, `integration/readme_snippet_test`,
  `dispatch/signal_router_worker_test`, `orchestration/digest_explainability_test`,
  `orchestration/delivery_planning_test`, `rendering/render_identity_integration_test`,
  `digests/digest_rule_test`, `digests/emission_test`, `digests/accumulation_test`,
  `webhooks/process_feedback_worker_test`.
- **D-02 (3-axis flip-safety filter, applied per candidate — the grep list is a starting point,
  NOT a blind-flip set):** a module is flip-safe only if ALL hold: **(a)** never mutates global
  app-env (`Application.put_env`/`delete_env`, `System.put_env`); **(b)** never touches tenant
  prefix / `put_dynamic_repo` / `PrefixedRuntime` / `Triplex`; **(c)** never reads/writes
  `Chimeway.Repo` from a spawned process (`Task`/`GenServer`/`spawn`/Oban worker executed inline)
  without `Sandbox.allow/3` — because async drops shared-mode. `signal_router_worker_test` and
  `process_feedback_worker_test` are the highest-risk on axis (c) (worker-driven) and must be read
  carefully; if any candidate fails a vet, it **stays `async: false`** and the reason is noted.
- **D-03:** The 24 app-env mutators + 4 `:prefix` mutators + the 3 no-marker files stay
  `async: false`. No mass flip. The phase's headline number is "safe async conversion," not "max
  async."

### Pool sizing (CONC-02)
- **D-04:** Add an explicit `pool_size` to `Chimeway.Repo` in `config/test.exs`. ExUnit's default
  `max_cases` is `System.schedulers_online() * 2`; each concurrent async case checks out one sandbox
  connection, so `pool_size` must be **≥ max_cases + headroom**. **Discretion (planner to finalize):**
  either compute it (`System.schedulers_online() * 2`, matching `max_cases`, plus a small constant)
  or pin a safe fixed value with headroom for the ~4-core CI runner and larger dev machines. Floor:
  never leave it at the implicit **10**. Success is "no `DBConnection` ownership/queue timeouts under
  the new concurrency," provable across 3 consecutive CI runs.

### Warnings-as-errors parity (CONC-03)
- **D-05:** Add `--warnings-as-errors` to the `ci.test` alias (`mix.exs:76`) so the test lane fails
  on any warning at parity with `verify.*`. Single-line alias change. Expect it to surface latent
  test-file warnings that must be fixed (not suppressed) as part of this phase — treat those fixes as
  in-scope test hygiene, still no `lib/` behavior change.

### Ordering-coupling proof (CONC-04)
- **D-06:** Prove the async conversion introduced no test-ordering coupling: the suite must pass on
  CI's default randomized seed across 3 consecutive runs AND on one ordered `--seed 0` run, with
  identical pass/fail. If a seed exposes coupling, the offending module is reverted to `async: false`
  (or the shared-state leak fixed) — a green-on-lucky-seed flip is a failure, not a pass.
</decisions>

<canonical_refs>
- `test/support/data_case.ex` — the `shared: not tags[:async]` sandbox owner (async-safety root).
- `config/test.exs` — `Chimeway.Repo` block (add `pool_size`); partner-repo pools for contrast.
- `mix.exs` aliases — `ci.test` (`:76`, add flag), the `verify.*` parity precedent.
- `.github/workflows/ci.yml:217` — `mix ci.test` invocation (the `test` lane).
- Phase 88 outcome (`.planning/CI-PERF-BASELINE.md`) — proves the residual is execution-bound.
</canonical_refs>

<success_criteria>
Mirror ROADMAP Phase 89:
1. The vetted pure-DB `Chimeway.DataCase` modules run `async: true`; app-env + `:prefix` mutators
   stay `async: false`; no data races across 3 consecutive CI runs.
2. `config/test.exs` sets an explicit `Chimeway.Repo` `pool_size` sized for the concurrency, with no
   connection-pool-exhaustion failures.
3. `ci.test` runs `--warnings-as-errors` and fails the lane on any compiler warning, at parity with
   `verify.*`.
4. The suite passes across randomized-seed CI runs and one ordered `--seed 0` run with identical
   pass/fail — proving no ordering coupling.
</success_criteria>

<risks>
- **Pool exhaustion** — under-sized `pool_size` → `DBConnection` ownership timeouts under async load
  (mitigated by D-04 headroom + the 3-run proof).
- **Hidden cross-process DB access** — a candidate that reaches the Repo from an un-`allow`ed spawned
  process passes serially but flakes under async on unlucky seeds (mitigated by D-02 axis (c) + D-06).
- **Latent warnings** — D-05 may surface real warnings that block the lane until fixed; scope them in.
- **Ordering coupling** — a flip that shares state across modules only fails on some seeds
  (mitigated by D-06's `--seed 0` + multi-run proof).
</risks>
