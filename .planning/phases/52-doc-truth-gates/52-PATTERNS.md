# Phase 52: Doc Truth & Gates — Pattern Map

**Mapped:** 2026-05-29  
**Phase:** 52-doc-truth-gates  
**Requirements:** DOCS-04, DOCS-05, GATE-03  

Maps every file Phase 52 creates or modifies to closest codebase analogs with copy-ready excerpts. Documentation-only phase — no runtime, CI alias, or test changes per D-01.

---

## File Inventory

| File | Action | Role | Closest Analog |
|------|--------|------|----------------|
| `examples/chimeway_demo_host/README.md` | **Edit** | Primary adoption narrative — TeamPulse personas, command table, TraceDemo framing | Phase 42 commit `b51c8aa` (README prod-auth truth); Phase 37 deferred/webhook split tone |
| `lib/mix/tasks/demo.up.ex` | **Edit** | `@moduledoc` usage truth for `--check` | Same file `run/1` (`:21–33`) + JOUR-05 smoke test |
| `MAINTAINING.md` | **Edit** | Pre-ship quintet explanatory bullet for journey gate | Phase 41 quintet block (`:25–31`); Phase 51 deferred GATE-03 |
| `mix.exs` | **Edit** | `verify.journeys` alias **comment only** | Phase 47 GATE-02 comment at `:90–93` |
| `.planning/PROJECT.md` | **Edit** | Current State journey count + v1.7 posture | Phase 51 `51-VERIFICATION.md` (9-test evidence) |
| `guides/recipes/mention-escalation.md` | **Optional edit** | JOUR-06 scope-fence cleanup (line 90) | Same file `:86–95` + `doc_contract_test.exs` mention recipe describe |

**Explicitly out of scope (do not touch):**

| File | Why |
|------|-----|
| `test/chimeway/doc_contract_test.exs` | Demo README not in contract (D-01); Phase 37 Pattern 5 applies to guides only |
| `.github/workflows/ci.yml` | CI already runs 9 tests; alias body unchanged |
| `mix.exs` `verify.journeys` alias body | D-01 scope fence |
| `examples/chimeway_demo_host/README.md` lines 135–141 | Phase 42 verified prod-auth truth — regression zone |

**Read-only truth sources (anchor edits here):**

| Source | Use |
|--------|-----|
| `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | Morgan `:escalation_waiting` READ shape |
| `guides/recipes/mention-escalation.md` | Read-cancel + time-fallback prose |
| `.planning/phases/51-journey-admin-proof/51-VERIFICATION.md` | 9 tests / JOUR-06 dual-test count |
| `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` | JOUR-01..03, JOUR-06 tags |
| `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | JOUR-04, JOUR-07, JOUR-08 |
| `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` | JOUR-05 `--check` smoke |

---

## Pattern 1: Persona Table READ Truth (DOCS-04)

**Closest analog:** `DemoHost.Seeds` moduledoc + `seed_escalation_waiting/0` doc  
**Anti-pattern:** Current README line 39 "awaiting webhook"

**Canonical source — seeds moduledoc:**

```elixir
# examples/chimeway_demo_host/lib/demo_host/seeds.ex:8-14
## Scenarios

- **Invite** (`:invite`) — successful multi-channel delivery for Alex
- **Password reset** (`:password_reset`) — email suppressed by preference for Sam
- **Payment escalation** (`:escalation_waiting`) — READ-driven `:waiting` after in-app delivery
```

**Canonical source — escalation seed doc:**

```elixir
# examples/chimeway_demo_host/lib/demo_host/seeds.ex:109-115
@doc """
JOUR-03: payment reminder with READ-driven workflow waiting.

Uses `Chimeway.trigger/3` only — after in-app delivery succeeds, the engine
enters `:waiting` with `pending_signals` from `cancel_signals`. Pair with
`Chimeway.mark_read/3` in journey tests for early exit.
"""
```

**README drift (replace):**

```markdown
| Product Manager | Payment escalation awaiting webhook | `DemoHost.Notifiers.PaymentReminder` |
```

