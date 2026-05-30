# Phase 63: Threadline Telemetry Bridge - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Chimeway notification lifecycle outcomes (suppressed, deferred, dispatched, failed) automatically appear in Threadline's immutable audit ledger via an optional telemetry reporter — host glue is attach-only (dependency + reporter attach in `Application.start/2`).

**In scope:** `Chimeway.Telemetry.ThreadlineReporter` (or equivalent), optional `threadline` dep, `@moduletag :threadline` integration tests proving lifecycle event → Threadline `audit_actions` row with `correlation_id` correlation, selective CI exclude wiring.

**Out of scope (later phases):** Demo host proof + operator inspectability (Phase 65 DEMO-09), reference blueprint recipe (Phase 65), golden-path guide + doc-contract (Phase 66 DOCS-10/11), `mix verify.threadline` CI gate + MAINTAINING checklist entry (Phase 66 GATE-07).

**Depends on:** v1.9 durable spine (telemetry correlation, explainable traces, `safe_meta/1` redaction).

**Requirements:** ECOS-08
</domain>

<decisions>
## Implementation Decisions

### Integration seam (telemetry bridge, not adapter)
- **D-01:** Phase 63 delivers a **`:telemetry` handler bridge** only — no `Chimeway.Adapter` delivery seam. Chimeway owns orchestration explainability; Threadline owns audit ledger persistence.
- **D-02:** Module name **`Chimeway.Telemetry.ThreadlineReporter`**, compiled behind `Code.ensure_loaded?(Threadline)` guard — mirror Oban conditional spans in `Chimeway.Telemetry.attach_default_handlers/0`.

### Host wiring (attach-only)
- **D-03:** Host adds `{:threadline, "~> 0.7", optional: true, runtime: false}` and calls **`Chimeway.Telemetry.ThreadlineReporter.attach/0`** in `Application.start/2` (idempotent attach, same contract as `attach_default_handlers/0`).
- **D-04:** Reporter reads **`config :chimeway, :threadline_reporter`** for required `:repo` and `:actor` (`%Threadline.Semantics.ActorRef{}`); optional action-name overrides allowed. No per-notification host callbacks.

### Outcome mapping (telemetry → Threadline audit actions)
- **D-05:** Reporter listens to `:stop` events on these Chimeway spans and maps to `Threadline.record_action/2`:

  | Chimeway span | Detect | Default action atom |
  |---|---|---|
  | `[:chimeway, :policy, :evaluate]` | `suppression_reason` in meta | `:notification_suppressed` |
  | `[:chimeway, :policy, :evaluate]` | deferred (`planning_reason` present) | `:notification_deferred` |
  | `[:chimeway, :dispatch, :sync]` or `:perform` | dispatch completed | `:notification_dispatched` |
  | `[:chimeway, :attempts, :record]` | `outcome: :failed` | `:notification_failed` |

- **D-06:** Threadline action opts carry only **deterministic outcome metadata**: `correlation_id`, `category: "notifications"`, `reason` (suppression/planning/outcome atom as string), `comment` (bounded key=value summary). No payload, email, template, or provider response bodies.
- **D-07:** **`correlation_id`** from Chimeway telemetry meta is forwarded to Threadline `record_action/2` so `Threadline.Query.timeline/2` strict correlation filter links audit rows to Chimeway operator traces.
- **D-08:** Add **`planning_reason`** to `Chimeway.Telemetry` `@allowed_meta_keys` so deferred outcomes are explainable in telemetry (and bridge) without DB lookups — policy already emits it but `safe_meta/1` strips it today.

### Cross-repo ownership
- **D-09:** Phase 63 is **Chimeway-only**. Reporter calls public `Threadline.record_action/2`; no Threadline repo changes required for ECOS-08.

### Test harness & CI (Wave 63-01)
- **D-10:** Mirror Accrue/Mailglass selective CI: `@moduletag :threadline`, `--exclude threadline` on default `ci.test`, unconditional Threadline test config in `config/test.exs` (Accrue 58-01 precedent).
- **D-11:** Optional dep with **`THREADLINE_PATH`** env override for local dev (`../threadline` path-dep); `test/support/threadline_*` shim bootstraps `Threadline.TestRepo` like Mailglass/Accrue harness.
- **D-12:** Integration test proves **one notification lifecycle event → Threadline `audit_actions` row** with matching `correlation_id` — no demo host glue in test path.
- **D-13:** **`mix verify.threadline` alias deferred to Phase 66** (GATE-07). Phase 63 only adds tag + exclude wiring prep.

