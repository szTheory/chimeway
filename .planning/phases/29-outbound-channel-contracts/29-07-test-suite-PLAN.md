---
phase: 29-outbound-channel-contracts
plan: "07"
type: execute
wave: 4
depends_on:
  - "03"
  - "04"
  - "05"
  - "06"
files_modified:
  - lib/chimeway/adapters/test.ex
  - test/chimeway/rendering/channel_contract_test.exs
  - test/chimeway/integration/delivery_lifecycle_test.exs
  - test/chimeway/traces_test.exs
  - test/chimeway/telemetry_integration_test.exs
autonomous: true
requirements:
  - CHAN-01
  - CHAN-02

must_haves:
  truths:
    - "Adapters.Test sends {:chimeway_delivery, channel, delivery} to the test process on deliver"
    - "channel_contract_test.exs has round-trip cases for Sms (valid + error), Push (valid + error), Chat (valid + error)"
    - "channel_contract_test.exs has one registry-overlay case proving host-defined channels resolve correctly"
    - "delivery_lifecycle_test.exs asserts attempt.adapter_module == the test adapter module string"
    - "traces_test.exs asserts explanation.last_attempt.adapter_module is present and not nil"
    - "telemetry_integration_test.exs asserts channel_unregistered and adapter_fallback events fire"
    - "All 25 decisions D-01..D-25 are covered by at least one test assertion"
    - "mix test exits 0 across the full suite"
  artifacts:
    - path: "lib/chimeway/adapters/test.ex"
      provides: "Channel-tagged mailbox send in deliver/2"
      contains: "chimeway_delivery"
    - path: "test/chimeway/rendering/channel_contract_test.exs"
      provides: "Round-trip tests for Sms, Push, Chat + registry-overlay"
      contains: "sms"
    - path: "test/chimeway/integration/delivery_lifecycle_test.exs"
      provides: "adapter_module assertion on attempt row"
      contains: "adapter_module"
    - path: "test/chimeway/traces_test.exs"
      provides: "adapter_module assertion in explain_delivery last_attempt"
      contains: "adapter_module"
    - path: "test/chimeway/telemetry_integration_test.exs"
      provides: "channel_unregistered and adapter_fallback telemetry assertions"
      contains: "channel_unregistered"
  key_links:
    - from: "test/chimeway/rendering/channel_contract_test.exs"
      to: "lib/chimeway/rendering/channels/sms.ex"
      via: "Rendering.render_delivery(:sms, ...) round-trip"
      pattern: "render_delivery.*:sms"
    - from: "test/chimeway/integration/delivery_lifecycle_test.exs"
      to: "lib/chimeway/dispatch/executor.ex"
      via: "attempt.adapter_module assertion after trigger"
      pattern: "adapter_module"
---

<objective>
Update `Chimeway.Adapters.Test` with channel-tagged mailbox sends (D-23), then write
the full test coverage for Phase 29 across four test files. This is the final integration
wave: all implementation is in place, tests prove each decision is correctly implemented.

Purpose: The test suite is the executable verification of all 25 locked decisions. Plan 07
runs last (Wave 4) because it depends on all implementation plans (03, 04, 05, 06) being
complete so the tests can actually pass.

Output: Updated test.ex adapter + extended test files; full suite green.
</objective>

<execution_context>
@/Users/jon/.claude/get-shit-done/workflows/execute-plan.md
@/Users/jon/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/phases/29-outbound-channel-contracts/29-CONTEXT.md
@.planning/phases/29-outbound-channel-contracts/29-RESEARCH.md
@.planning/phases/29-outbound-channel-contracts/29-PATTERNS.md

<interfaces>
<!-- Exact current code shapes the executor needs for targeted edits. -->

From lib/chimeway/adapters/test.ex (current deliver/2, lines 24-29):
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

From test/chimeway/rendering/channel_contract_test.exs (email round-trip test to copy):
```elixir
test "renders validated email payloads with subject, html_body, and text_body" do
  assert {:ok,
          %{
            channel: "email",
            render_data: %{
              "html_body" => "<p>Ada left a new comment</p>",
              "subject" => "New comment",
              "text_body" => "Ada left a new comment"
            },
            render_key: "comment.created.email",
            render_version: 4
          }} =
           Rendering.render_delivery(
             :email,
             "comment.created.email",
             4,
             %{
               "html_body" => "<p>Ada left a new comment</p>",
               "subject" => "New comment",
               "text_body" => "Ada left a new comment"
             }
           )
end
```

