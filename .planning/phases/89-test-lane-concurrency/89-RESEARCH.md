# Phase 89: Test-Lane Concurrency - Research

**Researched:** 2026-07-29
**Domain:** ExUnit async test scheduling + Ecto SQL Sandbox connection ownership (Elixir/Ecto CI internals)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Async conversion (CONC-01)**
- D-01: Flip `async: false` -> `async: true` per file, on the vetted pure-DB candidate set only.
  Do not change `Chimeway.DataCase`'s default — async stays an explicit per-module opt-in so the
  serial mutators remain obviously serial. Starting candidate set (21, each still to be
  independently vetted against D-02 before flipping): `workflows_inspection_test`,
  `inbox_state_transition_test`, `telemetry_correlation_test`, `inbox_pagination_test`,
  `workflows_test`, `inbox_query_test`, `idempotency_constraint_test`,
  `trigger_sanitization_test`, `persistence_transaction_test`, `inbox_integration_test`,
  `signal_test`, `integration/trigger_explain_test`, `integration/readme_snippet_test`,
  `dispatch/signal_router_worker_test`, `orchestration/digest_explainability_test`,
  `orchestration/delivery_planning_test`, `rendering/render_identity_integration_test`,
  `digests/digest_rule_test`, `digests/emission_test`, `digests/accumulation_test`,
  `webhooks/process_feedback_worker_test`.
- D-02 (3-axis flip-safety filter, applied per candidate — the grep list is a starting point, NOT
  a blind-flip set): a module is flip-safe only if ALL hold: (a) never mutates global app-env
  (`Application.put_env`/`delete_env`, `System.put_env`); (b) never touches tenant prefix /
  `put_dynamic_repo` / `PrefixedRuntime` / `Triplex`; (c) never reads/writes `Chimeway.Repo` from a
  spawned process (`Task`/`GenServer`/`spawn`/Oban worker executed inline) without
  `Sandbox.allow/3` — because async drops shared-mode. `signal_router_worker_test` and
  `process_feedback_worker_test` are the highest-risk on axis (c) (worker-driven) and must be read
  carefully; if any candidate fails a vet, it stays `async: false` and the reason is noted.
- D-03: The 24 app-env mutators + 4 `:prefix` mutators + the 3 no-marker files stay
  `async: false`. No mass flip. The phase's headline number is "safe async conversion," not "max
  async."

**Pool sizing (CONC-02)**
- D-04: Add an explicit `pool_size` to `Chimeway.Repo` in `config/test.exs`. ExUnit's default
  `max_cases` is `System.schedulers_online() * 2`; each concurrent async case checks out one
  sandbox connection, so `pool_size` must be >= max_cases + headroom. Discretion (planner to
  finalize): either compute it (`System.schedulers_online() * 2`, matching `max_cases`, plus a
  small constant) or pin a safe fixed value with headroom for the ~4-core CI runner and larger dev
  machines. Floor: never leave it at the implicit 10. Success is "no `DBConnection`
  ownership/queue timeouts under the new concurrency," provable across 3 consecutive CI runs.

**Warnings-as-errors parity (CONC-03)**
- D-05: Add `--warnings-as-errors` to the `ci.test` alias (`mix.exs:76`) so the test lane fails on
  any warning at parity with `verify.*`. Single-line alias change. Expect it to surface latent
  test-file warnings that must be fixed (not suppressed) as part of this phase — treat those fixes
  as in-scope test hygiene, still no `lib/` behavior change.

**Ordering-coupling proof (CONC-04)**
- D-06: Prove the async conversion introduced no test-ordering coupling: the suite must pass on
  CI's default randomized seed across 3 consecutive runs AND on one ordered `--seed 0` run, with
  identical pass/fail. If a seed exposes coupling, the offending module is reverted to
  `async: false` (or the shared-state leak fixed) — a green-on-lucky-seed flip is a failure, not a
  pass.

### Claude's Discretion
- Exact `pool_size` value/formula (D-04) — computed vs. fixed, provided it never leaves the
  implicit floor of 10 and covers both the ~4-core CI runner and larger dev machines.
- Whether any individual D-01 candidate that fails the D-02 vet (or an equivalent risk found
  during research) stays `async: false` with a documented reason, rather than being force-flipped.

### Deferred Ideas (OUT OF SCOPE)
- `--partitions` / `MIX_TEST_PARTITION` sharding — deliberately skipped this milestone (4-core
  runner; the partition scaffolding in `config/test.exs` DB names stays but is not activated). A
  milestone-level decision already recorded; do not reopen.
