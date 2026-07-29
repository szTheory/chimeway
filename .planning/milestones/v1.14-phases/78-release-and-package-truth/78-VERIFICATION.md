---
phase: 78-release-and-package-truth
verified: 2026-07-03T09:05:00Z
status: passed
score: 11/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
requirements_verified: [TRUTH-01, TRUTH-02, TRUTH-03]
---

# Phase 78: Release and Package Truth Verification Report

**Phase Goal:** Align root package metadata, release manifest, changelog, HexDocs source refs, README install constraints, package files whitelist, canonical repo/source links, sibling package install-status copy, and package truth contracts.
**Verified:** 2026-07-03T09:05:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal is achieved. Every package-facing truth surface (root metadata, release manifest, changelog heading, HexDocs source refs, README install constraint, package files whitelist, canonical repo/source links, and sibling install-status copy) is not only correct in source but is enforced by executable ExUnit contracts (`Chimeway.ReleaseGateContractTest`, `Chimeway.DocContractTest`) plus the `mix verify.parity` artifact proof. I ran the contracts and the parity proof myself rather than trusting the SUMMARY claims — both pass.

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | TRUTH-01/D-01: root @version, manifest, changelog heading, HexDocs source_ref, README install constraint agree on package SemVer 1.0.0 / v1.0.0 | ✓ VERIFIED | mix.exs `@version "1.0.0"` + `source_ref: "v#{@version}"` (mix.exs:4,228); manifest `{".": "1.0.0"}`; CHANGELOG `## 1.0.0 (2026-05-08)`; README `{:chimeway, "~> 1.0"}`; contract `root package release identity uses package SemVer refs` (test:319) asserts all of these and passes |
| 2 | TRUTH-02/D-03: package-facing repo/source URLs use https://github.com/szTheory/chimeway | ✓ VERIFIED | mix.exs `links` + `source_url` canonical (mix.exs:221,229); README CI badge canonical (README.md:6); legacy `jonlunsford` absent (grep count 0 in mix.exs/README); contract `package-facing repository and source URLs use the canonical repository` (test:351) passes |
| 3 | D-02: Release Please + publish workflows stay root-only, no sibling publish lanes | ✓ VERIFIED | release-please-config.json `packages` has exactly `"."` with `changelog-path: CHANGELOG.md`, `include-v-in-tag: true`; grep for `chimeway_admin`/`chimeway_inbox` in both workflows returns none; contract `Release Please config stays root-only` (test:387) + workflow root-only contracts pass |
| 4 | D-04: Phase 78 narrows only package-facing truth, no Phase 79/80 rewrite | ✓ VERIFIED | Modified files limited to package/release/guide-status surfaces; guide edits confined to dependency sections; no front-door IA rewrite present |
| 5 | TRUTH-03/D-05: admin & inbox docs state in-repo preview/path status until promotion | ✓ VERIFIED | admin guide line 17 + inbox guide line 17 both state "in-repo preview/path package" and "not published on Hex yet"; doc contracts (test:378,885) pass |
| 6 | TRUTH-03/D-06: guide copy carries no current-Hex sibling install claims | ✓ VERIFIED | grep for `{:chimeway_admin, "~> 1.0"}` / `{:chimeway_inbox, "~> 1.0"}` in guides returns none; negative doc contracts `refute` these snippets (test:396,903) pass |
| 7 | D-07: truth enforced via ExUnit contracts, not a parallel shell checker | ✓ VERIFIED | All checks live in `release_gate_contract_test.exs` / `doc_contract_test.exs`, run by `mix ci.verify_gates`; no standalone shell checker added |
| 8 | TRUTH-01/D-08: default `mix hex.build --unpack` succeeds (no skip env) and proves whitelist | ✓ VERIFIED | Ran `mix verify.parity` → exit 0, "unpacked package root /tmp/chimeway_verify contains all whitelist entries"; artifact contract `unpacked Hex package contains the package file whitelist` (test:473) passes; env-scoped sigra override (mix.exs:208-214) keeps prod build Hex-legal while dev/test resolves |
| 9 | TRUTH-02/D-03: unpacked artifact carries canonical package/source links | ✓ VERIFIED | verify.parity output shows `GitHub: https://github.com/szTheory/chimeway`; artifact contract `unpacked Hex package carries package truth docs and source links` (test:493) asserts canonical present + legacy absent, passes |
| 10 | TRUTH-03/D-05/D-06: unpacked artifact includes corrected admin/inbox guide copy | ✓ VERIFIED | Artifact contract (test:517-529) reads unpacked guides, asserts preview/path status + refutes current-Hex snippets, passes; guides are in `files` whitelist |
| 11 | D-07: package artifact truth enforced via ExUnit + verify.parity, not shell-only | ✓ VERIFIED | Artifact proof is `Chimeway.ReleaseGateContractTest` describe block + `verify.parity` Mix alias; both run and pass |

