# Phase 16: Discussion Log

## Architectural Decisions (Autonomously Resolved)

Based on the project's goals, Elixir ecosystem idiomatic patterns, and user preferences for deep, cohesive, one-shot recommendations, the following decisions have been made for Phase 16.

### 1. Dispatch Seam Testing Strategy (INT-02)
**Decision:** Retain Separate Tests (`sync_test.exs` and `oban_test.exs`).

**Rationale:** 
In the Elixir ecosystem, explicit execution and the "principle of least surprise" prioritize readable tests over DRYness. While libraries like Ecto successfully use shared contract tests, their adapters share synchronous return shapes. Chimeway dispatchers bridge fundamentally different paradigms (synchronous execution vs database-backed async Oban queuing). 

A Unified Contract Test using ExUnit macros would necessitate leaky conditional logic—branching between `Oban.Testing.assert_enqueued/2` and direct functional assertions—and inappropriately force Ecto Sandbox requirements onto pure sync tests, worsening developer ergonomics and obscuring ExUnit failures. 

Maintaining **Separate Tests** is the idiomatic, decisive choice. It ensures tests remain explicit, debuggable, and capable of targeting adapter-specific edge cases like queue isolation or job states. To prevent architectural drift, the project relies on strict `@callback` definitions and Dialyzer typespecs on the dispatcher behaviour.

### 2. Host-App Integration Documentation Approach (INT-01)
**Decision:** Write Dedicated Integration Guides and keep introductory stubs light.

**Rationale:**
Elixir ecosystem standards (like Phoenix and Oban) prioritize a fast, confidence-building "Time to First Run" in their introductory documentation. Because Chimeway is a durable, explainable notification library involving complex systems like Oban transactional dispatch, telemetry correlation, and policy engines, stuffing all host-app integration details into `getting-started.md` risks overwhelming new developers.

The idiomatic ExDoc approach—and the best choice for developer ergonomics—is to adopt the **Write Dedicated Integration Guides** strategy. 
- The introductory stubs (`installation.md`, `getting-started.md`) will be expanded slightly to focus on minimal setup (deps, basic config, supervision tree).
- Complex, production-grade architectural seams (Oban wiring, telemetry, adapter config at runtime) will be delegated to dedicated guides (e.g., in a new `guides/integration/` group). 

This separation of concerns preserves a welcoming onboarding funnel while providing deep, cleanly navigable documentation for enterprise integration.