- Flipping the app-env or `:prefix` mutators to async — they must stay serial (D-02/D-03).
- Partner-repo async (accrue/threadline/sigra/mailglass DataCases) — separate case templates, own
  pools, own `allow/3` wiring; not this phase.
- Nightly tiering / OTP-matrix / Playwright relocation -> Phase 90 (TIER-*).
- No runtime library behavior changes.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| CONC-01 | Pure-DB `Chimeway.DataCase` test modules run `async: true`; the ~25 app-env mutators and ~5 `:prefix` mutators remain `async: false`. | Full per-candidate D-02 audit completed (all 21 files read/grepped); 20 confirmed flip-safe, `telemetry_correlation_test` flagged to stay `async: false` (see "Ecto SQL Sandbox + ExUnit Async" section 4). Exact `OwnershipError` failure signature documented for diagnosis. |
| CONC-02 | `config/test.exs` sets an explicit `Chimeway.Repo` `pool_size` sized for the async concurrency. | `max_cases`-derived formula given (`System.schedulers_online() * 2 + 10`), with concrete `config/test.exs` snippet, verified against measured CI (4 vCPU) and local (18-core) core counts and Postgres's default `max_connections` ceiling. See "Pool Sizing for Async ExUnit." |
| CONC-03 | The `ci.test` lane runs with `--warnings-as-errors` (parity with the `verify.*` lanes). | Exact flag semantics confirmed from Mix v1.19 docs, confirmed orthogonal to existing `--exclude` flags, single-line alias diff provided. See "`--warnings-as-errors` on `mix test`." |
| CONC-04 | The suite passes across randomized seeds and an ordered `--seed 0` run after the async conversion (no ordering coupling introduced). | `--seed 0` scope precisely bounded (intra-file order only, does not serialize async scheduling) — repeated-random-seed + single-ordered-seed proof strategy specified, with `--trace` noted as a future debugging escape hatch. See "Ordering-Coupling Proof." |
</phase_requirements>

## Summary

This phase is a config/test-file-only conversion: flip ~21 vetted pure-DB `Chimeway.DataCase`
modules from `async: false` to `async: true`, raise `Chimeway.Repo`'s implicit `pool_size: 10` to
cover the new concurrency, add `--warnings-as-errors` to the `ci.test` alias, and prove no
ordering coupling was introduced. All four requirements are mechanically well-understood — Ecto's
sandbox, ExUnit's scheduler, and `mix test`'s flag semantics are stable, documented behaviors with
no ambiguity requiring a design decision. The main value this research adds beyond CONTEXT.md's
grounded facts is a **completed per-candidate D-02 audit** (all 21 files individually inspected,
not just grepped) and **one corrected/refined risk finding**: `telemetry_correlation_test` is not
safe to flip in the same wave as its five `Trigger.trigger`-calling siblings, for a reason that is
adjacent to but distinct from D-02's three named axes.

**Primary recommendation:** Flip 20 of the 21 D-01 candidates to `async: true` as planned; hold
`telemetry_correlation_test` at `async: false` (reason below). Set
`pool_size: System.schedulers_online() * 2 + 10` in `config/test.exs` (self-scaling for both the
4-vCPU CI runner and larger dev machines). Add `--warnings-as-errors` to the `ci.test` alias
verbatim (single-line change, no interaction with the existing `--exclude` flags). Prove CONC-04
via **3 consecutive default-random-seed CI runs with identical pass/fail** plus **one `--seed 0`
run** — but do not treat `--seed 0` alone as sufficient, because it only fixes intra-file test
order, not cross-module async interleaving (see Pitfall 3).

## Architectural Responsibility Map

This phase operates entirely in test/CI infrastructure, not application tiers. Mapped to the
closest equivalent responsibility layers:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Async test execution (CONC-01) | Test Framework (ExUnit `DataCase`) | Database/Storage (Sandbox ownership) | The `async:` tag is set per test module; the sandbox's `shared`/`allow` mechanics are what make it safe or unsafe |
| Connection pool sizing (CONC-02) | Database/Storage (`Chimeway.Repo` / `DBConnection`) | Test Framework (`max_cases`) | Pool size is an Ecto/Postgrex config value, but must be *derived from* ExUnit's own concurrency knob |
| Warnings-as-errors parity (CONC-03) | Build/Compile (`mix.exs` alias) | CI Pipeline (`ci.yml`) | Pure Mix task config; no runtime component |
| Ordering-coupling proof (CONC-04) | Test Framework (ExUnit seed/scheduler) | CI Pipeline (repeated-run signal) | The proof is a property of scheduler nondeterminism, verified by repeated CI execution, not a single artifact |

