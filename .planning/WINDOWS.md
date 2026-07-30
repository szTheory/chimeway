---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 0
total_count: 5
last_updated: 2026-07-30T18:33:55.306Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 91 | unrun-verify | .github/workflows/ci.yml |  | QUAL-01 backstop: live CI proof that all 14 converted setup-beam jobs resolve Elixir 1.19.5 / Erlang OTP-27.3.4.15 identically — not yet observed running end-to-end (deferred per orchestrator instruction for this run). | open |  | 2026-07-30T14:14:20.666Z |  |
| 2 | 91 | unrun-verify | .github/dependabot.yml |  | Dependabot config-parse backstop (GitHub Insights -> Dependency graph -> Dependabot listing mix + github-actions ecosystems) not observable pre-merge; only verifiable in a live GitHub run post-push | open |  | 2026-07-30T14:19:25.282Z |  |
| 3 | 91 | unrun-verify | .github/workflows/ci.yml | 97 | CI advisory-audit step backstop (lint job running hex.audit + deps.audit, printing findings, never failing the gate via continue-on-error) not observable locally; only verifiable in a live CI run | open |  | 2026-07-30T14:19:25.345Z |  |
| 4 | 92 | unrun-verify | .github/workflows/ci.yml |  | REL-03 backstop: test_seed_zero + nightly-gate wiring is contract-tested locally but not yet observed green on a live -f run_nightly=true dispatch (deferred — phase commits not pushed in this execution session, push out of scope for this executor). | open |  | 2026-07-30T18:33:55.228Z |  |
| 5 | 92 | unrun-verify | .planning/CI-HARDENING-BACKLOG.md |  | REL-02 backstop: backlog #2/#3 root causes are pinned but the verified-fixed decision requires a live-CI proof pinned to phase HEAD's own push run; that run does not exist yet (commits not pushed this session). Quarantined behind tracking issue #4 pending push. | open |  | 2026-07-30T18:33:55.306Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "QUAL-01 backstop: live CI proof that all 14 converted setup-beam jobs resolve Elixir 1.19.5 / Erlang OTP-27.3.4.15 identically — not yet observed running end-to-end (deferred per orchestrator instruction for this run).",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T14:14:20.666Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/dependabot.yml",
    "line": null,
    "description": "Dependabot config-parse backstop (GitHub Insights -> Dependency graph -> Dependabot listing mix + github-actions ecosystems) not observable pre-merge; only verifiable in a live GitHub run post-push",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T14:19:25.282Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "unrun-verify",
    "phase": "91",
    "file": ".github/workflows/ci.yml",
    "line": 97,
    "description": "CI advisory-audit step backstop (lint job running hex.audit + deps.audit, printing findings, never failing the gate via continue-on-error) not observable locally; only verifiable in a live CI run",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T14:19:25.345Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "92",
    "file": ".github/workflows/ci.yml",
    "line": null,
    "description": "REL-03 backstop: test_seed_zero + nightly-gate wiring is contract-tested locally but not yet observed green on a live -f run_nightly=true dispatch (deferred — phase commits not pushed in this execution session, push out of scope for this executor).",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T18:33:55.228Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "92",
    "file": ".planning/CI-HARDENING-BACKLOG.md",
    "line": null,
    "description": "REL-02 backstop: backlog #2/#3 root causes are pinned but the verified-fixed decision requires a live-CI proof pinned to phase HEAD's own push run; that run does not exist yet (commits not pushed this session). Quarantined behind tracking issue #4 pending push.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-30T18:33:55.306Z",
    "resolved_at": null
  }
]
````