**Target shape (from 52-RESEARCH §4.1):**

```markdown
| Product Manager | Payment escalation — READ-driven `:waiting` (inbox read cancels; time fallback to email) | `DemoHost.Notifiers.PaymentReminder` |
```

**Cross-link:** Add [Mention escalation recipe](../../guides/recipes/mention-escalation.md) near persona table or Related guides.

---

## Pattern 2: Webhook vs READ Path Split (DOCS-04 / D-03)

**Closest analog:** Phase 37 Pattern 6 (Deferred / Future callout) — describe outcomes, separate paths, do not delete  
**Secondary analog:** `guides/recipes/mention-escalation.md` "Related guides" webhook pointer

**Current drift — denies workflow progression for entire README:**

```markdown
## Not this path: webhook progression

This README proves **explainability on a simple delivery**, not workflow progression after inbound webhooks.

- For webhook-driven progression, use the [Golden Path webhook appendix](../../guides/introduction/golden-path.md#next-webhook-feedback-loop).
- The [feedback pipeline E2E test](test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs) is an internal test reference for webhook progression — **do not** copy fixture helpers from that file into your app.
```

**Reframe guidance (retitle + opening prose, keep bullets):**

1. **TeamPulse Morgan** (persona table) = READ-driven `:waiting` — cite `mention-escalation.md`, JOUR-03/06.
2. **Webhook-driven progression** = separate adoption path — Golden Path appendix + E2E test reference.
3. Keep "do not copy fixture helpers" bullet unchanged.

**Recipe analog — dual-path Related guides:**

```markdown
# guides/recipes/mention-escalation.md:97-101
## Related guides

- [Multi-step journeys](../flows/multi-step-journeys.md) — full workflow authoring reference
- [Feedback escalation workflow](feedback-escalation-workflow.md) — webhook / delivery-feedback path
```

---

## Pattern 3: TraceDemo Supplementary vs TeamPulse Primary (DOCS-04 / D-04)

**Closest analog:** v1.6 README structure (TeamPulse quick start first) + Phase 39 TraceDemo IEx section (preserved below webhook block)

**Primary path — already correct (keep):**

```markdown
# examples/chimeway_demo_host/README.md:5-14
## Quick start (5 minutes)
...
Open ... and search `user:alex@teampulse.test`.
```

**Banner truth — `demo.up.ex` print_banner:**

```elixir
# lib/mix/tasks/demo.up.ex:48-54
Mix.shell().info("TeamPulse demo ready")
Mix.shell().info("  Admin UI:  http://localhost:4001/admin/chimeway")
Mix.shell().info("  Recipient: user:alex@teampulse.test")
```

**Supplementary path — TraceDemo (add intro before section):**

```markdown
## Supplementary: TraceDemo IEx walkthrough

**Primary adoption path:** TeamPulse personas via `mix demo.up` / `DemoHost.Seeds` → admin UI with `user:alex@teampulse.test` (Alex, Sam, Morgan scenarios).

**This section:** minimal single-delivery explainability via `TraceDemo` + `mix demo.trace` — no TeamPulse domain setup required.
```

**Operator UI bridge — resolve competing entry points:**

```markdown
# Current drift (line 126): only demo_user_1
search by recipient (e.g. `user:demo_user_1` from `mix demo.trace`)

# Target: note both entry points
search by recipient — `user:alex@teampulse.test` (TeamPulse seeds) or `user:demo_user_1` (TraceDemo)
```

---

## Pattern 4: `--check` Moduledoc + Command Table Truth (DOCS-05)

**Closest analog:** `Mix.Tasks.Demo.Up.run/1` implementation + JOUR-05 assertion  
**Anti-pattern:** "seed only" in moduledoc and README command table

**Implementation truth (only `ecto.create` skipped):**

```elixir
# lib/mix/tasks/demo.up.ex:17-33
def run(args) do
  check? = "--check" in args
  ...
  unless check? do
    Mix.Task.run("ecto.create")
  end

  Mix.Task.run("ecto.migrate")
  Mix.Task.run("app.start")

  {output, status} =
    System.cmd("mix", ["demo.seed"], ...)
```

