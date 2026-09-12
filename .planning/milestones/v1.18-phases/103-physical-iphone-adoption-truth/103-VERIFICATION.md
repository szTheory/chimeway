---
phase: 103-physical-iphone-adoption-truth
verified: 2026-09-12T04:45:00Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: missing
  previous_score: 0/3
  gaps_closed:
    - "The genuine signed-device run completed and retained source-bound owner-separated evidence."
    - "The publisher now emits the planned four-file canonical, digest-bound, no-replace snapshot."
    - "Guide, requirements, roadmap, project, CI, and release contracts now derive bounded support truth from the verified snapshot."
  gaps_remaining: []
  regressions: []
---

# Phase 103: Physical iPhone & Adoption Truth Verification Report

**Phase Goal:** Adopter Alpha can present bounded, redacted real-iPhone evidence of the production path and understand its operational limits.
**Verified:** 2026-09-12T04:45:00Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A signed iPhone sandbox run records permission, authenticated registration, APNs provider handoff, visible alert confirmation, and one-time protected activation in redacted evidence. | ✓ VERIFIED | Opaque run `cw-physical-57aa04f3f7f2c1a81d9d2c93` completed with every fixed Chimeway and CrossWake outcome passed. The separately supplied visible-alert state is `observed`; no device, account, credential, endpoint, payload, log, or media value is retained. |
| 2 | The proof is machine-validatable and separates subjective presentation from executable provider and protected-open facts. | ✓ VERIFIED | Three canonical typed records are linked by exact run reference and machine-envelope digest. `.complete` binds each record digest and bundle digest `e84ba08c151af2f227f2e0a9e550289f576c8004f3f9b65c13b57ba17e3863fc`; a second publication is rejected without byte changes. |
| 3 | Host/operator guidance explains setup, ownership, compatibility, outcome vocabulary, offline opens, proof commands, and explicit non-goals. | ✓ VERIFIED | The canonical mobile operations guide is contract-tested, cites only safe retained authority, and keeps provider acceptance, visible presentation, protected activation, inbox state, and engagement distinct. Android/FCM, generic background sync, broad device support, device management, rich actions, and analytics remain explicit non-goals. |

**Score:** 3/3 roadmap must-haves verified

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `evidence/mobile_physical/promoted/chimeway-envelope.json` | Immutable Chimeway package and fixed lifecycle/provider facts | ✓ VERIFIED | Canonical closed schema; artifact digest, selected CrossWake authority, opaque run, capture time, and three passed Chimeway facts validate. |
| `evidence/mobile_physical/promoted/crosswake-record.json` | CrossWake-owned safe source and assertion record | ✓ VERIFIED | Exact canonical remote/revision/contract/evidence/marker/run/outcome fields plus the three owner-qualified passed assertions validate. |
| `evidence/mobile_physical/promoted/visible-alert-attestation.json` | Isolated bounded observation | ✓ VERIFIED | Exact six-field record is `observed`, shares the opaque run, and binds the exact machine envelope digest. |
| `evidence/mobile_physical/promoted/.complete` | No-replace completion authority | ✓ VERIFIED | Exact component digests and overall bundle digest rederive from retained canonical bytes; state is `validated`. |
| `lib/chimeway/mobile_proof/physical_bundle.ex` | Closed validation and exclusive publication | ✓ VERIFIED | Exact keys, ownership, revision, digest, privacy, canonical-byte, observed-only, last-marker, and collision checks execute in the focused suite. |
| `lib/mix/tasks/chimeway.mobile_physical_proof.ex` | Preflight, promotion, and retained verification | ✓ VERIFIED | Preflight returned all nine ordered checks passed from the immutable artifact, selected revision, source-bound evidence, Phase 162 regression suite, and signed-device result before promotion. |
| `guides/introduction/mobile-adoption-operations.md` | Bounded promoted support authority | ✓ VERIFIED | Documentation contract revalidates the bundle and requires every safe authority value before accepting the promoted wording. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Immutable Chimeway artifact | Chimeway envelope | archive validation plus SHA-256 | ✓ WIRED | Promotion validated the archive and retained only its digest with fixed lifecycle/provider facts. |
| Selected CrossWake source | CrossWake record | canonical named ref, exact detached clean checkout, focused test, and source-bound evidence check | ✓ WIRED | The canonical remote advertises the sole authority-file revision; fresh verification passed at exact HEAD. |
| Chimeway envelope | visible alert attestation | shared opaque run plus exact envelope SHA-256 | ✓ WIRED | The observer state cannot establish or mutate machine outcomes. |
| Three typed records | `.complete` | component digests and bundle digest | ✓ WIRED | Retained-directory verification recomputes canonical bytes and every digest before returning promoted status. |
| Verified completion snapshot | public/planning truth | executable documentation contract | ✓ WIRED | Guide and planning surfaces claim only `physical_support_promoted` for the recorded path. |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Promoted snapshot revalidation | `mix chimeway.mobile_physical_proof --verify-promoted --json` | `physical_support_promoted`; all bundle checks passed | ✓ PASS |
| Local release/doc parity | `mix ci.verify_gates` | 633 tests, 0 failures, 4 excluded; packaged Accrue lane 3 tests, 0 failures | ✓ PASS |
| Hermetic regression proof | `mix verify.alpha_twin` | Expected immutable-package Alpha proof emitted | ✓ PASS |
| Fresh remote physical contract | `mix verify.physical_proof_contract` | Exact selected revision advertised, detached, clean, focused/source-bound checks passed | ✓ PASS |
| Bundle and runner contracts | focused ExUnit selection | 7 tests, 0 failures | ✓ PASS |
| Sensitive-data exclusion | staged diff and retained-record scans | No email/account identifier; closed schema rejects forbidden sensitive categories | ✓ PASS |

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TWIN-03 | 103-01..04 | Genuine signed-iPhone proof with isolated display confirmation and redacted machine evidence | ✓ SATISFIED | Selected source authority, signed-device result, CrossWake evidence, four-file Chimeway snapshot, observed attestation, and full gate chain pass. |
| DOCS-01 | 103-03..04 | Accurate operational guidance and bounded promoted support truth | ✓ SATISFIED | Canonical guide and completion-aware documentation/release contracts pass. |

## Claim Boundary

APNs provider acceptance proves provider handoff only. Visible presentation and protected activation are separately evidenced. Nothing in this phase proves inbox seen/read, engagement, Android/FCM delivery, generic background synchronization, broad device coverage, device management, rich actions, or analytics.

## Gaps Summary

No blocking gaps remain. The only subjective input was the explicitly supplied visible-alert observation; all other acceptance claims are machine-verified. No additional phone run is required for Phase 103 or v1.18 closeout.

---

_Verified: 2026-09-12T04:45:00Z_
_Verifier: Codex (goal-backward verification)_
