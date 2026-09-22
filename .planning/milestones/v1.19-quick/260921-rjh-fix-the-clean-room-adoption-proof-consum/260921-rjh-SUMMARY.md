---
phase: quick-260921-rjh
plan: "01"
subsystem: ci-adoption-proof
tags: [swoosh, mailglass, apns, ci-gate, nightly-gate, upstream-drift, dependency-audit]
requirements: [QUICK-260921-RJH]
requirements-completed: [QUICK-260921-RJH]
status: complete

dependency-graph:
  requires: []
  provides:
    - Clean-room Mailglass adoption-proof consumer boots under swoosh 1.28.x with no mix.lock
    - Regression guard for the generated consumer's Swoosh api_client setting (fast lane + end-to-end)
    - Adopter-facing Swoosh api_client guidance on guide, demo host, and doc contract
    - Optional APNs adapter gate green again after two independent upstream-drift breaks
  affects:
    - guides/introduction/mailglass-integration.md
    - examples/chimeway_demo_host/config/config.exs
    - scripts/verify-apns.sh
    - test/fixtures/apns_consumer/apns-enabled.lock

tech-stack:
  added: []
  patterns:
    - "config :swoosh, :api_client, false in a fake/local-adapter consumer, instead of adding {:hackney, ...} as a dependency"
    - "Baseline-aware dependency-tree assertions that tolerate an upstream package's requirement flipping from mandatory to optional (tzdata 1.1 -> 1.2 Hackney requirement)"
    - "Hermetic-consumer lockfiles regenerated (not overridden) to pick up an upstream security patch already satisfied by the existing version constraint"

key-files:
  created: []
  modified:
    - priv/adoption_proof/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
    - test/chimeway/doc_contract_test.exs
    - guides/introduction/mailglass-integration.md
    - examples/chimeway_demo_host/config/config.exs
    - scripts/verify-apns.sh
    - test/fixtures/apns_consumer/apns-enabled.lock

decisions:
  - "[D-01, from plan]: Disable Swoosh's api_client (config :swoosh, :api_client, false) in the generated consumer rather than adding {:hackney, ...} as a dependency — the proof's adapter is Mailglass.Adapters.Fake, so no HTTP client is ever exercised, and this keeps the clean-room proof's dependency surface unchanged."
  - "[deviation, Rule 1]: scripts/verify-apns.sh's disabled-mode Hackney-edge assertion assumed tzdata's Hackney requirement was always non-optional; tzdata 1.2 made it optional, so a fresh resolve now legitimately shows zero edges instead of exactly one. Widened the check to accept 0 or 1 edges, running the tzdata-provenance check only when an edge is present."
  - "[deviation, Rule 1]: The enabled APNs consumer's locked mint 1.10.0 carries a real medium-severity advisory (CVE-2026-82672, HTTP/1 response smuggling). The script's mix hex.audit gate is intentionally strict (contract-tested to forbid --ignore, continue-on-error, and || true), so the fix was the dependency itself: regenerated apns-enabled.lock, which naturally resolves mint 1.10.1 (patched) under finch's existing `~> 1.8` constraint. pigeon/httpoison/hackney pins unchanged."

actuals:
  tokens: 5114
  tasks: 3
  commits: 3
  plan_head_before: a653535e17a9d19c4f6d18b3c4ffab19f1e1c76b

duration: ~3h
completed: 2026-09-22
---

# Phase quick-260921-rjh Plan 01: Fix the Clean-Room Adoption-Proof Consumer Summary

