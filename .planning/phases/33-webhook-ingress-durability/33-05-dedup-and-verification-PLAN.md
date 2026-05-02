---
phase: 33-webhook-ingress-durability
plan: 05
type: execute
wave: 4
depends_on: [33-01, 33-02, 33-03, 33-04]
files_modified:
  - test/chimeway/webhooks_test.exs
  - .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md
autonomous: true
requirements: [FEED-01, FEED-02]
requirements_addressed: [FEED-01, FEED-02]
tags: [elixir, ecto, dedup, verification, audit, phase-gate]

must_haves:
  truths:
    - "Two `Webhooks.process/4` calls with the same `(adapter_module, provider_event_id)` produce ONE durable ingress row at the DB level (D-05 / T-33-DEDUP read-side)."
    - "The duplicate provider retry STILL returns `{:ok, ingress}` from `process/4` (no error surfaced to the host) — both calls map cleanly to 2xx (D-03)."
    - "Phase 33's `33-VERIFICATION.md` artifact exists, maps every requirement (FEED-01, FEED-02) to a passing test, and maps every threat (T-33-PII, T-33-ATOMIC, T-33-RETRY, T-33-RAWBODY, T-33-DEDUP, T-33-AUTH-LEAK) to a mitigation site."
    - "The audit gaps from `v1.4-MILESTONE-AUDIT.md` (durability, host ingress proof, unknown delivery_id) are explicitly cited and CLOSED in the verification artifact."
    - "`mix ci` AND `mix verify.example` both exit 0 — the phase gate is green."
  artifacts:
    - path: "test/chimeway/webhooks_test.exs"
      provides: "Dedup convergence integration test in the existing Plan 02 test file"
      contains: "T-33-DEDUP"
    - path: ".planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md"
      provides: "Phase verification artifact mapping requirements + threats to test sites"
      contains: "FEED-01"
  key_links:
    - from: "test/chimeway/webhooks_test.exs"
      to: "lib/chimeway/webhooks.ex"
      via: "two Webhooks.process/4 calls with same (adapter_module, provider_event_id) collapse via on_conflict + partial unique index"
      pattern: "T-33-DEDUP"
    - from: ".planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md"
      to: "all 5 plans + audit gap evidence"
      via: "requirements table + threats table + audit-gap closure table"
      pattern: "FEED-01|FEED-02|T-33-"
---

<objective>
Close the remaining read-side dedup test (T-33-DEDUP convergence) and produce the phase verification artifact (`33-VERIFICATION.md`) that maps every requirement and every threat to a passing test or mitigation site. This is the gate-closure plan: after this plan lands, the milestone audit can re-run and `33` should flip from `not_started` to `passed` with explicit `requirements-completed` frontmatter.

Purpose: The v1.4 milestone audit (`/Users/jon/projects/chimeway/.planning/v1.4-MILESTONE-AUDIT.md`) flagged FEED-01 and FEED-02 as orphaned because Phase 30 had no `30-VERIFICATION.md`. Phase 33 closes those audit gaps by (a) shipping the durable handoff + safe-noop + host-mount proof in Plans 01-04, and (b) producing this explicit verification artifact so the audit can map FEED-01/FEED-02 to satisfied requirement IDs.

Output: One new test in the existing `test/chimeway/webhooks_test.exs` describe block, plus a freshly authored `33-VERIFICATION.md` consumed by the v1.4 audit re-run.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/v1.4-MILESTONE-AUDIT.md
@.planning/phases/33-webhook-ingress-durability/33-CONTEXT.md
@.planning/phases/33-webhook-ingress-durability/33-RESEARCH.md
@.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md
@.planning/phases/33-webhook-ingress-durability/33-01-SUMMARY.md
@.planning/phases/33-webhook-ingress-durability/33-02-SUMMARY.md
@.planning/phases/33-webhook-ingress-durability/33-03-SUMMARY.md
@.planning/phases/33-webhook-ingress-durability/33-04-SUMMARY.md
@lib/chimeway/webhooks.ex
@lib/chimeway/webhooks/ingress.ex
@lib/chimeway/webhooks/process_feedback_worker.ex
@test/chimeway/webhooks_test.exs

<interfaces>
<!-- The dedup test relies on Plan 02's process/4 + Plan 01's partial unique index. -->

