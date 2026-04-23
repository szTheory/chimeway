# Project Research Summary

**Project:** Chimeway  
**Domain:** Embedded, local-first notification infrastructure for Elixir/Phoenix  
**Researched:** 2026-04-23  
**Confidence:** HIGH

## Executive Summary

Chimeway should be built as an embedded notification layer with a durable data spine first, not as a hosted orchestration platform. Research across Elixir ecosystem tooling and prior-art frameworks converges on a clear shape: persist stable notification identity and lifecycle records (event -> notification -> delivery -> attempt), then layer dispatch modes, adapters, and operator surfaces on top.

The recommended approach is Ecto/Postgres-first with optional Oban and channel adapters (Swoosh first) behind explicit behaviours. This aligns with Chimeway's principles: explainability, composability, and local ownership. The shortest path to validating the product is a vertical slice that proves in-app durability, one outbound seam, idempotency, and policy-aware suppression.

Key risk is building UI or provider breadth before core semantics are correct. Mitigation: phase ordering must force stable key contracts, idempotency, trace schemas, and adapter contracts before broad channel matrix or rich admin workflows.

## Key Findings

### Recommended Stack

The stack is a pragmatic Elixir baseline: Elixir/OTP + Ecto/Postgres as required foundation, with Phoenix/LiveView and Oban/Swoosh as optional-but-recommended integrations. This keeps core adoption easy while preserving a strong production path.

**Core technologies:**
- Elixir + OTP: reliable BEAM runtime and idiomatic implementation surface.
- Ecto + PostgreSQL: durable lifecycle state and idempotency constraints.
- Oban (optional): robust retries/scheduling for async dispatch.
- Swoosh (optional adapter): mature email/provider abstraction.

### Expected Features

Research indicates v1 must focus on foundational reliability features rather than channel breadth.

**Must have (table stakes):**
- Stable notification key/version identity with explicit notifier contracts.
- Durable event/notification/delivery/attempt records.
- Idempotency and dedupe protections.
- Preference/policy suppression with stored reasons.
- In-app read/seen semantics and one outbound adapter seam.

**Should have (competitive):**
- First-class "why wasn't this sent?" traceability experience.
- Delayed fallback (for example, email only if in-app remains unread).

**Defer (v2+):**
- Broad channel matrix (push/SMS/chat/webhook parity).
- Full digest/orchestration suite and advanced preference UX.

### Architecture Approach

Use a plan-then-dispatch architecture: deterministic planning and persistence before side effects. Keep adapters behind behaviours and test contracts. Preserve strict boundary ownership: host app controls auth/tenancy/correlation context while Chimeway owns lifecycle data model and dispatch contracts.

**Major components:**
1. Core planner/policy/idempotency engine - deterministic delivery planning and suppression decisions.
2. Persistence layer - durable lifecycle records and trace metadata.
3. Dispatch + adapter layer - sync/Oban execution and provider calls with attempt classification.
4. Optional operator/UI surface - queryable timeline and diagnostics on top of persisted facts.

### Critical Pitfalls

1. **Unstable notification identity** - persist stable keys and versions, never module names as DB type.
2. **Hidden send outcomes** - require attempt rows and trace updates for every provider call.
3. **Idempotency gaps** - enforce deterministic keys and uniqueness constraints.
4. **Stale policy decisions** - evaluate policy before enqueue and before perform.
5. **Premature UI over weak semantics** - complete lifecycle state model before heavy dashboard investment.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Durable Core Spine
**Rationale:** Everything depends on stable identity and durable lifecycle records.  
**Delivers:** notifier contracts, stable keys, event/notification/delivery/attempt schemas, idempotency primitives.  
**Addresses:** table-stakes durability and traceability baseline.  
**Avoids:** unstable identity and hidden-outcome pitfalls.

### Phase 2: First Vertical Dispatch Slice
**Rationale:** Validate end-to-end value early with one practical channel seam.  
**Delivers:** in-app canonical flow plus one outbound adapter (sync-first acceptable), suppression reasons, retry classification.  
**Uses:** Swoosh/email or equivalent test/log adapter seam.  
**Implements:** planner -> persist -> dispatch -> attempt lifecycle.

### Phase 3: Optional Oban Async Path + Policy Hardening
**Rationale:** Production workloads require queue durability and late policy checks.  
**Delivers:** Oban worker path, transactional enqueue, perform-time suppression recheck, backoff strategy.  
**Addresses:** stale-policy and retry-storm pitfalls.

### Phase 4: Operator Trace Surface
**Rationale:** Chimeway differentiates on explainability, not just delivery.  
**Delivers:** mountable admin/trace views, filtered timelines, redacted payload previews, support diagnostics.  
**Addresses:** "why wasn't this sent?" operational workflow.

### Phase 5: Expansion and Hardening
**Rationale:** Channel breadth and advanced controls come after core trust is established.  
**Delivers:** additional adapters, contract-test expansion, retention/tenancy hardening, advanced policies (digests/caps).  
**Uses:** established seam architecture and CI verification discipline.

### Phase Ordering Rationale

- Core schema and idempotency must precede adapter breadth to prevent rework and data migrations.
- Async dispatch should follow first vertical sync slice to reduce complexity while validating semantics.
- Operator UI should project durable truth, so it follows state/trace maturity.
- Advanced channels and policies are safest once contract tests and observability are stable.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3:** Oban queue tuning and backoff by channel/provider failure class.
- **Phase 5:** Push/SMS provider behavior nuances, legal compliance requirements, and webhook security patterns.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Ecto schema + key/version identity patterns are well established.
- **Phase 2:** In-app + one adapter seam is straightforward with existing Elixir primitives.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strong convergence from existing Elixir ecosystem tools and sibling OSS practices. |
| Features | HIGH | Clear overlap between stated product principles and ecosystem gap analysis. |
| Architecture | HIGH | Mature patterns from Noticed/Laravel lessons and Elixir durability requirements. |
| Pitfalls | HIGH | Repeated failure modes documented across prior art and operations-focused research. |

**Overall confidence:** HIGH

### Gaps to Address

- Validate exact version support matrix in CI before promising hard compatibility guarantees.
- Confirm package topology milestone (`chimeway` vs `chimeway_admin`) based on early API stability.
- Validate provider-specific adapter priorities against maintainer bandwidth and real user demand.

## Sources

### Primary (HIGH confidence)
- `prompts/CHIMEWAY-GSD-IDEA.md`
- `prompts/elixir_notifykit_research_brief.md`
- `prompts/chimeway-engineering-dna-from-prior-libs.md`
- `prompts/chimeway-admin-ui-and-operator-ia.md`

### Secondary (MEDIUM confidence)
- `prompts/chimeway-testing-and-e2e-strategy.md`
- `prompts/chimeway-release-engineering-and-ci.md`
- `prompts/chimeway-host-app-integration-seam.md`

### Tertiary (LOW confidence)
- Provider-specific SDK/version assumptions that require phase-time verification.

---
*Research completed: 2026-04-23*
*Ready for roadmap: yes*
