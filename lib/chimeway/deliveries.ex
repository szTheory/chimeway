defmodule Chimeway.Deliveries do
  @moduledoc """
  Context module for delivery planning, attempt recording, and status transitions.

  Delivery rows are idempotent per (notification_id, channel). Attempt rows are
  append-only — each adapter call produces a new attempt row.
  """

  import Ecto.Changeset, only: [change: 2]

  alias Chimeway.{Delivery, DeliveryAttempt, Repo}
  alias Chimeway.Telemetry
  alias Ecto.Multi

  @terminal_states [:succeeded, :suppressed, :cancelled]

  @doc """
  Returns the list of terminal delivery states — used by the dispatcher (Plan 02-02)
  to short-circuit dispatch for already-terminal deliveries.
  """
  def terminal_states, do: @terminal_states

  @allowed_transitions %{
    pending: [:dispatched, :suppressed, :cancelled],
    dispatched: [:succeeded, :failed, :suppressed],
    failed: [:dispatched]
  }

  @doc """
  Plans a delivery row for the given notification_id and channel.
  Idempotent: duplicate calls on the same (notification_id, channel) create exactly one row.
  """
  @spec plan_delivery(binary(), atom() | binary()) ::
          {:ok, Delivery.t()} | {:error, Ecto.Changeset.t()}
  def plan_delivery(notification_id, channel) do
    channel_str = if is_atom(channel), do: Atom.to_string(channel), else: channel

    result =
      %Delivery{}
      |> Delivery.changeset(%{
        notification_id: notification_id,
        channel: channel_str,
        status: :pending
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:notification_id, :channel])

    case result do
      {:ok, _} ->
        # Reload from DB: on_conflict: :nothing returns a phantom struct on conflict.
        # Always return the authoritative row with current status.
        {:ok, Repo.get_by!(Delivery, notification_id: notification_id, channel: channel_str)}

      error ->
        error
    end
  end

  @doc """
  Fetches a delivery by ID, raising if not found.
  """
  @spec get_delivery!(binary()) :: Delivery.t()
  def get_delivery!(id), do: Repo.get!(Delivery, id)

  @doc """
  Transitions a delivery to a new status, respecting the allowed transition table.
  Returns {:error, {:invalid_transition, from: current, to: new}} for disallowed transitions.
  """
  @spec transition_status(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def transition_status(%Delivery{} = delivery, new_status) do
    allowed = Map.get(@allowed_transitions, delivery.status, [])

    if new_status in allowed do
      delivery
      |> change(status: new_status)
      |> Repo.update()
    else
      {:error, {:invalid_transition, from: delivery.status, to: new_status}}
    end
  end

  @doc """
  Transitions a delivery to :suppressed and persists the suppression_reason.
  """
  @spec suppress_delivery(Delivery.t(), atom()) :: {:ok, Delivery.t()} | {:error, term()}
  def suppress_delivery(%Delivery{} = delivery, reason) when is_atom(reason) do
    delivery
    |> change(status: :suppressed, suppression_reason: Atom.to_string(reason))
    |> Repo.update()
  end

  @doc """
  Atomically inserts an attempt row and transitions the delivery status.
  Returns {:ok, %{delivery: updated_delivery, attempt: attempt}} on success.
  Returns {:error, step, reason, changes} if any step fails (both operations roll back).
  """
  @spec record_attempt(Delivery.t(), map()) ::
          {:ok, %{delivery: Delivery.t(), attempt: DeliveryAttempt.t()}}
          | {:error, atom(), term(), map()}
  def record_attempt(%Delivery{} = delivery, attrs) do
    Telemetry.span(
      [:attempts, :record],
      Telemetry.safe_meta(%{delivery_id: delivery.id}),
      fn ->
        outcome = Map.get(attrs, :outcome) || Map.get(attrs, "outcome")

        delivery_status =
          case outcome do
            :succeeded -> :succeeded
            "succeeded" -> :succeeded
            _ -> :failed
          end

        safe_attrs =
          attrs
          |> Map.update(:provider_response, nil, &sanitize_metadata/1)
          |> Map.put(:delivery_id, delivery.id)

        result =
          Multi.new()
          |> Multi.insert(:attempt, DeliveryAttempt.changeset(%DeliveryAttempt{}, safe_attrs))
          |> Multi.run(:delivery, fn _repo, _changes ->
            transition_status(delivery, delivery_status)
          end)
          |> Repo.transaction()
          |> case do
            {:ok, %{delivery: updated_delivery, attempt: attempt}} ->
              {:ok, %{delivery: updated_delivery, attempt: attempt}}

            {:error, step, reason, changes} ->
              {:error, step, reason, changes}
          end

        extra =
          case result do
            {:ok, %{attempt: attempt}} ->
              Telemetry.safe_meta(%{attempt_id: attempt.id, outcome: attempt.outcome})

            _ ->
              %{}
          end

        {result, extra}
      end
    )
  end

  @sensitive_keys ~w(password token secret)

  defp sanitize_metadata(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if sensitive_key?(key), do: acc, else: Map.put(acc, key, value)
    end)
  end

  defp sanitize_metadata(_), do: %{}

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
  defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
  defp sensitive_key?(_), do: false
end