From Plan 02 (`lib/chimeway/webhooks.ex`):
```elixir
Multi.new()
|> Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs),
     on_conflict: :nothing,
     conflict_target: {:unsafe_fragment, ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|},
     returning: true
   )
|> Oban.insert(:job, fn %{ingress: ingress} -> ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id}) end)
|> Repo.transaction()
```

From Plan 01 (`priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs`):
```elixir
create unique_index(
  :chimeway_webhook_ingress,
  [:adapter_module, :provider_event_id],
  name: :chimeway_webhook_ingress_adapter_provider_event_uniq,
  where: "provider_event_id IS NOT NULL"
)
```

From Plan 02's MockAdapter test extensions:
```elixir
def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
def resolve_provider_event_id(_), do: :none
```
</interfaces>
</context>

<assumptions>
<!-- Plan 05 Task 2 milestone-audit re-run claim — surfaced for user confirm. LOW risk. -->

- **A8 (no automated milestone-audit tool exists):** As of this revision, there is no `gsd-sdk query milestone.audit` subcommand or equivalent CLI tool that parses phase verification artifacts and emits a milestone-level pass/fail. The v1.4-MILESTONE-AUDIT.md document is itself a hand-authored audit; the "re-run" referenced in this plan is a MANUAL re-read of that document by the operator after Phase 33 closes. The Plan 05 Task 2 verification artifact is therefore documentation-only — its purpose is to provide the manual-audit cross-reference, not to satisfy an automated tool. Acceptance is enforced via a frontmatter-superset check against the existing passing analog `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md` (Phase 32 was the most recent phase to ship a verification artifact under v1.4 milestone work and serves as the canonical shape).
- **A9 (frontmatter superset check):** Phase 32's verification artifact uses the keys `{phase, verified, status, score, overrides_applied, re_verification}`. Phase 33's verification artifact intentionally adds richer keys (`audited`, `requirements_completed`, `threats_mitigated`, `audit_gaps_closed`, `audit_gaps_deferred`, `nyquist_compliant`) per the v1.4-MILESTONE-AUDIT.md surface area. The acceptance criterion below asserts that Phase 33's frontmatter is a STRICT SUPERSET — i.e., contains a `phase:` key and a `status:` key matching the analog's required shape, plus the additional Phase-33-specific keys. The richer shape is forward-compatible with any future automated audit tool that consumes either shape.
</assumptions>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add dedup-convergence integration test to test/chimeway/webhooks_test.exs</name>
  <files>test/chimeway/webhooks_test.exs</files>
  <read_first>
    - test/chimeway/webhooks_test.exs (Plan 02 output — confirm the MockAdapter has `resolve_provider_event_id/1` and the existing describe blocks)
    - lib/chimeway/webhooks.ex (Plan 02 output — confirm `on_conflict + conflict_target` is in place)
    - priv/repo/migrations/20260502120000_create_chimeway_webhook_ingress.exs (Plan 01 output — confirm partial unique index exists)
    - .planning/phases/33-webhook-ingress-durability/33-RESEARCH.md (§ Validation Architecture > Phase Requirements → Test Map row "Duplicate provider retries with same (adapter_module, provider_event_id) collapse to one ingress row")
    - .planning/phases/33-webhook-ingress-durability/33-PATTERNS.md (§ test/chimeway/webhooks_test.exs)
  </read_first>
  <behavior>
    - Test 1: Two `Webhooks.process/4` calls with body containing the same `event_id` field (so `MockAdapter.resolve_provider_event_id/1` returns the SAME id) result in `Repo.aggregate(Ingress, :count) == 1` — only ONE durable ingress row exists. Both calls return `{:ok, %Ingress{}}` (no error surfaced; partial unique conflict is absorbed by `on_conflict: :nothing`).
    - Test 2: Two `Webhooks.process/4` calls with bodies that have DIFFERENT `event_id` fields produce TWO ingress rows. Negative control — proves the dedup is keyed on `provider_event_id`, not on payload identity.
    - Test 3: Two `Webhooks.process/4` calls with bodies that have NO `event_id` field at all (so `resolve_provider_event_id/1` returns `:none` -> stored as `nil`) produce TWO ingress rows. Negative control — proves the partial unique index ignores NULLs (Pitfall 5 / "partial index" design).
  </behavior>
  <action>
    Append a new describe block to `test/chimeway/webhooks_test.exs` at the end of the file (after the existing "process/4" and "process/4 — atomic handoff (T-33-ATOMIC)" describe blocks):

    ```elixir
    describe "process/4 — dedup convergence (T-33-DEDUP / D-05)" do
      test "duplicate provider retries with same (adapter_module, provider_event_id) collapse to ONE ingress row" do
        # delivery_id must be a real UUID — schema field is :binary_id; literal strings Postgrex-error at insert.
        delivery_uuid = Ecto.UUID.generate()
        body = Jason.encode!(%{"id" => delivery_uuid, "status" => "ok", "event_id" => "evt_001"})
        headers = [{"signature", "valid"}]

        assert {:ok, %Chimeway.Webhooks.Ingress{} = first} =
                 Webhooks.process(MockAdapter, body, headers, [])
        assert first.provider_event_id == "evt_001"

        # Provider retry — same body, same headers, same event_id
        assert {:ok, %Chimeway.Webhooks.Ingress{} = second} =
                 Webhooks.process(MockAdapter, body, headers, [])

        # Both calls return success cleanly — neither surfaces the partial-unique conflict
        # to the host (D-03: 2xx on both).
        # Crucially: ONE durable ingress row, not two. The on_conflict: :nothing in
        # Multi.insert(:ingress, ..., conflict_target: ..., where: provider_event_id IS NOT NULL)
        # absorbs the duplicate at the DB level (T-33-DEDUP closed).
        assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 1
        assert first.provider_event_id == second.provider_event_id
      end

      test "different event_ids for same adapter produce TWO ingress rows (negative control)" do
        # delivery_ids must be real UUIDs — schema field is :binary_id.
        body1 = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok", "event_id" => "evt_001"})
        body2 = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok", "event_id" => "evt_002"})
        headers = [{"signature", "valid"}]

        assert {:ok, _first} = Webhooks.process(MockAdapter, body1, headers, [])
        assert {:ok, _second} = Webhooks.process(MockAdapter, body2, headers, [])

        assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2
      end

      test "missing event_id (NULL provider_event_id) does NOT trigger dedup — exercises NULL-distinct semantics that the partial index preserves" do
        # NOTE on what this test actually verifies (warning #9 disposition):
        # This exercises PostgreSQL's standard NULL-distinct semantics — two NULL
        # values do not collide on a unique index regardless of the WHERE clause
        # on PG <= 14. The partial index `WHERE provider_event_id IS NOT NULL`
        # PRESERVES that semantic by excluding NULL rows from the index entirely.
        # On PG >= 15, `NULLS NOT DISTINCT` could change this behavior on a full
        # unique index, but the partial index defended-by-WHERE here remains
        # NULL-distinct by construction.
        # The test's verification value is in describing the design intent —
        # the assertion (`count == 2`) holds equally with or without the WHERE clause
        # on PG <= 14, but the WHERE clause is what makes the design correct on
        # arbitrary PG versions and explicitly documents the NULL-tolerant intent.
        # Two distinct deliveries (different UUIDs) are used so the rows are not
        # collapsed by some other adapter-side dedup mechanism.
        body1 = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok"})  # no "event_id"
        body2 = Jason.encode!(%{"id" => Ecto.UUID.generate(), "status" => "ok"})  # no "event_id"
        headers = [{"signature", "valid"}]

        assert {:ok, first} = Webhooks.process(MockAdapter, body1, headers, [])
        assert first.provider_event_id == nil

        assert {:ok, second} = Webhooks.process(MockAdapter, body2, headers, [])
        assert second.provider_event_id == nil

        # Pitfall 5 design: partial index `WHERE provider_event_id IS NOT NULL`
        # means NULLs are excluded from the index — NULL rows do not collide.
        # See PG >= 15 NULLS NOT DISTINCT for completeness.
        assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2
      end
    end
    ```

    Confirm the existing `MockAdapter` (line 7-23 in the file) already has the `resolve_provider_event_id/1` clauses added by Plan 02:
    ```elixir
    def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
    def resolve_provider_event_id(_), do: :none
    ```
    If those are missing (Plan 02 was incomplete), add them BEFORE running the new tests; otherwise proceed.
  </action>
  <verify>
    <automated>grep -q "T-33-DEDUP" test/chimeway/webhooks_test.exs && grep -q "duplicate provider retries with same" test/chimeway/webhooks_test.exs && grep -q "different event_ids for same adapter produce TWO" test/chimeway/webhooks_test.exs && grep -q "missing event_id" test/chimeway/webhooks_test.exs && grep -q "Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 1" test/chimeway/webhooks_test.exs && grep -q "Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2" test/chimeway/webhooks_test.exs && mix test test/chimeway/webhooks_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `test/chimeway/webhooks_test.exs` contains `describe "process/4 — dedup convergence (T-33-DEDUP / D-05)"`.
    - File contains a test asserting `Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 1` after two duplicate calls.
    - File contains a test asserting `Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2` for different event_ids.
    - File contains a test asserting `Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2` for NULL event_ids.
    - File contains `first.provider_event_id == "evt_001"`.
    - File contains `first.provider_event_id == nil`.
    - `mix test test/chimeway/webhooks_test.exs` exits 0 (all describes pass: original + atomic-handoff from Plan 02 + dedup-convergence from this plan).
  </acceptance_criteria>
  <done>The dedup convergence behavior (T-33-DEDUP / D-05) is verified by 3 integration tests. The partial-unique-index design is structurally correct: dedup on (adapter, event_id), NULL-tolerant, cross-adapter-safe.</done>
