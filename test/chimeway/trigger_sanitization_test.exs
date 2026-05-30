defmodule Chimeway.TriggerSanitizationTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Trigger

  defmodule AuthFlowSanitizationNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "test.auth_flow_sanitization"

    @impl true
    def version, do: 1

    @impl true
    def recipients(%{"user_id" => user_id}) do
      {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}
    end

    @impl true
    def build(params, _recipient) do
      {:ok, %{"user_id" => params["user_id"], "kind" => "auth_flow_test"}}
    end

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app]}

    @impl true
    def rendering(_params, _recipient) do
      {:ok,
       %{
         assigns: %{
           "user_id" => "1",
           "url" => "https://secret.example/login/abc",
           "code" => "123456",
           "raw_token" => "raw-secret",
           "magic_link_url" => "https://secret.example/magic/xyz",
           "headline" => "Auth test",
           "body" => "Sanitized assigns",
           "primary_action" => %{"label" => "Open", "url" => "https://example.test/safe"}
         },
         channels: %{
           in_app: %{render_key: "test.auth_flow_sanitization.in_app", render_version: 1}
         }
       }}
    end
  end

  @sensitive_values %{
    "url" => "https://secret.example/login/abc",
    "code" => "123456",
    "raw_token" => "raw-secret",
    "magic_link_url" => "https://secret.example/magic/xyz"
  }

  describe "sanitize_payload/1 auth-flow keys (D-08)" do
    test "strips url, code, raw_token, and magic_link_url from persisted event payload" do
      params =
        Map.merge(@sensitive_values, %{
          "user_id" => "1"
        })

      assert {:ok, %{event: event}} =
               Trigger.trigger(
                 AuthFlowSanitizationNotifier,
                 params,
                 idempotency_key: "sanitization-payload-#{System.unique_integer()}",
                 tenant_id: "tenant-1"
               )

      reloaded = Repo.get!(Event, event.id)

      assert reloaded.payload["user_id"] == "1"

      for {key, value} <- @sensitive_values do
        refute Map.has_key?(reloaded.payload, key)
        refute reloaded.payload |> inspect() |> String.contains?(value)
      end
    end

    test "strips auth-flow sensitive keys from notification render_assigns" do
      params =
        Map.merge(@sensitive_values, %{
          "user_id" => "1"
        })

      idempotency_key = "sanitization-render-#{System.unique_integer()}"

      assert {:ok, %{event: event}} =
               Trigger.trigger(
                 AuthFlowSanitizationNotifier,
                 params,
                 idempotency_key: idempotency_key,
                 tenant_id: "tenant-1"
               )

      notification =
        Repo.one!(
          from(n in Notification,
            where: n.event_id == ^event.id
          )
        )

      for key <- Map.keys(@sensitive_values) do
        refute Map.has_key?(notification.render_assigns, key)
        refute Map.has_key?(notification.metadata, key)
      end

      assert notification.render_assigns["user_id"] == "1"
      assert notification.render_assigns["headline"] == "Auth test"
    end
  end
end
