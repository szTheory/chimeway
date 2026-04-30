---
phase: 29-outbound-channel-contracts
plan: "03"
type: execute
wave: 2
depends_on:
  - "01"
files_modified:
  - lib/chimeway/rendering/channels/sms.ex
  - lib/chimeway/rendering/channels/push.ex
  - lib/chimeway/rendering/channels/chat.ex
  - lib/chimeway/rendering/channels/email.ex
  - lib/chimeway/rendering/channels/in_app.ex
autonomous: true
requirements:
  - CHAN-01
  - CHAN-02

must_haves:
  truths:
    - "Chimeway.Rendering.Channels.Sms validates text_body (required) and rejects vendor fields"
    - "Chimeway.Rendering.Channels.Push validates title + body (required), data (:map, optional)"
    - "Chimeway.Rendering.Channels.Chat validates text (required), rich_payload (:map, optional)"
    - "Email and InApp declare use Chimeway.Rendering.Channel and @impl annotations"
    - "All five built-in channel modules compile without warnings"
  artifacts:
    - path: "lib/chimeway/rendering/channels/sms.ex"
      provides: "SMS render contract validator"
      exports: ["validate/1"]
      contains: "text_body"
    - path: "lib/chimeway/rendering/channels/push.ex"
      provides: "Push render contract validator"
      exports: ["validate/1"]
      contains: "title"
    - path: "lib/chimeway/rendering/channels/chat.ex"
      provides: "Chat render contract validator"
      exports: ["validate/1"]
      contains: "rich_payload"
  key_links:
    - from: "lib/chimeway/rendering/channels/sms.ex"
      to: "lib/chimeway/rendering/channel.ex"
      via: "use Chimeway.Rendering.Channel"
      pattern: "use Chimeway\\.Rendering\\.Channel"
    - from: "lib/chimeway/rendering/channels/push.ex"
      to: "lib/chimeway/rendering/channel.ex"
      via: "use Chimeway.Rendering.Channel"
      pattern: "use Chimeway\\.Rendering\\.Channel"
    - from: "lib/chimeway/rendering/channels/chat.ex"
      to: "lib/chimeway/rendering/channel.ex"
      via: "use Chimeway.Rendering.Channel"
      pattern: "use Chimeway\\.Rendering\\.Channel"
---

<objective>
Create the three new built-in channel render-contract modules (Sms, Push, Chat) and
refactor the two existing modules (Email, InApp) to declare `@behaviour` via
`use Chimeway.Rendering.Channel`. All five use the Ecto.Changeset skeleton from
`email.ex` (D-25).

Purpose: Satisfies CHAN-02 (distinct per-channel render contracts) and D-01/D-05/D-09
field shapes. The `@behaviour` refactor on Email/InApp enforces the contract compiler-
wide (D-11). Plan 04 depends on Sms/Push/Chat existing.

Output: Five compiled channel modules all declaring `@behaviour Chimeway.Rendering.Channel`.
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
<!-- Full email.ex skeleton the executor copies verbatim for Sms/Push/Chat. -->