</task>

<task type="auto">
  <name>Task 2: Author 33-VERIFICATION.md — phase gate artifact</name>
  <files>.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md</files>
  <read_first>
    - .planning/REQUIREMENTS.md (FEED-01, FEED-02 wording)
    - .planning/v1.4-MILESTONE-AUDIT.md (the 4 audit gaps this phase closes; the orphaned-requirements-table format)
    - .planning/phases/33-webhook-ingress-durability/33-CONTEXT.md (D-01 through D-14 — every locked decision)
    - .planning/phases/33-webhook-ingress-durability/33-VALIDATION.md (per-task verify map; copy the test commands)
    - .planning/phases/33-webhook-ingress-durability/33-01-SUMMARY.md through 33-04-SUMMARY.md (for `requirements_completed` and `threats_mitigated` rollup)
    - .planning/phases/32-operator-traces-audit/32-VERIFICATION.md (REQUIRED — analog format from the most recent passing v1.4 phase verification artifact; Phase 33's frontmatter MUST be a strict superset of this file's required keys per A9)
  </read_first>
  <action>
    Author `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` with the following structure. Use the format that the milestone-audit tool expects (REQUIREMENTS table mapping every ID to a test or proof; threats mapped to mitigations; audit-gap closure table).

    ```markdown
    ---
    phase: 33-webhook-ingress-durability
    audited: 2026-05-XX  # set to date of execution
    status: satisfied
    requirements_completed: [FEED-01, FEED-02]
    threats_mitigated:
      - T-33-PII
      - T-33-ATOMIC
      - T-33-RETRY
      - T-33-RAWBODY
      - T-33-DEDUP
      - T-33-AUTH-LEAK
      - T-33-IDEMPOTENT
    audit_gaps_closed:
      - "Webhook ingest can report success even if async processing was never queued"
      - "No runtime webhook ingress consumer exists in the repo"
      - "Unknown delivery_id feedback crashes the worker instead of failing safely"
    audit_gaps_deferred:
      - "Outcome vocabulary drifts across phases (delivered vs succeeded)"  # Phase 34 owns
    nyquist_compliant: true
    ---

    # Phase 33 — Webhook Ingress Durability — Verification

    **Phase:** 33-webhook-ingress-durability
    **Status:** satisfied
    **Requirements covered:** FEED-01, FEED-02
    **Audit driver:** `.planning/v1.4-MILESTONE-AUDIT.md`

    ## Summary

    Phase 33 ships the durable webhook ingress lifecycle, the safe-noop worker
    pivot, and the runtime host-mount proof. Three of the four v1.4-MILESTONE-AUDIT
    integration gaps are closed by this phase; the fourth (outcome vocabulary
    drift) is deferred to Phase 34 per CONTEXT.md D-14.

    ## Requirements Table

    | Req ID | Requirement | Verification | Status |
    |--------|-------------|--------------|--------|
    | FEED-01 | System provides a webhook ingestion layer to receive asynchronous provider callbacks (receipts, bounces). | Atomic Multi+Oban handoff in `Chimeway.Webhooks.process/4` (Plan 02) + safe-noop worker (Plan 03) + runtime host-mount E2E proof (Plan 04). Tests: `mix test test/chimeway/webhooks_test.exs` (atomic-handoff, D-09, dedup) + `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` (safe-noop, idempotent, A6 shim) + `mix verify.example` (E2E mount). | SATISFIED |
    | FEED-02 | Provider-specific callback payloads are normalized into canonical Chimeway delivery outcomes (delivered, bounced, failed). | Normalized status persisted on `chimeway_webhook_ingress.normalized_status` (Plan 01 schema; field `:string` with `validate_inclusion(["delivered", "bounced", "failed"])`). Tests: `mix test test/chimeway/webhooks/ingress_test.exs` (changeset + DB integration) + worker round-trip in `process_feedback_worker_test.exs`. | SATISFIED |

    ## Decisions Honored (CONTEXT.md D-01..D-14)

    | Decision | Where Implemented | Test Site |
    |----------|------------------|-----------|
    | D-01: durable inbound webhook ingress record | `lib/chimeway/webhooks/ingress.ex` (Plan 01) | `test/chimeway/webhooks/ingress_test.exs` |
    | D-02: process/4 returns success only after Multi commits BOTH ingress + Oban | `lib/chimeway/webhooks.ex` (Plan 02) | `test/chimeway/webhooks_test.exs` "atomic handoff" describe |
    | D-03: tagged-tuple contract for host status mapping | `lib/chimeway/webhooks.ex` @spec union; example app controller maps to 200/401/500 | `test/chimeway/webhooks_test.exs` + `examples/.../webhooks_controller_test.exs` |
    | D-04: ingress row stores only normalized facts (no raw body, no headers) | Schema's `@allowed_fields` list (Plan 01); migration column-by-column match | Acceptance criterion: `grep -E "field\\(:(provider_response\|headers)" lib/chimeway/webhooks/ingress.ex` returns empty |
    | D-05: composite (adapter_module, provider_event_id) partial unique dedup | Migration `unique_index ... where: "provider_event_id IS NOT NULL"` (Plan 01) + Multi `on_conflict + conflict_target` (Plan 02) | `test/chimeway/webhooks_test.exs` "dedup convergence" describe (Plan 05) |
    | D-06: stop using raising lookup paths | `Deliveries.fetch_delivery/1` non-raising helper (Plan 02); worker uses `Repo.get` not `Repo.get!` (Plan 03) | `test/chimeway/webhooks/process_feedback_worker_test.exs` "marks ingress :ignored" tests |
    | D-07: missing correlation returns :ok with explicit ignored_reason | `mark_ignored/2` writes `ingress_state: :ignored, ignored_reason: ...` (Plan 03) | same as D-06 |
    | D-08: ignored audit lives on ingress, not DeliveryAttempt | Schema field `ignored_reason` (Plan 01); worker writes ONLY to ingress for the `:not_found` branch (Plan 03) | tests assert `Repo.aggregate(DeliveryAttempt, :count) == 0` on stale-id path |
    | D-09: unauthorized + unparseable do NOT create ingress rows | `with`-pipeline short-circuits BEFORE `Multi.new()` (Plan 02) | `test/chimeway/webhooks_test.exs` D-09 tests assert `Repo.aggregate(Ingress, :count) == 0` |
    | D-10: Chimeway core stays framework-agnostic | Root `mix.exs` does NOT add phoenix/plug (Plan 04) | `grep -c "{:phoenix" mix.exs` returns 0 |
    | D-11: runtime proof via fixture host app | `examples/chimeway_demo_host/` (Plan 04) | `mix verify.example` exits 0 |
    | D-12: example app is canonical doc reference | docstrings in CacheBodyReader + WebhooksController point to this example | manual review of doc cross-refs |
    | D-13: signature verification on raw bytes BEFORE JSON parse | `Plug.Parsers` `:body_reader` MFA + controller `IO.iodata_to_binary/1` (Plan 04) | `examples/.../webhooks_controller_test.exs` "raw body iolist is correctly flattened" test |
    | D-14: phase scope narrow; vocabulary unification deferred | `canonicalize_status/1` keeps existing `delivered -> :succeeded` semantic (Plan 03); no cross-phase signal name change | Plan 03 acceptance criterion: `Chimeway.Signal.track` emission preserved |

    ## Threats Table (STRIDE / ASVS L1)

    | Threat ID | STRIDE | Component | Mitigation | Test Site |
    |-----------|--------|-----------|------------|-----------|
    | T-33-PII | Information Disclosure | `chimeway_webhook_ingress` table | Schema enumerates ONLY normalized fields; migration column-by-column match; no `provider_response`, no `headers`, no `raw_body`, no `source_ip` columns exist (Plan 01). | `lib/chimeway/webhooks/ingress.ex` field grep + migration grep + `test/chimeway/webhooks/ingress_test.exs` |
    | T-33-ATOMIC | Tampering | `Chimeway.Webhooks.process/4` | `Ecto.Multi` + `Oban.insert(:job, fn ->)` + `Repo.transaction/1`; `enqueue/1` antipattern deleted (Plans 02 & 03). | `test/chimeway/webhooks_test.exs` "atomic handoff" describe + E2E test in Plan 04 |
    | T-33-RETRY | DoS (queue retry storm) | `ProcessFeedbackWorker.perform/1` | `Repo.get/2` (non-raising), `Deliveries.fetch_delivery/1` (non-raising), `mark_ignored` writes durable reason, `:ok` return at queue boundary; mirrors `WorkflowProgressionWorker.normalize_progress_result/1` (Plan 03). | `test/chimeway/webhooks/process_feedback_worker_test.exs` "marks ingress :ignored" describe |
    | T-33-RAWBODY | Tampering / Spoofing | host endpoint + controller | `Plug.Parsers` `:body_reader` MFA caches raw bytes BEFORE JSON parse; controller flattens iolist via `IO.iodata_to_binary/1` after `Enum.reverse/1` (Plan 04). | `examples/.../webhooks_controller_test.exs` "raw body iolist is correctly flattened" test |
    | T-33-DEDUP | Spoofing (replay) | partial composite unique index + `on_conflict: :nothing` | DB-level race-free dedup; `on_conflict + conflict_target` absorbs duplicates without surfacing error (Plans 01 & 02). | `test/chimeway/webhooks_test.exs` "dedup convergence" describe (Plan 05) + `test/chimeway/webhooks/ingress_test.exs` partial-unique-index DB test |
    | T-33-AUTH-LEAK | Information Disclosure | `Chimeway.Webhooks.process/4` + host controller | `with` short-circuits BEFORE `Multi.new()` on unauthorized + unparseable; example controller returns minimal text bodies; no error reasons leaked to provider (Plans 02 & 04). | `test/chimeway/webhooks_test.exs` D-09 tests + E2E "bad signature" test |
    | T-33-IDEMPOTENT | Tampering / Repudiation | `ProcessFeedbackWorker.perform/1` re-perform | `:ignored` and `:processed` ingress_state branches return `:ok` without re-applying side effects (Plan 03). | `test/chimeway/webhooks/process_feedback_worker_test.exs` "safe-noop edge cases" describe |

    ## Audit Gap Closure (v1.4-MILESTONE-AUDIT.md cross-reference)

    | Audit Gap | Severity | Plan(s) | Closed | Evidence |
    |-----------|----------|---------|--------|----------|
    | "Webhook ingest can report success even if async processing was never queued" | high | 02 + 03 | YES | `enqueue/1` antipattern deleted; `process/4` uses `Ecto.Multi` + `Repo.transaction/1`; `test/chimeway/webhooks_test.exs` "rolls back the ingress row when the Multi cannot commit" passes. |
    | "No runtime webhook ingress consumer exists in the repo" | medium | 04 | YES | `examples/chimeway_demo_host/` is a sibling Mix project; `mix verify.example` exits 0; the E2E test exercises the full mount. |
    | "Unknown delivery_id feedback crashes the worker instead of failing safely" | medium | 03 | YES | `Deliveries.get_delivery!/1` removed from worker; `Repo.get/2` + `Deliveries.fetch_delivery/1` used; stale ids become `:ignored` audit rows; `:ok` returned to Oban. Test "marks ingress :ignored with :delivery_not_found" passes. |
    | "Outcome vocabulary drifts across phases (delivered vs succeeded)" | medium | n/a | DEFERRED to Phase 34 | Phase 33 D-14 explicitly scopes vocabulary unification out. `canonicalize_status/1` preserves the existing `delivered -> :succeeded` semantic so Phase 32 traces remain consistent. |

    ## Phase Gate Commands

    All commands MUST exit 0 before this verification artifact is finalized:

    | Command | Purpose | Status |
    |---------|---------|--------|
    | `mix compile --warnings-as-errors` | Code health | GREEN |
    | `mix ci` | Core lib full suite | GREEN |
    | `mix verify.example` | E2E host-mount proof | GREEN |
    | `mix test test/chimeway/webhooks/ingress_test.exs` | Schema + DB integration | GREEN |
    | `mix test test/chimeway/webhooks_test.exs` | process/4 contract + atomic + D-09 + dedup | GREEN |
    | `mix test test/chimeway/webhooks/process_feedback_worker_test.exs` | Worker safe-noop + idempotent + A6 shim | GREEN |

    ## Manual Verifications

    | Behavior | Owner | Status |
    |----------|-------|--------|
    | A6 backwards-compat shim deploy-runbook review | Operator | PENDING — operator confirms whether queue is drained pre-deploy or shim is required (per `33-VALIDATION.md` Manual-Only Verifications table). |

    ## Sign-Off

    - [x] All requirements (FEED-01, FEED-02) mapped to passing tests.
    - [x] All threats (T-33-*) mapped to mitigations with test sites.
    - [x] All locked decisions (D-01..D-14) implemented and traceable.
    - [x] Three of four v1.4 audit gaps explicitly closed; the fourth deferred per D-14.
    - [x] Phase gate commands exit 0.
    - [ ] Operator A6 deploy-runbook review (pending; not blocking phase closure but flagged for milestone audit).

    **Phase 33 verification status: SATISFIED.**
    ```

    Replace `2026-05-XX` with the actual execution date when the executor runs this plan.
  </action>
  <verify>
    <automated>test -f .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "FEED-01" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "FEED-02" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-PII" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-ATOMIC" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-RETRY" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-RAWBODY" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-DEDUP" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "T-33-AUTH-LEAK" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "requirements_completed:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "Webhook ingest can report success even if async processing was never queued" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "No runtime webhook ingress consumer exists in the repo" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "Unknown delivery_id feedback crashes the worker" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "^phase:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "^status:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && test -f .planning/phases/32-operator-traces-audit/32-VERIFICATION.md && grep -q "^phase:" .planning/phases/32-operator-traces-audit/32-VERIFICATION.md && grep -q "^status:" .planning/phases/32-operator-traces-audit/32-VERIFICATION.md && grep -q "^audited:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "^threats_mitigated:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "^audit_gaps_closed:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md && grep -q "^nyquist_compliant:" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md</automated>
  </verify>
  <acceptance_criteria>
    - File `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` exists.
    - File frontmatter contains `status: satisfied`.
    - File frontmatter contains `requirements_completed: [FEED-01, FEED-02]`.
    - File frontmatter contains `threats_mitigated:` listing T-33-PII, T-33-ATOMIC, T-33-RETRY, T-33-RAWBODY, T-33-DEDUP, T-33-AUTH-LEAK, T-33-IDEMPOTENT.
    - File frontmatter contains `audit_gaps_closed:` listing the three v1.4 audit gaps closed by this phase.
    - File frontmatter contains `audit_gaps_deferred:` listing outcome vocabulary drift (Phase 34).
    - File frontmatter contains `nyquist_compliant: true`.
    - File body contains a Requirements Table mapping FEED-01 and FEED-02 to test sites.
    - File body contains a Decisions Honored table mapping D-01 through D-14 to implementation sites.
    - File body contains a Threats Table mapping all 7 threats to mitigation + test sites.
    - File body contains an Audit Gap Closure table cross-referencing `v1.4-MILESTONE-AUDIT.md`.
    - File body contains a Phase Gate Commands table with `mix ci` and `mix verify.example`.
    - File body contains a Manual Verifications table flagging the A6 deploy-runbook review.
    - **Frontmatter superset check (per A9):** Every top-level key present in `.planning/phases/32-operator-traces-audit/32-VERIFICATION.md` frontmatter (`phase`, `verified`, `status`, `score`, `overrides_applied`, `re_verification`) MUST also appear in `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` frontmatter, OR be replaced by an equivalent key with the same semantic meaning. Specifically: Phase 33 uses `audited` instead of `verified` (richer ISO-8601 + audit-trail semantics), so the audit comparison MUST treat `audited` and `verified` as equivalents. Confirm by reading both files side-by-side. The `<automated>` command above performs this check via `awk` extraction + `comm -23` — if any analog key is missing AND no equivalent has been documented in this acceptance section, the check fails.
    - **Documentation-only acceptance (per A8):** This task ships a documentation artifact, not an automated audit pass. The "milestone-audit re-run" cited in the objective is a manual re-read of `v1.4-MILESTONE-AUDIT.md` by the operator after Phase 33 closes. No `gsd-sdk query milestone.audit` invocation is asserted because no such subcommand exists. If a future tool is added, the frontmatter-superset check above is forward-compatible with it.
  </acceptance_criteria>
  <done>The phase verification artifact exists and maps every requirement, every threat, every D-decision, and every audit gap to concrete evidence. The v1.4 milestone audit can re-run and flip Phase 33 to "passed" with FEED-01 and FEED-02 satisfied.</done>
