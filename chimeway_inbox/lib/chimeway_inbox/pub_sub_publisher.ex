defmodule ChimewayInbox.PubSubPublisher do
  @moduledoc """
  Phoenix PubSub implementation of `Chimeway.Inbox.ChangePublisher`.

  Configure this module in the core package and configure this package's
  PubSub server and topic secret to opt into connected inbox reloads.
  """

  @behaviour Chimeway.Inbox.ChangePublisher

  alias Chimeway.Inbox.Change
  alias ChimewayInbox.ChangeStream

  @impl true
  def publish(%Change{tenant_id: tenant_id, recipient_ref: recipient_ref}) do
    with {:ok, topic} <- ChangeStream.topic(tenant_id, recipient_ref) do
      ChangeStream.broadcast_topic(topic)
    end
  end

  def publish(_change), do: {:error, :invalid_stream}
end
