# Phase 94: Mailglass Transactional-Email Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Downstream research, planning, and execution consume 94-CONTEXT.md; this log preserves the analysis and expanded research.

**Date:** 2026-08-08
**Phase:** 94-Mailglass Transactional-Email Proof
**Mode:** assumptions, expanded ecosystem/architecture/DX research
**Areas analyzed:** artifact provenance, Mailglass ownership and migrations, transactional orchestration, evidence and redaction, adopter DX and documentation

## Assumptions Presented

| Area | Assumption | Confidence | Evidence |
|---|---|---|---|
| Clean-consumer boundary | Extend Phase 93's unpacked-artifact fixture; do not substitute DemoHost or a path dependency. | Confident | Phase 93 context/summary; ArtifactConsumerFixture |
| Transactional orchestration | Use an adopter-owned notifier, stable render key, configured adapter map, and host mailable. | Confident | Mailglass adapter; demo notifier/mailable; canonical guide |
| Deterministic outcome | Use Fake transport plus explicit ownership and public trace evidence. | Confident | Phase 93 evidence contract; adapter tests; official Fake/testing docs |
| Documentation boundary | State Fake's local-composition boundary in the canonical guide and distinguish maintainer regression from adopter proof. | Likely, confirmed by expanded research | Canonical guide/blueprint; official Mailglass docs |

## Expanded Research Applied

### Ecosystem and architecture
- Official Mailglass documentation confirms a host-configured Ecto repo and Fake ownership setup; a separate Mailglass.TestRepo is a harness choice, not the default adopter architecture.
- Existing public Mailglass.Migration up/down wrappers are the safe host migration pattern; hand-copied DDL and Phoenix-oriented installers are inappropriate for this generated clean consumer.
- Phase 93's direct Oban dependency is retained because it reflects the published Chimeway artifact's compile contract.

### Adopter DX
- The proof validates host mailable selection and Chimeway/Mailglass orchestration while leaving external-provider trust decisions visible and separate.
- A strict sentinel plus fixed scope/limitation prose is preferred over bare output, full inspect output, browser/admin proof, or a default live-provider test.
- No UI work is appropriate: the artifact proof and guide are the user-facing path, while the optional admin package would weaken artifact-adopter authenticity.

## Corrections Made

- Corrected a broad separate-Mailglass-repo interpretation: the generated proof uses one host-owned repo/database for Mailglass while retaining Chimeway's established dependency-owned configuration boundary.
- Corrected the guidance interpretation: mix verify.mailglass is a repository maintainer regression suite, not the clean-consumer adopter proof command.

## User Direction

The user requested breadth-and-depth expert consideration across architecture, Elixir/Phoenix/Ecto idioms, ecosystem precedent, footguns, safety, developer experience, JTBD, documentation, and brand voice, then approved the cohesive recommendation set for context capture.
