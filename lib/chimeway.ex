defmodule Chimeway do
  @moduledoc """
  Public entrypoint for notification triggering.
  """

  @doc """
  Triggers a notifier execution with explicit runtime options.
  """
  def trigger(notifier, params, opts \\ []) do
    Chimeway.Trigger.trigger(notifier, params, opts)
  end
end
