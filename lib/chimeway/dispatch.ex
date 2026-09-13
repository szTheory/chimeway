defmodule Chimeway.Dispatch do
  @moduledoc """
  Behaviour contract for the dispatcher seam.

  Configure the dispatcher via:

      config :chimeway, :dispatcher, Chimeway.Dispatch.Sync

  The default implementation is `Chimeway.Dispatch.Sync`, which plans and executes
  deliveries in the calling process. Configure `Chimeway.Dispatch.Oban` to plan
  deliveries and enqueue their adapter calls as background jobs.

  Dispatch is called after notification creation, outside the notification
  `Ecto.Multi` transaction. Adapter calls must never hold a DB transaction open.
  """

  alias Chimeway.{Delivery, Notifications.Notification}

  @callback dispatch(notifications :: [Notification.t()], opts :: keyword()) ::
              {:ok, [Delivery.t()]} | {:error, term()}

  @callback dispatch_delivery(delivery_or_id :: Delivery.t() | binary(), opts :: keyword()) ::
              {:ok, Delivery.t()} | {:skip, Delivery.t()} | {:error, term()}
end
