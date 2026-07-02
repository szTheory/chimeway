---
phase: 77
slug: truth-baseline-and-package-model-decision
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-02
---

# Phase 77 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit through Mix for release-contract surfaces; source assertions for the phase-local decision artifact. |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `rg -n "chimeway|chimeway_admin|chimeway_inbox|v1\\.14|v1\\.0\\.0|Release Please|HexDocs|source_ref" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` |
| **Full suite command** | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --warnings-as-errors` |
| **Estimated runtime** | ~30 seconds for source assertions; ~60 seconds for focused ExUnit release contracts |

---

## Sampling Rate

- **After every task commit:** Run the quick `rg` assertion against `77-PACKAGE-MODEL-DECISION.md`.
- **After every plan wave:** Run `git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides` and confirm it is empty for Phase 77.
- **Before `/gsd:verify-work`:** Run the full focused release contract command if package/release language changed; otherwise run quick artifact assertions plus the public-surface diff scope check.
- **Max feedback latency:** 90 seconds.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 77-01-01 | 01 | 1 | TRUTH-04 | T-77-01 | Planning labels such as `v1.14` are explicitly prohibited as package release refs. | source assertion | `rg -n "planning.*v1\\.14|milestone.*v1\\.14|not.*package|package.*tag|source_ref|publish ref|GitHub release" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` | W0 | pending |
| 77-01-02 | 01 | 1 | TRUTH-04 | T-77-02 | Root package model names `chimeway` as the only v1.14 Hex package and names sibling packages as preview/path packages. | source assertion | `rg -n "only Hex-published package|chimeway_admin|chimeway_inbox|preview|path package|not.*Hex" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md` | W0 | pending |
| 77-01-03 | 01 | 1 | TRUTH-04 | T-77-03 | Baseline inventory assigns package, docs, and CI drift to Phases 78, 79, and 80 without editing public surfaces. | source assertion | `rg -n "Phase 78|Phase 79|Phase 80|README|mix\\.exs|CHANGELOG|release-please|ci-gate|pr-gate" .planning/phases/77-truth-baseline-and-package-model-decision/77-PACKAGE-MODEL-DECISION.md && git diff --name-only -- README.md mix.exs CHANGELOG.md .github/workflows MAINTAINING.md guides` | W0 | pending |

---

## Wave 0 Requirements

Existing infrastructure covers the phase requirement. Phase 77 creates a planning artifact and should not add new test framework files.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Decision artifact is narrow enough for Phase 77 and does not drift into Phase 78-80 implementation. | TRUTH-04 | Scope boundary is a planning judgment. | Review `77-PACKAGE-MODEL-DECISION.md` and confirm it records the package model, tag namespace, owner map, and baseline inventory without editing README, package metadata, changelog, workflows, maintainer docs, or guides. |

---

## Validation Sign-Off

- [x] All tasks have automated source assertions or existing focused release-contract coverage.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all missing references.
- [x] No watch-mode flags.
- [x] Feedback latency < 90s.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
