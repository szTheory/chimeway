# Phase 42: Close gap DOCS-02/GATE-01 — Research

**Researched:** 2026-05-29  
**Phase:** 42-close-gap-docs-02-gate-01-align-consumer-docs-to-1-0-0-and-f  
**Requirements:** DOCS-02, GATE-01  
**Status:** Ready for planning

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Phase boundary and success criteria
- **D-01:** Phase succeeds when all four MAINTAINING.md pre-ship commands exit 0: `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example`.
- **D-02:** Requirements satisfied: DOCS-02 (consumer semver alignment) and GATE-01 (doc-contract gates + pre-ship verification).

#### Version alignment (DOCS-02)
- **D-03:** Align README, `guides/introduction/installation.md`, and `guides/introduction/golden-path.md` to `{:chimeway, "~> 1.0"}` matching `mix.exs` `@version "1.0.0"`.
- **D-04:** Use `~> MAJOR.MINOR` constraint form only — no patch-level `~> 1.0.0`.

#### Drift pattern reconciliation
- **D-05:** Replace static `@drift_patterns` with dynamic `stale_drift_patterns(major, minor)` derived from `mix.exs` at test runtime.
- **D-06:** At `1.0.0`, forbid `{:chimeway, "~> 0.1"}`, `0.1.0`, and `{:chimeway, "~> 0.` prefix drift. At `0.x`, forbid premature `~> 1.0` / `1.0.0` drift.
- **D-07:** Keep alignment test dynamic — derive expected constraint from `@version`, do not hard-code `"1.0.0"`.

#### ex_doc cross-package links
- **D-08:** Convert `../../examples/chimeway_demo_host/` and `../../chimeway_admin/` relative links to GitHub absolute URLs (`https://github.com/jonlunsford/chimeway`).
- **D-09:** Fix all four guides with `../../` cross-package links, not only currently failing files.
- **D-10:** Do not add `examples/` or `chimeway_admin/` to `mix.exs` `:files` — GitHub URLs are the established fix (Phase 36-03).

#### Demo host README auth doc
- **D-11:** Remove stale `ALLOW_DEMO_ADMIN=true` escape hatch; document `:prod` always returns `{:error, :unauthorized}` until host implements real `ChimewayAdmin.Auth`.

### Deferred (OUT OF SCOPE)
- Nyquist frontmatter fixes (phases 35/39)
- Hex 1.0.0 publish ceremony
- Doc-contract gates for every guide under `guides/`
- Engine/API changes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Requirement | Phase closure evidence |
|----|-------------|------------------------|
| DOCS-02 | Consumer-facing version strings align with `mix.exs` `@version` | `{:chimeway, "~> 1.0"}` in README + installation + golden-path; `mix ci.verify_gates` alignment describe green |
| GATE-01 | Pre-ship verification quartet green | `mix ci`, `mix ci.docs`, `mix ci.verify_gates`, `mix verify.example` all exit 0 |
</phase_requirements>

---

## Current Repo State (2026-05-29)

### Already green (working tree / uncommitted)

| Command | Status | Notes |
|---------|--------|-------|
| `mix ci.verify_gates` | ✅ 86 tests, 0 failures | Consumer docs show `~> 1.0`; `stale_drift_patterns/2` implemented |
| `mix ci` | ✅ 647 tests, 0 failures | Full suite green |
| `mix verify.example` | ✅ 11 tests, 0 failures | Demo host + chimeway_admin subprocess chain |

### Still failing

| Command | Status | Blocker |
|---------|--------|---------|
| `mix ci.docs` | ❌ exit 1 | 10 ex_doc warnings — relative `../../` links in Hex extras |

### ex_doc warning inventory

Unique warning types (all from files outside Hex `:files` list):

```
warning: documentation references file "../../chimeway_admin/" but it does not exist
warning: documentation references file "../../examples/chimeway_demo_host/README.md" but it does not exist
warning: documentation references file "../../examples/chimeway_demo_host/README.md#operator-trace-ui-browser" but it does not exist
```

**Affected guides (in `mix.exs` extras):**

| File | Relative links to convert |
|------|---------------------------|
| `guides/introduction/golden-path.md` | demo host README (×2), chimeway_admin dir, operator UI anchor |
| `guides/recipes/password-reset-support-trace.md` | demo host README (×2), operator UI anchor |
| `guides/recipes/feedback-escalation-workflow.md` | feedback_pipeline_e2e_test.exs |
| `guides/flows/multi-step-journeys.md` | feedback_pipeline_e2e_test.exs |

**Precedent (already fixed in golden-path webhook appendix, lines 174–175):**

```markdown
- [Demo host example](https://github.com/jonlunsford/chimeway/tree/main/examples/chimeway_demo_host/)
- [Feedback pipeline E2E test](https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs)
```

