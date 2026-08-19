defmodule Chimeway.DeliveryTargets do
  @moduledoc false

  import Ecto.Query
  alias Ecto.Multi
  alias Chimeway.{Delivery, DeliveryTarget, DeliveryTargetAttempt, Repo, SafeEvidence}
  alias Chimeway.TargetResolver.BindingRevision

  @terminal_statuses [
    :provider_accepted,
    :failed,
    :expired,
    :invalidated,
    :retry_exhausted,
    :ambiguous_handoff
  ]

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

  @doc false
  @spec fetch_target_delivery(String.t(), String.t()) :: {:ok, Delivery.t()} | {:noop, :not_found}
  def fetch_target_delivery(target_id, tenant_id)
      when is_binary(target_id) and is_binary(tenant_id) do
    case Repo.one(
           from(t in DeliveryTarget,
             join: d in assoc(t, :delivery),
             where:
               t.id == ^target_id and t.tenant_id == ^tenant_id and d.tenant_id == ^tenant_id,
             select: d
           )
         ) do
      %Delivery{} = delivery -> {:ok, delivery}
      nil -> {:noop, :not_found}
    end
  end

  @doc false
  def actionable_targets(%Delivery{id: delivery_id, tenant_id: tenant_id}) do
    Repo.all(
      from(t in DeliveryTarget,
        where:
          t.delivery_id == ^delivery_id and t.tenant_id == ^tenant_id and t.status == :pending,
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
    target_id = Keyword.get(opts, :target_id)

    Multi.new()
    |> Multi.run(:target, fn repo, _ ->
      target =
        case target_id do
          id when is_binary(id) ->
            repo.one(
              from(t in DeliveryTarget,
                where:
                  t.delivery_id == ^delivery.id and t.tenant_id == ^tenant_id and t.id == ^id and
                    (t.status == :pending or
                       (t.status == :claimed and t.lease_expires_at < ^now)),
                lock: "FOR UPDATE"
              )
            )

          nil ->
            repo.one(
              from(t in DeliveryTarget,
                where:
                  t.delivery_id == ^delivery.id and t.tenant_id == ^tenant_id and
                    (t.status == :pending or
                       (t.status == :claimed and t.lease_expires_at < ^now)),
                order_by: [asc: t.binding_revision_ref],
                limit: 1,
                lock: "FOR UPDATE"
              )
            )
        end

      case target do
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
      {prior_attempt_id, duplicate_risk} = redrive_link(target.claim_token)

      DeliveryTargetAttempt.changeset(%DeliveryTargetAttempt{}, %{
        tenant_id: tenant_id,
        delivery_target_id: target.id,
        attempt_number: attempt_number,
        outcome: :attempt_started,
        started_at: now,
        source: source,
        prior_attempt_id: prior_attempt_id,
        duplicate_risk: duplicate_risk,
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

  @doc false
  @spec close_stale_started_attempt(String.t(), String.t()) ::
          {:ok, %{target: DeliveryTarget.t(), attempt: DeliveryTargetAttempt.t()}}
          | {:noop, :not_found}
  def close_stale_started_attempt(target_id, tenant_id)
      when is_binary(target_id) and is_binary(tenant_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      target =
        Repo.one(
          from(t in DeliveryTarget,
            where:
              t.id == ^target_id and t.tenant_id == ^tenant_id and t.status == :claimed and
                t.lease_expires_at < ^now,
            lock: "FOR UPDATE"
          )
        )

      if is_nil(target), do: Repo.rollback(:not_found)

      attempt =
        Repo.one(
          from(a in DeliveryTargetAttempt,
            where:
              a.delivery_target_id == ^target.id and a.tenant_id == ^tenant_id and
                a.outcome == :attempt_started,
            order_by: [desc: a.attempt_number],
            limit: 1,
            lock: "FOR UPDATE"
          )
        )

      if is_nil(attempt), do: Repo.rollback(:not_found)

      updated_target =
        target
        |> Ecto.Changeset.change(status: :ambiguous_handoff, lease_expires_at: nil)
        |> Repo.update!()

      updated_attempt =
        attempt
        |> Ecto.Changeset.change(
          outcome: :ambiguous_handoff,
          finished_at: now,
          safe_facts: %{"provider_code" => "possible_provider_handoff"}
        )
        |> Repo.update!()

      {:ok, _delivery} =
        recompute_delivery(target.delivery_id |> get_delivery_for_target!(tenant_id), tenant_id)

      %{target: updated_target, attempt: updated_attempt}
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, :not_found} -> {:noop, :not_found}
    end
  end

  defp get_delivery_for_target!(delivery_id, tenant_id) do
    Repo.one!(from(d in Delivery, where: d.id == ^delivery_id and d.tenant_id == ^tenant_id))
  end

  @doc false
  @spec authorize_target_redrive(String.t(), String.t(), String.t()) ::
          {:ok, %{target: DeliveryTarget.t(), attempt: DeliveryTargetAttempt.t()}}
          | {:noop, :not_found}
  def authorize_target_redrive(target_id, tenant_id, "policy_authorized")
      when is_binary(target_id) and is_binary(tenant_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      target =
        Repo.one(
          from(t in DeliveryTarget,
            where:
              t.id == ^target_id and t.tenant_id == ^tenant_id and t.status == :ambiguous_handoff,
            lock: "FOR UPDATE"
          )
        )

      if is_nil(target), do: Repo.rollback(:not_found)

      prior =
        Repo.one(
          from(a in DeliveryTargetAttempt,
            where:
              a.delivery_target_id == ^target.id and a.tenant_id == ^tenant_id and
                a.outcome == :ambiguous_handoff,
            order_by: [desc: a.attempt_number],
            limit: 1,
            lock: "FOR UPDATE"
          )
        )

      if is_nil(prior) or
           Repo.exists?(from(a in DeliveryTargetAttempt, where: a.prior_attempt_id == ^prior.id)) do
        Repo.rollback(:not_found)
      end

      updated_target =
        target
        |> Ecto.Changeset.change(
          status: :pending,
          claimed_at: now,
          lease_expires_at: nil,
          claim_token: "redrive:" <> prior.id
        )
        |> Repo.update!()

      %{target: updated_target}
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, :not_found} -> {:noop, :not_found}
    end
  end

  def authorize_target_redrive(_, _, _), do: {:noop, :not_found}

  defp redrive_link("redrive:" <> prior_attempt_id), do: {prior_attempt_id, true}
  defp redrive_link(_claim_token), do: {nil, false}

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
      |> Multi.run(:delivery, fn _repo, _ -> recompute_delivery(delivery, delivery.tenant_id) end)
      |> Repo.transaction()
      |> case do
        {:ok, %{delivery: updated, target: updated_target, attempt: updated_attempt}} ->
          {:ok, %{delivery: updated, target: updated_target, attempt: updated_attempt}}

        {:error, _step, reason, _} ->
          {:error, reason}
      end
    end
  end

  @doc "Changes one tenant-qualified target back to pending and recomputes its parent."
  @spec schedule_retry(Delivery.t(), String.t(), keyword()) ::
          {:ok, DeliveryTarget.t()} | {:error, term()}
  def schedule_retry(%Delivery{} = delivery, target_id, opts \\ []) when is_binary(target_id),
    do: transition_target(delivery, target_id, :pending, opts)

  @doc "Marks one tenant-qualified target as expired and recomputes its parent."
  @spec expire_target(Delivery.t(), String.t(), keyword()) ::
          {:ok, DeliveryTarget.t()} | {:error, term()}
  def expire_target(%Delivery{} = delivery, target_id, opts \\ []) when is_binary(target_id),
    do: transition_target(delivery, target_id, :expired, opts)

  @doc "Marks one tenant-qualified target as invalidated and recomputes its parent."
  @spec invalidate_target(Delivery.t(), String.t(), keyword()) ::
          {:ok, DeliveryTarget.t()} | {:error, term()}
  def invalidate_target(%Delivery{} = delivery, target_id, opts \\ []) when is_binary(target_id),
    do: transition_target(delivery, target_id, :invalidated, opts)

  @doc "Marks one tenant-qualified target as retry-exhausted and recomputes its parent."
  @spec exhaust_target(Delivery.t(), String.t(), keyword()) ::
          {:ok, DeliveryTarget.t()} | {:error, term()}
  def exhaust_target(%Delivery{} = delivery, target_id, opts \\ []) when is_binary(target_id),
    do: transition_target(delivery, target_id, :retry_exhausted, opts)

  @doc "Derives the logical-delivery outcome from its tenant-scoped targets."
  @spec recompute_delivery(Delivery.t(), String.t()) :: {:ok, Delivery.t()} | {:error, term()}
  def recompute_delivery(%Delivery{id: delivery_id, tenant_id: tenant_id}, tenant_id) do
    Repo.transaction(fn ->
      delivery =
        Repo.one(
          from(d in Delivery,
            where: d.id == ^delivery_id and d.tenant_id == ^tenant_id,
            lock: "FOR UPDATE"
          )
        )

      if is_nil(delivery), do: Repo.rollback(:not_found)
      targets = authoritative_targets(delivery_id, tenant_id)
      aggregate = aggregate(targets)

      delivery
      |> Ecto.Changeset.change(%{
        metadata: Map.put(delivery.metadata || %{}, "target_aggregate", aggregate),
        status: aggregate_status(delivery.status, aggregate),
        suppression_reason: suppression_reason(delivery, aggregate)
      })
      |> Repo.update!()
    end)
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  def recompute_delivery(_, _), do: {:error, :tenant_mismatch}

  defp transition_target(%Delivery{tenant_id: tenant_id} = delivery, target_id, status, opts) do
    if Keyword.get(opts, :tenant_id, tenant_id) != tenant_id do
      {:error, :not_found}
    else
      Repo.transaction(fn ->
        target =
          Repo.one(
            from(t in DeliveryTarget,
              where:
                t.id == ^target_id and t.delivery_id == ^delivery.id and t.tenant_id == ^tenant_id,
              lock: "FOR UPDATE"
            )
          )

        if is_nil(target), do: Repo.rollback(:not_found)

        updated =
          target |> Ecto.Changeset.change(status: status, lease_expires_at: nil) |> Repo.update!()

        if status in @terminal_statuses do
          now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

          Repo.insert!(
            DeliveryTargetAttempt.changeset(%DeliveryTargetAttempt{}, %{
              tenant_id: tenant_id,
              delivery_target_id: target.id,
              attempt_number:
                Repo.aggregate(
                  from(a in DeliveryTargetAttempt, where: a.delivery_target_id == ^target.id),
                  :count,
                  :id
                ) + 1,
              outcome: status,
              started_at: now,
              finished_at: now,
              source: "lifecycle",
              safe_facts: %{}
            })
          )
        end

        {:ok, _delivery} = recompute_delivery(delivery, tenant_id)
        updated
      end)
      |> case do
        {:ok, target} -> {:ok, target}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp aggregate(targets) do
    target_count = length(targets)
    terminal_targets = Enum.filter(targets, &(&1.status in @terminal_statuses))
    accepted = Enum.count(targets, &(&1.status == :provider_accepted))

    %{
      "target_count" => target_count,
      "terminal_target_count" => length(terminal_targets),
      "provider_accepted_count" => accepted,
      "terminal_failure_count" => length(terminal_targets) - accepted,
      "partial_failure" => accepted > 0 and length(terminal_targets) > accepted,
      "all_targets_terminal" => target_count > 0 and length(terminal_targets) == target_count
    }
  end

  defp aggregate_status(_current_status, %{"target_count" => 0}), do: :suppressed
  defp aggregate_status(current_status, %{"all_targets_terminal" => false}), do: current_status

  defp aggregate_status(_current_status, %{"provider_accepted_count" => accepted})
       when accepted > 0, do: :succeeded

  defp aggregate_status(_current_status, _aggregate), do: :failed

  defp suppression_reason(_delivery, %{"target_count" => 0}), do: "no_eligible_targets"
  defp suppression_reason(delivery, _aggregate), do: delivery.suppression_reason
end
