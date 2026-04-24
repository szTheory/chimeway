defmodule Chimeway.TriggerPipelineTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Trigger

  defmodule PipelineNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 3

    @impl true
    def recipients(_params) do
      {:ok,
       [
         %{recipient_identity: "z-user", channel: :in_app},
         %{recipient_identity: "a-user", channel: :email},
         %{recipient_identity: "a-user", channel: :sms},
         %{recipient_identity: "m-user", channel: :push}
       ]}
    end

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  end

  test "returns error when idempotency key is missing" do
    assert {:error, :missing_idempotency_key} = Trigger.trigger(PipelineNotifier, %{}, [])
  end

  test "returns error when idempotency key is blank" do
    assert {:error, :blank_idempotency_key} =
             Trigger.trigger(PipelineNotifier, %{}, idempotency_key: "   ")
  end

  test "returns deterministic, deduped recipient output" do
    assert {:ok, result} = Trigger.trigger(PipelineNotifier, %{}, idempotency_key: "idem-123")

    assert result.notification_key == "comment.created"
    assert result.notification_version == 3
    assert result.idempotency_key == "idem-123"

    assert Enum.map(result.recipients, & &1.recipient_identity) == ["a-user", "m-user", "z-user"]
    assert length(result.recipients) == 3
  end
end