**JOUR-05 behavior proof (unchanged — docs must match):**

```elixir
# examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:7-24
test "JOUR-05 mix demo.up --check exits 0" do
  {output, status} = System.cmd("mix", ["demo.up", "--check"], cd: repo_root, ...)
  assert status == 0
  assert output =~ "TeamPulse demo ready"
  assert output =~ "admin/chimeway"
end
```

**Moduledoc drift (replace line 8 only):**

```elixir
mix demo.up --check      # CI smoke — seed only, exit 0
```

**Target:**

```elixir
mix demo.up --check      # CI smoke — migrate + app.start + seed (skip ecto.create), exit 0
```

**README command table drift (line 28):**

```markdown
| `mix demo.up --check` | repo root | CI smoke — seed only, exit 0 |
```

**Target:**

```markdown
| `mix demo.up --check` | repo root | CI smoke — migrate + app.start + seed (skips `ecto.create` only), exit 0 |
```

Keep lines 26–27 (`mix demo.up`, `--serve`) unchanged — already accurate per RESEARCH §1.1.

---

## Pattern 5: Pre-Ship Quintet Bullet Update (GATE-03)

**Closest analog:** Phase 41 `MAINTAINING.md` quintet command block + Phase 51 explicit GATE-03 deferral

**Quintet commands — DO NOT EDIT (already correct):**

```bash
# MAINTAINING.md:25-31
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
```

**Stale explanatory bullet (line 37 only):**

```markdown
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..05, GATE-02)
```

**Target (9 tests / JOUR-01..08 / GATE-03):**

```markdown
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..08, GATE-03) — 9 tests including READ read-cancel + time-fallback (JOUR-06), Sam suppression admin (JOUR-07), Morgan escalation admin (JOUR-08)
```

**Authoritative journey map for prose:**

| Req | Tag | File | Proves |
|-----|-----|------|--------|
| JOUR-01 | `:jour_01` | `journey_test.exs:25` | Alex invite delivery |
| JOUR-02 | `:jour_02` | `journey_test.exs:39` | Sam password-reset suppression |
| JOUR-03 | `:jour_03` | `journey_test.exs:47` | Morgan escalation via mark_read → signal → resume |
| JOUR-04 | `:jour_04` | `admin_trace_live_test.exs:10` | Admin search — Alex invite |
| JOUR-05 | `:jour_05` | `demo_up_test.exs:7` | `mix demo.up --check` smoke |
| JOUR-06a | `:jour_06` | `journey_test.exs:90` | Read-cancel — no email before `due_at` |
| JOUR-06b | `:jour_06` | `journey_test.exs:139` | Time-fallback — email when unread past `due_at` |
| JOUR-07 | `:jour_07` | `admin_trace_live_test.exs:41` | Sam suppression admin trace |
| JOUR-08 | `:jour_08` | `admin_trace_live_test.exs:75` | Morgan escalation admin trace |

**Count nuance:** 8 requirement IDs, **9 ExUnit tests** (JOUR-06 dual `@tag :jour_06` from Phase 51).

---

## Pattern 6: `mix.exs` Alias Comment (GATE-03)

**Closest analog:** Phase 47 GATE-02 comment — comment-only edit, alias body frozen

**Current:**

```elixir
# mix.exs:90-93
# v1.6 GATE-02: TeamPulse consumer journey proof (demo host journey suite)
"verify.journeys": [
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only journey"
]
```

**Target comment only:**

```elixir
# v1.7 GATE-03: TeamPulse consumer journey proof JOUR-01..08 (9 tests)
```

Do **not** change alias body — D-01 scope fence.

---

## Pattern 7: PROJECT.md Current State Counts (GATE-03 / D-09)

**Closest analog:** Phase 51 `51-VERIFICATION.md` + Phase 42 `stale_drift_patterns/2` mindset (update Current State, preserve archived history)

**Stale Current State (line 13):**

```markdown
... plus **5 journey tests** (`mix verify.journeys`).
```

