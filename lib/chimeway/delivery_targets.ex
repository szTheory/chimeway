defmodule Chimeway.DeliveryTargets do
  @moduledoc false

  import Ecto.Query
  alias Ecto.Multi
  alias Chimeway.{Deliveries, Delivery, DeliveryTarget, DeliveryTargetAttempt, Repo, SafeEvidence}
  alias Chimeway.TargetResolver.BindingRevision

  @spec plan_targets(Delivery.t(), String.t(), [BindingRevision.t()]) ::
          {:ok, [DeliveryTarget.t()]} | {:error, term()}
  def plan_targets(%Delivery{tenant_id: tenant_id} = delivery, tenant_id, bindings)
      when is_list(bindings) do
    with {:ok, bindings} <- Chimeway.TargetResolver.normalize(tenant_id, bindings) do
      Repo.transaction(fn ->
        Enum.each(bindings, fn %BindingRevision{binding_revision_ref: ref} ->
          %DeliveryTarget{}
          |> DeliveryTarget.changeset(%{
            tenant_id: tenant_id,
            delivery_id: delivery.id,
            binding_revision_ref: ref,
            status: :pending
          })
          |> Repo.insert!(
            on_conflict: :nothing,
            conflict_target: [:delivery_id, :binding_revision_ref]
          )
        end)

        authoritative_targets(delivery.id, tenant_id)
      end)
      |> case do
        {:ok, targets} -> {:ok, targets}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def plan_targets(_, _, _), do: {:error, :tenant_mismatch}

  defp authoritative_targets(delivery_id, tenant_id) do
    Repo.all(
      from(t in DeliveryTarget,
        where: t.delivery_id == ^delivery_id and t.tenant_id == ^tenant_id,
        order_by: [asc: t.binding_revision_ref, asc: t.id]
      )
    )
  end

  @spec begin_target_attempt(Delivery.t(), keyword()) ::
          {:ok, %{target: DeliveryTarget.t(), attempt: DeliveryTargetAttempt.t()}}
          | {:noop, term()}
          | {:error, term()}
  def begin_target_attempt(%Delivery{tenant_id: tenant_id} = delivery, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    source = Keyword.get(opts, :source, "sync")

    Multi.new()
    |> Multi.run(:target, fn repo, _ ->
      case repo.one(
             from(t in DeliveryTarget,
               where:
                 t.delivery_id == ^delivery.id and t.tenant_id == ^tenant_id and
                   t.status == :pending,
               order_by: [asc: t.binding_revision_ref],
               limit: 1,
               lock: "FOR UPDATE"
             )
           ) do
        nil -> {:error, :no_eligible_target}
        target -> {:ok, target}
      end
    end)
    |> Multi.update(:claimed_target, fn %{target: target} ->
      Ecto.Changeset.change(target,
        status: :claimed,
        claimed_at: now,
        lease_expires_at: DateTime.add(now, 60, :second)
      )
    end)
    |> Multi.run(:attempt_number, fn repo, %{target: target} ->
      {:ok,
       repo.aggregate(
         from(a in DeliveryTargetAttempt, where: a.delivery_target_id == ^target.id),
         :count,
         :id
       ) + 1}
    end)
    |> Multi.insert(:attempt, fn %{target: target, attempt_number: attempt_number} ->
      DeliveryTargetAttempt.changeset(%DeliveryTargetAttempt{}, %{
        tenant_id: tenant_id,
        delivery_target_id: target.id,
        attempt_number: attempt_number,
        outcome: :attempt_started,
        started_at: now,
        source: source,
        safe_facts: %{}
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{claimed_target: target, attempt: attempt}} ->
        {:ok, %{target: target, attempt: attempt}}

      {:error, :target, :no_eligible_target, _} ->
        {:noop, :no_eligible_target}

      {:error, _step, reason, _} ->
        {:error, reason}
    end
  end

  @spec record_target_result(Delivery.t(), DeliveryTarget.t(), DeliveryTargetAttempt.t(), term()) ::
          {:ok,
           %{
             delivery: Delivery.t(),
             target: DeliveryTarget.t(),
             attempt: DeliveryTargetAttempt.t()
           }}
          | {:error, term()}
  def record_target_result(
        %Delivery{} = delivery,
        %DeliveryTarget{} = target,
        %DeliveryTargetAttempt{} = attempt,
        result
      ) do
    with {:ok, safe_facts} <- SafeEvidence.target_attempt_facts(result) do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      Multi.new()
      |> Multi.update(
        :target,
        Ecto.Changeset.change(target, status: :provider_accepted, lease_expires_at: nil)
      )
      |> Multi.update(
        :attempt,
        Ecto.Changeset.change(attempt,
          outcome: :provider_accepted,
          finished_at: now,
          safe_facts: safe_facts
        )
      )
      |> Multi.run(:delivery, fn _repo, _ ->
        case Deliveries.transition_status(delivery, :dispatched) do
          {:ok, dispatched} -> Deliveries.transition_status(dispatched, :succeeded)
          {:error, _} = error -> error
        end
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{delivery: updated, target: updated_target, attempt: updated_attempt}} ->
          {:ok, %{delivery: updated, target: updated_target, attempt: updated_attempt}}

        {:error, _step, reason, _} ->
          {:error, reason}
      end
    end
  end
end
