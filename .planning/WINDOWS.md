---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 0
total_count: 3
last_updated: 2026-07-30T14:19:25.345Z
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
  }
]
````
