defmodule Chimeway.TriggerPipelineTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query

  alias Chimeway.{Delivery, Notifications.Notification, Repo, Trigger}

  defmodule FanoutNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.fanout"

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

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  end

  defmodule PipelineNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created.fallback"

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

  test "returns deterministic, deduped recipient output with explicit channel fanout" do
    assert {:ok, result} = Trigger.trigger(FanoutNotifier, %{}, idempotency_key: "idem-123")

    assert result.notification_key == "comment.created.fanout"
    assert result.notification_version == 3
    assert result.idempotency_key == "idem-123"

    assert Enum.map(result.recipients, & &1.recipient_identity) == ["a-user", "m-user", "z-user"]
    assert length(result.recipients) == 3

    notifications =
      Repo.all(from(n in Notification, where: n.event_id == ^result.event.id, select: n.id))

    assert length(notifications) == 3

    delivery_count =
      Repo.aggregate(
        from(d in Delivery, where: d.notification_id in ^notifications),
        :count,
        :id
      )

    assert delivery_count == 6

    recipient_channels =
      Repo.all(
        from(d in Delivery,
          join: n in Notification,
          on: d.notification_id == n.id,
          where: n.event_id == ^result.event.id,
          select: {n.recipient_identity, d.channel}
        )
      )

    assert MapSet.new(recipient_channels) ==
             MapSet.new([
               {"a-user", "email"},
               {"a-user", "in_app"},
               {"m-user", "email"},
               {"m-user", "in_app"},
               {"z-user", "email"},
               {"z-user", "in_app"}
             ])
  end

  test "falls back to a single in_app delivery when notifier has no channels/2 callback" do
    assert {:ok, result} = Trigger.trigger(PipelineNotifier, %{}, idempotency_key: "idem-124")

    assert result.notification_key == "comment.created.fallback"
    assert Enum.map(result.recipients, & &1.recipient_identity) == ["a-user", "m-user", "z-user"]

    notifications =
      Repo.all(from(n in Notification, where: n.event_id == ^result.event.id, select: n.id))

    assert Repo.aggregate(from(d in Delivery, where: d.notification_id in ^notifications), :count, :id) ==
             3

    channels =
      Repo.all(
        from(d in Delivery,
          where: d.notification_id in ^notifications,
          select: d.channel,
          distinct: true
        )
      )

    assert MapSet.new(channels) == MapSet.new(["in_app"])
  end
end
