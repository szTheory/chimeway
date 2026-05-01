---
phase: 30-inbound-feedback-normalization
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/repo/migrations/*_add_provider_message_id_to_delivery_attempts.exs
  - lib/chimeway/delivery_attempt.ex
  - lib/chimeway/deliveries.ex
  - lib/chimeway/adapter.ex
  - lib/chimeway/webhooks.ex
  - lib/chimeway/webhooks/process_feedback_worker.ex
autonomous: true
requirements:
  - FEED-01
  - FEED-02
must_haves:
  truths:
    - "System provides a pure function to process inbound webhooks"
    - "Webhook signatures are verified synchronously via the adapter"
    - "Valid webhooks enqueue a background job to update delivery state"
    - "Canonical delivery records reflect asynchronous provider outcomes"
  artifacts:
    - path: "lib/chimeway/webhooks.ex"
      provides: "Synchronous webhook ingestion boundary"
    - path: "lib/chimeway/webhooks/process_feedback_worker.ex"
      provides: "Asynchronous state update logic"
  key_links:
    - from: "lib/chimeway/webhooks.ex"
      to: "lib/chimeway/adapter.ex"
      via: "adapter callbacks (verify_webhook, resolve_delivery, normalize_feedback)"
    - from: "lib/chimeway/webhooks/process_feedback_worker.ex"
      to: "lib/chimeway/deliveries.ex"
      via: "Deliveries.record_attempt/2"
---

<objective>
Implement the canonical webhook ingestion layer that translates vendor payloads into asynchronous delivery state updates.

Purpose: Enable host apps to safely receive delivery feedback (e.g. bounces, deliveries) and map it back to canonical delivery records using a pure function integration boundary.
Output: Schema updates for provider IDs, expanded Adapter contracts, Webhook core module, and an Oban worker.
</objective>

<context>
@.planning/phases/30-inbound-feedback-normalization/30-RESEARCH.md
@.planning/milestones/v1.4-ROADMAP.md
@lib/chimeway/deliveries.ex
@lib/chimeway/delivery_attempt.ex
@lib/chimeway/adapter.ex
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Data Model Updates for Provider Correlation</name>
  <files>
    priv/repo/migrations/*_add_provider_message_id_to_delivery_attempts.exs,
    lib/chimeway/delivery_attempt.ex,
    lib/chimeway/deliveries.ex
  </files>
  <action>
    1. Generate an Ecto migration to add `provider_message_id` (:string, default: null) to the `chimeway_delivery_attempts` table. Create an index on this column.
    2. Update the `Chimeway.DeliveryAttempt` schema to include `provider_message_id` as a field and add it to `@optional_fields`.
    3. Update `Chimeway.Deliveries` to include a new public function `get_delivery_by_provider_message_id(provider_message_id)` that queries `Chimeway.DeliveryAttempt` for the given ID, preloads the `delivery`, and returns `{:ok, delivery}` or `{:error, :not_found}`. This is required because adapters returning `provider_message_id` will need Chimeway to lookup the primary delivery record.
  </action>
  <verify>
    <automated>mix test test/chimeway/deliveries_test.exs</automated>
  </verify>
  <done>The database can store and index provider message IDs on attempts, and deliveries can be looked up by this ID.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Adapter Behaviour Ingestion Contracts</name>
  <files>lib/chimeway/adapter.ex</files>
  <action>
    Add three new optional callbacks to the `Chimeway.Adapter` behaviour:
    - `@callback verify_webhook(raw_body :: binary(), headers :: list(), config :: keyword()) :: :ok | {:error, :unauthorized}`
    - `@callback resolve_delivery(parsed_payload :: map()) :: {:ok, %{delivery_id: binary()}} | {:ok, %{provider_message_id: String.t()}} | :error`
    - `@callback normalize_feedback(parsed_payload :: map()) :: {:ok, %{status: :delivered | :bounced | :failed}} | :error`

    Use `@optional_callbacks` for all three so existing adapters don't break. Document that these are required for adapters that wish to support async feedback loops via webhooks.
  </action>
  <verify>
    <automated>mix compile --force</automated>
  </verify>
  <done>Adapter contract explicitly defines the verification and normalization callbacks required for webhook processing.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Webhooks Pure Function & Oban Worker</name>
  <files>
    lib/chimeway/webhooks.ex,
    lib/chimeway/webhooks/process_feedback_worker.ex,
    test/chimeway/webhooks_test.exs,
    test/chimeway/webhooks/process_feedback_worker_test.exs
  </files>
  <behavior>
    - `Webhooks.process/4` synchronously delegates verification to the adapter.
    - If verification fails, it immediately returns `{:error, :unauthorized}`.
    - If verification passes, it resolves the delivery, normalizes the feedback, and enqueues the Oban worker.
    - `ProcessFeedbackWorker` looks up the delivery (by `delivery_id` or `provider_message_id`) and updates state via `Deliveries.record_attempt/2`.
  </behavior>
  <action>
    1. Create `Chimeway.Webhooks.ProcessFeedbackWorker` (using `Oban.Worker`). In `perform/1`, read `delivery_id` or `provider_message_id`. Look up the `%Delivery{}` using `Deliveries.get_delivery!(id)` or the new `get_delivery_by_provider_message_id/1`. Then call `Deliveries.record_attempt/2` passing the normalized status (e.g., if status is `:bounced`, pass `%{outcome: :bounced, error_class: "bounced", provider_response: payload}`).
    2. Create `Chimeway.Webhooks` module with `process(adapter_module, raw_body, headers, config)`:
       - Call `adapter_module.verify_webhook/3`. Return `{:error, :unauthorized}` on failure.
       - Parse `raw_body` as JSON.
       - Call `adapter_module.resolve_delivery/1` and `adapter_module.normalize_feedback/1`.
       - If both succeed, prepare the args (merging resolved delivery identifier, status, and raw payload as `provider_response`) and call `ProcessFeedbackWorker.enqueue(args)` (or `Oban.insert`).
       - Return `{:ok, :enqueued}`.
  </action>
  <verify>
    <automated>mix test test/chimeway/webhooks_test.exs test/chimeway/webhooks/process_feedback_worker_test.exs</automated>
  </verify>
  <done>A pure function securely parses incoming webhooks, verifies signatures, and enqueues a background job that successfully mutates canonical delivery state.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Webhook Endpoint -> `Chimeway.Webhooks` | Untrusted external payloads from third-party providers enter the system. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-30-01 | Spoofing | `Webhooks.process/4` | mitigate | Delegate signature verification to `adapter.verify_webhook/3` synchronously before parsing JSON. Rejects invalid signatures instantly with 401. |
| T-30-02 | Denial of Service | `Webhooks.process/4` | mitigate | Offload database updates and parsing to Oban worker (hybrid processing) so the HTTP connection is freed instantly. |
| T-30-03 | Information Disclosure | `Adapter.Contract` | mitigate | Emphasize in docs that `Plug.Crypto.secure_compare/2` MUST be used by adapters to prevent timing attacks. |
</threat_model>

<verification>
mix test test/chimeway/webhooks_test.exs
mix test test/chimeway/webhooks/process_feedback_worker_test.exs
</verification>

<success_criteria>
- The Webhook pure function successfully rejects forged payloads synchronously.
- Valid payloads asynchronously update the `Chimeway.Delivery` canonical state to `:cancelled` (via `:bounced`) or `:succeeded`.
- The system supports lookup by either `delivery_id` or `provider_message_id`.
</success_criteria>

<output>
After completion, create `.planning/phases/30-inbound-feedback-normalization/30-01-SUMMARY.md`
</output>