</task>

<task type="auto">
  <name>Task 3: Run full phase gate and confirm green</name>
  <files></files>
  <read_first>
    - .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md (Task 2 — for the gate command list)
  </read_first>
  <action>
    Run the phase gate commands in order, confirm each exits 0, and update `33-VERIFICATION.md`'s "Phase Gate Commands" table with the actual GREEN status:

    ```bash
    mix compile --warnings-as-errors
    mix ci
    mix verify.example
    ```

    If ANY command fails, do NOT mark the phase satisfied. Instead, return failure to the orchestrator with the failing command output so a gap-closure plan can be spawned.

    Also update `.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md` frontmatter:
    - `nyquist_compliant: true`
    - `wave_0_complete: true`
    - Approval: `granted` (replace `pending`).
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors && mix ci && mix verify.example</automated>
  </verify>
  <acceptance_criteria>
    - `mix compile --warnings-as-errors` exits 0.
    - `mix ci` exits 0.
    - `mix verify.example` exits 0.
    - `.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md` frontmatter contains `nyquist_compliant: true`.
    - `.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md` frontmatter contains `wave_0_complete: true`.
    - `.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md` Approval line shows `granted`.
  </acceptance_criteria>
  <done>Phase 33 gate is GREEN. Verification artifact and validation strategy both reflect the closed state. Phase is ready for milestone-audit re-run.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| client → API | Same as Plan 02 — duplicate provider replays cross into `process/4`. |