## Package Legitimacy Audit

**N/A — this phase installs no new packages.** It only edits `config/test.exs`, `mix.exs`
aliases, and `async:`/tag lines in existing `test/*.exs` files. No `deps()` changes.

## Ecto SQL Sandbox + ExUnit Async: Verified Semantics

### 1. What `shared: not tags[:async]` actually does [VERIFIED: deps/ecto_sql 3.13.5 source]

`test/support/data_case.ex` calls
`Ecto.Adapters.SQL.Sandbox.start_owner!(Chimeway.Repo, shared: not tags[:async])` in a `setup`
that runs before **every** test (not once per module). Read directly from the installed
`ecto_sql` 3.13.5 sandbox moduledoc (`deps/ecto_sql/lib/ecto/adapters/sql/sandbox.ex`):

- `shared: true` (today, `async: false`): the checked-out connection is placed in **shared mode**
  — *any* process in the VM can use it for the duration of that test, no explicit wiring needed.
  This is why worker/Task-spawning tests have "just worked" so far without any `allow/3` calls.
- `shared: false` (after flipping to `async: true`): the connection reverts to **allowance mode**
  — only the owner process (the test process) may use it. Any *other* process (a `Task`,
  `GenServer`, or an Oban worker executed inline in a different process) that touches
  `Chimeway.Repo` without an explicit `Ecto.Adapters.SQL.Sandbox.allow(Chimeway.Repo, owner_pid,
  other_pid)` call will fail immediately.

### 2. Exact failure signature [VERIFIED: same source, line 82]

```
** (DBConnection.OwnershipError) cannot find ownership process for #PID<0.35.0>
```

This is the diagnostic string the executor should grep for to distinguish a **bad async flip**
(missing `allow/3` — deterministic, fails every run) from **pool exhaustion** (intermittent,
different signature — see next section: `owner #PID<> timed out because it owned the connection
for longer than Nms`, or a `DBConnection.ConnectionError` queue-timeout). The two failure modes
are easy to conflate; they require different fixes (code fix vs. config fix).

### 3. How to audit a candidate for cross-process Repo access (the practical D-02 axis-(c) check)

Grep each candidate for the actual spawn primitives, not just "does it call Repo":

```bash
grep -nE 'Task\.(async|async_stream|start)|GenServer\.(start|call|cast)|spawn(_link)?\(' <file>
```

If a hit exists, read the spawned function body: does it touch `Chimeway.Repo` (directly or via a
context module), and if so, is `Sandbox.allow/3` called **before** the Repo access, from a process
that already holds the connection? If yes → safe. If a hit exists with **no** `allow/3` → unsafe,
must stay `async: false` or be fixed.

**Completed audit of all 21 D-01 candidates** (full-file read/grep, not sampling):

| File | Task/GenServer/spawn? | `allow/3` present? | Verdict |
|------|------------------------|---------------------|---------|
| `dispatch/signal_router_worker_test.exs` | No — calls `Oban.Testing.perform_job/2` directly in the test process (Oban.Testing runs the worker's `perform/1` synchronously in the caller, does not spawn) | N/A | **Safe** |
| `webhooks/process_feedback_worker_test.exs` | No — calls `ProcessFeedbackWorker.perform/1` directly, same reasoning | N/A | **Safe** |
| `idempotency_constraint_test.exs` | `Task.async_stream` (10 concurrent tasks) | Yes, `Sandbox.allow(Repo, parent, self())` inside every task, before any Repo call | **Safe** |
| `workflows_test.exs` | `Task.async_stream` (2 concurrent tasks) | Yes, same pattern | **Safe** |
| Remaining 17 candidates | No spawn primitives found | N/A | **Safe** on axis (c) |

Two clarifying findings from this audit that revise the CONTEXT.md's stated risk ranking:

- **The two worker tests flagged as "highest-risk" in D-02 are actually the lowest-risk on axis
  (c).** `Oban.Testing.perform_job/2` and calling `Worker.perform/1` directly are both synchronous,
  in-process calls — no process boundary is crossed at all, so there is nothing to `allow/3`.
  `signal_router_worker_test` and `process_feedback_worker_test` only *look* dangerous because
  "worker" suggests async execution; in the test harness they do not spawn anything.
- **The two `Task.async_stream` candidates (`idempotency_constraint_test`,
  `workflows_test`) already correctly call `allow/3` inside every spawned task, before touching
  `Repo`.** They were written defensively in anticipation of concurrent execution and need no
  changes to flip safely. Also note: `allow/3` does not check out an *additional* connection —
  it grants the spawned process permission to use the **same** connection the owner already holds.
  So `Task.async_stream(1..10, max_concurrency: 10)` inside one test consumes **1** pool
  connection, not 10 — this pattern does not inflate the CONC-02 pool-sizing requirement.

### 4. `telemetry_correlation_test.exs` — flagged NOT safe to flip in this wave

This file is **not caught by any of D-02's three named axes** (no app-env mutation, no
prefix/dynamic-repo, no un-`allow`ed spawn) but fails a **fourth axis: global, VM-wide process
state that isn't scoped to the sandbox at all.**

