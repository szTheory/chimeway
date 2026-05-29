# Phase 52: Doc Truth & Gates — Research

**Researched:** 2026-05-29  
**Domain:** Adoption-evidence documentation alignment — demo README, `mix demo.up` moduledoc, release-gate runbook  
**Requirements:** DOCS-04, DOCS-05, GATE-03  
**Confidence:** HIGH — all drift verified against live source; `mix verify.journeys` run in this session (9 tests, 0 failures)

---

<user_constraints>
## User Constraints (from 52-CONTEXT.md)

### Locked Decisions

| ID | Constraint |
|----|------------|
| D-01 | Documentation-only phase — no new journey tests, no `demo.up` runtime changes, no CI workflow or `verify.journeys` alias changes |
| D-02 | Replace README persona row "Payment escalation awaiting webhook" with READ-driven `:waiting` language aligned to `DemoHost.Seeds` / `mention-escalation.md` |
| D-03 | Reframe (not delete) "Not this path: webhook progression" — Morgan's path is READ-driven; Golden Path webhook appendix remains the separate webhook-progression path |
| D-04 | Keep `TraceDemo` as supplementary IEx walkthrough; TeamPulse personas remain primary adoption narrative; unify README so both paths are coherent |
| D-05 | Fix `@moduledoc` in `demo.up.ex` and README command table: `--check` = `ecto.migrate` + `app.start` + `demo.seed`, skipping only `ecto.create` |
| D-06 | Align `mix demo.up` and `mix demo.up --serve` descriptions with actual behavior |
| D-07 | Update `MAINTAINING.md` pre-ship quintet bullet for `mix verify.journeys` to JOUR-01..08 (GATE-03), noting JOUR-06 read-cancel + time-fallback |
| D-08 | Update `mix.exs` `verify.journeys` alias comment from GATE-02 / JOUR-01..05 to GATE-03 / JOUR-01..08 |
| D-09 | Update stale journey-count references in `.planning/PROJECT.md` ("5 journey tests") to 9 tests / JOUR-01..08 |

### Claude's Discretion

- `guides/recipes/mention-escalation.md` line 90 Phase-50 scope-fence wording
- `.planning/RETROSPECTIVE.md` journey counts (defer to milestone close unless trivial)
- Exact README section ordering for TraceDemo vs TeamPulse unification

### Explicit Out of Scope

- `doc_contract_test.exs` expansion for demo README
- Playwright (INV-004)
- Engine, CI job, or alias behavior changes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-04 | Demo host README resolves webhook-path contradiction; unifies TeamPulse vs TraceDemo narrative | Audit lines 39, 62–67, 69–133 in `examples/chimeway_demo_host/README.md`; canonical truth in `seeds.ex`, `mention-escalation.md` |
| DOCS-05 | `mix demo.up --check` moduledoc accurately describes migrate + seed + app.start | Audit `demo.up.ex:8`, `README.md:28`; behavior at `demo.up.ex:21–33` |
| GATE-03 | `mix verify.journeys` covers JOUR-06..08; MAINTAINING.md pre-ship quintet documents expanded READ journey proof | CI already runs 9 tests; docs stale at JOUR-01..05 / GATE-02 in `MAINTAINING.md:37`, `mix.exs:90`, `PROJECT.md:13` |
</phase_requirements>

## Executive Summary

Phase 52 is a **documentation-only close-out** for v1.7 adoption evidence. Phases 50–51 shipped READ-driven TeamPulse escalation and extended journey CI to 9 tests (JOUR-01..08, with JOUR-06 as two distinct `@tag :jour_06` tests). Runtime behavior and CI wiring are already correct — only prose drift remains.

The highest-impact drift is **DOCS-04**: the demo host README still tells adopters Morgan's payment escalation "awaiting webhook" while `DemoHost.Seeds.seed_escalation_waiting/0` and JOUR-03/06 prove READ-driven `:waiting`. A secondary section ("Not this path: webhook progression") incorrectly frames the whole README as "simple delivery only," contradicting the TeamPulse scenarios table.

**Primary recommendation:** Two plans in one wave — **52-01** (DOCS-04 + DOCS-05: demo host README + `demo.up.ex` moduledoc) and **52-02** (GATE-03: `MAINTAINING.md`, `mix.exs` comment, `PROJECT.md`). Optional third micro-task in 52-01 for `mention-escalation.md` line 90 if executor has bandwidth.

---

## 1. Current State Audit

