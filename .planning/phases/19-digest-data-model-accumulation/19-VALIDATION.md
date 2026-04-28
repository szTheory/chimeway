---
phase: 19
slug: digest-data-model-accumulation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL sandbox DataCase patterns and manual Oban testing where needed |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace` |
| **Full suite command** | `mix test` and `mix ci.test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/chimeway/digests/digest_rule_test.exs test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace`
- **After every plan wave:** Run `mix ci.test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-00-01 | TBD | 0 | DIGEST-01 | T-19-01 | Digest rule declarations persist stable rule identity, grouping mode, and supported window metadata without using notifier module names. | unit | `mix test test/chimeway/digests/digest_rule_test.exs --trace` | ❌ W0 | ⬜ pending |
| 19-00-02 | TBD | 0 | DIGEST-01 | T-19-02 | Bucket identity remains unique by rule, recipient, channel, grouping value, and window boundaries to prevent cross-scope bleed. | unit | `mix test test/chimeway/digests/digest_bucket_test.exs --trace` | ❌ W0 | ⬜ pending |
| 19-00-03 | TBD | 0 | DIGEST-01 | T-19-03 | Repeated planning retries create at most one membership per source delivery and do not accumulate non-held deliveries. | integration | `mix test test/chimeway/digests/accumulation_test.exs test/chimeway/orchestration/delivery_planning_test.exs --trace` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `test/chimeway/digests/digest_rule_test.exs` — lock rule identity, grouping-mode validation, and migration constraints for `DIGEST-01`
- [ ] `test/chimeway/digests/digest_bucket_test.exs` — lock composite bucket identity and window-boundary uniqueness
- [ ] `test/chimeway/digests/accumulation_test.exs` — prove retries and duplicate planning create one membership per source `delivery_id`
- [ ] Extend `test/chimeway/orchestration/delivery_planning_test.exs` — prove accumulation happens only after the canonical delivery remains pending and `:digest_held`

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