Two of its tests call `:telemetry.attach/attach_many` on the *exact* production spans
(`[:chimeway, :deliveries, :plan, :stop]`, `[:chimeway, :policy, :evaluate, :stop]`,
`[:chimeway, :attempts, :record, :stop]` — confirmed unconditional in
`lib/chimeway/telemetry.ex`) and then `assert_receive {:telemetry_event, meta}` with **no
correlation_id in the match pattern itself** — the correlation check happens only *after* the
message is received. `:telemetry` handlers are dispatched by event name across the entire VM,
independent of which process fired `:telemetry.execute/3` and independent of Ecto sandbox mode
entirely (there is no `allow/3` equivalent for telemetry).

Six candidates in the D-01 list call `Trigger.trigger/3`, which fires these exact spans on every
call: `idempotency_constraint_test`, `integration/trigger_explain_test`,
`persistence_transaction_test`, `rendering/render_identity_integration_test`,
`trigger_sanitization_test`, and `telemetry_correlation_test` itself
[VERIFIED: grep across `test/chimeway`, cross-checked against `lib/chimeway/telemetry.ex`].
**Today this is safe** because ExUnit runs all `async: false` modules to completion *before*
starting any `async: true` module [CITED: dockyard.com/blog/2019/02/13, cross-checked against
Elixir issue #3580 discussion] — so `telemetry_correlation_test` (currently `async: false`)
never overlaps with anything. **If `telemetry_correlation_test` itself is flipped to `async: true`
in the same wave as any of its five siblings**, it loses that serial-phase isolation and its
`assert_receive` can legitimately pull a telemetry message off the mailbox that was fired by a
concurrently-running sibling's `Trigger.trigger` call — a message that matches the receive
pattern's shape but carries the wrong `correlation_id`, failing the test non-deterministically
depending on scheduling, not on a real product bug. This is precisely the flaky-not-a-real-bug
signature D-06 exists to catch, and it is foreseeable before ever running the suite.

**Recommendation:** Keep `telemetry_correlation_test` at `async: false`. It is one file with no
performance cost to leaving serial, and the CONTEXT.md's own bias is "safe conversion over max
async." If the planner wants it flipped anyway, the file must first be changed so the
`assert_receive` patterns filter on `correlation_id` (e.g. `assert_receive {:telemetry_event, %{correlation_id: ^correlation_id} = meta}`) — a `lib/`-free test-file-only fix, still in-scope, but adds risk/effort for no stated requirement benefit. **20 of 21, not 21 of 21, should flip this phase.**

## Pool Sizing for Async ExUnit (CONC-02)

### Authoritative relationship [CITED: ex-unit.hexdocs.pm/1.19/ExUnit.html]

> "`:max_cases` — the maximum number of tests to run in parallel. Only tests from different
> modules run in parallel. Defaults to `System.schedulers_online() * 2`."

Combined with the scheduling fact above (async modules run concurrently with each other, but
tests *within* one module always run serially — each test's `setup` still does its own
`start_owner!`/`stop_owner` cycle, sequentially), the concurrent connection-checkout ceiling is
bounded by **the number of concurrently-running async *modules*, not the number of tests inside
them**. That ceiling is `max_cases`. Therefore:

```
pool_size ≥ max_cases + headroom
          = System.schedulers_online() * 2 + headroom
```

### Concrete recommendation

```elixir
# config/test.exs
pool_size = System.schedulers_online() * 2 + 10

repo_config =
  case System.get_env("DATABASE_URL") do
    nil ->
      pg_user = System.get_env("PGUSER") || System.get_env("USER") || "postgres"

      [
        username: pg_user,
        password: System.get_env("PGPASSWORD"),
        hostname: System.get_env("PGHOST") || "localhost",
        database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: pool_size
      ]

    database_url ->
      [url: database_url, pool: Ecto.Adapters.SQL.Sandbox, pool_size: pool_size]
  end

config :chimeway, Chimeway.Repo, repo_config
```

**Why a formula, not a fixed constant:** the phase brief explicitly requires sizing for both "a
~4-core CI runner AND larger dev machines" [VERIFIED: GitHub's Ubuntu-latest public-repo runners
are 4 vCPU / 16 GB, effective 2023-12-01 — CITED: github.blog/news-insights product-news]. A fixed
constant sized for CI (e.g. `pool_size: 20`) would be *insufficient* on this repo's own dev
machine (`sysctl -n hw.ncpu` = 18 cores measured locally → `max_cases` = 36 > 20, guaranteed pool
exhaustion locally even though CI would be fine). The formula self-scales: **CI (4 cores):
`8 + 10 = 18`**; **this dev machine (18 cores): `36 + 10 = 46`**. Both are comfortably under
Postgres 15's default `max_connections = 100` [VERIFIED: `.github/workflows/ci.yml` uses
`postgres:15` service image with no `max_connections` override, so the upstream Postgres image
default of 100 applies], and each CI job gets its own service container, so no cross-job
contention.