**Target:**

```markdown
... plus **9 journey tests** (`mix verify.journeys`, JOUR-01..08 including READ escalation proof).
```

**Also update (light touch):**

- Line 21: Phase 51 complete / Phase 52 doc close-out posture
- Line 46: Add GATE-03 as v1.7 journey expansion; keep GATE-02 as v1.6 foundation

**Preserve archived sections** (`PROJECT.md:134–151` v1.6 snapshot with JOUR-01..05 / GATE-02) — historical accuracy OK inside `<details>` blocks per D-09.

---

## Pattern 8: Optional Recipe Scope-Fence Cleanup

**Closest analog:** Phase 49 doc_contract mention recipe describe (forbidden webhook staging strings)  
**Discretion:** CONTEXT allows defer; low-risk if bundled in 52-01

**Drift (line 90):**

```markdown
Automated proof that email fires only when unread is JOUR-06 (Phase 51) — this recipe documents the pattern; read-cancel does not halt the scheduled worker in Phase 50.
```

**Target:**

```markdown
Automated proof: JOUR-06 under `mix verify.journeys` (read-cancel + time-fallback; two `@tag :jour_06` tests).
```

Line 95 (JOUR-03 mark_read path) — still accurate, no change.

---

## Pattern 9: Grep-Based Doc Truth Verification (Phase 37/42 Adaptation)

**Closest analog:** Phase 37 `doc_contract_test.exs` forbidden/required strings; Phase 42 grep acceptance criteria  
**Phase 52 delta:** Manual grep only — demo README **not** in `doc_contract_test.exs`

**DOCS-04 / DOCS-05 forbidden strings:**

```bash
rg -n "awaiting webhook|seed only" examples/chimeway_demo_host/README.md lib/mix/tasks/demo.up.ex
# Expect: no matches

rg -n "READ-driven|:waiting" examples/chimeway_demo_host/README.md
# Expect: match on Morgan scenario row
```

**GATE-03 forbidden strings (in-scope files only):**

```bash
rg -n "JOUR-01\.\.05|GATE-02" MAINTAINING.md mix.exs .planning/PROJECT.md
# Expect: no matches in Current State / MAINTAINING / mix.exs comment
# Historical v1.6 archived sections in PROJECT.md may retain GATE-02 if labeled

rg -n "JOUR-01\.\.08|GATE-03|9 journey" MAINTAINING.md mix.exs .planning/PROJECT.md
# Expect: matches in updated locations
```

**Regression (required after every plan commit):**

```bash
mix verify.journeys   # 9 tests, 0 failures
cd examples/chimeway_demo_host && mix test --only jour_05   # JOUR-05 smoke
```

**Phase 37 Pattern 5 NOT applicable:** Do not extend `doc_contract_test.exs` for demo README (explicit deferral in CONTEXT).

---

## Pattern 10: Do-Not-Regress Zone (Phase 42)

**Closest analog:** Phase 42 commit `b51c8aa` — surgical README edit, preserve surrounding structure

**Protected block — do not edit:**

```markdown
# examples/chimeway_demo_host/README.md:135-141
### Production auth

`DemoHost.AdminAuth` always allows access in `:dev` and `:test`. In `:prod` it always returns `{:error, :unauthorized}` — replace with your host's real `ChimewayAdmin.Auth` implementation before exposing admin routes.

### Out of scope for `chimeway_admin` MVP
...
```

Phase 42 removed `ALLOW_DEMO_ADMIN` staging escape hatch — Phase 52 must not reintroduce webhook or auth drift in this block.

---

## Plan Split Reference

| Plan | Files | Requirements |
|------|-------|--------------|
| **52-01** | `README.md`, `demo.up.ex`, optional `mention-escalation.md` | DOCS-04, DOCS-05 |
| **52-02** | `MAINTAINING.md`, `mix.exs` (comment), `PROJECT.md` | GATE-03 |

Plans are parallel-safe — disjoint file sets.

---

*Phase: 52-doc-truth-gates*

## PATTERN MAPPING COMPLETE
