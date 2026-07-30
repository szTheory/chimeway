# Runtime proof of the README §"Trigger to explainable trace" snippet chain.
#
# This test IS the documented adopter path from README.md — an adopter who copies the
# public snippets (define notifier with a stable notification_key/0 + version/0, trigger
# with tenant_id + idempotency_key, then read result.trace.delivery_ids and call
# Chimeway.Traces.explain_delivery/1) must reach an explainable trace against a real DB.
#
# It replaces the former human UAT item "mix demo.up --check" (79-UAT.md test 2): unlike
# demo.up --check (migrate+seed+exit-0, no trace assertion), this exercises and asserts the
# exact documented Chimeway.trigger/3 -> Chimeway.Traces.explain_delivery/1 chain. If the
# public API shape drifts from the README, this test fails.
#
# Runs in the default `mix test` -> `ci.test` -> CI `test` job (Postgres already provisioned).
defmodule Chimeway.ReadmeSnippetTest do
  use Chimeway.DataCase, async: true

  @moduletag :integration

  alias Chimeway.Traces

  # Mirrors the README "1. Define a notifier" block (notification_key/0 "welcome_user",
  # version/0 1). recipients/1, build/2 and rendering/2 are the minimal delivery wiring the
  # golden-path guide shows — required so the triggered notification actually plans an
  # in_app delivery to explain.
  defmodule WelcomeUser do
    use Chimeway.Notifier

    @impl true
    def notification_key, do: "welcome_user"

    @impl true
    def version, do: 1

    @impl true
    def recipients(%{user_id: user_id}),
      do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

    @impl true
    def build(_params, _recipient), do: {:ok, %{title: "Welcome"}}

    @impl true
    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{
           "headline" => "Welcome",
           "body" => "Welcome aboard",
           "primary_action" => %{"label" => "Open", "url" => "https://example.test/welcome"}
         },
         channels: %{in_app: %{render_key: "welcome_user.in_app", render_version: 1}}
       }}
    end
  end

  test "the documented trigger -> explain_delivery snippet chain runs end-to-end" do
    # README "3. Trigger — both tenant_id and idempotency_key are always required"
    {:ok, result} =
      Chimeway.trigger(WelcomeUser, %{user_id: "user_12345"},
        idempotency_key: "signup_user_12345",
        tenant_id: "default"
      )

    # README "4. Explain the delivery"
    [delivery_id | _] = result.trace.delivery_ids
    {:ok, explanation} = Traces.explain_delivery(delivery_id)

    # The documented explanation carries the answer to "why did this go out?"
    assert %Chimeway.Traces.Explanation{} = explanation
    assert explanation.delivery_id == delivery_id
    assert explanation.notification_key == "welcome_user"

    assert explanation.status in [
             :succeeded,
             :failed,
             :suppressed,
             :pending,
             :cancelled,
             :dispatched
           ]

    assert is_list(explanation.timeline)
    assert :delivery_planned in Enum.map(explanation.timeline, & &1.event)
  end
end