### 1.1 `examples/chimeway_demo_host/README.md` — DOCS-04 + DOCS-05

| Line(s) | Current (drift) | Canonical truth | Req |
|---------|-----------------|-----------------|-----|
| **28** | `\| mix demo.up --check \| ... \| CI smoke — seed only, exit 0 \|` | Skips `ecto.create` only; always runs `ecto.migrate`, `app.start`, `demo.seed` | DOCS-05 |
| **39** | `\| Product Manager \| Payment escalation awaiting webhook \| ... \|` | Seeds moduledoc: "READ-driven `:waiting` after in-app delivery" (`seeds.ex:12`); `mention-escalation.md` documents read-cancel + time fallback | DOCS-04 |
| **62–67** | Section **"Not this path: webhook progression"** opens with: *"This README proves explainability on a simple delivery, not workflow progression after inbound webhooks."* | Morgan's TeamPulse scenario **is** workflow progression (READ-driven `:waiting`). Webhook progression is a **different** path (Golden Path appendix + `feedback_pipeline_e2e_test.exs`) — not Morgan's primary story | DOCS-04 |
| **69–133** | **"Trace walkthrough (IEx)"** uses `TraceDemo` notifier + `demo_user_1`; no framing vs TeamPulse personas (`alex@teampulse.test`, Sam, Morgan) | D-04: TraceDemo is supplementary simple-delivery explainability; TeamPulse seeds/admin are primary adoption path | DOCS-04 |
| **124–133** | Operator UI section references `user:demo_user_1` from TraceDemo | Quick start (line 14) and banner use `user:alex@teampulse.test` — competing entry points without bridge prose | DOCS-04 |

**Non-drift (keep):**

- Lines 26–27: `mix demo.up` / `--serve` descriptions are accurate (migrate + seed + banner; serve adds admin).
- Lines 135–141: Production auth section is current (no `ALLOW_DEMO_ADMIN`; Phase 42 verified).
- Lines 143–147: Related guides links are fine.

### 1.2 `lib/mix/tasks/demo.up.ex` — DOCS-05

| Line(s) | Current (drift) | Actual behavior | Req |
|---------|-----------------|-----------------|-----|
| **8** | `mix demo.up --check      # CI smoke — seed only, exit 0` | `unless check?` skips `ecto.create` only (`:21–23`); always `ecto.migrate`, `app.start`, `demo.seed` (`:25–33`); prints banner; does not `--serve` when `--check` (`:41`) | DOCS-05 |
| **7–9** | Base and `--serve` lines are correct | Matches implementation | — |

JOUR-05 (`demo_up_test.exs:7–24`) asserts exit 0 + banner output — behavior unchanged; docs must catch up.

### 1.3 `MAINTAINING.md` — GATE-03

| Line(s) | Current (drift) | Should reflect | Req |
|---------|-----------------|----------------|-----|
| **37** | `` `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..05, GATE-02) `` | JOUR-01..08, GATE-03; 9 ExUnit tests; READ proof via JOUR-06 (dual tests) + JOUR-07/08 admin personas | GATE-03 |

Lines 25–31 (quintet command list) are correct — `mix verify.journeys` already included; only the explanatory bullet is stale.

### 1.4 `mix.exs` — GATE-03

| Line(s) | Current (drift) | Should reflect | Req |
|---------|-----------------|----------------|-----|
| **90–93** | Comment: `# v1.6 GATE-02: TeamPulse consumer journey proof (demo host journey suite)` | `# v1.7 GATE-03: TeamPulse consumer journey proof JOUR-01..08 (9 tests)` | GATE-03 |

Alias body (`cmd --shell cd examples/chimeway_demo_host && mix test --only journey`) is **correct and unchanged** per D-01.

### 1.5 `.planning/PROJECT.md` — GATE-03 (D-09)

| Line(s) | Current (drift) | Should reflect | Req |
|---------|-----------------|----------------|-----|
| **13** | `**5 journey tests** (\`mix verify.journeys\`)` | **9 journey tests** (JOUR-01..08); mention GATE-03 for v1.7 expansion | GATE-03 |
| **21** | `Phases 48–50 shipped, Phase 51 next` | Stale milestone posture — update to reflect Phase 51 complete / Phase 52 doc close-out | D-09 (light) |
| **46** | `GATE-02: mix verify.journeys CI job` | Add GATE-03 as v1.7 journey expansion; keep GATE-02 as v1.6 foundation | D-09 |
| **145–146** | `Journey E2E suite (JOUR-01..05)` | Historical v1.6 snapshot OK in archived section **or** annotate expanded count in Current State | D-09 |

