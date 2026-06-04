# Phase 63: Threadline Telemetry Bridge — Research

**Researched:** 2026-05-30  
**Phase:** 63-threadline-telemetry-bridge  
**Requirement:** ECOS-08  
**Status:** Ready for planning

---

## 1. Executive Summary

Phase 63 delivers **`Chimeway.Telemetry.ThreadlineReporter`**: an optional `:telemetry` handler that sinks Chimeway notification lifecycle outcomes (suppressed, deferred, dispatched, failed) into Threadline's `audit_actions` table via public `Threadline.record_action/2`. Host wiring is attach-only — optional `threadline` dep + `Chimeway.Telemetry.ThreadlineReporter.attach/0` in `Application.start/2` [CITED: 63-CONTEXT.md D-01, D-03].

The work is **Chimeway-only** (no Threadline repo changes) and follows the **Accrue/Mailglass selective-CI template**: optional dep, `@moduletag :threadline`, `--exclude threadline` on `ci.test`, dedicated verify alias deferred to Phase 66 (GATE-07) [CITED: 63-CONTEXT.md D-10, D-13].

**Two gaps to close in Chimeway core before the bridge works end-to-end:**

1. **`planning_reason` stripped by `safe_meta/1`** — `Policy.evaluate/2` emits it on defer stop meta, but `@allowed_meta_keys` omits it today [VERIFIED: `lib/chimeway/policy.ex` L63, `lib/chimeway/telemetry.ex` L80–84].
2. **`correlation_id` missing on outcome spans** — only `[:events, :create]` and `[:deliveries, :plan]` stop events carry `correlation_id`; reporter target spans (`policy:evaluate`, `dispatch:sync|perform`, `attempts:record`) do not [VERIFIED: `test/chimeway/telemetry_correlation_test.exs`; `telemetry_integration_test.exs` L322–323 explicitly asserts attempts:record lacks correlation_id].

**Planner takeaway:** Split into **Wave 63-01 (harness + telemetry enrichment)** and **Wave 63-02 (reporter + lifecycle integration proof)** mirroring Accrue 58-01/58-02 scope split [CITED: 58-CONTEXT.md vertical-slice precedent].

---

## 2. Standard Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Language | Elixir ~> 1.17, OTP 26+ | Matches `mix.exs` + AGENTS.md [CITED: mix.exs] |
| Persistence | Ecto 3.x + PostgreSQL 15+ | Chimeway `Repo` + Threadline `Threadline.Test.Repo` in tests [CITED: Threadline test/support/repo.ex] |
| Telemetry | `:telemetry` 1.x | Chimeway span catalog in `Chimeway.Telemetry` [CITED: lib/chimeway/telemetry.ex] |
| Audit sink | Threadline ~> 0.7 (optional dep) | `Threadline.record_action/2` public API [CITED: ../threadline/lib/threadline.ex L40–62] |
| Test harness | ExUnit + conditional bootstrap | Mailglass/Accrue precedent in `test/test_helper.exs` [CITED: test/test_helper.exs] |

**OTP patterns:**

- **Optional ecosystem dep:** `Code.ensure_loaded?(Threadline)` compile gate [CITED: 63-CONTEXT.md D-02; Oban pattern in telemetry.ex L167–177].
- **Attach-only host wiring:** Chimeway never auto-attaches reporter at library boot [CITED: telemetry.ex moduledoc L48–54].
- **Selective CI:** `@moduletag :threadline` excluded from default `ci.test`; `mix verify.threadline` deferred to Phase 66 [CITED: 63-CONTEXT.md D-10, D-13].
- **PII redaction:** Reporter must only forward keys already allowed by `safe_meta/1`; never bypass redaction [CITED: ECOS-08; telemetry.ex moduledoc L25–33].

---

## 3. Architecture Patterns

### 3.1 Outcome flow: Chimeway telemetry → Threadline audit row

```
Chimeway lifecycle (trigger → policy → dispatch → attempt)
  → :telemetry.span/3 emits [:chimeway, ..., :stop]
  → ThreadlineReporter.handle_event/4 (host-attached)
  → Threadline.record_action(action_atom, repo:, actor:, correlation_id:, category:, reason:, comment:)
  → audit_actions row (queryable via Threadline.Query.timeline/2 :correlation_id filter)
```

[CITED: 63-CONTEXT.md D-05, D-06, D-07] [CITED: ../threadline/lib/threadline/query.ex strict correlation_id semantics]

### 3.2 Outcome mapping table (locked defaults)