From test/chimeway/integration/delivery_lifecycle_test.exs (Application.put_env isolation pattern, lines 378-390):
```elixir
setup do
  original = Application.get_env(:chimeway, :adapter)
  Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
  TestAdapter.clear()

  on_exit(fn ->
    case original do
      nil -> Application.delete_env(:chimeway, :adapter)
      mod -> Application.put_env(:chimeway, :adapter, mod)
    end
    TestAdapter.clear()
  end)

  :ok
end
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update Adapters.Test with channel-tagged mailbox send</name>
  <files>lib/chimeway/adapters/test.ex</files>
  <read_first>
    - lib/chimeway/adapters/test.ex — read the full current file before editing; need to see the exact deliver/2 implementation and confirm delivered_messages/0 and assert_delivered/1 are unchanged
  </read_first>
  <action>
Make exactly one change to `lib/chimeway/adapters/test.ex` (D-23):

In `deliver/2`, add `send(self(), {:chimeway_delivery, delivery.channel, delivery})` as a
new line after the `Process.put` call and before the return value:

Replace:
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

With:
```elixir
@impl Chimeway.Adapter
def deliver(%Chimeway.Delivery{} = delivery, _config) do
  existing = Process.get(:chimeway_test_deliveries, [])
  Process.put(:chimeway_test_deliveries, [delivery | existing])
  send(self(), {:chimeway_delivery, delivery.channel, delivery})   # D-23: channel-tagged mailbox
  {:ok, %{adapter: "test", delivered_at: DateTime.utc_now()}}
end
```

The `delivered_messages/0`, `assert_delivered/1`, and `clear/0` functions are UNCHANGED.
Existing tests using `delivered_messages()` and `assert_delivered()` will continue to work
because the process dictionary store is still there. The `send(self(), ...)` only adds a
new capability for per-channel assertions.

Note on process context: `self()` during sync dispatch is the test process. During
`Oban.drain_queue` the job also runs in-process so `self()` is still the test process.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix compile 2>&1 | grep -E "error" | head -5</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "chimeway_delivery" lib/chimeway/adapters/test.ex` outputs `1`
    - `grep -c "send(self()" lib/chimeway/adapters/test.ex` outputs `1`
    - `grep -c "delivery.channel" lib/chimeway/adapters/test.ex` outputs `1`
    - `grep -c "delivered_messages" lib/chimeway/adapters/test.ex` outputs at least `1` (function still exists)
    - `mix compile` exits 0
  </acceptance_criteria>
  <done>Adapters.Test.deliver/2 sends {:chimeway_delivery, channel, delivery} to test process mailbox; existing functions unchanged</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Extend channel_contract_test.exs with Sms/Push/Chat + registry-overlay</name>
  <files>test/chimeway/rendering/channel_contract_test.exs</files>
  <read_first>
    - test/chimeway/rendering/channel_contract_test.exs — read the full file before adding; understand existing test describe blocks and aliases to append to the right section
    - lib/chimeway/rendering/channels/sms.ex — confirm the exact field names that should appear in render_data
    - lib/chimeway/rendering/channels/push.ex — same
    - lib/chimeway/rendering/channels/chat.ex — same
  </read_first>
  <behavior>
    - Sms round-trip: render_delivery(:sms, "otp.sent.sms", 1, %{"text_body" => "Your code is 123456"}) returns {:ok, %{channel: "sms", render_data: %{"text_body" => "Your code is 123456"}, render_key: "otp.sent.sms", render_version: 1}}
    - Sms error: render_delivery(:sms, "otp.sent.sms", 1, %{}) returns {:error, {:rendering_failed, "sms", {:invalid_channel_payload, "sms", changeset}}} with text_body: ["can't be blank"]
    - Sms vendor-field strip: render_delivery(:sms, ..., %{"text_body" => "Hi", "from" => "+1555"}) returns render_data with only "text_body" key (D-02)
    - Sms no GSM-7 limit: 200-char text_body validates successfully (D-03)
    - Push round-trip: render_delivery(:push, "alert.push", 1, %{"title" => "Alert", "body" => "New message", "data" => %{"deep_link" => "/inbox"}}) returns {:ok, %{channel: "push", render_data: %{"body" => "New message", "data" => %{"deep_link" => "/inbox"}, "title" => "Alert"}, ...}}
    - Push error: render_delivery(:push, ..., %{"title" => "Alert"}) returns changeset with body: ["can't be blank"] (D-05)
    - Push vendor-field strip: render_data never includes "device_token", "apns_topic" (D-07)
    - Chat round-trip: render_delivery(:chat, "comment.chat", 1, %{"text" => "Hello", "rich_payload" => %{"blocks" => []}}) returns {:ok, %{channel: "chat", render_data: %{"rich_payload" => %{"blocks" => []}, "text" => "Hello"}, ...}}
    - Chat error: render_delivery(:chat, ..., %{}) returns changeset with text: ["can't be blank"] (D-09)
    - Registry overlay: after Application.put_env(:chimeway, :channel_render_modules, %{"slack" => TestSlackChannel}), render_delivery(:slack, ...) returns {:ok, %{channel: "slack", ...}}
  </behavior>
  <action>
