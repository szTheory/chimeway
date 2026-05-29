# Milestones

## v1.0

- Status: shipped
- Date: 2026-04-25
- Phases: 1-12
- Requirements: 20/20 satisfied
- Notes: milestone audit passed with non-blocking tech debt only

## v1.1 Production Trust

- Status: shipped
- Date: 2026-04-27
- Phases: 13-16
- Requirements: 11/11 satisfied
- Git range: `v1.0..v1.1`
- Notes: Completed reliability hardening, explicit policy controls, observability surfaces, and integration paths.

## v1.2 Delivery Orchestration

- Status: shipped
- Date: 2026-04-29
- Phases: 17-23
- Requirements: 11/11 satisfied
- Notes: Delivery orchestration (digest and deferred) completed.

## v1.3 Workflow Journeys

- Status: shipped
- Date: 2026-04-30
- Phases: 24-28
- Requirements: 11/11 satisfied
- Notes: Workflow engine, escalations, wait gates, host signal API, and tracing.

## v1.4 Channel Feedback Loops

- Status: shipped
- Date: 2026-05-08 (formally closed 2026-05-28)
- Phases: 29-34 (6 phases, 21 plans)
- Requirements: 8/8 satisfied
- Git tag: v1.4
- Tests at close: 549 (`mix ci.test`)
- Known deferred items at close: 7 (see STATE.md Deferred Items; audit tech debt in `milestones/v1.4-MILESTONE-AUDIT.md`)
- Notes: Outbound channel contracts, inbound feedback normalization, feedback-driven progression, operator traces, webhook durability, E2E feedback proof host, and Three-Axis Vocabulary Contract.

## v1.5 Adoption Surface

- Status: shipped
- Date: 2026-05-29
- Phases: 35-41 (7 phases, 22 plans)
- Requirements: 12/12 satisfied
- Git tag: v1.5
- Tests at close: 655 (`mix ci`) + 94 (`mix ci.verify_gates`) + 20 (`mix verify.example`)
- Audit: [milestones/v1.5-MILESTONE-AUDIT.md](milestones/v1.5-MILESTONE-AUDIT.md)
- Key accomplishments:
  - `mix chimeway.gen.migrations` installer with golden-diff CI contract
  - Golden-path integration guide with version alignment gates
  - Journey guide doc-truth rewrite and doc-contract tests
  - Password-reset and feedback escalation reference recipes
  - Demo host non-webhook IEx trace path
  - `chimeway_admin` operator trace MVP with host auth behaviour
  - GATE-01 release verification: `mix ci.verify_gates`, `verify.example` CI job, MAINTAINING.md quartet
- Notes: ex_doc relative-link warnings remain tech debt (`mix ci.docs` exits 1); Mix 1.19 `--shell` fix for verify.example alias