| Chimeway `:stop` event | Detect condition | Default Threadline action |
|------------------------|------------------|---------------------------|
| `[:chimeway, :policy, :evaluate, :stop]` | `suppression_reason` in meta | `:notification_suppressed` |
| `[:chimeway, :policy, :evaluate, :stop]` | `planning_reason` in meta | `:notification_deferred` |
| `[:chimeway, :dispatch, :sync, :stop]` or `:perform, :stop` | dispatch completed (no suppress/defer on this path) | `:notification_dispatched` |
| `[:chimeway, :attempts, :record, :stop]` | `outcome: :failed` | `:notification_failed` |

**Precedence on policy span:** If both keys present (shouldn't happen), prefer `suppression_reason` over `planning_reason` [ASSUMED: mutual exclusivity from Policy.evaluate/2 return shapes].

**Skip `:notification_succeeded`:** ECOS-08 lists four outcomes only; dispatch `:stop` with `outcome: :succeeded` still maps to `:notification_dispatched` (delivery attempted), not a separate success action [CITED: 63-CONTEXT.md Claude's Discretion].

### 3.3 Reporter module shape (recommended)

```elixir
defmodule Chimeway.Telemetry.ThreadlineReporter do
  @moduledoc false

  if Code.ensure_loaded?(Threadline) do
    # attach/0, handle_event/4, config lookup from :chimeway, :threadline_reporter
  end
end
```

- **`attach/0`:** Idempotent `:telemetry.attach_many/4` on reporter `:stop` events only (not `:exception` unless Phase 66 adds failure audit rows) [ASSUMED].
- **Config:** `Application.get_env(:chimeway, :threadline_reporter)` → `repo:` (required), `actor:` (`%Threadline.Semantics.ActorRef{}`, required), optional action-name overrides [CITED: 63-CONTEXT.md D-04].
- **Default actor:** `ActorRef.new(:system, "chimeway")` as config default in docs; require explicit config in tests [ASSUMED: matches host ownership boundary].

### 3.4 Threadline `record_action/2` contract

Required opts: `:repo`, `:actor` (or `:actor_ref`) [CITED: threadline.ex L16–19].

Relevant optional opts for bridge:
- `:correlation_id` — string, max 256 bytes trimmed [CITED: threadline/query.ex validate_correlation_id_filter!/1]
- `:category` — use `"notifications"` [CITED: 63-CONTEXT.md D-06]
- `:reason` — suppression/planning/outcome atom as string
- `:comment` — bounded key=value summary (no payload bodies)

Action `name` atom becomes stored `name` string via `build_attrs/3` [CITED: threadline.ex].

---

## 4. Telemetry Enrichment Requirements

### 4.1 Add `planning_reason` to allowed keys (D-08)

```elixir
# lib/chimeway/telemetry.ex — add to @allowed_meta_keys
:planning_reason
```

Also update moduledoc event catalog table for `[:chimeway, :policy, :evaluate]`.

Add unit test in `telemetry_integration_test.exs` or extend `safe_meta/1` describe: defer path includes `planning_reason`, PII still stripped.

### 4.2 Add `correlation_id` to outcome spans (research recommendation)

Reporter target spans must carry `correlation_id` in `:stop` metadata to satisfy D-07 without DB lookups in the handler.

| Span emitter | Enrichment source |
|--------------|-------------------|
| `policy.ex` `evaluate/2` | Load `delivery.metadata["correlation_id"]` or join Event via Notification (metadata already populated per `telemetry_correlation_test.exs` L67) |
| `dispatch/sync.ex`, `oban_worker.ex` | Same — delivery struct available at span site |
| `deliveries.ex` `record_attempt/2` | Same — delivery in scope |

**Alternative rejected:** Reporter DB lookup by `delivery_id` — works but violates "telemetry meta only" contract in D-06/D-07 and adds Repo dependency in hot handler path [CITED: 63-CONTEXT.md D-06].

Update `telemetry_correlation_test.exs` to assert `correlation_id` on at least `policy:evaluate` and `attempts:record` stop events after enrichment.

---

## 5. Test Harness Pattern (Mailglass/Accrue Template)

### 5.1 mix.exs changes

| Accrue/Mailglass | Threadline (Phase 63) |
|------------------|----------------------|
| `{:accrue, "~> 1.3", optional: true, runtime: false}` | `{:threadline, "~> 0.7", optional: true, runtime: false}` |
| `ACCRUE_PATH` env path override | `THREADLINE_PATH` env path override |
| `ci.test` `--exclude accrue` | `ci.test` `--exclude threadline` |
| `verify.accrue` alias | **Deferred** — Phase 66 GATE-07 adds `verify.threadline` [CITED: D-13] |

### 5.2 config/test.exs

Mirror Accrue block: configure `Threadline.Test.Repo` database (`chimeway_threadline_test`), repo in app env for reporter config.

Threadline test repo module: `Threadline.Test.Repo` [CITED: threadline/test/support/repo.ex].

Migrations path: `:threadline |> :code.priv_dir() |> Path.join("repo/migrations")` [ASSUMED: same as Accrue fallback in test_helper.exs L52–57].

### 5.3 test/test_helper.exs

When `Code.ensure_loaded?(Threadline)`:
1. `Application.ensure_all_started(:threadline)`
2. `storage_up` + migrate `Threadline.Test.Repo`
3. `start_link` TestRepo
4. **Note:** Threadline's own `DataCase` avoids sandbox (trigger capture); Chimeway bridge tests only need `audit_actions` inserts — table cleanup in setup is sufficient [CITED: threadline/test/support/data_case.ex L5–6]. Use delete-all on `audit_actions` in setup, not full Threadline trigger capture.

### 5.4 test/support/threadline/

| File | Purpose |
|------|---------|
| `data_case.ex` | Shared Chimeway.Repo sandbox + Threadline audit_actions cleanup |
| `fixtures.ex` | `configure_threadline_reporter!/0`, default ActorRef, attach/detach helpers |

### 5.5 Integration test proof (D-12)

`test/chimeway/integrations/threadline_telemetry_lifecycle_test.exs`:
- `@moduletag :threadline`
- Conditional module: `if Code.ensure_loaded?(Threadline)`
- Attach reporter in setup
- Trigger notification with known `correlation_id`
- Assert `Threadline.Semantics.AuditAction` row with matching `correlation_id` and expected action name
- Prove **suppressed** path easiest via test notifier + policy suppress rule [ASSUMED: mirror telemetry_integration_test patterns]
- Assert no PII in Threadline `comment`/`reason` fields

Query proof: `Threadline.Query.timeline/2` with `correlation_id:` filter returns the action-linked row [CITED: threadline/test/threadline/audit_transaction_test.exs correlation tests].

---

## 6. Wave Recommendation

| Wave | Plan focus | Delivers |
|------|------------|----------|
| **63-01** | Harness + telemetry fixes | Optional dep, CI exclude, test bootstrap, `planning_reason` + `correlation_id` span enrichment |
| **63-02** | Reporter + integration proof | `ThreadlineReporter`, config contract, lifecycle → audit row test |

Demo host, blueprint, docs, `verify.threadline` CI job → Phases 65–66 [CITED: 63-CONTEXT.md out of scope].

---

## 7. Security & Redaction

| Threat | Mitigation |
|--------|------------|
| PII in Threadline audit ledger | Reporter reads only `safe_meta`-filtered telemetry; build `comment` from allowed keys only [CITED: ECOS-08 SC-2] |
| Unbounded comment size | Cap comment string (e.g. 512 chars) when assembling key=value summary [ASSUMED] |
| Missing repo/actor config | `record_action/2` returns `{:error, :missing_repo}` / `{:error, :missing_actor}` — reporter should log at debug and not crash handler [ASSUMED: match default logger handler resilience] |
| Handler crash breaks telemetry | Rescue/log in handler; never raise into `:telemetry` dispatch [ASSUMED: standard telemetry handler practice] |

---

## 8. Pitfalls & Risks

| Pitfall | Impact | Mitigation |
|---------|--------|------------|
| **`planning_reason` not in allowed keys** | Deferred outcomes never bridge | D-08 fix in Wave 63-01 [VERIFIED] |
| **No `correlation_id` on outcome spans** | Timeline filter can't link audit rows | Enrich spans in Wave 63-01 [VERIFIED gap] |
| **Double `:notification_dispatched`** | Duplicate audit rows on sync + perform | Attach to both spans but dedupe by `delivery_id` + action within short window, OR only fire on `attempts:record` success — planner must pick one [OPEN: OQ-1] |
| **Suppress before dispatch span** | Only policy span fires | Map suppression on policy span only — correct [VERIFIED] |
| **Threadline trigger capture in tests** | Unnecessary complexity | Test `record_action` path only; no capture triggers needed [VERIFIED] |
| **Threadline version skew** | CI hex without API | Pin `~> 0.7`; path dep via `THREADLINE_PATH` for local dev [CITED: mix.exs accrue_dep pattern] |
| **Reporter attached without Threadline started** | `record_action` fails | Document host must start Threadline app + repo before attach [ASSUMED] |

---

## 9. Validation Architecture (Nyquist Dimension 8)

Nyquist dimension 8 = every ROADMAP success criterion maps to an **automated** verify command [CITED: 58-RESEARCH.md §9].

### 9.1 Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17+) |
| Config | `mix.exs` aliases |
| Quick run (Wave 1) | `mix test test/chimeway/integrations/threadline_telemetry_harness_test.exs --only threadline --warnings-as-errors` [ASSUMED: path] |
| Phase gate (partial) | `mix test --only threadline --warnings-as-errors` (full `verify.threadline` alias = Phase 66) |
| Default CI | `mix ci.test` (excludes `:threadline`) |
| Regression | `mix test test/chimeway/telemetry_integration_test.exs --warnings-as-errors` |

### 9.2 ROADMAP success criteria → verification map

| # | Success criterion (ROADMAP) | Requirement | Test type | Automated command | Wave |
|---|----------------------------|-------------|-----------|-------------------|------|
| 1 | Host attaches reporter; four outcomes appear in Threadline audit | ECOS-08 | integration | `mix test --only threadline` (lifecycle describe) | 63-02 |
| 2 | Reporter redacts sensitive fields | ECOS-08 | unit + integration | `mix test test/chimeway/telemetry_integration_test.exs` + threadline lifecycle asserts on comment/reason | 63-01/02 |
| 3 | `@moduletag :threadline` selective CI | ECOS-08 | config | `mix ci.test` excludes threadline; `--only threadline` passes | 63-01 |

### 9.3 Wave 0 gaps (for VALIDATION.md)

- [ ] `mix.exs` threadline dep + `ci.test` exclude
- [ ] `config/test.exs` Threadline.Test.Repo config
- [ ] `test/test_helper.exs` conditional bootstrap
- [ ] `test/support/threadline/*`
- [ ] `threadline_telemetry_harness_test.exs` (63-01)
- [ ] `threadline_telemetry_lifecycle_test.exs` (63-02)
- [ ] `lib/chimeway/telemetry/threadline_reporter.ex`
- [ ] Telemetry enrichment (`planning_reason`, `correlation_id` on outcome spans)

---

## 10. Open Questions for Planner

### OQ-1: Dedupe `:notification_dispatched` on sync + Oban perform

**Options:**

| Option | Pros | Cons |
|--------|------|------|
| Fire on dispatch `:stop` only | Matches "dispatched" semantics early | Oban path may emit both `:perform` and `:sync` in some configs |
| Fire on first successful `attempts:record` only | One row per delivery outcome | Skips "dispatched" if attempt recording fails |
| Dedupe map in reporter by `{delivery_id, action}` | Handles both paths | Slightly more complex handler state |

**Recommendation:** Fire on `[:dispatch, :sync|:perform, :stop]` when outcome is not `:failed`; rely on single dispatch path per delivery in tests. Add integration test comment documenting assumption [ASSUMED: Sync dispatcher default in tests].

### OQ-2: Default system actor

**Recommendation:** Require explicit `:actor` in config (no silent default in production config); test fixtures supply `ActorRef.new(:system, "chimeway")` [CITED: 63-CONTEXT.md Claude's Discretion].

### OQ-3: Test-support file layout

**Recommendation:** `test/support/threadline/*` mirroring Accrue/Mailglass [CITED: 63-CONTEXT.md D-11].

---

## 11. Canonical Code References

| Ref | Path | Relevance |
|-----|------|-----------|
| Phase decisions | `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` | D-01–D-13 locked |
| ROADMAP SC | `.planning/ROADMAP.md` (Phase 63) | Success criteria |
| ECOS-08 | `.planning/REQUIREMENTS.md` | Acceptance wording |
| SEED-003 Threadline slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Bridge intent |
| Chimeway telemetry | `lib/chimeway/telemetry.ex` | Span catalog, safe_meta, attach pattern |
| Policy telemetry | `lib/chimeway/policy.ex` | suppression_reason, planning_reason emit |
| Dispatch telemetry | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex` | Dispatch spans |
| Attempt telemetry | `lib/chimeway/deliveries.ex` | record_attempt span + outcome meta |
| Correlation tests | `test/chimeway/telemetry_correlation_test.exs` | correlation_id on delivery metadata |
| Telemetry integration | `test/chimeway/telemetry_integration_test.exs` | PII stripping, mandatory spans |
| Accrue harness template | `test/test_helper.exs`, `test/support/accrue/*`, `mix.exs` | Selective CI pattern |
| Accrue 58-01 plan | `.planning/milestones/v1.9-phases/58-accrue-dunning-core/58-01-PLAN.md` | Wave 1 harness plan shape |
| Threadline API | `../threadline/lib/threadline.ex` | record_action/2 |
| Threadline audit schema | `../threadline/lib/threadline/semantics/audit_action.ex` | audit_actions fields |
| Threadline timeline query | `../threadline/lib/threadline/query.ex` | correlation_id strict filter |
| Threadline test repo | `../threadline/test/support/repo.ex` | Test.Repo module |

---

## RESEARCH COMPLETE
