# Phase 26: Escalations & Stop Conditions - Context & Decisions

This document captures the finalized architectural decisions for Phase 26, derived from the research and tradeoffs analyzed in `26-DISCUSSION-LOG.md`.

## 1. Explicit Stop Rules
The progression DSL will support explicit `stop` rules.
*   **Syntax:** `{"kind": "stop", "outcome": "some_outcome"}` (or similar, depending on rule matching).
*   **Purpose:** Allows workflow authors to explicitly define when a workflow has reached its success state (e.g. a user acted) and should halt before reaching natural exhaustion.

## 2. Terminal Workflow States
The `WorkflowRun` row will be mutated to strict terminal states instead of remaining `:active` indefinitely.
*   **States:** `[:active, :waiting, :completed, :stopped]`.
*   **Purpose:** Ensures accurate querying for active workflows and improves operational visibility.

## 3. Implicit Completion for Exhaustion
Workflows will implicitly complete when they reach natural exhaustion.
*   **Behavior:** If `Progression.evaluate_step/5` finds a terminal delivery outcome but there are no matching progression rules (or the rules array is empty), the workflow transitions to `:completed`.
*   **Purpose:** Eliminates the need for boilerplate `{"kind": "stop"}` rules at the end of every simple workflow path. Explicit stop rules are reserved for early branching/exits.

## 4. Operational Visibility & Transitions
Terminal state changes will be recorded in the `chimeway_workflow_transitions` table.
*   **Implicit Completion:** Appends a transition with `reason: "workflow_completed"`, `from_state: :active`, `to_state: :completed`.
*   **Explicit Stop:** Appends a transition with `reason: "workflow_stopped"`, `from_state: :active`, `to_state: :stopped`.
*   **Purpose:** Maintains the append-only event sourcing philosophy, allowing operators to diagnose exactly why a workflow ended without cross-referencing definitions and delivery states.