Append the following test cases to `test/chimeway/rendering/channel_contract_test.exs`.
Read the existing file first to find the correct location (append inside the appropriate
describe block, or add new describe blocks after the existing ones).

Add a describe block for SMS (D-01, D-02, D-03, D-04, D-25):
```elixir
describe "SMS channel" do
  test "renders validated SMS payloads with text_body" do
    assert {:ok,
            %{
              channel: "sms",
              render_data: %{"text_body" => "Your code is 123456"},
              render_key: "otp.sent.sms",
              render_version: 1
            }} =
             Rendering.render_delivery(
               :sms,
               "otp.sent.sms",
               1,
               %{"text_body" => "Your code is 123456"}
             )
  end

  test "returns tagged validation failure when text_body is missing" do
    assert {:error, {:rendering_failed, "sms", {:invalid_channel_payload, "sms", changeset}}} =
             Rendering.render_delivery(:sms, "otp.sent.sms", 1, %{})

    assert %Ecto.Changeset{} = changeset
    assert %{text_body: ["can't be blank"]} = errors_on(changeset)
  end

  test "strips vendor routing fields from render_data (D-02)" do
    assert {:ok, %{render_data: render_data}} =
             Rendering.render_delivery(
               :sms,
               "otp.sent.sms",
               1,
               %{"text_body" => "Hi", "from" => "+15551234567", "to" => "+15559876543"}
             )

    assert Map.keys(render_data) == ["text_body"]
  end

  test "does not enforce GSM-7 / UCS-2 length limits (D-03)" do
    long_body = String.duplicate("x", 200)

    assert {:ok, %{render_data: %{"text_body" => ^long_body}}} =
             Rendering.render_delivery(:sms, "otp.sent.sms", 1, %{"text_body" => long_body})
  end
end
```

Add a describe block for Push (D-05, D-07, D-08):
```elixir
describe "Push channel" do
  test "renders validated push payloads with title, body, and data" do
    assert {:ok,
            %{
              channel: "push",
              render_data: %{
                "body" => "New message",
                "data" => %{"deep_link" => "/inbox"},
                "title" => "Alert"
              },
              render_key: "alert.push",
              render_version: 1
            }} =
             Rendering.render_delivery(
               :push,
               "alert.push",
               1,
               %{"title" => "Alert", "body" => "New message", "data" => %{"deep_link" => "/inbox"}}
             )
  end

  test "renders push payload without optional data field" do
    assert {:ok, %{render_data: render_data}} =
             Rendering.render_delivery(
               :push,
               "alert.push",
               1,
               %{"title" => "Alert", "body" => "New message"}
             )

    refute Map.has_key?(render_data, "data")
  end

  test "returns tagged validation failure when body is missing" do
    assert {:error, {:rendering_failed, "push", {:invalid_channel_payload, "push", changeset}}} =
             Rendering.render_delivery(:push, "alert.push", 1, %{"title" => "Alert"})

    assert %{body: ["can't be blank"]} = errors_on(changeset)
  end

  test "strips platform plumbing fields from render_data (D-07)" do
    assert {:ok, %{render_data: render_data}} =
             Rendering.render_delivery(
               :push,
               "alert.push",
               1,
               %{"title" => "Alert", "body" => "x", "device_token" => "abc", "apns_topic" => "com.myapp"}
             )

    refute Map.has_key?(render_data, "device_token")
    refute Map.has_key?(render_data, "apns_topic")
  end
end
```

