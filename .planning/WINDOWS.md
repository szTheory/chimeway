---
schema_version: 1
open_count: 1
waived_count: 1
fixed_count: 7
total_count: 9
last_updated: 2026-08-12T17:40:11.227Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 91 | unrun-verify | .github/workflows/ci.yml |  | QUAL-01 backstop: live CI proof that all 14 converted setup-beam jobs resolve Elixir 1.19.5 / Erlang OTP-27.3.4.15 identically — not yet observed running end-to-end (deferred per orchestrator instruction for this run). | fixed | VERIFIED during /gsd-verify-work 91 on push run 30556372077 @ fe3f732 — all 14 version-file lanes resolved identical 1.19.5 / 27.3.4.15; matrix legs diverged (OTP 26 → 26.2.5.21), floor → 1.17.3/OTP 27. Reconciled at v1.16 close. | 2026-07-30T14:14:20.666Z | 2026-07-30T20:21:47.633Z |
| 2 | 91 | unrun-verify | .github/dependabot.yml |  | Dependabot config-parse backstop (GitHub Insights -> Dependency graph -> Dependabot listing mix + github-actions ecosystems) not observable pre-merge; only verifiable in a live GitHub run post-push | waived | Post-merge GitHub-UI-only observation; proven at phase time as config-on-default-branch + schema-valid. main is now pushed so the config is live — the Insights listing is a manual eyeball whenever desired, not a code defect. Waived at v1.16 close. | 2026-07-30T14:19:25.282Z | 2026-07-30T20:21:47.633Z |
| 3 | 91 | unrun-verify | .github/workflows/ci.yml | 97 | CI advisory-audit step backstop (lint job running hex.audit + deps.audit, printing findings, never failing the gate via continue-on-error) not observable locally; only verifiable in a live CI run | fixed | VERIFIED during /gsd-verify-work 91 on push run 30556372077 @ fe3f732 — both hex.audit + deps.audit printed hackney/decimal advisories with Lint green (exit 1 swallowed by continue-on-error). Reconciled at v1.16 close. | 2026-07-30T14:19:25.345Z | 2026-07-30T20:21:47.633Z |
| 4 | 92 | unrun-verify | .github/workflows/ci.yml |  | REL-03 backstop: test_seed_zero + nightly-gate wiring is contract-tested locally but not yet observed green on a live -f run_nightly=true dispatch (deferred — phase commits not pushed in this execution session, push out of scope for this executor). | fixed | VERIFIED on nightly-dispatch run 30573935421 @ eff0ba43 — test_seed_zero=success, nightly-gate=success; on the push run 30573877353 test_seed_zero correctly skipped (nightly-only adjacency edge holds). | 2026-07-30T18:33:55.228Z | 2026-07-30T19:26:34.000Z |
| 5 | 92 | unrun-verify | .planning/CI-HARDENING-BACKLOG.md |  | REL-02 backstop: backlog #2/#3 root causes are pinned but the verified-fixed decision requires a live-CI proof pinned to phase HEAD's own push run; that run does not exist yet (commits not pushed this session). Quarantined behind tracking issue #4 pending push. | fixed | VERIFIED-FIXED on phase-HEAD push run 30573877353 @ eff0ba43 — verify_example, verify_journeys, verify_accrue all success. Backlog #2/#3 flipped to verified-fixed; issue #4 closed. | 2026-07-30T18:33:55.306Z | 2026-07-30T19:26:34.000Z |
| 6 | 96 | unrun-verify | .github/workflows/ci.yml |  | Live GitHub Actions verify_adoption_paths execution remains required after push. | fixed |  | 2026-08-10T03:56:08.129Z | 2026-08-11T22:01:22.438Z |
| 7 | 96 | unrun-verify | test/chimeway/release_gate_contract_test.exs |  | mix ci.verify_gates remains red in pre-existing Mailglass timeline and Accrue source-contract cases outside Plan 96-03 files | fixed |  | 2026-08-10T20:57:09.536Z | 2026-08-11T22:01:23.413Z |
| 8 | 96.1 | unrun-verify | scripts/ci/assert-adoption-run.sh |  | Hosted exact-SHA Adoption proof paths evidence unavailable until the implementation commit has a completed pull-request run. | fixed |  | 2026-08-11T15:34:40.947Z | 2026-08-11T22:01:24.084Z |
| 9 | 97 | deviation | test/chimeway/runtime_prefix_integration_test.exs | 313 | Authorized fixture tenant alignment required for the explicit event-recovery predicate. | open |  | 2026-08-12T17:40:11.227Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "QUAL-01 backstop: live CI proof that all 14 converted setup-beam jobs resolve Elixir 1.19.5 / Erlang OTP-27.3.4.15 identically — not yet observed running end-to-end (deferred per orchestrator instruction for this run).",
    "status": "fixed",
    "reason": "VERIFIED during /gsd-verify-work 91 on push run 30556372077 @ fe3f732 — all 14 version-file lanes resolved identical 1.19.5 / 27.3.4.15; matrix legs diverged (OTP 26 → 26.2.5.21), floor → 1.17.3/OTP 27. Reconciled at v1.16 close.",
    "recorded_at": "2026-07-30T14:14:20.666Z",
    "resolved_at": "2026-07-30T20:21:47.633Z"
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/dependabot.yml",
    "line": null,
    "description": "Dependabot config-parse backstop (GitHub Insights -> Dependency graph -> Dependabot listing mix + github-actions ecosystems) not observable pre-merge; only verifiable in a live GitHub run post-push",
    "status": "waived",
    "reason": "Post-merge GitHub-UI-only observation; proven at phase time as config-on-default-branch + schema-valid. main is now pushed so the config is live — the Insights listing is a manual eyeball whenever desired, not a code defect. Waived at v1.16 close.",
    "recorded_at": "2026-07-30T14:19:25.282Z",
    "resolved_at": "2026-07-30T20:21:47.633Z"
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/workflows/ci.yml",
    "line": 97,
    "description": "CI advisory-audit step backstop (lint job running hex.audit + deps.audit, printing findings, never failing the gate via continue-on-error) not observable locally; only verifiable in a live CI run",
    "status": "fixed",
    "reason": "VERIFIED during /gsd-verify-work 91 on push run 30556372077 @ fe3f732 — both hex.audit + deps.audit printed hackney/decimal advisories with Lint green (exit 1 swallowed by continue-on-error). Reconciled at v1.16 close.",
    "recorded_at": "2026-07-30T14:19:25.345Z",
    "resolved_at": "2026-07-30T20:21:47.633Z"
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "92",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "REL-03 backstop: test_seed_zero + nightly-gate wiring is contract-tested locally but not yet observed green on a live -f run_nightly=true dispatch (deferred — phase commits not pushed in this execution session, push out of scope for this executor).",
    "status": "fixed",
    "reason": "VERIFIED on nightly-dispatch run 30573935421 @ eff0ba43 — test_seed_zero=success, nightly-gate=success; on the push run 30573877353 test_seed_zero correctly skipped (nightly-only adjacency edge holds).",
    "recorded_at": "2026-07-30T18:33:55.228Z",
    "resolved_at": "2026-07-30T19:26:34.000Z"
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "92",
    "file": ".planning/CI-HARDENING-BACKLOG.md",
    "line": null,
    "description": "REL-02 backstop: backlog #2/#3 root causes are pinned but the verified-fixed decision requires a live-CI proof pinned to phase HEAD's own push run; that run does not exist yet (commits not pushed this session). Quarantined behind tracking issue #4 pending push.",
    "status": "fixed",
    "reason": "VERIFIED-FIXED on phase-HEAD push run 30573877353 @ eff0ba43 — verify_example, verify_journeys, verify_accrue all success. Backlog #2/#3 flipped to verified-fixed; issue #4 closed.",
    "recorded_at": "2026-07-30T18:33:55.306Z",
    "resolved_at": "2026-07-30T19:26:34.000Z"
  },
  {
    "id": 6,
    "kind": "unrun-verify",
    "phase": "96",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "Live GitHub Actions verify_adoption_paths execution remains required after push.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T03:56:08.129Z",
    "resolved_at": "2026-08-11T22:01:22.438Z"
  },
  {
    "id": 7,
    "kind": "unrun-verify",
    "phase": "96",
    "file": "test/chimeway/release_gate_contract_test.exs",
    "line": null,
    "description": "mix ci.verify_gates remains red in pre-existing Mailglass timeline and Accrue source-contract cases outside Plan 96-03 files",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-10T20:57:09.536Z",
    "resolved_at": "2026-08-11T22:01:23.413Z"
  },
  {
    "id": 8,
    "kind": "unrun-verify",
    "phase": "96.1",
    "file": "scripts/ci/assert-adoption-run.sh",
    "line": null,
    "description": "Hosted exact-SHA Adoption proof paths evidence unavailable until the implementation commit has a completed pull-request run.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-11T15:34:40.947Z",
    "resolved_at": "2026-08-11T22:01:24.084Z"
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "97",
    "file": "test/chimeway/runtime_prefix_integration_test.exs",
    "line": 313,
    "description": "Authorized fixture tenant alignment required for the explicit event-recovery predicate.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T17:40:11.227Z",
    "resolved_at": null
  }
]
````
