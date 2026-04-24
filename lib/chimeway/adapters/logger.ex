defmodule Chimeway.Adapters.Logger do
  @moduledoc """
  Structured-log adapter that emits a tagged Logger.info line and always succeeds.

  Logs only identity fields (channel, recipient_identity, notification_id) — never
  the delivery metadata map, which may contain rendered content or sensitive data.

  No state, no external dependencies. Safe for any environment including production
  debugging.
  """

  @behaviour Chimeway.Adapter

  require Logger

  @impl Chimeway.Adapter
  def deliver(%Chimeway.Delivery{} = delivery, _config) do
    Logger.info(
      "[chimeway_delivery] channel=#{delivery.channel} notification_id=#{delivery.notification_id}"
    )

    {:ok, %{adapter: "logger", logged: true}}
  end
end
