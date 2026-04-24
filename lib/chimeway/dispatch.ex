defmodule Chimeway.Dispatch do
  @moduledoc """
  Behaviour contract for the dispatcher seam.

  Configure the dispatcher via:

      config :chimeway, :dispatcher, Chimeway.Dispatch.Sync

  The default implementation is `Chimeway.Dispatch.Sync`, which plans delivery rows
  without calling any adapter. `Chimeway.Dispatch.Oban` will be the Phase 3
  alternative that enqueues adapter calls as background jobs.

  Dispatch is called after notification creation, outside the notification
  `Ecto.Multi` transaction. Adapter calls must never hold a DB transaction open.
  """

  alias Chimeway.{Delivery, Notifications.Notification}

  @callback dispatch(notifications :: [Notification.t()], opts :: keyword()) ::
              {:ok, [Delivery.t()]} | {:error, term()}
end