**Score:** 11/11 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `mix.exs` | Canonical links/source_url, @version 1.0.0, source_ref, files whitelist, verify.parity, env-scoped sigra | ✓ VERIFIED | All present (lines 4, 208-214, 219, 221, 228-229, 91-93); wired into project()/package()/docs()/aliases() |
| `README.md` | `{:chimeway, "~> 1.0"}` + canonical CI badge | ✓ VERIFIED | Lines 6, 15; legacy URL absent |
| `test/chimeway/release_gate_contract_test.exs` | Chimeway.ReleaseGateContractTest release/package/source/artifact contracts | ✓ VERIFIED | 4 phase-added describe blocks; runs green (part of 493-test gate) |
| `test/chimeway/doc_contract_test.exs` | Chimeway.DocContractTest sibling preview/path contracts | ✓ VERIFIED | Positive + negative + source-evidence assertions (lines 378-407, 885-910) |
| `guides/introduction/admin-console-integration.md` | Admin preview/path install-status copy | ✓ VERIFIED | Line 17 status prose; path dep line 23 |
| `guides/introduction/inbox-integration.md` | Inbox preview/path install-status copy | ✓ VERIFIED | Line 17 status prose; path dep line 23 |

### Key Link Verification

| From | To | Via | Status |
| ---- | -- | --- | ------ |
| mix.exs | .release-please-manifest.json | contract parses both @version and manifest root entry | ✓ WIRED (test:327-333 passes) |
| mix.exs | README.md | contract derives install constraint from @version MAJOR.MINOR | ✓ WIRED (test:344-348 passes) |
| release_gate_contract_test.exs | release.yml / publish-hex.yml | workflow contracts assert tag checkout, gate replay, root hex.build/publish | ✓ WIRED (test:402,441 pass) |
| release_gate_contract_test.exs | mix hex.build --unpack | System.cmd builds package, asserts whitelist roots | ✓ WIRED (verify.parity exit 0; test:473 passes) |
| release_gate_contract_test.exs | admin/inbox guides | unpacked artifact includes corrected guide content | ✓ WIRED (test:493 passes) |
| chimeway_admin/mix.exs, chimeway_inbox/mix.exs | guides | source-evidence path-package assertions | ✓ WIRED (doc contracts test:400,907) |

### Behavioral Spot-Checks / Probe Execution

| Check | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| ci.verify_gates surface | `MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --warnings-as-errors` | 493 tests, 0 failures | ✓ PASS |
| Package artifact proof | `mix verify.parity` | exit 0; unpacked root has all whitelist entries; GitHub link canonical | ✓ PASS |
| Dev/test dependency resolution (Rule-4) | test suite compiled+ran under MIX_ENV=test | 493 tests ran (deps resolved) | ✓ PASS |
| Prod Hex build (Rule-4) | verify.parity built under MIX_ENV=prod | build succeeded, override absent | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
| ----------- | -------------- | ----------- | ------ | -------- |
| TRUTH-01 | 78-01, 78-03 | Root version/manifest/changelog/source-ref/README/automation/whitelist/artifact agree | ✓ SATISFIED | Truths 1, 8; verify.parity; REQUIREMENTS.md marked Complete |
| TRUTH-02 | 78-01, 78-03 | Canonical repo/source links, reject stale | ✓ SATISFIED | Truths 2, 9; legacy URL absent everywhere |
| TRUTH-03 | 78-02, 78-03 | Sibling docs state preview/path, no current-Hex claims | ✓ SATISFIED | Truths 5, 6, 10 |

All three requirement IDs declared in PLAN frontmatter (TRUTH-01, TRUTH-02, TRUTH-03) are accounted for in REQUIREMENTS.md (lines 12-14, 72-74), all mapped to Phase 78 and marked Complete. No orphaned requirements.

### Anti-Patterns Found

None. Debt-marker scan (TBD/FIXME/XXX/PLACEHOLDER/not-yet-implemented) across all eight phase-modified files returned no hits.

### Rule-4 Deviation Assessment

Plan 78-03 changed the Sigra dependency approach from "unconditionally remove `override: true`" to "scope `override: true` to `Mix.env() != :prod`" (coordinator-approved, 78-03-SUMMARY). This deviation is verified as sound, not a scope reduction: the prod Hex build omits the override (verify.parity exit 0, no skip env), and dev/test resolves with the override (493 tests ran). Both goal conditions — default prod package build succeeds AND deps resolve in dev/test — hold. The mix.exs comment (lines 200-207) documents the rationale. Goal met; no penalty.

### Gaps Summary

None. All 11 must-have truths verified against the actual codebase with executable evidence. The two ExUnit contract modules and the `verify.parity` artifact proof were run directly during verification and pass. The package build produces a Hex-legal artifact carrying canonical links, the correct file whitelist, and corrected sibling preview/path guide copy.

---

_Verified: 2026-07-03T09:05:00Z_
_Verifier: Claude (gsd-verifier)_