Add a describe block for Chat (D-09, D-10):
```elixir
describe "Chat channel" do
  test "renders validated chat payloads with text and rich_payload" do
    assert {:ok,
            %{
              channel: "chat",
              render_data: %{"rich_payload" => %{"blocks" => []}, "text" => "Hello"},
              render_key: "comment.chat",
              render_version: 1
            }} =
             Rendering.render_delivery(
               :chat,
               "comment.chat",
               1,
               %{"text" => "Hello", "rich_payload" => %{"blocks" => []}}
             )
  end

  test "renders chat payload without optional rich_payload" do
    assert {:ok, %{render_data: %{"text" => "Hi"}}} =
             Rendering.render_delivery(:chat, "comment.chat", 1, %{"text" => "Hi"})
  end

  test "returns tagged validation failure when text is missing" do
    assert {:error, {:rendering_failed, "chat", {:invalid_channel_payload, "chat", changeset}}} =
             Rendering.render_delivery(:chat, "comment.chat", 1, %{})

    assert %{text: ["can't be blank"]} = errors_on(changeset)
  end
end
```

Add a describe block for the registry overlay (D-11, D-12):
```elixir
describe "registry-overlay channel resolution" do
  setup do
    defmodule TestRegistryChannel do
      use Chimeway.Rendering.Channel

      @impl Chimeway.Rendering.Channel
      def validate(attrs) when is_map(attrs), do: {:ok, attrs}
      def validate(_), do: {:error, :invalid}
    end

    original = Application.get_env(:chimeway, :channel_render_modules)
    Application.put_env(:chimeway, :channel_render_modules, %{"slack" => TestRegistryChannel})

    on_exit(fn ->
      case original do
        nil -> Application.delete_env(:chimeway, :channel_render_modules)
        val -> Application.put_env(:chimeway, :channel_render_modules, val)
      end
    end)

    :ok
  end

  test "host-defined channel resolves via :channel_render_modules registry (D-12)" do
    assert {:ok, %{channel: "slack"}} =
             Rendering.render_delivery(:slack, "slack.message", 1, %{"text" => "hi"})
  end
end
```
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/rendering/channel_contract_test.exs 2>&1 | tail -15</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "SMS channel" test/chimeway/rendering/channel_contract_test.exs` outputs `1`
    - `grep -c "Push channel" test/chimeway/rendering/channel_contract_test.exs` outputs `1`
    - `grep -c "Chat channel" test/chimeway/rendering/channel_contract_test.exs` outputs `1`
    - `grep -c "registry-overlay" test/chimeway/rendering/channel_contract_test.exs` outputs `1`
    - `grep -c "text_body" test/chimeway/rendering/channel_contract_test.exs` outputs at least `4` (multiple SMS tests)
    - `mix test test/chimeway/rendering/channel_contract_test.exs` exits 0 with all tests passing
  </acceptance_criteria>
  <done>channel_contract_test.exs has SMS/Push/Chat round-trips, error cases, vendor-field strip, GSM-7 no-limit, and registry-overlay tests — all passing</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Extend delivery_lifecycle, traces, and telemetry tests</name>
  <files>
    test/chimeway/integration/delivery_lifecycle_test.exs,
    test/chimeway/traces_test.exs,
    test/chimeway/telemetry_integration_test.exs
  </files>
  <read_first>
    - test/chimeway/integration/delivery_lifecycle_test.exs — read the full file to find existing Scenario B (Test adapter) test block around lines 378-440; understand the Application.put_env isolation pattern used there
    - test/chimeway/traces_test.exs — read the existing explain_delivery test section to find where to add adapter_module assertions
    - test/chimeway/telemetry_integration_test.exs — read the existing telemetry attach/assert pattern to replicate it for the two new events
  </read_first>
  <behavior>
    - delivery_lifecycle_test: attempt.adapter_module == "Chimeway.Adapters.Test" after sync delivery
    - delivery_lifecycle_test: assert_receive {:chimeway_delivery, "email", %Chimeway.Delivery{}} after sync delivery (D-23)
    - traces_test: explanation.last_attempt.adapter_module == "Chimeway.Adapters.Test" for a Phase-29 attempt
    - telemetry_integration_test: [:chimeway, :rendering, :channel_unregistered] fires with %{channel: "unknown_xyz_channel"} when unknown channel hits graceful fallback (D-14)
    - telemetry_integration_test: [:chimeway, :dispatch, :adapter_fallback] fires with %{channel: _, fallback_module: _} when :channel_adapters is set and lookup misses (D-19)
    - telemetry_integration_test: NO adapter_fallback event when only :adapter is configured and no :channel_adapters (D-18/D-19)
  </behavior>
  <action>
**test/chimeway/integration/delivery_lifecycle_test.exs**:

Find the existing Scenario B test block that uses `Chimeway.Adapters.Test` (around lines
378-440). Inside an existing test (or in a new test within that describe block), after
triggering a delivery and loading the attempt row from the DB, add:

```elixir
# D-20: adapter_module persisted as inspect(module) string
assert attempt.adapter_module == "Chimeway.Adapters.Test"