**In-scope per D-09:** Line 13 primary count + Current State journey posture. Archived milestone sections may stay historically accurate if labeled v1.6.

### 1.6 Optional drift — `guides/recipes/mention-escalation.md`

| Line(s) | Current | Issue |
|---------|---------|-------|
| **90** | `... JOUR-06 (Phase 51) — this recipe documents the pattern; read-cancel does not halt the scheduled worker in Phase 50.` | Phase-50 scope fence is obsolete; JOUR-06 now proves read-cancel + time-fallback in CI |
| **95** | References JOUR-03 for mark_read path | Still accurate — no change required |

Not a phase requirement; low-risk fix in 52-01 if bundled.

### 1.7 Verified green — no doc drift in code paths

| Asset | Status | Evidence |
|-------|--------|----------|
| `DemoHost.Seeds` | ✅ READ truth | `seeds.ex:12`, `:109–125` — trigger-only, READ-driven waiting |
| Journey CI | ✅ 9 tests | `mix verify.journeys` → 9 tests, 0 failures (this session) |
| CI job | ✅ Wired | `.github/workflows/ci.yml:123–161` — `verify_journeys` job unchanged |
| `doc_contract_test.exs` | ✅ N/A | Demo README not in contract (explicitly out of scope) |

### 1.8 Journey suite map (authoritative for GATE-03 prose)

| Requirement | Tag | File | What it proves |
|-------------|-----|------|----------------|
| JOUR-01 | `:jour_01` | `journey_test.exs:25` | Alex invite delivery |
| JOUR-02 | `:jour_02` | `journey_test.exs:39` | Sam password-reset suppression |
| JOUR-03 | `:jour_03` | `journey_test.exs:47` | Morgan escalation via `mark_read` → signal → resume |
| JOUR-04 | `:jour_04` | `admin_trace_live_test.exs:10` | Admin search — Alex invite |
| JOUR-05 | `:jour_05` | `demo_up_test.exs:7` | `mix demo.up --check` smoke |
| JOUR-06a | `:jour_06` | `journey_test.exs:90` | Read-cancel — no email before `due_at` |
| JOUR-06b | `:jour_06` | `journey_test.exs:139` | Time-fallback — email when unread past `due_at` |
| JOUR-07 | `:jour_07` | `admin_trace_live_test.exs:41` | Sam suppression admin trace |
| JOUR-08 | `:jour_08` | `admin_trace_live_test.exs:75` | Morgan escalation admin trace |

**Count nuance:** 8 requirement IDs, **9 ExUnit tests** (JOUR-06 dual-test pattern from Phase 51). GATE-03 documentation must mention both.

---

## 2. Prior Phase Patterns Applicable to Doc-Truth Work

### Phase 37 — Doc Truth & Journey Guides (DOCS-03)

**Pattern:** Drift inventory table with line references → full prose rewrite anchored on engine/tests → extend `doc_contract_test.exs` for automated regression.

**Applicable to Phase 52:**

- Use the **line-by-line drift inventory** format (Section 1 above) as the plan's edit checklist.
- Phase 37 shipped `37-VALIDATION.md` with grep gates + `mix ci.verify_gates` — Phase 52 has **no doc-contract target** for demo README; verification is grep + journey regression instead.
- Phase 37 explicitly moved aspirational paths to "Deferred" callouts — Phase 52 mirrors this by **reframing** webhook vs READ paths rather than deleting webhook references.

**Not applicable:** Engine-facing guide rewrite; `doc_contract_test.exs` extension (out of scope per D-01).

### Phase 42 — Consumer Doc / GATE-01 Gap Closure (DOCS-02, GATE-01)

**Pattern:** Documentation-only phase with **pre-ship command quartet** as closure gate; 3-plan wave split (content → cross-links → sign-off); grep-based drift checks (`stale_drift_patterns/2`).

**Applicable to Phase 52:**

- **Pre-ship quintet** already exists (Phase 41 + v1.6 GATE-02); Phase 52 updates **one bullet** in the quintet explanation, not the command list.
- Phase 42's **grep verification** maps to Phase 52 forbidden-string checks (see Section 5).
- Phase 42 fixed demo README auth — Phase 52 must **not regress** lines 135–141.

