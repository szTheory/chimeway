defmodule ChimewayInbox.TestSupport.Fixtures do
  @moduledoc false

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo

  @doc """
  Inserts an inbox notification row for LiveView tests.

  Creates a backing `Event` and `Notification` for `recipient_identity`.
  """
  def insert_inbox_notification!(recipient_identity, attrs \\ %{}) do
    idempotency_key = Map.get(attrs, :idempotency_key, "inbox-fixture-#{Ecto.UUID.generate()}")
    event = insert_event!(idempotency_key)

    notification_attrs =
      %{
        recipient_identity: recipient_identity,
        recipient_type: "member",
        metadata: %{},
        read_at: nil
      }
      |> Map.merge(Map.drop(attrs, [:idempotency_key]))

    insert_notification!(event, notification_attrs)
  end

  defp insert_event!(idempotency_key) do
    %Event{}
    |> Event.changeset(%{
      notification_key: "comment.created",
      notification_version: 1,
      idempotency_key: idempotency_key,
      payload: %{}
    })
    |> Repo.insert!()
  end

  defp insert_notification!(event, attrs) do
    %Notification{}
    |> Notification.changeset(Map.merge(attrs, %{event_id: event.id}))
    |> Repo.insert!()
  end
end