# D-23: channel-tagged mailbox delivery
assert_receive {:chimeway_delivery, "email", %Chimeway.Delivery{}}
```

Note: If loading the attempt from DB in the existing test, use:
```elixir
[attempt] = Chimeway.Repo.all(Chimeway.DeliveryAttempt)
assert attempt.adapter_module == "Chimeway.Adapters.Test"
```

Or access it from the `{:ok, %{attempt: attempt}}` return of `record_attempt`.

**test/chimeway/traces_test.exs**:

Find the existing `explain_delivery` test section. In a test that creates a delivery and
has at least one attempt, add after the explain call:

```elixir
# D-22: adapter_module in trace explain output
assert explanation.last_attempt.adapter_module == "Chimeway.Adapters.Test"
```

For a nil-safe test (pre-Phase-29 rows):
```elixir
# nil is valid for pre-Phase-29 attempts — null-safe path must not crash
assert is_nil(explanation.last_attempt.adapter_module) or
         is_binary(explanation.last_attempt.adapter_module)
```

**test/chimeway/telemetry_integration_test.exs**:

Follow the existing telemetry attach + assert_receive pattern already in the file.
Add two new test cases (or two new tests within an existing describe block):

```elixir
test "emits channel_unregistered telemetry for unknown render channels (D-14)" do
  handler_id = "test-channel-unregistered-#{System.unique_integer()}"

  :telemetry.attach(
    handler_id,
    [:chimeway, :rendering, :channel_unregistered],
    fn _event, measurements, metadata, _config ->
      send(self(), {:telemetry_event, measurements, metadata})
    end,
    nil
  )

  on_exit(fn -> :telemetry.detach(handler_id) end)

  # Trigger rendering for a channel not in compiled clauses or registry
  Chimeway.Rendering.render_delivery(:unknown_xyz_channel, "test.key", 1, %{"x" => "y"})

  assert_receive {:telemetry_event, %{count: 1}, %{channel: "unknown_xyz_channel"}}, 500
end

test "emits adapter_fallback telemetry when :channel_adapters set and lookup misses (D-19)" do
  handler_id = "test-adapter-fallback-#{System.unique_integer()}"

  :telemetry.attach(
    handler_id,
    [:chimeway, :dispatch, :adapter_fallback],
    fn _event, measurements, metadata, _config ->
      send(self(), {:telemetry_event, measurements, metadata})
    end,
    nil
  )

  on_exit(fn ->
    :telemetry.detach(handler_id)
    Application.delete_env(:chimeway, :channel_adapters)
  end)

  # Set :channel_adapters for "sms" only, then trigger an "email" delivery
  Application.put_env(:chimeway, :channel_adapters, %{"sms" => Chimeway.Adapters.Logger})

  # Call resolve_adapter indirectly via a delivery or directly via test helper
  # The adapter_fallback fires because :channel_adapters is non-empty and "email" is not in it
  Chimeway.Dispatch.Executor.run_delivery(build_test_delivery_for_channel("email"))

  assert_receive {:telemetry_event, %{count: 1}, %{channel: "email", fallback_module: _}}, 500