**Not applicable:** ex_doc `../../` link conversion; version semver alignment.

### Phase 51 — Journey & Admin Proof (JOUR-06..08)

**Pattern:** Test-only extension; **explicit deferral** of GATE-03 docs to Phase 52 (`51-VERIFICATION.md:36`, `51-CONTEXT.md D-06`).

**Applicable to Phase 52:**

- **Authoritative evidence:** `51-VERIFICATION.md` — 9 tests, 0 failures; JOUR-06 dual-test explanation.
- GATE-03 is **documentation alignment only** — CI already runs expanded suite.
- Phase 51 `@moduledoc` in `journey_test.exs:3` lists "JOUR-01..06" — code comment, not a phase-52 requirement; optional consistency touch if executor edits nearby files.

**Key lesson:** Plans estimated 8 tests; actual count is 9 — Phase 52 docs must say **9 tests / JOUR-01..08**, not "8 tests."

---

## 3. Recommended Plan Split

| Plan | Wave | Scope | Requirements | Depends on |
|------|------|-------|--------------|------------|
| **52-01** | 1 | Demo host README (DOCS-04 narrative + DOCS-05 command table) + `lib/mix/tasks/demo.up.ex` `@moduledoc` | DOCS-04, DOCS-05 | — |
| **52-02** | 1 | `MAINTAINING.md` quintet bullet, `mix.exs` alias comment, `.planning/PROJECT.md` journey counts | GATE-03 | — |

**Parallelism:** 52-01 and 52-02 touch disjoint files (except no overlap) — **run in parallel in Wave 1**.

**Optional add-on in 52-01:** `guides/recipes/mention-escalation.md:90` scope-fence cleanup (discretion).

**Do not split further:** Phase is small (~6 edit sites); a third plan for GATE-03 alone would add overhead without risk isolation benefit.

**Phase closure gate:** All three requirements verified via grep checks + `mix verify.journeys` regression (Section 5).

---

## 4. Files to Modify — Before/After Guidance

### 4.1 `examples/chimeway_demo_host/README.md`

#### Persona table (line 39) — DOCS-04

**Before:**
```markdown
| Product Manager | Payment escalation awaiting webhook | `DemoHost.Notifiers.PaymentReminder` |
```

**After (guidance):**
```markdown
| Product Manager | Payment escalation — READ-driven `:waiting` (inbox read cancels; time fallback to email) | `DemoHost.Notifiers.PaymentReminder` |
```

Cross-link: [Mention escalation recipe](../../guides/recipes/mention-escalation.md) in prose below table or in Related guides.

#### Command table (line 28) — DOCS-05

**Before:**
```markdown
| `mix demo.up --check` | repo root | CI smoke — seed only, exit 0 |
```

**After:**
```markdown
| `mix demo.up --check` | repo root | CI smoke — migrate + app.start + seed (skips `ecto.create` only), exit 0 |
```

#### Reframe webhook section (lines 62–67) — DOCS-04 / D-03

**Before:** Title "Not this path: webhook progression" + opening sentence denying workflow progression for this README.

**After (guidance):**

- Retitle e.g. **"Webhook progression (separate path)"** or **"Not Morgan's path: delivery-feedback webhooks"**.
- Opening prose should state:
  1. **TeamPulse Morgan scenario** (table above) uses **READ-driven** workflow waiting — see `mention-escalation.md` and JOUR-03/06.
  2. **Webhook-driven progression** is a distinct adoption path documented in Golden Path webhook appendix and `feedback_pipeline_e2e_test.exs` — not the TeamPulse payment-escalation story.
  3. Do **not** copy internal fixture helpers from the E2E test (keep existing bullet).

#### Unify TraceDemo vs TeamPulse (lines 69–133) — DOCS-04 / D-04

**Add brief intro** before "## Trace walkthrough (IEx)" (or rename to "## Supplementary: TraceDemo IEx walkthrough"):

- **Primary path:** TeamPulse personas via `mix demo.up` / `DemoHost.Seeds` → admin UI with `user:alex@teampulse.test` (and Sam/Morgan scenarios).
- **Supplementary path:** `TraceDemo` notifier + `mix demo.trace` for minimal single-delivery explainability without TeamPulse domain setup.

**Operator UI section (line 126):** Note that TraceDemo uses `demo_user_1` while TeamPulse quick start uses `alex@teampulse.test` — both valid; choose based on whether exploring simple delivery vs full persona seeds.

