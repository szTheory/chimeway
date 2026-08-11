# Phase 96: Adoption Front Door & Proof Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-10T02:43:25Z
**Phase:** 96-adoption-front-door-proof-gate
**Mode:** assumptions, expanded user-requested research
**Areas analyzed:** adoption selector and ownership, proof command and evidence presentation, focused verification and CI lane, drift contracts, Elixir/Phoenix DX, JTBD/brand/accessibility

## Assumptions Presented

### Adoption Selector and Ownership
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| A new HexDocs-listed outcome-first selector routes to the existing Core, Mailglass, and Accrue guides with explicit ownership boundaries. | Likely | `guides/introduction/*.md`, `mix.exs`, `README.md`, `.planning/ROADMAP.md` |

### Proof Command and Evidence Presentation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Each path retains its strict safe proof record and gets individual focused execution plus one aggregate adoption gate. | Likely | `priv/adoption_proof/artifact_consumer_fixture.ex`, `test/chimeway/release_gate_contract_test.exs`, Phase 93–95 contexts |

### Focused Verification and CI Lane
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One PostgreSQL-backed adoption job runs only the three clean-room proofs and retains per-path diagnostics, separate from detailed partner suites. | Likely | `mix.exs`, `.github/workflows/ci.yml`, `priv/adoption_proof/artifact_consumer_fixture.ex` |

### Drift Contracts
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Existing ExUnit documentation and release-gate contracts should bind guide, command, fixture proof, CI entrypoint, and aggregate membership. | Confident | `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs` |

## Expanded Research Applied

- **Elixir/Phoenix docs and DX:** ExDoc ordered extras and a canonical introduction guide support outcome-first progressive disclosure; native Mix tasks provide bounded option validation and discoverability better than a long inline alias. Sources: https://ex-doc.github.io/ex_doc/ , https://hexdocs.pm/mix/Mix.Task.html
- **Ecto/PostgreSQL:** a configured host repo and standard migration flow remain conventional; generated clean consumers should keep their own temporary database lifecycle. Source: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html
- **CI/SRE:** one Linux-runner PostgreSQL service job with a health check is an idiomatic GitHub Actions integration lane; `always()` gate aggregation preserves honest required-check behavior. Sources: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers , https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- **Project design/JTBD:** project prompts and current brandbook favor a documentation-first decision surface, literal operational microcopy, strict safe evidence, host ownership clarity, and no browser/admin scope. Sources: `prompts/chimeway-*.md`, `brandbook/index.html`.

## Corrections Made

The user requested a broad, subagent-backed assessment of each decision through architecture, Elixir/Phoenix ecosystem, CI/SRE, peer-library DX, JTBD, accessibility, and project-brand lenses. The initial assumptions were expanded and refined into the cohesive decisions recorded in `96-CONTEXT.md`.

### Refined conclusions
- Selector: static canonical Markdown guide, not README-only prose or visual cards/UI.
- Command: documented Mix task with bounded `--only`, not aggregate-only, unrelated aliases, or raw test-tag guidance.
- CI: a single serial adoption lane in full `ci-gate`, not partner-suite reuse or a three-job matrix; cheap contracts remain on PR fast paths.
- Contracts: structural parity plus behavioral proof execution are complementary, not alternate truth systems.

## External Research

- Phoenix/ExDoc documentation information architecture: https://hexdocs.pm/phoenix/overview.html and https://ex-doc.github.io/ex_doc/
- Mix task and shell contracts: https://hexdocs.pm/mix/Mix.Task.html and https://hexdocs.pm/mix/Mix.Shell.html
- GitHub Actions PostgreSQL services/workflow dependencies: https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers and https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