### Claude's Discretion
- Exact Threadline action atom names (defaults above) and whether `:notification_dispatched` fires on both sync and Oban perform paths.
- Default system actor (`ActorRef.new(:system, "chimeway")`) vs config-required actor.
- Whether succeeded deliveries also emit a Threadline action (ECOS-08 lists suppressed/deferred/dispatched/failed only — skip `:notification_succeeded` unless research finds gap).
- Test-support shim file layout (`test/support/threadline_*` vs nested under `integrations/`).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 63) | Success criteria, scope boundary vs Phases 65–66 |
| Requirement | `.planning/REQUIREMENTS.md` (ECOS-08) | Locked acceptance: four outcomes, attach-only, redaction |
| SEED-003 Threadline slice | `.planning/seeds/SEED-003-ecosystem-integrations.md` | Bridge intent — telemetry sink, unified observability |
| Chimeway telemetry façade | `lib/chimeway/telemetry.ex` | Event catalog, `safe_meta/1`, handler attach pattern |
| Policy telemetry | `lib/chimeway/policy.ex` | Suppress/defer span metadata (`suppression_reason`, `planning_reason`) |
| Delivery outcomes | `lib/chimeway/deliveries.ex` | Status transitions, `record_attempt/2`, attempt outcomes |
| Dispatch telemetry | `lib/chimeway/dispatch/sync.ex`, `lib/chimeway/dispatch/oban_worker.ex` | Dispatch span emission |
| Correlation tests | `test/chimeway/telemetry_correlation_test.exs` | Correlation ID persistence contract |
| Accrue CI pattern | `mix.exs` (`verify.accrue`, `ci.test` exclude), `config/test.exs` | Template for `:threadline` tag + test harness |
| Accrue integration test | `test/chimeway/integrations/accrue_dunning_lifecycle_test.exs` | Selective CI + lifecycle proof pattern |
| Phase 58 context | `.planning/milestones/v1.9-phases/58-accrue-dunning-core/58-CONTEXT.md` | Vertical-slice scope split (core vs demo/docs/gate) |
| Threadline public API | `../threadline/lib/threadline.ex` | `record_action/2` contract, correlation_id support |
| Threadline audit action tests | `../threadline/test/threadline/semantics/audit_action_test.exs` | Required/optional fields, correlation_id persistence |
| Threadline timeline query | `../threadline/lib/threadline/query.ex` | Strict `:correlation_id` filter semantics |
| v1.10 planning | `.planning/PROJECT.md`, `.planning/STATE.md` | Milestone scope, Mailglass-first template reuse |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Chimeway.Telemetry.span/3` + `safe_meta/1`** — single redaction enforcement point; bridge must not bypass.
- **Existing telemetry integration tests** — `test/chimeway/telemetry_integration_test.exs` proves span emission + PII stripping.
- **Accrue/Mailglass test harness** — `test/test_helper.exs` conditional repo bootstrap pattern for optional deps.
- **`Threadline.record_action/2`** — public write API with `correlation_id`, `category`, `reason`, `comment` for semantic audit rows.

### Established Patterns
- Optional ecosystem dep: `optional: true, runtime: false` + path env override (`ACCRUE_PATH` → `THREADLINE_PATH`).
- Selective CI: `@moduletag`, exclude from `ci.test`, dedicated `mix verify.*` in later gate phase.
- Phase scope split: core integration in N, demo + docs + verify gate in N+1/N+2 (Accrue 58→60 precedent).
- Host attach-only: Chimeway never auto-attaches telemetry handlers at library boot.

### Integration Points
- Reporter attaches to Chimeway `:telemetry` stop events → calls `Threadline.record_action/2` with configured repo/actor.
- `correlation_id` threads Chimeway trigger opts → delivery metadata → telemetry meta → Threadline audit row → operator timeline filter.
- Gap to close: `planning_reason` not in `@allowed_meta_keys` — blocks deferred outcome in bridge without fix (D-08).
</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as presented.
</specifics>

<deferred>
## Deferred Ideas

None — analysis stayed within phase scope.

### Reviewed Todos (not folded)

No pending todos matched Phase 63 scope.
</deferred>
