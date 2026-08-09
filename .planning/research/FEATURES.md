# Feature Landscape: Chimeway v1.17 Adopter Proof Paths

**Domain:** Open-source Elixir/Phoenix library adoption and evaluation
**Researched:** 2026-08-08
**Confidence:** HIGH for the current Chimeway surface (repository evidence); LOW for general ecosystem comparison because the configured web-search provider was unavailable.

## Scope Finding

Chimeway already has credible canonical guides, a deterministic demo host, named `verify.*` lanes, doc contracts, and a packaged-artifact parity check. The adoption gap is not another feature set or another UI: it is the missing **adopter-facing route from intent to a clean, independently repeatable proof**. Existing `mix verify.mailglass` and `mix verify.accrue` primarily execute maintainer-oriented test suites in the repository; they are valuable release evidence but are not, by themselves, a fresh-host proof a prospect can understand or reproduce.

The v1.17 MVP should therefore package three focused tracer bullets behind one concise selector: (1) Chimeway core trigger-to-explanation, (2) Mailglass transactional email, and (3) Accrue billing-event dunning. Each must install/use the shipped or locally built Chimeway artifact, operate with deterministic data and no production credentials, assert visible outcome evidence, and state precisely what the host, Chimeway, and the integration partner own.

## Table Stakes

Features an evaluator reasonably needs before trusting a library integration.

| Feature | Why Expected | Complexity | Concrete requirement / evidence |
|---|---|---:|---|
| Goal-based adoption front door | A prospect should choose a relevant proof without reading several overlapping guides first. | Low | Add one short selector in the README/HexDocs entry surface: **I need explainable notifications** → Core; **I send transactional email** → Mailglass; **I run billing dunning** → Accrue. Each card declares prerequisites, duration, outcome, and canonical guide. |
| Explicit responsibility split per route | Integration confidence depends on knowing what is orchestrated versus owned by the host/partner. | Low | Keep the existing Chimeway/Mailglass and Chimeway/Accrue boundaries, but surface them beside each selected route. Core must explicitly state host ownership of recipients, auth, tenancy, DB, and provider credentials. |
| Clean-room core tracer bullet | The foundational claim is durable, local-first, explainable notification delivery. | Medium | From an empty throwaway host/database, install a built/unpacked Chimeway artifact; generate/run migrations using `prefix: "chimeway"`; define a public-API notifier with stable key/version; trigger with `tenant_id` and `idempotency_key`; assert `explain_delivery/1` reports a terminal status and timeline. |
| Clean-room Mailglass tracer bullet | An email adopter must prove adapter routing and traceability without live provider credentials. | Medium | Fresh host adds Chimeway + Mailglass compatible artifacts, configures one host mailable and `render_key`, uses a safe local/test delivery seam, triggers an email, and proves the trace contains the Mailglass adapter/attempt evidence. Optional webhook feedback stays clearly optional. |
| Clean-room Accrue tracer bullet | Billing teams need proof of event-driven progression and termination, not a direct notifier call. | High | Fresh host configures the Accrue dunning engine, starts from `invoice.payment_failed`, observes initial delivery and `:waiting`, then sends `invoice.paid` and proves the Outcome Signal stops/progresses the waiting workflow. Preserve the sibling/path prerequisite honestly until partner packaging makes it unnecessary. |
| Copyable command contract | Docs are credible only when the exact commands are continuously executable. | Medium | One named command per path, with all required environment values documented and deterministic. Commands must return non-zero on absent expected lifecycle evidence, not merely on test failures. |
| Human-readable proof output | A green test alone does not explain what was proven. | Medium | Each tracer bullet prints: artifact source/version, migration/schema target, stable `notification_key`, event/delivery/correlation identifiers, lifecycle state(s) asserted, trace lookup command, and partner-boundary note. Never print payload body, secrets, or provider credentials. |
| Packaged/local-release artifact coverage | A repository checkout can hide missing packaged files or path-dependency coupling. | Medium | Reuse `mix verify.parity` as the package prerequisite, then run tracer bullets against its unpacked artifact or a release-equivalent local package. The proof must not import Chimeway internals from the source checkout. |
| Docs-to-proof contract | Canonical guide names, command names, prerequisites, and expected evidence must not silently drift. | Low | Extend existing doc/release contract testing to lock selector labels, route ownership statements, clean-room command names, and expected output markers. |

## Differentiators

Features that make Chimeway's adoption experience reflect its local-first, explainability-first product promise.

| Feature | Value Proposition | Complexity | Notes |
|---|---|---:|---|
| Explainability as the success criterion | The proof validates not only “a notification was sent,” but “an operator can answer why.” | Medium | Require a trace/timeline assertion in every path. For Accrue, include workflow and signal evidence; for Mailglass, include adapter/attempt evidence. |
| Route-specific responsibility matrix | Eliminates the common integration ambiguity between orchestration, domain state, rendering, provider send, and auth. | Low | A compact three-column matrix per path is better than prose: Host / Chimeway / Partner. Clearly label Accrue as an engine + workflow bridge, not an adapter. |
| Credential-free default proofs | Lets evaluators validate architecture before signing up for or exposing a provider account. | Medium | Core uses in-app/synchronous delivery; Mailglass uses its safe test/local delivery seam; Accrue uses logger email plus deterministic event fixtures. Live provider delivery and webhooks remain follow-ons. |
| Stable-identity evidence | Shows the durable contract adopters will maintain through refactors. | Low | Proof output includes the stable notification key/version, tenant, idempotency key, and correlation/event/delivery identifiers—never module name as the durable identity. |
| Failure/suppression-oriented evidence | Matches the real support question: why was it not sent? | Medium | Core proof should optionally include one controlled suppression/error assertion after the happy path. Do not make browser UI or webhook configuration a prerequisite. |
| One source of truth, two audiences | Guides remain learning material while proof scripts remain executable artifacts. | Medium | The command prints concise evidence for evaluators; contract tests protect the guide. Avoid copying long code samples into three separate documents. |