### 4.2 `lib/mix/tasks/demo.up.ex` (line 8) — DOCS-05

**Before:**
```elixir
      mix demo.up --check      # CI smoke — seed only, exit 0
```

**After:**
```elixir
      mix demo.up --check      # CI smoke — migrate + app.start + seed (skip ecto.create), exit 0
```

Keep lines 7 and 9 unchanged (already accurate).

### 4.3 `MAINTAINING.md` (line 37) — GATE-03

**Before:**
```markdown
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..05, GATE-02)
```

**After (guidance):**
```markdown
- `mix verify.journeys` — TeamPulse consumer journey proof (JOUR-01..08, GATE-03) — 9 tests including READ read-cancel + time-fallback (JOUR-06), Sam suppression admin (JOUR-07), Morgan escalation admin (JOUR-08)
```

Keep quintet command block (lines 25–31) unchanged.

### 4.4 `mix.exs` (line 90) — GATE-03

**Before:**
```elixir
      # v1.6 GATE-02: TeamPulse consumer journey proof (demo host journey suite)
```

**After:**
```elixir
      # v1.7 GATE-03: TeamPulse consumer journey proof JOUR-01..08 (9 tests)
```

Do **not** change alias body (lines 91–93).

### 4.5 `.planning/PROJECT.md` (line 13+) — GATE-03 / D-09

**Before (line 13 excerpt):**
```markdown
... plus **5 journey tests** (`mix verify.journeys`).
```

**After:**
```markdown
... plus **9 journey tests** (`mix verify.journeys`, JOUR-01..08 including READ escalation proof).
```

Also update line 21 milestone posture (Phase 51 complete) and line 46 to mention GATE-03 for expanded journey gate. Preserve v1.6 archived sections as historical unless a single clarifying footnote helps.

### 4.6 Optional — `guides/recipes/mention-escalation.md` (line 90)

**Before:**
```markdown
Automated proof that email fires only when unread is JOUR-06 (Phase 51) — this recipe documents the pattern; read-cancel does not halt the scheduled worker in Phase 50.
```

**After:**
```markdown
Automated proof: JOUR-06 under `mix verify.journeys` (read-cancel + time-fallback; two `@tag :jour_06` tests).
```

---

## 5. Verification Commands

### Primary regression (required after every plan)

```bash
# From repo root — must stay green (9 tests, 0 failures)
mix verify.journeys
```

### DOCS-04 / DOCS-05 grep gates (demo adoption docs)

```bash
# Forbidden strings must be absent after 52-01
rg -n "awaiting webhook|seed only" examples/chimeway_demo_host/README.md lib/mix/tasks/demo.up.ex
# Expect: no matches

# Required READ truth present in README persona row
rg -n "READ-driven|:waiting" examples/chimeway_demo_host/README.md
# Expect: match on Morgan scenario row
```

### GATE-03 grep gates (release runbook)

```bash
# Stale GATE-02 / JOUR-01..05 references removed from in-scope files
rg -n "JOUR-01\.\.05|GATE-02" MAINTAINING.md mix.exs .planning/PROJECT.md
# Expect: no matches in Current State / MAINTAINING / mix.exs comment
# (Historical v1.6 archived sections in PROJECT.md may retain GATE-02 if labeled)

# GATE-03 / expanded count present
rg -n "JOUR-01\.\.08|GATE-03|9 journey" MAINTAINING.md mix.exs .planning/PROJECT.md
```

### JOUR-05 smoke (confirms demo.up behavior unchanged)

```bash
cd examples/chimeway_demo_host && mix test --only jour_05
```

