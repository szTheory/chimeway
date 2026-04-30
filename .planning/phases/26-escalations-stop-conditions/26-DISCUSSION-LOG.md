# Phase 26: Escalations & Stop Conditions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `26-CONTEXT.md`; this log preserves the analysis that led there.

**Date:** 2026-04-29
**Phase:** 26-escalations-stop-conditions
**Mode:** deep research / one-shot recommendation
**Areas analyzed:** Explicit stop rules, terminal workflow states, implicit completion, operational visibility.

## Research & Recommendations

Based on the user's request for a deep, cohesive set of one-shot recommendations emphasizing DX, Elixir/Ecto idiomatics, and ecosystem lessons:

### 1. Explicit Stop Rules vs. Escalation in the DSL
**Analysis & Tradeoffs:**
*   **Empty Escalations:** Relying solely on the absence of a matching rule to infer a "stop" creates ambiguity: is an unhandled outcome an oversight or a deliberate halt?
*   **Explicit Stop Rules:** Introducing a dedicated rule kind (e.g., `{"kind": "stop", "outcome": "user_acted"}`) forces author intent.
*   **Lessons Learned:** Inngest and Temporal heavily favor explicit `return` or `step.cancel()` primitives to halt execution branches.

**Recommendation:** Introduce explicit `stop` rules. This allows developers to express "success" conditions explicitly while leaving room for escalations if those conditions aren't met.

### 2. Terminal Workflow States
**Analysis & Tradeoffs:**
*   **Current State:** `WorkflowRun` defines `@state_values [:active, :waiting, :completed, :stopped]`, but the progression engine leaves runs in `:active` if no rules match.
*   **Zombie Runs:** Leaving runs in `:active` indefinitely ruins operational visibility and makes querying active workflows difficult.

**Recommendation:** Mutate the `WorkflowRun` row strictly to `:completed` (natural exhaustion) or `:stopped` (explicitly halted). This ensures a simple query accurately reflects the system's true active concurrency.

### 3. Implicit Completion vs. Explicit Stop Boilerplate
**Analysis & Tradeoffs:**
*   **Forced Explicit Stop:** Forcing `[{"kind": "stop"}]` at the end of every final step is tedious boilerplate and violates the principle of least surprise for simple 1-step workflows.
*   **Implicit Completion:** Natural exhaustion should imply successful completion.

**Recommendation:** Use Implicit Completion for Exhaustion, and Explicit Stop for Early Exits. If a step reaches a terminal outcome and has no matching progression rules, automatically transition to `:completed`. Use explicit `stop` rules only for branching/early exits.

### 4. Operational Visibility & Transitions
**Analysis & Tradeoffs:**
*   **Inference:** Inferring termination from delivery status saves an `INSERT` but breaks the append-only event sourcing philosophy.
*   **Explicit Transitions:** Appending a transition row guarantees the workflow's history is self-contained.

**Recommendation:** Append explicit `WorkflowTransition` rows.
*   For implicit completion: Append a transition with `reason: "workflow_completed"`, `from_state: :active`, `to_state: :completed`.
*   For explicit stop: Append a transition with `reason: "workflow_stopped"`, `from_state: :active`, `to_state: :stopped`.

## Corrections Made
The user instructed the system to shift this deep-research preference "left" within GSD. This preference has been recognized and is already persisted in the global `~/.gemini/GEMINI.md` memory for future phases. No other corrections were made to the proposed design.

## Methodology Applied
- `Deep Ecosystem Research`
- `Cohesive Recommendation Default`
- `Developer Ergonomics (DX) First`
- `Durable Explainability Bias`

## Notes for Downstream Agents
- **DSL Changes:** Add the `"stop"` kind to progression rules.
- **Engine Changes:** Update `Progression.evaluate_step/5` to handle explicit matches for `stop` rules, and to halt the run with `:completed` when rules are exhausted.
- **Traceability:** Always insert a `WorkflowTransition` row when transitioning to a terminal state.
