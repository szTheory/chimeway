# Phase 30: Inbound Feedback Normalization - Architectural Research

This analysis is grounded in Chimeway’s core tenets: local-first data ownership, explicit explainability, and integration with ecosystem primitives (Oban/Plug). It represents the cohesive, "one-shot" architectural recommendation for implementing webhook ingestion.

### 1. Integration Boundary: Plug vs. Pure Function

**Recommendation: Pure Function with Explicit Controller Handoff**
Chimeway must not hide the HTTP boundary in a macro or a Plug.
1. Expose a pure function: `Chimeway.Webhooks.process(adapter_name, raw_body, headers, config)`.
2. Provide a concrete documentation guide showing users how to configure `Plug.Parsers` to retain the raw body using a custom body reader (e.g., `CacheBodyReader`), and provide a copy-pasteable Phoenix Controller for the ingestion route.

*Rationale & Tradeoffs:*
While a Plug provides minimal boilerplate, webhook signature verification requires the raw request body bytes. Standard Phoenix setups use `Plug.Parsers` which consumes the body, leading to failed signatures if abstracted behind a Plug. A pure function is explicit, highly testable, and follows idiomatic prior art like `stripe`'s `Stripe.Webhook.construct_event/3`.

### 2. Security & Signature Verification: Who Validates?

**Recommendation: Adapter-Delegated Verification**
Security is a Chimeway responsibility, but the implementation is provider-specific.
1. Add a callback to the `Chimeway.Adapter` behaviour: `c: verify_webhook(raw_body, headers, config) :: :ok | {:error, :unauthorized}`.
2. The core `Chimeway.Webhooks.process/4` function must call this synchronously before doing anything else.
3. *Footgun avoidance:* Adapters must use `Plug.Crypto.secure_compare/2` to prevent timing attacks.
4. If it fails, return `{:error, :unauthorized}` so the host controller can immediately return an HTTP 401.

*Rationale & Tradeoffs:*
Host developers should not implement complex cryptographic verification (bad DX). Centralizing in Chimeway core is impossible due to provider variance. Delegating to the adapter ensures the correct scheme is used natively.

### 3. Delivery Correlation Strategy

**Recommendation: Adapter-Defined Correlation (Dual Strategy)**
Because Chimeway integrates with diverse channels, correlation must be flexible.
1. When planning, adapters should prefer injecting `delivery_id` into the payload's metadata/custom-args if supported.
2. Add a callback to `Chimeway.Adapter`: `c: resolve_delivery(parsed_payload) :: {:ok, %{delivery_id: id}} | {:ok, %{provider_message_id: id}} | :error`.
3. The adapter inspects the payload. If it finds the Chimeway UUID, it returns it. If metadata isn't supported, it returns the provider's native ID, and Chimeway core handles the secondary-index lookup.

*Rationale & Tradeoffs:*
Looking up by `provider_message_id` requires a string index and async handling. Passing `chimeway_delivery_id` offers instant primary-key lookup but isn't universally supported. A dual strategy handles both elegantly. Note: `chimeway_delivery_attempts` must store `provider_message_id` to make this work.

### 4. Processing Model: Sync vs Async

**Recommendation: The Hybrid "Sync-Verify, Async-Process" Model**
Aligns with Chimeway's transactional Oban dispatch architecture.
1. **Synchronous Phase (Web request):** Core receives payload, calls `Adapter.verify_webhook/3`, parses JSON, and extracts status via `Adapter.resolve_delivery/1` and `Adapter.normalize_feedback/1`.
2. **Asynchronous Handoff:** Core transactionally enqueues a `Chimeway.Webhooks.ProcessFeedbackWorker` with verified, normalized data (`%{delivery_id: id, status: :bounced}`).
3. **HTTP Response:** Host controller returns `200 OK` instantly.
4. **Oban Worker Phase:** Oban executes database updates, writes traces, and triggers workflow progressions safely.

*Rationale & Tradeoffs:*
Sync processing risks timeouts if database operations take >3-5s, causing provider retries. Pure async processing risks DoS attacks if unverified payloads flood the queue. The hybrid approach guarantees cryptographic safety at the edge, instant HTTP responses, and async durability.

### The Cohesive "One-Shot" Architecture

1. **Host App** configures a standard Phoenix controller route (`/webhooks/chimeway/postmark`) and retains the raw body.
2. **Controller calls:**
   ```elixir
   case Chimeway.Webhooks.process(Chimeway.Adapters.Postmark, raw_body, headers) do
     {:ok, :enqueued} -> send_resp(conn, 200, "OK")
     {:error, :unauthorized} -> send_resp(conn, 401, "Bad Signature")
   end
   ```
3. **Inside `process/3`**, the adapter verifies the HMAC signature synchronously.
4. The adapter extracts the `chimeway_delivery_id` and normalizes the event.
5. Chimeway enqueues an Oban job and frees the connection.
6. **In the background**, Oban marks the delivery status, creates an explainable trace, and triggers the Workflow engine to escalate if needed.