### Full pre-ship quintet (phase closure — documentation should match reality)

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
```

**Note:** Phase 52 does not require re-running full quintet on every task commit — `mix verify.journeys` + grep gates suffice per plan. Run full quintet once at phase verification.

### Manual read-through (DOCS-04)

1. Read README top-to-bottom as a new adopter.
2. Confirm Morgan story is READ-driven with no webhook implication.
3. Confirm TraceDemo section is clearly supplementary, not competing with TeamPulse quick start.
4. Confirm webhook appendix is positioned as a **separate** progression path.

---

## Validation Architecture

### Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (journey regression); grep/manual for doc truth |
| **Config file** | Root `mix.exs` alias `verify.journeys` |
| **Quick run command** | `mix verify.journeys` |
| **Doc drift command** | `rg` forbidden strings (Section 5) |
| **Full pre-ship command** | Quintet in `MAINTAINING.md` lines 25–31 |
| **Estimated runtime** | ~2–5s (`verify.journeys`); ~3–5 min (full quintet) |

### Per-deliverable verification map

| Deliverable | Requirement | Test type | Automated command | File / gate exists? |
|-------------|-------------|-----------|-------------------|---------------------|
| README Morgan row READ truth | DOCS-04 | grep + manual | `rg "awaiting webhook" README.md` → empty | ✅ edit target |
| README webhook section reframe | DOCS-04 | manual | Read-through checklist (Section 5) | ✅ |
| TraceDemo / TeamPulse unification | DOCS-04 | manual | Read-through checklist | ✅ |
| `--check` command table truth | DOCS-05 | grep | `rg "seed only" README.md` → empty | ✅ |
| `demo.up.ex` moduledoc truth | DOCS-05 | grep | `rg "seed only" demo.up.ex` → empty | ✅ |
| `demo.up --check` behavior unchanged | DOCS-05 | journey | `mix test --only jour_05` (demo host) | ✅ JOUR-05 |
| MAINTAINING.md JOUR-01..08 / GATE-03 | GATE-03 | grep | `rg "JOUR-01..08\|GATE-03" MAINTAINING.md` | ✅ |
| mix.exs alias comment | GATE-03 | grep | `rg "GATE-03" mix.exs` | ✅ |
| PROJECT.md journey count | GATE-03 | grep | `rg "9 journey" PROJECT.md` | ✅ |
| Journey suite regression | GATE-03 | journey | `mix verify.journeys` (9 tests) | ✅ green |
| Doc contract (guides) | — | N/A | Out of scope — no `doc_contract_test.exs` change | — |

### Sampling rate

- **After 52-01 commit:** grep gates for DOCS-04/05 + `mix verify.journeys`
- **After 52-02 commit:** grep gates for GATE-03 + `mix verify.journeys`
- **Before `/gsd-verify-work`:** full quintet (optional but recommended for GATE-03 sign-off)

### Wave 0 gaps

**None.** All behaviors already implemented in Phases 50–51. Phase 52 is prose-only — no new tests, fixtures, or CI jobs.

### Manual-only verifications

| Behavior | Requirement | Why manual | Instructions |
|----------|-------------|------------|--------------|
| README narrative coherence | DOCS-04 | No doc-contract for demo README | Adopter read-through (Section 5) |
| RETROSPECTIVE.md counts | — | Deferred per CONTEXT discretion | Skip unless milestone close |

### Nyquist compliance notes

- Every task has automated verify (`mix verify.journeys` and/or grep) except README narrative coherence (one manual row).
- No three consecutive doc-only commits without `mix verify.journeys` — enforce in plan tasks.
- `52-VALIDATION.md` should mirror this section at plan time (Phase 48/51 template).

---

## Pitfalls

| Pitfall | What goes wrong | Avoid |
|---------|-----------------|-------|
| Changing `verify.journeys` alias or CI job | Violates D-01 scope fence | Comment-only in `mix.exs` |
| Deleting webhook section entirely | Loses Golden Path cross-link for delivery-feedback adopters | Reframe per D-03 |
| Saying "8 journey tests" | Undercounts ExUnit (JOUR-06 × 2) | Document **9 tests / JOUR-01..08** |
| Implying `--check` is seed-only | Perpetuates DOCS-05 drift | Explicit migrate + app.start + seed |
| Adding demo README to `doc_contract_test.exs` | Scope creep | Defer to follow-on |
| Breaking Phase 42 auth docs | Regression on shipped v1.5 fix | Do not edit README lines 135–141 |
| Updating all historical `.planning/` archives | Unbounded scope | D-09 targets `PROJECT.md` Current State; RETROSPECTIVE optional |

---

## Canonical Reference Sources (read-only)

| Source | Use |
|--------|-----|
| `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | Morgan `:escalation_waiting` READ shape |
| `guides/recipes/mention-escalation.md` | PM JTBD read-cancel + time fallback prose |
| `.planning/phases/51-journey-admin-proof/51-VERIFICATION.md` | 9-test count evidence |
| `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` | JOUR-01..03, JOUR-06 |
| `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | JOUR-04, JOUR-07, JOUR-08 |
| `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs` | JOUR-05 |

---

## RESEARCH COMPLETE

**Phase:** 52-doc-truth-gates  
**Confidence:** HIGH  
**Ready for:** `/gsd-plan-phase 52`