## Anti-Features

Features to explicitly not build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|---|---|---|
| A new browser/admin evaluation UI | Browser iteration is out of scope and would obscure the public API proof. | Use IEx/CLI evidence as the canonical proof; link the existing demo admin only as optional visual inspection. |
| Treating `verify.*` test lanes as adopter instructions | Those lanes depend on repository topology, test tags, fixtures, and sibling paths; a prospect cannot infer adoption readiness from them. | Keep them as internal CI evidence and add clean-room commands built for an external host. |
| A fake “all integrations” mega-demo | It forces unrelated dependencies, creates opaque failures, and weakens route selection. | Maintain three independent vertical tracer bullets with clear dependency boundaries. |
| Live provider accounts, real inboxes, or webhook secrets as baseline prerequisites | Credentials turn evaluation into account setup and make proofs nondeterministic. | Default to safe local/test adapters and deterministic fixtures; document live delivery/webhook validation as optional next steps. |
| Direct host calls to the Accrue notifier | This tests the wrong boundary and bypasses billing event ownership. | Drive the Accrue proof through payment-failed and paid events / Accrue engine APIs. |
| Teaching consumers to copy internal fixtures or private modules | It couples adopters to test implementation and contradicts the public-API promise. | Put all tracer-bullet host code in an intentionally public fixture/template and test only public `Chimeway.*` APIs. |
| New runtime delivery semantics or partner features | This milestone is adoption clarity, not an engine expansion. | Limit changes to docs, proof templates/scripts, contracts, and CI wiring required to verify them. |
| Reporting sensitive data in proof logs | Evidence output can otherwise violate Chimeway’s trust boundary. | Emit identifiers, lifecycle status, and redacted metadata only; leave payload/content and credentials out. |

## Feature Dependencies

```text
Adoption selector + route ownership matrix
  ├──> Core clean-room tracer bullet
  │      └──> public trigger → durable rows → explain_delivery evidence
  ├──> Mailglass clean-room tracer bullet
  │      └──> Core prerequisites + Mailglass mailable/render_key + adapter-attempt evidence
  └──> Accrue clean-room tracer bullet
         └──> Core prerequisites + Accrue engine/event harness + workflow/signal evidence

Packaged/local-release artifact proof
  └──> all three tracer bullets

Tracer-bullet commands + stable output markers
  └──> doc-contract / CI verification
```

### Dependency Notes

- The selector must land before detailed guides are reorganized: it establishes which guide is canonical for each adopter goal.
- Core clean-room proof is the shared foundation; Mailglass and Accrue may reuse only clearly documented setup, never hidden repository fixtures.
- Mailglass proof depends on a safe local delivery mode and a public host mailable example; webhook ingress is deliberately a separate optional proof.
- Accrue proof has the highest integration dependency and must preserve the current explicit sibling checkout/ref requirement until an independently installable partner artifact is proven.
- `mix verify.parity` proves package contents, not consumer installation. A v1.17 tracer bullet must bridge that gap by executing from an external/throwaway host against the produced artifact.

## MVP Recommendation

Prioritize:

1. **Adopter route selector and ownership matrix** — establish the front door and prevent route/partner confusion before adding more narrative.
2. **Core clean-room tracer bullet with explainability output** — prove the local-first lifecycle, storage prefix, idempotency, tenancy, and trace claim from a consumer perspective.
3. **Mailglass clean-room tracer bullet** — prove the most direct transactional-email extension without provider credentials.
4. **Accrue clean-room tracer bullet** — prove the event-driven dunning path, including Outcome Signal termination; scope the external checkout as a declared prerequisite.
5. **Executable-doc and artifact contracts** — run all proof paths in CI against a packaged/local-release artifact and lock their user-facing instructions/output.

Defer:

- Browser walkthrough redesign, inbox/badge behavior, generalized partner marketplace, performance optimization, live-provider acceptance, and new runtime notification features. These do not reduce the adoption uncertainty this milestone targets.

## Sources

### Repository evidence (HIGH confidence)

- [Project scope](../PROJECT.md) — v1.17 goal and target features.
- [README](../../README.md) — local-first positioning, host-owned boundaries, public trigger-to-trace API, and current documentation front door.
- [Golden Path](../../guides/introduction/golden-path.md) — current core lifecycle, required invariants, trace proof, and optional UI/webhook boundaries.
- [Mailglass Integration](../../guides/introduction/mailglass-integration.md) — adapter seam, mailable/render-key mapping, and optional inbound feedback boundary.
- [Accrue Dunning Integration](../../guides/introduction/accrue-dunning-integration.md) — event-driven dunning, engine boundary, Outcome Signal termination, and local checkout constraint.
- [Demo Host README](../../examples/chimeway_demo_host/README.md) — deterministic demo commands, public API walkthrough, and explicit warning not to copy internal fixtures.
- [Mix aliases](../../mix.exs) — existing `verify.parity`, `verify.mailglass`, and `verify.accrue` lanes and their repository/test orientation.

### Ecosystem comparison (LOW confidence)

The configured Brave provider was unavailable (`BRAVE_API_KEY` absent), so no external web findings are treated as authoritative. This document deliberately bases recommendations on current, directly verified Chimeway evidence rather than unsupported generalizations.