**`+10` headroom rationale:** covers (a) the ~24 app-env-mutator + 4 prefix-mutator + 3 no-marker
files that stay `async: false` and may still be mid-checkout during the boundary between the
serial and concurrent execution phases, and (b) partner-repo test lanes (`verify.mailglass`,
`verify.accrue`, etc.) that run as **separate `mix test` invocations** in **separate CI jobs**
(confirmed in `mix.exs` — they are distinct aliases run outside `ci.test`), so they do not add to
`Chimeway.Repo`'s pool pressure within a single `ci.test` run; the headroom is defensive margin,
not a computed requirement from those lanes.

### `ownership_timeout` / `queue_target` — do they need tuning?

[CITED: deps/ecto_sql sandbox moduledoc] `ownership_timeout` defaults to **120,000ms (2 min)** —
per-test-timeout, not a concurrency knob; no candidate test in this phase's scope is long-running,
so leave at default. `queue_target`/`queue_interval` (DBConnection pool queue-wait tuning, default
**50ms / 2000ms** [VERIFIED: `deps/db_connection/lib/db_connection.ex`]) govern how long a request
waits for a free connection before the pool considers itself under strain and doubles the target —
this is a self-correcting backpressure mechanism, not a hard cutoff. **No config change needed
for either.** If the 3-run CONC-02 proof (below) shows queue-related warnings in CI logs despite
correct `pool_size`, that is a signal to revisit `queue_target`, not to preemptively tune it now.

## `--warnings-as-errors` on `mix test` (CONC-03)

[CITED: mix.hexdocs.pm/1.19/Mix.Tasks.Test.html] Introduced in Mix v1.12.0. Exact documented
behavior:

> "treats compilation warnings (from loading the test suite) as errors and returns an exit status
> of 1 if the test suite would otherwise pass."

This is distinct from `compile --warnings-as-errors` (already in `ci.lint`): Mix does **not**
compile `test/` files during a normal `mix compile` — they are only compiled when `mix test`
itself loads them. `ci.lint`'s `compile --warnings-as-errors` therefore has zero visibility into
warnings inside `*_test.exs` files or `test/support/*.ex` — this is the exact CONC-03 gap
CONTEXT.md identified, now confirmed from the Mix source-of-truth doc rather than inference.

**Interaction with existing flags:** `--exclude`, `--only`, `--seed`, and `--warnings-as-errors`
are independent, orthogonal flags with no documented interaction. The change is additive:

```elixir
"ci.test": [
  "cmd env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --warnings-as-errors"
],
```

**Known consequence (in-scope hygiene, per D-05):** the first `mix ci.test` run after this change
will very likely surface pre-existing test-file warnings (unused variables/aliases, deprecated
calls in test helpers, etc.) that were previously silent. These must be fixed as test-file edits
(no `lib/` changes) — expect this, do not treat it as scope creep.

## Ordering-Coupling Proof (CONC-04)