end

test "does NOT emit adapter_fallback when only :adapter is configured (D-18, D-19)" do
  handler_id = "test-no-fallback-#{System.unique_integer()}"
  received = :counters.new(1, [])

  :telemetry.attach(
    handler_id,
    [:chimeway, :dispatch, :adapter_fallback],
    fn _event, _measurements, _metadata, _config ->
      :counters.add(received, 1, 1)
    end,
    nil
  )

  on_exit(fn -> :telemetry.detach(handler_id) end)

  # Only :adapter is configured — no :channel_adapters
  # Trigger delivery; no adapter_fallback should fire
  :timer.sleep(50)
  assert :counters.get(received, 1) == 0
end
```

Use the existing helpers in the test file (`build_test_delivery_for_channel/1` or equivalent)
to create a delivery struct for testing. If no such helper exists, construct a minimal
delivery struct directly — read the existing test file for the pattern used there.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/integration/delivery_lifecycle_test.exs test/chimeway/traces_test.exs test/chimeway/telemetry_integration_test.exs 2>&1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "adapter_module" test/chimeway/integration/delivery_lifecycle_test.exs` outputs at least `1`
    - `grep -c "chimeway_delivery" test/chimeway/integration/delivery_lifecycle_test.exs` outputs at least `1`
    - `grep -c "adapter_module" test/chimeway/traces_test.exs` outputs at least `1`
    - `grep -c "channel_unregistered" test/chimeway/telemetry_integration_test.exs` outputs `1`
    - `grep -c "adapter_fallback" test/chimeway/telemetry_integration_test.exs` outputs at least `2`
    - `mix test test/chimeway/integration/delivery_lifecycle_test.exs` passes
    - `mix test test/chimeway/traces_test.exs` passes
    - `mix test test/chimeway/telemetry_integration_test.exs` passes
    - `mix test` (full suite) exits 0
  </acceptance_criteria>
  <done>All three test files extended with Phase 29 assertions; full suite green</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test adapter → test process | {:chimeway_delivery, channel, delivery} crosses from adapter execute context to test process mailbox |
| telemetry handler → test process | Telemetry events cross from library execution context to test handler |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-21 | Information Disclosure | Adapters.Test sending full delivery struct to mailbox | accept | Test-adapter-only behavior; never used in production; delivery struct in test mailbox is equivalent to already-accessible delivered_messages() list |
| T-29-22 | Spoofing | Fake {:chimeway_delivery, _, _} message injection | accept | Test environment only; send(self(), ...) in Adapters.Test is production code but only exercised in test config; production adapters never send to any process |
| T-29-23 | Backwards-compat breakage | Existing tests pattern-matching old adapter shape | mitigate | D-23 RESEARCH: no existing assert_receive {:chimeway_delivery, ...} patterns exist in test/**/*.exs; delivered_messages/0 and assert_delivered/1 unchanged; verified by RESEARCH.md Q6 |
</threat_model>

<verification>
After plan execution:
- `mix test` (full suite) exits 0
- `grep -c "chimeway_delivery" lib/chimeway/adapters/test.ex` returns `1`
- `grep -c "channel_unregistered" test/chimeway/telemetry_integration_test.exs` returns `1`
- `grep -c "adapter_module" test/chimeway/integration/delivery_lifecycle_test.exs` returns at least `1`
- All 25 decisions D-01..D-25 have at least one test assertion per the Coverage Matrix in 29-RESEARCH.md
</verification>

<success_criteria>
Adapters.Test sends channel-tagged messages to the test process. channel_contract_test.exs
has 10+ new test cases covering Sms/Push/Chat round-trips, error cases, vendor-field strip,
and registry-overlay. delivery_lifecycle_test.exs asserts adapter_module on the attempt row.
traces_test.exs asserts adapter_module in explanation.last_attempt. telemetry_integration_test.exs
asserts both new telemetry events. Full suite (mix test) exits 0.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-07-SUMMARY.md`
</output>