From lib/chimeway/rendering/channels/email.ex (complete file — the template):
```elixir
defmodule Chimeway.Rendering.Channels.Email do
  @moduledoc """
  Validates the durable email render contract.
  """

  import Ecto.Changeset

  @types %{
    subject: :string,
    html_body: :string,
    text_body: :string
  }

  @required_fields [:subject, :html_body, :text_body]

  @spec validate(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def validate(attrs) when is_map(attrs) do
    {%{}, @types}
    |> cast(attrs, Map.keys(@types))
    |> validate_required(@required_fields)
    |> apply_action(:insert)
    |> case do
      {:ok, validated} -> {:ok, stringify_keys(validated)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def validate(other) do
    types = %{payload: :map}

    {%{}, types}
    |> cast(%{payload: other}, [:payload])
    |> add_error(:payload, "must be a map")
    |> apply_action(:insert)
  end

  defp stringify_keys(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {Atom.to_string(key), value}
    end)
  end
end
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create Sms, Push, Chat channel modules</name>
  <files>
    lib/chimeway/rendering/channels/sms.ex,
    lib/chimeway/rendering/channels/push.ex,
    lib/chimeway/rendering/channels/chat.ex
  </files>
  <read_first>
    - lib/chimeway/rendering/channels/email.ex — the exact template to copy verbatim; read the full file before creating any new module
    - lib/chimeway/rendering/channel.ex — confirms the behaviour module is compiled (Wave 1 Plan 01 output)
  </read_first>
  <behavior>
    - Sms.validate(%{"text_body" => "Hello"}) returns {:ok, %{"text_body" => "Hello"}}
    - Sms.validate(%{}) returns {:error, %Ecto.Changeset{}} with text_body: ["can't be blank"]
    - Sms.validate(%{"text_body" => "x", "from" => "+1555"}) returns {:ok, %{"text_body" => "x"}} — vendor fields stripped by cast
    - Push.validate(%{"title" => "Alert", "body" => "New msg"}) returns {:ok, %{"title" => "Alert", "body" => "New msg"}}
    - Push.validate(%{"title" => "Alert"}) returns {:error, %Ecto.Changeset{}} with body: ["can't be blank"]
    - Push.validate(%{"title" => "Alert", "body" => "x", "data" => %{"deep_link" => "/inbox"}}) returns {:ok, map with data}
    - Chat.validate(%{"text" => "Hi"}) returns {:ok, %{"text" => "Hi"}}
    - Chat.validate(%{}) returns {:error, %Ecto.Changeset{}} with text: ["can't be blank"]
  </behavior>
  <action>
Create three files, each a copy of `email.ex` with the substitutions described below.
Copy the full `email.ex` skeleton verbatim (including the validate(other) fallback and
stringify_keys/1 private function). Then apply per-module substitutions.

**lib/chimeway/rendering/channels/sms.ex** (D-01, D-02, D-03, D-04, D-25):
- Module name: `Chimeway.Rendering.Channels.Sms`
- Add `use Chimeway.Rendering.Channel` after the opening `@moduledoc` block
- Add `@impl Chimeway.Rendering.Channel` before the `@spec validate` line
- `@types %{text_body: :string}`
- `@required_fields [:text_body]`
- `@moduledoc` must include this paragraph (D-03):
  ```
  Only the message body is a render concern. Sender ID, Messaging Service SID,
  and recipient phone number are adapter-config territory — never in render_data.

  GSM-7 encoding supports up to 160 characters per segment; UCS-2 (unicode) supports
  up to 70 characters per segment. Multi-segment messages are billed per segment.
  Segmentation and encoding are vendor concerns handled in the adapter, not validated here.
  ```
- No `media_url` field (D-04 deferred)
- Vendor fields (`from`, `to`, `phone_number`) are automatically stripped by Ecto.Changeset
  `cast/3` since they are not in @types — no extra code needed

**lib/chimeway/rendering/channels/push.ex** (D-05, D-06, D-07, D-08, D-25):
- Module name: `Chimeway.Rendering.Channels.Push`
- Add `use Chimeway.Rendering.Channel` after the opening `@moduledoc` block
- Add `@impl Chimeway.Rendering.Channel` before the `@spec validate` line
- `@types %{title: :string, body: :string, data: :map}`
- `@required_fields [:title, :body]`
- `data` is `:map` only — no sub-shape validation (D-08); Ecto handles nil data as optional
- `@moduledoc` must include this paragraph (D-07):
  ```
  Only content fields are render concerns. APNs/FCM platform plumbing (apns_topic,
  priority, collapse_id, expiration, push_type, device_token) belongs in the adapter,
  not in render_data. Use the opaque `data` map for app-specific custom payloads.
  ```
- No platform-specific fields (D-06, D-07)

**lib/chimeway/rendering/channels/chat.ex** (D-09, D-10, D-25):
- Module name: `Chimeway.Rendering.Channels.Chat`
- Add `use Chimeway.Rendering.Channel` after the opening `@moduledoc` block
- Add `@impl Chimeway.Rendering.Channel` before the `@spec validate` line
- `@types %{text: :string, rich_payload: :map}`
- `@required_fields [:text]`
- `rich_payload` is `:map` only — opaque for Slack blocks, Discord embeds, Teams Adaptive Cards (D-09)
- `text` (not `text_body`) matches Slack's native API field name
- `@moduledoc` must include this paragraph (D-10):
  ```
  This is the discoverable starter validator for generic chat. Host apps with
  vendor-specific shapes (Slack-only, Discord-only, in-house chat) should define
  their own validators via the :channel_render_modules registry without modifying this module.
  ```
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix test test/chimeway/rendering/channel_contract_test.exs 2>&1 | tail -10</automated>
  </verify>
  <acceptance_criteria>
    - `ls lib/chimeway/rendering/channels/` lists sms.ex, push.ex, chat.ex, email.ex, in_app.ex
    - `grep -c "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/sms.ex` outputs `1`
    - `grep -c "@impl Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/sms.ex` outputs `1`
    - `grep "text_body" lib/chimeway/rendering/channels/sms.ex | grep "@types"` shows `text_body: :string`
    - `grep -c "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/push.ex` outputs `1`
    - `grep "title" lib/chimeway/rendering/channels/push.ex | grep "@types"` shows `title: :string`
    - `grep "data" lib/chimeway/rendering/channels/push.ex | grep "@types"` shows `data: :map`
    - `grep -c "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/chat.ex` outputs `1`
    - `grep "rich_payload" lib/chimeway/rendering/channels/chat.ex | grep "@types"` shows `rich_payload: :map`
    - `mix compile` exits 0 with no errors on any of the three new files
    - Existing `mix test test/chimeway/rendering/channel_contract_test.exs` still passes (existing email/in_app tests unaffected)
  </acceptance_criteria>
  <done>Three new channel modules exist, compile, and pass existing channel_contract_test.exs</done>
