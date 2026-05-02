# Chimeway Methodology

Project-scoped lenses that later GSD phases should apply before surfacing assumptions,
research, or implementation plans.

## Cohesive Recommendation Default

**Diagnoses:** Analysis that pushes too many medium-stakes choices back to the user, or presents
menus of options without a coherent recommendation set.

**Recommends:** Do codebase-first and ecosystem-backed research, then converge on one
recommendation set that is internally consistent with Chimeway's architecture, DX goals, and
local-first explainability model. Present alternatives only to justify the recommendation or when
tradeoffs materially affect the decision.

**Apply when:** Discussing phase shape, comparing patterns, researching libraries, or planning
implementation details with multiple viable designs.

## High-Impact Escalation Gate

**Diagnoses:** The agent interrupts the user for decisions that are reversible, implementation-local,
or already constrained by project direction.

**Recommends:** Escalate only when a choice is high-blast-radius, difficult to reverse, changes the
public product model, or conflicts with a locked project principle. Otherwise, choose the least
surprising option and document it clearly.

**Apply when:** A workflow would otherwise ask the user to choose among several plausible
technical approaches.

## Research-First Decision Ownership

**Diagnoses:** The agent gives the user an option menu before doing enough codebase and ecosystem
research to form a strong recommendation, or pushes medium-stakes architectural choices back to the
user even when project principles already constrain the answer.

**Recommends:** Research first, synthesize second, recommend one coherent architecture that fits the
codebase, ecosystem norms, and Chimeway's product posture. Escalate only for choices that are
public-model-defining, hard to reverse, or in genuine tension with locked project principles.

**Apply when:** Discussing architecture, persistence models, operator-facing surfaces, orchestration
behavior, DX/API shape, or any phase where multiple viable technical designs exist.

## One-Shot Recommendation Bias

**Diagnoses:** The agent surfaces multiple viable designs but stops at comparison instead of closing
with one cohesive recommendation set, leaving the user to do architecture synthesis work that the
agent could have finished.

**Recommends:** After researching codebase and ecosystem context, collapse the analysis into one
coherent recommendation set by default. Present alternatives only to justify the recommendation,
document reversibility, and flag the few choices that truly deserve human sign-off.

**Apply when:** Producing discuss-phase context, research docs, implementation guidance, DX/API
recommendations, or any recommendation memo where the user wants a decisive answer rather than a
menu.

## Durable Explainability Bias

**Diagnoses:** Designs that hide lifecycle decisions in transient job state, opaque metadata blobs,
or transport-specific side effects.

**Recommends:** Prefer explicit, durable, queryable records that preserve why work was sent,
deferred, grouped, suppressed, resumed, or cancelled. Keep durable identity separate from module
names and keep host-app ownership boundaries intact.

**Apply when:** Designing persistence, orchestration, digest behavior, trace surfaces, or operator
debugging flows.

## Least-Surprise DX Default

**Diagnoses:** Tooling, APIs, or recommendations that optimize for clever short-term convenience at
the cost of predictability, safety, or easy mental models for library adopters and maintainers.

**Recommends:** Choose the most predictable safe default that fits ecosystem norms. Prefer
data-first public APIs, explicit validation, stable error shapes, and developer tooling that reuses
real production paths without hidden code execution or silent fallback magic. Escalate only when
the safer default would materially harm the product model or long-term ergonomics.

**Apply when:** Designing library entrypoints, preview or operator tooling, CLI interfaces, safe
defaults, validation contracts, or developer-facing UX where convenience could otherwise smuggle in
surprising behavior.

## Low-Escalation Recommendation Default

**Diagnoses:** The agent asks the user to choose among medium-stakes implementation options even
after enough codebase and ecosystem evidence exists to make a strong recommendation.

**Recommends:** Research first, then present one cohesive recommendation set by default. Only
surface a decision to the user when it is high-blast-radius, hard to reverse, public-model
defining, or genuinely in tension with a locked project principle. For ordinary architecture and DX
choices, choose the least-surprising option and document the tradeoff instead of offloading the
decision.

**Apply when:** Running discuss-phase, architectural research, planning, API-shape decisions,
workflow/tooling design, and any phase where the user has signaled a preference for decisive
one-shot recommendations.