### `--seed 0` — precise scope, and why it is NOT sufficient alone

[CITED: mix.hexdocs.pm/1.19/Mix.Tasks.Test.html] The documented behavior:

> "`--seed 0` disables randomization so the tests in a single file will always be ran in the same
> order they were defined in."

**Critical nuance for this phase:** `--seed` only controls the *definition-order* in which tests
within one file are dispatched — it does **not** disable or serialize `async: true` concurrent
execution across modules. Even with `--seed 0`, all the newly-flipped modules still run
concurrently with each other. This means `--seed 0` is a **useful reproducibility baseline**
(confirms the suite is not accidentally relying on inter-file definition order — e.g., module A's
tests assuming module B ran first) but it is **not** a proof against the interleaving/scheduling
hazards this phase actually introduces (cross-process races, the telemetry cross-talk pattern
above, shared-fixture leakage). Those hazards only surface probabilistically, under whatever
random scheduling the BEAM/ExUnit happens to produce on a given run.

**Recommended proof strategy (answers the phase's open question directly):** a single `--seed 0`
run is necessary but not sufficient. Combine it with **repeated default-random-seed runs**:

1. Run `mix ci.test` (or the equivalent full command) with CI's default (random, timestamp-derived)
   seed, **3 consecutive times**. Identical pass/fail set across all 3 = no seed-dependent flake.
2. Run once more with `--seed 0` explicitly. Same pass/fail set as the 3 random runs = no
   definition-order dependency either.
3. If any run in either category diverges, the diverging module is the one to investigate first —
   revert it to `async: false` (D-06) rather than chase a shared-state fix under time pressure,
   unless the fix is trivial and provably scoped to that module (as with the telemetry-filter fix
   described above).

For future debugging (not part of this phase's proof, but worth documenting for whoever hits a
flake later): `--trace` forces `max_cases` to `1`, fully serializing execution — useful to confirm
a failure is concurrency-induced (passes under `--trace`, fails without it) versus a genuine
regression (fails either way).

## Common Pitfalls

### Pitfall 1: Confusing ownership errors with pool exhaustion
**What goes wrong:** A flipped module fails with a Postgrex/DBConnection error and the fix attempt
targets `pool_size` when the real bug is a missing `allow/3`.
**Why it happens:** Both failure classes originate from `DBConnection`/`Postgrex` and can look
superficially similar in CI log noise.
**How to avoid:** Grep the failure for the literal string `cannot find ownership process` (missing
`allow/3`, code fix, deterministic every run) vs. `owned the connection for longer than` /
queue-timeout language (pool sizing, config fix, often intermittent under load).
**Warning signs:** A newly-flipped module fails **every** run (ownership) vs. fails **sometimes**
under concurrent CI load (pool).

### Pitfall 2: Assuming `Task.async_stream` needs N pool connections
**What goes wrong:** Sizing `pool_size` as if each concurrent `Task` inside a test consumes its
own connection.
**Why it happens:** Surface-level reading of "10 concurrent tasks" as "10 connections."
**How to avoid:** `Sandbox.allow/3` grants an *existing* checked-out connection to another
process; it does not check out a new one. A `Task.async_stream(1..10, max_concurrency: 10)` inside
one test still uses exactly 1 pool connection (verified in `idempotency_constraint_test.exs` and
`workflows_test.exs`, both of which already implement this correctly).

### Pitfall 3: Treating `--seed 0` as a complete ordering-coupling proof
**What goes wrong:** Running `--seed 0` once, seeing green, and closing out CONC-04.
**Why it happens:** The flag name ("seed") suggests it controls all nondeterminism, but per Mix's
own docs it only fixes intra-file definition order, not cross-module async scheduling.
**How to avoid:** Always pair `--seed 0` with multiple default-random-seed runs (see CONC-04
section above); treat `--seed 0` as a supplementary check, not the primary signal.
**Warning signs:** A module passes reliably under `--seed 0` but fails under 1 of 3 random-seed
runs — that is the coupling D-06 is designed to catch, and `--seed 0` alone would have missed it.

### Pitfall 4: Global process-wide state (telemetry, ETS, Registry) invisible to the 3-axis filter
**What goes wrong:** A candidate passes all of D-02's app-env/prefix/spawn checks but still
becomes racy once flipped, because it depends on VM-wide state that isn't scoped to the Ecto
sandbox at all.
**Why it happens:** `:telemetry.attach`, unregistered `Registry` entries, and bare `:ets` tables
are dispatched/visible across every process in the VM regardless of sandbox mode — there is no
`allow/3` equivalent for them.
**How to avoid:** Extend the D-02 audit with a fourth check: does the candidate register a
VM-global handler/name keyed only by event/type (not correlation id, not test-scoped ref) that
overlaps with an event fired by another candidate being flipped in the *same wave*? See
`telemetry_correlation_test.exs` above for a concrete instance.
**Warning signs:** `assert_receive` patterns that match on message *shape* only, without also
matching on a value unique to that test run.

## Code Examples

### Verified async-safe cross-process pattern (already present, model for future workers)
```elixir
# Source: test/chimeway/idempotency_constraint_test.exs:63-83 (this repo)
test "concurrent duplicate triggers still produce one canonical event row" do
  parent = self()

  results =
    1..10
    |> Task.async_stream(
      fn _attempt ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

        Trigger.trigger(
          IdempotentNotifier,
          %{"body" => "hello", "secret" => "drop-this"},
          idempotency_key: "concurrent-dup-key",
          tenant_id: "acme"
        )
      end,
      ordered: false,
      max_concurrency: 10,
      timeout: 15_000
    )
    |> Enum.map(fn {:ok, result} -> result end)

  assert Enum.count(results, &match?({:ok, _payload}, &1)) == 1
end
```

### `config/test.exs` pool_size snippet
```elixir
# Source: this research, applying System.schedulers_online()/2 * + headroom formula
pool_size = System.schedulers_online() * 2 + 10
```

### `mix.exs` `ci.test` alias, corrected
```elixir
# Source: mix.exs:74-77, single-line addition
"ci.test": [
  "cmd env MIX_ENV=test mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --warnings-as-errors"
],
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Implicit `pool_size: 10` (Ecto/Postgrex default) | Explicit, `System.schedulers_online()`-derived pool_size | This phase | Removes a silent ceiling that would starve under the new async concurrency |
| `ci.test` without `--warnings-as-errors` | Parity with `verify.*` (flag added Mix v1.12.0, 2021) | This phase | Test-file warnings now block the lane instead of accumulating silently |

**Deprecated/outdated:** none — all APIs used (`Sandbox.start_owner!/2`, `Sandbox.allow/3`,
`--warnings-as-errors`, `--seed`) are current, stable, non-deprecated as of Ecto SQL 3.13.5 / Mix
1.19 (this repo's installed versions).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `+10` is adequate fixed headroom on top of `max_cases` for this repo's specific serial/app-env-mutator tail | Pool Sizing | Low — headroom is generous (CI: 18 vs. floor of 8; local: 46 vs. floor of 36) and Postgres's 100-connection ceiling gives further margin; even doubling the headroom would stay well under the ceiling |
| A2 | GitHub-hosted `ubuntu-latest` public-repo runners report `System.schedulers_online() == 4` (matching the advertised 4 vCPU) | Pool Sizing | Low-medium — if the BEAM detects fewer/more schedulers than advertised vCPUs (e.g., due to `+S` flags or container cgroup limits), `max_cases` would differ from the assumed 8; the formula still self-corrects since it reads `schedulers_online()` directly, so no config drift results even if the raw vCPU/scheduler count assumption is imprecise |

**A1 and A2 are self-mitigating** because the recommended config uses a formula
(`System.schedulers_online() * 2 + 10`) rather than a hardcoded number — even if the *reasoning*
about exact CI core count is imprecise, the *config* automatically tracks whatever the runtime
actually reports.

## Open Questions

None blocking. One item for the planner's judgment, not a research gap: whether to flip
`telemetry_correlation_test.exs` this phase (with the correlation-id filter fix) or leave it
`async: false` and let a later phase revisit it. This research recommends the latter (minimal
diff, zero risk, no stated requirement forces the former).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit, bundled with Elixir 1.19.5 (this repo's `elixir --version`) |
| Config file | `test/test_helper.exs` (no separate `ex_unit` app config; `Sandbox.mode(Chimeway.Repo, :manual)` set there) |
| Quick run command | `mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra` |
| Full suite command | `mix ci.test` (the alias this phase modifies) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|--------------------|--------------|
| CONC-01 | 20 vetted `DataCase` modules run correctly under `async: true`; app-env/prefix mutators + `telemetry_correlation_test` stay `async: false` | integration (suite-level) | `mix ci.test` (3 consecutive runs, identical pass/fail) | ✅ existing files, tag-only edit |
| CONC-02 | No connection-ownership/queue timeouts under the new concurrency | integration (suite-level, log inspection) | `mix ci.test 2>&1 \| grep -E "OwnershipError\|owned the connection for longer than\|queue"` (expect no matches) across the same 3 runs | ✅ — no new test file, verified via CI run + log grep |
| CONC-03 | The lane fails on any test-file compiler warning | smoke (deliberate negative test) | Temporarily introduce an unused variable in any `_test.exs`, run `mix ci.test`, confirm non-zero exit; then revert | ✅ one-time manual proof, documented as verification evidence, not a permanent test |
| CONC-04 | Suite passes identically across randomized seeds and one ordered `--seed 0` run | integration (suite-level, repeated) | `mix ci.test` × 3 (default random seed) + `mix ci.test --seed 0` × 1; diff the pass/fail sets | ✅ existing suite, no new file |

### Sampling Rate
- **Per task commit (per-file async flip):** `mix test <changed_file> --seed 0` — fast, isolated
  sanity check that the individual flipped module still passes standalone.
- **Per wave merge (all flips + pool_size + alias change together):** full `mix ci.test`, 3
  consecutive default-seed runs + 1 `--seed 0` run (the CONC-04 proof).
- **Phase gate:** all 4 runs green, and the CONC-03 deliberate-warning negative-proof executed
  once and reverted, before `/gsd-verify-work`.

### Wave 0 Gaps
None — existing test infrastructure (ExUnit, `Chimeway.DataCase`, `mix ci.test`) covers all four
phase requirements. No new test files, fixtures, or framework installs needed; this phase only
edits tags, one config value, and one alias line.

## Sources

### Primary (HIGH confidence — read directly from installed dependency source or this repo)
- `deps/ecto_sql/lib/ecto/adapters/sql/sandbox.ex` (ecto_sql 3.13.5, installed per `mix.lock`) —
  shared vs. allowance mode, exact `OwnershipError` string, `ownership_timeout` default.
- `deps/db_connection/lib/db_connection.ex` (installed per `mix.lock`) — `queue_target`/
  `queue_interval` defaults.
- `test/support/data_case.ex`, `config/test.exs`, `mix.exs` (this repo) — current state read
  directly, not inferred.
- All 21 D-01 candidate test files (this repo) — read/grepped in full for the D-02 axis audit.
- `lib/chimeway/telemetry.ex` (this repo) — confirmed unconditional span names.
- `.github/workflows/ci.yml` (this repo) — confirmed Postgres 15 service image, no
  `max_connections` override; confirmed `ubuntu-latest` runner.

### Secondary (MEDIUM confidence — official docs, WebFetch/WebSearch verified)
- `ex-unit.hexdocs.pm/1.19/ExUnit.html` — `:max_cases` default and definition.
- `mix.hexdocs.pm/1.19/Mix.Tasks.Test.html` — `--warnings-as-errors`, `--seed 0`,
  `--exclude`/`--only` semantics.
- `dockyard.com/blog/2019/02/13/understanding-test-concurrency-in-elixir` (cross-checked against
  `elixir-lang/elixir` issue #3580 discussion) — async-modules-run-after-sync-modules scheduling
  order.
- `github.blog/news-insights/product-news/github-hosted-runners-double-the-power-for-open-source` —
  4 vCPU / 16 GB public-repo runner spec, effective 2023-12-01.

### Tertiary (LOW confidence)
- None — every claim in this document traces to installed source, this repo's own files, or an
  official Elixir/Mix/GitHub doc page.

## Metadata

**Confidence breakdown:**
- Sandbox/ExUnit mechanics: HIGH — read directly from installed `ecto_sql`/`ex_unit` source and
  official docs, no training-data reliance.
- Per-candidate flip-safety audit: HIGH — every file individually read/grepped this session, not
  sampled.
- Pool sizing formula: HIGH — derived from documented `max_cases` behavior, cross-checked against
  measured local core count and documented CI runner spec.
- `telemetry_correlation_test` risk finding: HIGH — confirmed via direct grep of all
  `Trigger.trigger` callers and the actual span names in `lib/chimeway/telemetry.ex`, not
  speculation.

**Research date:** 2026-07-29
**Valid until:** Stable for this phase's lifetime; re-verify `ecto_sql`/`ex_unit` version-specific
claims if either dependency is upgraded before execution (unlikely mid-phase).

## RESEARCH COMPLETE
