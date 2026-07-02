# v1.14 Research Summary: Public Truth and Verification Architecture

**Date:** 2026-07-02
**Method:** Four read-only subagent research tracks plus local planning/prompt/code inspection and targeted ecosystem documentation research.

## Scope Question

How should Chimeway combine fast PR feedback, full release verification, README/package truth, and public adoption DX without weakening the project's local-first and explainability goals?

## Recommendation

Frame the milestone as **Public Truth and Verification Architecture**.

The coherent unit is not "docs cleanup" or "CI speed" in isolation. It is the public trust path:

1. A developer reads README or HexDocs.
2. They copy the install guidance.
3. They expect the package, optional surfaces, source links, and changelog to be true.
4. They open or review a PR and expect fast, actionable feedback.
5. Maintainers publish only after the full release gate proves docs, package, and runtime contracts still agree.

## Key Findings

### Package Model

- Only root `chimeway` is currently a real published package.
- `chimeway_admin` and `chimeway_inbox` are in-repo optional packages with path dependencies and should not be advertised as Hex `~> 1.0` dependencies.
- Root-only release automation is the least surprising current model. Independent sibling package releases can be considered later if the packages get their own metadata, docs, SemVer policy, publish jobs, and install smoke tests.
- Planning milestone identifiers and package SemVer tags should be separated to avoid implying that every planning milestone is a Hex release.

### CI And Release Gates

- Keep the stable full `ci-gate` name because release automation, publish recovery, and automerge flows already depend on it.
- Add a fast, always-running `pr-gate` for contributor feedback instead of shrinking the release gate.
- Avoid workflow-level required path filters because skipped workflows can leave required checks pending.
- Complex CI behavior should move into local scripts or Mix tasks so maintainers can reproduce failures without editing GitHub Actions YAML.
- Nested packages, demo apps, npm, and Playwright need cache coverage, but caches should never hide missing dependency or browser install failures.

### README And Docs DX

- README should be a decision page for the main adopter jobs-to-be-done, not a thin link index.
- The first page should answer: what Chimeway is, when to use it, when not to use it, what the host owns, what Chimeway persists, how to trigger, how to prove explainability, and what optional surfaces actually are.
- Snippets should demonstrate the real adoption invariants: stable notification key, `tenant_id`, `idempotency_key`, configured storage prefix, and trace/explainability lookup.
- Stub guides should not be listed as primary learning paths unless completed.

### Ecosystem Lessons

- Elixir libraries should keep optional dependencies genuinely optional and prove compilation without optional deps where applicable.
- Hex packages benefit from explicit metadata, source URL, homepage URL, license, links, and a narrow package files whitelist.
- Successful embedded framework libraries keep provider/application ownership boundaries explicit: host auth, tenancy, URL generation, correlation IDs, and secrets should stay host-owned.
- Admin/operator surfaces should be task-centered. For Chimeway that means "why was this sent, failed, deferred, or suppressed?" rather than generic CRUD over internal rows.

## Recommended Phase Shape

1. **Phase 77: Truth Baseline and Package Model Decision**
   - Record root-only package model and tag namespace decision.
   - Resolve known drift such as Sigra reference mismatch and package status ambiguity.

2. **Phase 78: Release and Package Truth**
   - Align package metadata, release manifest, changelog, docs source refs, README install guidance, optional package status, and clean install/unpacked package proof.

3. **Phase 79: Front Door and Docs IA**
   - Rewrite README and first-hop docs around local-first ownership, explainability, non-goals, host boundaries, optional surface status, and trace proof.

4. **Phase 80: Verification Architecture and CI/DX**
   - Add `pr-gate`, preserve full `ci-gate`, avoid pending-check topology, add caches, move complex logic into local scripts/tasks, and update maintainer/contributor docs.

## Tradeoffs

| Option | Recommendation | Why |
|--------|----------------|-----|
| Root-only package vs publishing all siblings now | Root-only now | Honest public surface, smaller blast radius, avoids premature SemVer and support promises. |
| Shrink `ci-gate` vs add `pr-gate` | Add `pr-gate` | Improves contributor speed without weakening release confidence. |
| Workflow-level path filters vs always-running aggregate gates | Always-running aggregate gates | Avoids required-check pending traps. |
| README-only cleanup vs package/docs/CI truth together | Treat as one milestone | Public adoption trust fails if docs, package, and verification disagree. |
| Decorative marketing README vs concrete trace proof | Concrete trace proof | Chimeway's differentiator is explainability, not broad notification SaaS positioning. |

## Sources Consulted

- Local planning source: `.planning/PROJECT.md`, `.planning/MILESTONES.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`, archived milestone artifacts, seeds.
- Local prompt research: `prompts/chimeway-release-engineering-and-ci.md`, `prompts/chimeway-brand-book.md`, `prompts/chimeway-engineering-dna-from-prior-libs.md`, `prompts/chimeway-admin-ui-and-operator-ia.md`, `prompts/chimeway-host-app-integration-seam.md`, `prompts/chimeway-testing-and-e2e-strategy.md`, and prior-art references.
- GitHub Actions workflow syntax, dependency caching, job summary, and security documentation.
- Hex package publish documentation and `mix hex.publish` documentation.
- Elixir library guidelines and Mix optional dependency documentation.
- ExDoc docs task documentation.
- Release Please action and manifest releaser documentation.
