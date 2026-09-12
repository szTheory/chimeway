defmodule Chimeway.Inbox.ChangePublisher do
  @moduledoc """
  Replaceable boundary for lossy inbox reload hints.

  Publishing happens after durable writes and is intentionally best-effort. A
  callback cannot change the result of the notification operation that produced it.
  """

  alias Chimeway.Inbox.Change
  alias Chimeway.Inbox.ChangePublisher.Noop

  @callback publish(Change.t()) :: :ok | {:error, term()}

  @spec publish(term(), term(), term()) :: :ok
  def publish(tenant_id, recipient_ref, event) do
    outcome =
      with {:ok, change} <- Change.new(tenant_id, recipient_ref, event),
           :ok <- invoke(configured_publisher(), change) do
        :succeeded
      else
        _ -> :failed
      end

    :telemetry.execute(
      [:chimeway, :inbox, :change_publish],
      %{count: 1},
      %{outcome: outcome}
    )

    :ok
  end

  defp configured_publisher do
    Application.get_env(:chimeway, :inbox_change_publisher, Noop)
  end

  defp invoke(publisher, change) when is_atom(publisher) do
    try do
      case publisher.publish(change) do
        :ok -> :ok
        _ -> :error
      end
    catch
      _, _ -> :error
    end
  end

  defp invoke(_publisher, _change), do: :error
end
