# Phase 103: Physical iPhone & Adoption Truth - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-26
**Phase:** 103-physical-iphone-adoption-truth
**Areas discussed:** Proof shape, Visible-alert attestation, Adoption guide structure, Promotion timing

---

## Proof Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Versioned reference envelope plus delegated CrossWake verifier | Keep CrossWake assertion ownership canonical; bind exact Chimeway and CrossWake evidence digests; add a distinct physical schema. | ✓ |
| Copy the CrossWake report into Chimeway JSON | Produce one flattened artifact by duplicating CrossWake's report and vocabulary. | |
| CI URL or artifact attestation only | Retain build/workflow provenance without a durable behavioral proof record. | |

**User's choice:** Asked the agent to research all options and deliver one coherent expert recommendation; approved the recommended versioned, digest-linked proof bundle.
**Notes:** Research emphasized one authority per fact, source-bound CrossWake validation, explicit resolution of the old Alpha pin versus current Phase 162 evidence revision, closed schemas, and no copied device authority.

---

## Visible-Alert Attestation

| Option | Description | Selected |
|--------|-------------|----------|
| Inline observation beside executable facts | Keep the human observation inside the machine-evidence envelope. | |
| Separate digest-linked companion attestation | Preserve an independently typed, append-only human fact linked to the machine proof. | ✓ |
| Free-form checklist, screenshot, or video | Retain richer manual context outside a closed machine-validatable schema. | |

**User's choice:** Approved the recommended separate visible-alert attestation as part of the cohesive recommendation set.
**Notes:** Automation may validate the record but may not mint `observed`. `not_observed` fails, `unavailable` blocks, and no screenshot/video or human/device identity is retained.

---

## Adoption Guide Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Add everything to Golden Path | Put mobile setup, operations, proof, and non-goals in the beginner guide. | |
| Split integration and operator guides | Create separate persona-specific pages with duplicated cross-cutting vocabulary. | |
| One canonical role-oriented guide | Add one Mobile Adoption & Operations guide with persona entry points and cross-links to existing procedures. | ✓ |

**User's choice:** Approved the canonical role-oriented guide recommendation.
**Notes:** The guide serves host integrators, operators/on-call, security reviewers, and maintainers. The current `brandbook/index.html` supersedes older prompt brand material and governs literal, calm, explainability-first copy.

---

## Promotion Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Hold all Phase 103 work | Wait for Apple signing before merging schemas, gates, or guidance. | |
| Ship all work as complete | Treat deterministic readiness as sufficient for physical support. | |
| Two-threshold promotion | Ship credential-free readiness while keeping physical support pending; promote only after real evidence. | ✓ |

**User's choice:** Approved staged readiness and physical-support promotion.
**Notes:** Threshold A remains machine-verifiable and leaves TWIN-03 incomplete. Threshold B requires the signed physical run, CrossWake source-bound evidence, Chimeway machine facts, human visible-alert observation, atomic evidence publication, and synchronized truth updates.

---

## the agent's Discretion

- Exact module, struct, task, rule-ID, fixture, bundle-directory, and JSON field names within the locked versioning, ownership, privacy, and promotion contracts.
- Exact guide prose layout and cross-links, provided every DOCS-01 topic, persona entry point, command, and claim boundary remains easy to find and contract-checked.
- Exact implementation of the CrossWake validation seam, provided CrossWake retains semantic authority and the declared immutable source/evidence revision is validated.

## Deferred Ideas

None. FCM/Android, generic offline sync, engagement analytics, screenshot/video retention, a general attestation framework, and broad device/support claims remain outside the milestone's existing scope.