Fixed the swoosh-1.28.x boot failure in the clean-room Mailglass adoption proof (`config :swoosh, :api_client, false`, D-01), extended the same fix to every adopter-facing surface (guide, demo host, doc contract), then drove `ci-gate` and `nightly-gate` fully green on the pushed SHA — surfacing and fixing two further, independent upstream-drift breaks in the Optional APNs gate along the way (tzdata's now-optional Hackney requirement, and a real mint CVE).

## What Was Built

**Task 1 — Boot the clean-room consumer end-to-end under swoosh 1.28.x**
- `priv/adoption_proof/artifact_consumer_fixture.ex`: the `mailglass?` branch of `config_exs/3` now emits `config :swoosh, :api_client, false` alongside the existing Mailglass config lines in the generated consumer's `config/config.exs`.
- `test/chimeway/release_gate_contract_test.exs`: added a cheap source-grep test (`generated consumer config sets a Swoosh api_client so the consumer boots without hackney`) next to the existing fast fixture-source test, plus an assertion on `prove_mailglass!`'s returned `config_source` proving the setting reached the file written to disk.
- Verified: `release_gate_contract_test.exs` green — 168 tests, 0 failures (the previously-failing end-to-end proof passes).

**Task 2 — Close the same gap on every adopter-facing surface**
- `guides/introduction/mailglass-integration.md`: added the Swoosh `api_client` line to the "Clean-consumer repository topology" config block, plus a prose paragraph in "Runtime config" explaining the swoosh-1.28 hard-boot-failure behavior and what fake/local vs. HTTP-backed adapters need.
- `test/chimeway/doc_contract_test.exs`: extended the existing guide↔fixture coupling test to assert the guide contains the same `config :swoosh, :api_client, false` line the fixture emits.
- `examples/chimeway_demo_host/config/config.exs`: added the same explicit setting with an explanatory comment (demo host's Mailglass adapter is fake/local).
- `guides/recipes/mailglass-integration-blueprint.md` and `README.md` checked — neither presents a full config.exs-style Mailglass block (only the `channel_adapters` registration snippet, already mirrored by the guide's Section 3) — left unchanged, as instructed.
- Verified: `doc_contract_test.exs` + `release_gate_contract_test.exs` green — 672 tests, 0 failures; demo host `mix format --check-formatted` clean.

**Task 3 — Full local `mix ci`, push, and assert both gates green**
- Ran `mix ci` (lint + test) locally: 1612 tests, 0 failures, Credo clean, exit 0.
- Ran `mix ci.verify_gates` locally: exit 0 (672 + 3 tests, 0 failures).
- Staged and committed Tasks 1 and 2, pushed to `main` (`origin/main` fast-forward via owner ruleset bypass).
- **First push (`26350c44`) revealed ci-gate red** on a lane unrelated to swoosh: `Optional APNs adapter gate` failed `mix verify.apns`. Root-caused and fixed (see Deviations) rather than band-aided, per the plan's explicit "diagnose and fix the root cause, do not disable/skip/tag-exclude" instruction.
- Re-ran `mix ci` locally (1612 tests, 0 failures) after the APNs fix, committed (`d188e410`), pushed again.
- Both gates asserted green on the final pushed SHA `d188e41031f2c35735ec32dcff5a0397165216fa`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `scripts/verify-apns.sh`'s disabled-mode Hackney-edge baseline assumed a mandatory tzdata→Hackney edge that no longer exists**
- **Found during:** Task 3, first `ci-gate` assertion on pushed SHA `26350c44` — `Optional APNs adapter gate` failed with `verify.apns: disabled fixture has a Hackney edge beyond the root tzdata baseline`.
- **Issue:** tzdata 1.2 (released 2026-09-16) changed its Hackney requirement from mandatory to `optional: true`. The disabled-APNs consumer fixture does a fresh, lockfile-free `mix deps.get`, so it now resolves tzdata 1.2.1, and since nothing else needs Hackney, `mix deps.tree` correctly omits it entirely — 0 edges instead of the previously-guaranteed 1.
- **Fix:** Widened the assertion to accept 0 or 1 Hackney edges; the tzdata-provenance `awk` check (verifying any edge that *is* present traces back to tzdata, not a stray APNs leak) now only runs when exactly one edge exists. Preserved both existing fail-message strings verbatim so the pre-existing contract test (`disabled consumer audit is baseline-aware about root tzdata's Hackney edge`) needed no changes.
- **Files modified:** `scripts/verify-apns.sh`
- **Commit:** `d188e410`

**2. [Rule 1 - Bug] Enabled APNs consumer's locked `mint 1.10.0` carries a real medium-severity CVE**
- **Found during:** Task 3, same `ci-gate` failure investigation — after fixing the Hackney-edge check, the enabled-mode `mix hex.audit` step failed on `mint 1.10.0 VULNERABLE! EEF-CVE-2026-82672 (MEDIUM)` (HTTP/1 response-smuggling via unvalidated chunk-size-line tail; published 2026-09-19, fixed in mint 1.10.1 published the same day).
- **Considered and rejected:** making `mix hex.audit` advisory-only (`|| true` / `set +e`) to match the root repo's `ci.audit` `continue-on-error` posture (D-12). Rejected because an existing contract test (`packaged APNs verifier locks, audits, and rejects graph drift`) explicitly refutes `"hex.audit --ignore"`, `"mix hex.audit || true"`, and `"continue-on-error"` in this script — this gate is intentionally strict by design, unlike the advisory-only root-level audit.
- **Fix:** Regenerated `test/fixtures/apns_consumer/apns-enabled.lock` via a fresh `mix deps.get` against the unpacked package (finch's existing `mint ~> 1.8` constraint naturally resolves the patched 1.10.1 without any override). `pigeon 2.0.1` / `httpoison 3.0.0` / `hackney 4.7.4` — the three explicitly overridden/asserted pins — are unchanged; other transitive bumps (h2, joken, oban, quic, tzdata, webtransport) are incidental normal-range upgrades from the same fresh resolve, not separately vetted.
- **Files modified:** `test/fixtures/apns_consumer/apns-enabled.lock`
- **Commit:** `d188e410`

Both fixes were verified directly via `bash scripts/verify-apns.sh` (exit 0, no advisories) before being folded into the pushed commit, and via the full `mix ci` (1612 tests, 0 failures) before the second push.

## Evidence Trail (ci-gate / nightly-gate)

**Pushed SHA:** `d188e41031f2c35735ec32dcff5a0397165216fa`

| Gate | Run ID | Conclusion | Trigger |
|------|--------|------------|---------|
| ci-gate | 106593694364 | success | push (35678709523) |
| ci-gate | 106596502468 | success | workflow_dispatch run_nightly=true (35679756564) |
| nightly-gate | 106591949184 | skipped | push (35678709523) — nightly tier not run on plain push, expected |
| nightly-gate | 106600955891 | success | workflow_dispatch run_nightly=true (35679756564) |
| Optional APNs adapter gate | (job on 35679756564) | success | workflow_dispatch run_nightly=true |
| Release gate contract | (job on 35679756564) | success | workflow_dispatch run_nightly=true |

Asserting commands (headSha-guarded, per plan instruction):
```bash
SHA=$(git rev-parse HEAD)
gh api "repos/szTheory/chimeway/actions/runs?head_sha=$SHA" --jq '[.workflow_runs[].id] | .[]' \
  | while read -r RID; do
      gh run view "$RID" --json headSha,jobs \
        --jq "select(.headSha==\"$SHA\") | .jobs[] | select(.name==\"ci-gate\" or .name==\"nightly-gate\") | \"\(.name)=\(.conclusion)\""
    done | sort -u
# -> ci-gate=success / nightly-gate=success (both runs on the pushed SHA)

gh workflow run ci.yml --ref main -f run_nightly=true
gh run list --workflow=ci.yml --limit 5 --json databaseId,headSha,event,status  # confirmed headSha == pushed SHA before trusting the dispatch
```

Note: an unrelated `chore(main): release 1.2.1` Release-Please PR run (`bbf291d1...`) appeared in the workflow run list during this window on a separate branch — it did not touch `main`, and `main`'s tip remained the pushed SHA throughout (confirmed via `git log origin/main`).

## Self-Check: PASSED

- `priv/adoption_proof/artifact_consumer_fixture.ex` — FOUND, contains `config :swoosh, :api_client, false`
- `scripts/verify-apns.sh` — FOUND, widened Hackney-edge check present
- `test/fixtures/apns_consumer/apns-enabled.lock` — FOUND, `mint` at `1.10.1`
- Commit `56483d6c` — FOUND in `git log --oneline`
- Commit `26350c44` — FOUND in `git log --oneline`
- Commit `d188e410` — FOUND in `git log --oneline`, `HEAD == origin/main`
- `ci-gate=success` and `nightly-gate=success` on pushed SHA — confirmed via `gh api`/`gh run view` above
