---
status: issues_found
phase: 01-durable-core-spine
updated: 2026-04-24T03:02:07Z
---

## Summary

- Reviewed Phase 01 implementation scope across plans `01-01`, `01-02`, and `01-03`, including all touched runtime modules, migrations, and tests.
- Executed verification command `mix test` in the project root (`17 tests, 0 failures`).
- Identified 3 actionable findings: 1 high-severity correctness risk and 2 medium-severity robustness/security risks.

## Findings

### 1) High — Notifier contract accepts recipient shapes that later fail persistence

**Where:** `lib/chimeway/notifier.ex`, `lib/chimeway/trigger.ex`, `priv/repo/migrations/20260424023201_create_chimeway_notifications.exs`  
**What:** The public notifier contract (`recipients/1`) does not require a recipient type/channel, but persistence requires non-null `recipient_type`. `Chimeway.Trigger` maps unknown recipient type to `nil`, which then fails at DB insert time.  
**Impact:** A notifier can satisfy the declared behaviour and still fail at runtime with `{:error, {:notifications_insert_failed, ...}}`, creating a contract mismatch and avoidable production failure mode.

### 2) Medium — Notifier callback exceptions are not normalized and can crash caller flow

**Where:** `lib/chimeway/trigger.ex`  
**What:** `notifier.recipients/1` and `notifier.build/2` are invoked without a defensive boundary that normalizes raised exceptions into tagged error tuples. Only the `insert_all` call is wrapped in `try/rescue`.  
**Impact:** A buggy notifier implementation can raise and terminate the trigger call path instead of returning a stable error contract, increasing operational risk and making retries/error handling inconsistent.

### 3) Medium — Sensitive-data redaction is shallow (top-level only)

**Where:** `lib/chimeway/trigger.ex` (`sanitize_map/1`)  
**What:** Sanitization drops `password|token|secret` only at the top map level. Nested maps/lists are persisted as-is.  
**Impact:** Secrets embedded in nested payload or metadata structures may be written to durable storage, creating an information disclosure risk.

## Recommendations

1. Add explicit recipient-shape validation in the trigger pipeline (or tighten notifier behaviour docs/contracts) so missing `recipient_type`/`channel` fails early with a deterministic tagged error before DB work.
2. Wrap notifier callback execution (`recipients/1`, `build/2`) in normalization logic that converts exceptions to stable error tuples, and add tests for raised callback paths.
3. Replace shallow redaction with recursive sanitization for nested maps/lists, then add test coverage proving nested secret keys are removed from both `payload` and `metadata`.
4. Optional quality follow-up: remove `mix test` warning about `test/support/data_case.ex` not matching test patterns (rename/configure) to keep CI output clean.
