# Phase 52: Doc Truth & Gates - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Close adoption-evidence doc drift and align release-gate documentation with the expanded READ journey suite — completing v1.7 close-out without code or CI behavior changes.

**In scope:** DOCS-04 (demo host README webhook/TraceDemo narrative fix); DOCS-05 (`mix demo.up --check` moduledoc + README command table truth); GATE-03 (`MAINTAINING.md` pre-ship quintet, `mix.exs` comment, stale planning doc counts for JOUR-01..08 / 9 tests).

**Out of scope:** New journey tests (Phase 51 shipped JOUR-06..08); `demo.up` behavior changes; CI job or `verify.journeys` alias changes; `doc_contract_test.exs` expansion for demo README (optional follow-on); Playwright (INV-004 deferral).

</domain>

<decisions>
## Implementation Decisions

### Scope fence — documentation only
- **D-01:** Phase 52 ships documentation updates only — no new journey tests, no `demo.up` runtime behavior changes, no CI workflow changes. JOUR-06..08 already pass under `mix verify.journeys` (9 tests, 0 failures per Phase 51 verification).

### DOCS-04 — Demo host README truth + narrative unification
- **D-02:** Replace "Payment escalation awaiting webhook" persona row with READ-driven `:waiting` escalation language aligned to Phase 50 / `DemoHost.Seeds` / `mention-escalation.md`.
- **D-03:** Reframe (not delete) the "Not this path: webhook progression" section so Morgan's payment-escalation scenario is clearly READ-driven; retain Golden Path webhook appendix as the separate webhook-progression path.
- **D-04:** Keep `TraceDemo` as supplementary IEx trace walkthrough (`mix demo.trace`, `demo_user_1`); TeamPulse personas (`alex@teampulse.test`, Sam, Morgan) remain the primary adoption narrative. Unify the README so both paths are coherent, not competing origin stories.

### DOCS-05 — `mix demo.up --check` moduledoc truth
- **D-05:** Update `@moduledoc` in `lib/mix/tasks/demo.up.ex` and the demo host README command table: `--check` runs `ecto.migrate` + `app.start` + `demo.seed`, skipping only `ecto.create` — not "seed only."
- **D-06:** Align `mix demo.up` and `mix demo.up --serve` descriptions with actual behavior (migrate + seed + banner; serve adds `demo.admin`).

### GATE-03 — Release gate documentation
- **D-07:** Update `MAINTAINING.md` pre-ship quintet bullet for `mix verify.journeys` to JOUR-01..08 (GATE-03), explicitly noting READ journey proof including JOUR-06 read-cancel + time-fallback.
- **D-08:** Update `mix.exs` `verify.journeys` alias comment from GATE-02 / JOUR-01..05 to GATE-03 / JOUR-01..08.
- **D-09:** Update stale journey-count references in `.planning/PROJECT.md` (currently "5 journey tests") to 9 tests / JOUR-01..08. No alias or CI job change required.

### Claude's Discretion
- Whether to update `guides/recipes/mention-escalation.md` line 90 ("JOUR-06 (Phase 51)") in this pass or leave as minor drift.
- Whether `.planning/RETROSPECTIVE.md` journey counts get a light touch-up in this phase or defer to milestone close.
- Exact README section ordering for TraceDemo vs TeamPulse unification (content truth is locked; layout is flexible).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` — Phase 52 goal, success criteria (DOCS-04, DOCS-05, GATE-03)
- `.planning/REQUIREMENTS.md` — DOCS-04, DOCS-05, GATE-03 acceptance criteria
- `.planning/PROJECT.md` — v1.7 milestone, journey CI posture (stale count to fix)

### Prior phase context
- `.planning/phases/51-journey-admin-proof/51-CONTEXT.md` — D-06 GATE-03 deferred here; JOUR-06..08 scope
- `.planning/phases/51-journey-admin-proof/51-VERIFICATION.md` — 9-test journey suite evidence
- `.planning/phases/50-natural-escalation-demo/50-CONTEXT.md` — READ-driven escalation; webhook choreography removed

### Primary edit targets
- `examples/chimeway_demo_host/README.md` — DOCS-04 webhook drift (line 39), command table (line 28), TraceDemo section
- `lib/mix/tasks/demo.up.ex` — DOCS-05 `@moduledoc` (line 8)
- `MAINTAINING.md` — GATE-03 pre-ship quintet (line 37)
- `mix.exs` — `verify.journeys` alias comment (line 90)

### Reference truth sources (read-only)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — READ-driven escalation seed shape
- `guides/recipes/mention-escalation.md` — canonical READ escalation pattern
- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — JOUR-01..03, JOUR-06 tags
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` — JOUR-04, JOUR-07, JOUR-08 tags
- `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` — JOUR-05 smoke test

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 37/42 doc-truth patterns — manual README hygiene + `doc_contract_test.exs` for guides (demo README not in contract today).
- Phase 51 verification artifact — authoritative 9-test count and JOUR-06 dual-test explanation.
- `demo.up.ex` implementation — correct behavior; only docs drift.

### Established Patterns
- `mix verify.journeys` runs `cd examples/chimeway_demo_host && mix test --only journey` (9 tests).
- Journey tags: `:jour_01`..`:jour_03`, `:jour_06`×2 in `journey_test.exs`; `:jour_04`, `:jour_07`, `:jour_08` in `admin_trace_live_test.exs`; `:jour_05` in `demo_up_test.exs`.
- `--check` skips `ecto.create` only; always runs migrate + app.start + demo.seed.
- CI already runs `verify_journeys` job — GATE-03 is documentation alignment, not wiring.

### Integration Points
- README persona table → `DemoHost.Seeds` + notifiers (`PaymentReminder`, `PasswordReset`, `InviteSent`).
- `MAINTAINING.md` quintet → release runbook step 3; must reflect expanded journey proof for v1.7 ship.
- `PROJECT.md` journey count → adopter-facing project summary; currently stale at "5 journey tests".

</code_context>

<specifics>
## Specific Ideas

No user corrections — all assumptions confirmed as-is.

</specifics>

<deferred>
## Deferred Ideas

- **`doc_contract_test.exs` for demo README** — would automate DOCS-04 regression prevention; out of Phase 52 scope per D-01.
- **`mention-escalation.md` line 90 update** — minor drift; Claude's discretion in this phase.

None — analysis stayed within phase scope.

</deferred>

---

*Phase: 52-Doc Truth & Gates*
*Context gathered: 2026-05-29 (assumptions mode)*
