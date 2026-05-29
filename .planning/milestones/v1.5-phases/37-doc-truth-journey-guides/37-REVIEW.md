---
phase: 37-doc-truth-journey-guides
reviewed: 2026-05-28T22:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - guides/flows/multi-step-journeys.md
  - guides/recipes/oban-integration.md
  - test/chimeway/doc_contract_test.exs
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 37: Code Review Report

**Reviewed:** 2026-05-28  
**Depth:** standard  
**Files Reviewed:** 3  
**Status:** issues_found

## Summary

Phase 37 delivers a strong doc-truth rewrite of the multi-step journey guide and Oban recipe, plus a focused doc-contract test suite for the journey guide. Engine semantics (`wait_until`, `on_outcome`, `stop`, `pending_signals` gap, Dispatch workers, `Chimeway.trigger/3`, `Chimeway.Signal.track/4`) match `lib/chimeway/notifier.ex`, `lib/chimeway/workflows/progression.ex`, and `lib/chimeway/workflows.ex`. The READ milestone deferral is honest and aligned with `enter_waiting/6` behavior.

No critical or security issues. Three warnings are doc-truth gaps in the Oban recipe transactional section, a misleading commented cron example, and stale Phase 38 deferral text in the journey guide. Two info items note limited doc-contract scope and minor naming inconsistency.

**Verification run during review:**

```
mix test test/chimeway/doc_contract_test.exs  → 18 tests, 0 failures
mix ci.docs                                     → pass
```

---

## Critical Issues

None.

---

## Warnings

### WR-01: Transactional example documents non-existent `multi:` option on `Chimeway.trigger/3`

**File:** `guides/recipes/oban-integration.md:74-94`

**Issue:** The Multi example passes `multi: multi` to `Chimeway.trigger/3` and claims trigger returns `{:ok, multi}` when using the multi option. `Chimeway.Trigger.trigger/3` always runs its own internal `Ecto.Multi` + `Repo.transaction/2`; it does not accept or forward a host `:multi` option. Transactional Oban enqueue is supported on `Chimeway.Dispatch.Oban.dispatch/2` (see `lib/chimeway/dispatch/oban.ex` moduledoc), not on trigger. The closure also references an undefined `multi` binding — the example would not compile as written.

**Fix:** Rewrite the section to separate concerns: (1) host `Multi` for application writes, then (2) trigger after commit, or document calling `dispatcher.dispatch(notifications, multi: host_multi)` inside a host-controlled transaction after notifications exist. Remove the false `{:ok, multi}` return claim.

---

### WR-02: Commented cron example targets the wrong worker for fallback sweeps

**File:** `guides/recipes/oban-integration.md:43-46`

**Issue:** The commented cron snippet schedules `Chimeway.Dispatch.WorkflowProgressionWorker` with no args. That worker's `perform/1` requires `%{"workflow_run_id" => id}` and delegates to `progress_run/2` for a single run — it cannot sweep all past-due waits. Prose correctly describes `Chimeway.Workflows.Progression.progress_due_runs/1` as the fallback, but the commented code contradicts it and would fail if uncommented.

**Fix:** Replace the commented cron entry with a thin host worker that calls `progress_due_runs/1`, or remove the worker module from the cron example and link to a host wrapper snippet.

---

### WR-03: Stale Phase 38 deferral in journey guide Next Steps

**File:** `guides/flows/multi-step-journeys.md:197`

**Issue:** The Oban Integration link parenthetical says "worker path corrections land in Phase 38 recipes when available", but plan 37-02 already corrected worker modules and queue guidance in `guides/recipes/oban-integration.md`. Readers may skip the recipe believing it is still outdated.

**Fix:** Drop the Phase 38 deferral parenthetical; describe the recipe as current (dispatcher config, per-run `due_at` scheduling, Dispatch workers).

---

## Info

### IN-01: Doc-contract test scope limited to journey guide

**File:** `test/chimeway/doc_contract_test.exs`

**Issue:** DOCS-03 criterion #3 is satisfied for `multi-step-journeys.md`, but `oban-integration.md` (also edited in phase 37) has no automated forbidden/required string gates. Issues like WR-01 would not fail CI.

**Fix:** Intentionally deferred to Phase 41 GATE-01 per plan 37-03; consider adding oban-recipe assertions in Phase 38 reference-recipes work.

---

### IN-02: ProcessFeedbackWorker referenced without namespace

**File:** `guides/flows/multi-step-journeys.md:153`

**Issue:** Delivery-feedback path uses bare `ProcessFeedbackWorker` while other API references use fully-qualified modules (`Chimeway.Dispatch.SignalRouterWorker`, etc.). Actual module is `Chimeway.Webhooks.ProcessFeedbackWorker`.

**Fix:** Optional consistency pass — qualify once on first mention or add "(Chimeway.Webhooks)" inline.

---

## Positive Observations

- Journey guide accurately documents the `wait_until` → `:waiting` → `WorkflowProgressionWorker` path and honestly surfaces the `pending_signals` engine gap (READ-01/READ-02 deferral).
- WR-02 `temporary_failure` early-fire warning matches `Chimeway.Notifier` moduledoc and curated outcome vocabulary.
- Doc-contract negative lookahead for `Chimeway.Workflow` vs `Chimeway.Workflows` is a correct, maintainable pattern; explicit phrase list for `type: :wait` avoids `~w` false positives.
- Oban recipe correctly documents per-run `due_at` scheduling as primary and removes the unused `chimeway_workflows` queue requirement.
- Cross-links to demo E2E and golden-path webhook appendix resolve to existing files.

---

## Recommendation

**Ship with follow-ups.** Journey guide and doc-contract gate meet DOCS-03 intent. Address WR-01 before adopters copy the transactional Multi pattern; WR-02 and WR-03 are quick doc edits in the same files.