</task>

<task type="auto">
  <name>Task 2: Refactor Email and InApp to declare @behaviour</name>
  <files>
    lib/chimeway/rendering/channels/email.ex,
    lib/chimeway/rendering/channels/in_app.ex
  </files>
  <read_first>
    - lib/chimeway/rendering/channels/email.ex — read full file before editing; adding two lines only
    - lib/chimeway/rendering/channels/in_app.ex — read full file before editing; has nested validation via validate_primary_action/1 — leave that unchanged
  </read_first>
  <action>
Make exactly two additions to each file. Do NOT change any functional code (D-11 refactor only).

**lib/chimeway/rendering/channels/email.ex**:
1. After the closing `"""` of the `@moduledoc` block, add:
   ```elixir
   use Chimeway.Rendering.Channel
   ```
2. Before the `@spec validate(map()) :: ...` line, add:
   ```elixir
   @impl Chimeway.Rendering.Channel
   ```

**lib/chimeway/rendering/channels/in_app.ex**:
1. After the closing `"""` of the `@moduledoc` block, add:
   ```elixir
   use Chimeway.Rendering.Channel
   ```
2. Before the `@spec validate(map()) :: ...` line (the first `validate/1` clause only), add:
   ```elixir
   @impl Chimeway.Rendering.Channel
   ```

InApp's nested `validate_primary_action/1` private function must remain unchanged.
All other lines in both files remain verbatim.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway && mix compile 2>&1 | grep -E "error|undefined" | head -10</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/email.ex` outputs `1`
    - `grep -c "@impl Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/email.ex` outputs `1`
    - `grep -c "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/in_app.ex` outputs `1`
    - `grep -c "@impl Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/in_app.ex` outputs `1`
    - `mix compile` exits 0 with no errors (no "does not implement behaviour" warnings because validate/1 IS implemented)
    - `mix test test/chimeway/rendering/channel_contract_test.exs` passes (no regressions)
  </acceptance_criteria>
  <done>Email and InApp declare @behaviour via use macro; compile is clean; existing tests pass</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| notifier attrs → changeset | Raw render attrs map crosses into Ecto.Changeset validation boundary |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-29-07 | Tampering | SMS text_body vendor field injection | mitigate | D-02: Ecto cast/3 strips any key not in @types (from, to, phone_number, media_url) — vendor fields never reach render_data |
| T-29-08 | Tampering | Push data map arbitrary payload | accept | D-08: data is :map validated only for type, not shape — this is intentional; APNs/FCM require opaque payloads; adapters own platform translation |
| T-29-09 | Information Disclosure | Chat rich_payload opaque map | accept | rich_payload is host-app territory (Slack blocks, Discord embeds); library does not inspect content; adapters own rendering |
| T-29-10 | Elevation of Privilege | @behaviour enforcement | mitigate | D-11: @impl annotations and @behaviour declaration cause compiler warnings/errors if validate/1 is missing or misnamed — typos surface at compile time, not at runtime delivery |
</threat_model>

<verification>
After plan execution:
- `mix compile` exits 0 with no errors across all five channel modules
- `mix test test/chimeway/rendering/channel_contract_test.exs` passes
- `grep -rn "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/` shows 5 matches
</verification>

<success_criteria>
Five channel modules (Email, InApp, Sms, Push, Chat) all compiled and declaring
`use Chimeway.Rendering.Channel`. Sms has @types %{text_body: :string},
Push has @types %{title: :string, body: :string, data: :map},
Chat has @types %{text: :string, rich_payload: :map}.
mix compile and mix test channel_contract_test.exs both exit 0.
</success_criteria>

<output>
After completion, create `.planning/phases/29-outbound-channel-contracts/29-03-SUMMARY.md`
</output>