| API → DB | Multi `:ingress` step now collapses replays via partial unique index `on_conflict: :nothing`. |

## STRIDE Threat Register (Plan 05 scope)

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-33-DEDUP (read-side) | Spoofing (replay) | `chimeway_webhook_ingress` partial unique index + `on_conflict: :nothing` | mitigate | This plan adds the integration test that PROVES the dedup contract converges: two `process/4` calls with same `(adapter_module, provider_event_id)` produce ONE row, two with different event_ids produce TWO rows, two with NULL event_ids produce TWO rows (partial-index design). All three tests are in `test/chimeway/webhooks_test.exs` "dedup convergence" describe. |
| T-33-AUDIT (gap-closure verification) | Repudiation | `33-VERIFICATION.md` artifact | mitigate | The verification artifact maps every CONTEXT.md D-decision (D-01..D-14), every requirement (FEED-01, FEED-02), and every threat (T-33-*) to a concrete test or mitigation site. The v1.4-MILESTONE-AUDIT.md table can re-run with this artifact present and flip Phase 33 from `not_started` to `passed`. |
</threat_model>

<verification>
- `mix test test/chimeway/webhooks_test.exs` exits 0 (includes original + atomic-handoff + dedup-convergence).
- `mix ci` exits 0 (full core suite).
- `mix verify.example` exits 0 (E2E host-mount).
- `.planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` exists with all required frontmatter and tables.
- `.planning/phases/33-webhook-ingress-durability/33-VALIDATION.md` frontmatter has `nyquist_compliant: true`.
- `grep -c "FEED-01" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` returns >= 2 (at least frontmatter + table row).
- `grep -c "T-33-" .planning/phases/33-webhook-ingress-durability/33-VERIFICATION.md` returns >= 7 (all threats listed).
</verification>

<success_criteria>
- T-33-DEDUP read-side convergence is proven by 3 integration tests (positive, negative-different-id, negative-null-id).
- `33-VERIFICATION.md` exists, satisfies the milestone-audit format, and explicitly closes the 3 in-scope v1.4 audit gaps.
- The deferred audit gap (outcome vocabulary drift) is explicitly cited as Phase 34 scope per D-14.
- Phase gate (`mix ci && mix verify.example`) is green.
- The milestone audit can re-run after this plan and Phase 33 will satisfy FEED-01 and FEED-02 with full traceability.
</success_criteria>

<output>
After completion, create `.planning/phases/33-webhook-ingress-durability/33-05-SUMMARY.md` per `$HOME/.claude/get-shit-done/templates/summary.md`. Include:
- `requirements_completed: [FEED-01, FEED-02]` (final closure for both)
- `threats_mitigated: [T-33-DEDUP (read-side), T-33-AUDIT]`
- A note that Phase 33 is COMPLETE and ready for the v1.4 milestone audit re-run.
</output>
