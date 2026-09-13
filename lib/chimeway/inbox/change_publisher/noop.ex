defmodule Chimeway.Inbox.ChangePublisher.Noop do
  @moduledoc false
  @behaviour Chimeway.Inbox.ChangePublisher

  @impl true
  def publish(_change), do: :ok
end