### Recommended GitHub URL mapping

| Relative target | Absolute URL |
|-----------------|--------------|
| `../../examples/chimeway_demo_host/README.md` | `https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/README.md` |
| `../../examples/chimeway_demo_host/README.md#operator-trace-ui-browser` | `https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/README.md#operator-trace-ui-browser` |
| `../../chimeway_admin/` | `https://github.com/jonlunsford/chimeway/tree/main/chimeway_admin/` |
| `../../examples/chimeway_demo_host/test/.../feedback_pipeline_e2e_test.exs` | `https://github.com/jonlunsford/chimeway/blob/main/examples/chimeway_demo_host/test/demo_host_web/controllers/feedback_pipeline_e2e_test.exs` |

Use `mix.exs` `source_url: "https://github.com/jonlunsford/chimeway"` as canonical base (matches Phase 36-03).

### doc_contract_test.exs drift helper (implemented)

```elixir
defp stale_drift_patterns("1", "0"),
  do: ["{:chimeway, \"~> 0.1\"}", "0.1.0", ~s({:chimeway, "~> 0.)]

defp stale_drift_patterns("0", _minor),
  do: ["{:chimeway, \"~> 1.0\"}", "1.0.0", ~s({:chimeway, "~> 1.)]
```

This inverts Phase 41 static `@drift_patterns` that forbade `~> 1.0` at 0.x — now major-aware per D-05/D-06.

### Demo host README (D-11)

`examples/chimeway_demo_host/README.md` Production auth section already documents `:prod` → `{:error, :unauthorized}` with no `ALLOW_DEMO_ADMIN` reference. Audit tech-debt item is resolved in working tree; plan should verify and keep.

---

## Root Cause (from v1.5 re-audit)

1. `mix.exs` bumped to `@version "1.0.0"` without consumer doc updates → DOCS-02 regression.
2. Phase 41 drift patterns forbade `~> 1.0` substring → doc fix alone would fail drift tests.
3. Phase 39–40 added cross-package relative links in guides → latent `mix ci.docs` failure when ex_doc validates extras with `--warnings-as-errors`.

---

## Validation Architecture

### Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `mix.exs` aliases + `test/test_helper.exs` |
| **Quick run command** | `mix ci.verify_gates` |
| **Docs command** | `mix ci.docs` |
| **Full quartet** | `mix ci && mix ci.docs && mix ci.verify_gates && mix verify.example` |
| **Estimated runtime** | ~60s quartet (ci dominates) |

### Per-deliverable verification map

| Deliverable | Requirement | Automated command | File exists |
|-------------|-------------|-------------------|-------------|
| Consumer version alignment | DOCS-02 | `mix ci.verify_gates` | ✅ |
| Drift pattern inversion | GATE-01 | `mix ci.verify_gates` | ✅ |
| ex_doc link hygiene | GATE-01 | `mix ci.docs` | ❌ (blocker) |
| Full test suite | GATE-01 | `mix ci` | ✅ |
| Example host smoke | GATE-01 | `mix verify.example` | ✅ |
| Demo README auth doc | OPER hygiene | `! grep -q ALLOW_DEMO_ADMIN examples/chimeway_demo_host/README.md` | ✅ |

### Wave 0 requirements

Existing infrastructure covers all phase requirements — no new test files or frameworks needed.

### Manual-only verifications

| Behavior | Why manual | Instructions |
|----------|------------|--------------|
| Audit artifact status update | Planning doc, not gated | Update `.planning/milestones/v1.5-MILESTONE-AUDIT.md` frontmatter `status` after quartet green |

---

## Plan Recommendations

### Suggested plan split (3 plans, 3 waves)

| Plan | Wave | Focus | Depends on |
|------|------|-------|------------|
| 42-01 | 1 | Land DOCS-02 consumer version + `stale_drift_patterns/2` | — |
| 42-02 | 2 | Convert cross-package `../../` links → GitHub URLs (4 guides) | 01 |
| 42-03 | 3 | Demo README verify, audit update, pre-ship quartet sign-off | 02 |

**Rationale:** Plan 01 may be mostly landed in working tree — executor verifies and commits. Plan 02 is the remaining `mix ci.docs` blocker. Plan 03 is closure gate per D-01.

### Pitfalls

| Pitfall | Mitigation |
|---------|------------|
| Fixing only golden-path links | D-09 mandates all four guides — feedback-escalation and multi-step-journeys also in extras |
| Using `blob` for directory links | Use `tree/main/chimeway_admin/` for package root; `blob` for files |
| Re-introducing `~> 1.0.0` patch constraint | doc_contract regex forbids patch-level constraints |
| Adding examples to Hex `:files` | D-10 explicitly rejects — use GitHub URLs |

---

## RESEARCH COMPLETE
