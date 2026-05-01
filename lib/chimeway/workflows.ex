defmodule Chimeway.Workflows do
  @moduledoc "Persistence helpers for durable workflow definitions and ordered step rows."

  import Ecto.Query

  alias Ecto.Multi
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal

  alias Chimeway.Workflows.{
    WorkflowDefinition,
    WorkflowRun,
    WorkflowStep,
    WorkflowTransition
  }

  @active_state :active
  @trigger_context %{"source" => "trigger"}
  @workflow_started_reason "workflow_started"
  @step_activated_reason "step_activated"

  @spec upsert_definition(String.t(), Chimeway.Notifier.workflow_resolution()) ::
          {:ok, WorkflowDefinition.t()} | {:error, term()}
  def upsert_definition(notification_key, workflow)
      when is_binary(notification_key) and is_map(workflow) do
    Multi.new()
    |> Multi.run(:workflow_definition, fn repo, _changes ->
      ensure_definition(repo, notification_key, workflow)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workflow_definition: definition}} -> {:ok, preload_steps(Repo, definition)}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  @spec ensure_definition(Ecto.Repo.t(), String.t(), Chimeway.Notifier.workflow_resolution()) ::
          {:ok, WorkflowDefinition.t()} | {:error, term()}
  def ensure_definition(repo, notification_key, workflow)
      when is_binary(notification_key) and is_map(workflow) do
    definition_attrs = %{
      workflow_key: workflow.workflow_key,
      workflow_version: workflow.workflow_version,
      notification_key: notification_key
    }

    definition_changeset = WorkflowDefinition.changeset(%WorkflowDefinition{}, definition_attrs)

    with {:ok, _definition} <-
           repo.insert(definition_changeset,
             on_conflict: [
               set: [notification_key: notification_key, updated_at: DateTime.utc_now()]
             ],
             conflict_target: [:workflow_key, :workflow_version]
           ) do
      definition =
        repo.get_by!(WorkflowDefinition,
          workflow_key: workflow.workflow_key,
          workflow_version: workflow.workflow_version
        )
        |> then(&preload_steps(repo, &1))

      case definition.steps do
        [] ->
          with {:ok, _steps} <- insert_steps(repo, definition.id, workflow.steps) do
            {:ok, preload_steps(repo, definition)}
          end

        persisted_steps ->
          if same_steps?(persisted_steps, workflow.steps) do
            {:ok, definition}
          else
            {:error, :workflow_definition_version_conflict}
          end
      end
    end
  end

  @spec fetch_definition(String.t(), pos_integer()) ::
          {:ok, WorkflowDefinition.t() | nil} | {:error, term()}
  def fetch_definition(workflow_key, workflow_version)
      when is_binary(workflow_key) and is_integer(workflow_version) do
    {:ok,
     Repo.get_by(WorkflowDefinition,
       workflow_key: workflow_key,
       workflow_version: workflow_version
     )
     |> preload_steps(Repo)}
  end

  @spec persisted_workflow(Ecto.UUID.t() | map()) ::
          {:ok, Chimeway.Notifier.workflow_resolution() | nil} | {:error, term()}
  def persisted_workflow(%{workflow_definition_id: nil}), do: {:ok, nil}

  def persisted_workflow(%{workflow_definition_id: workflow_definition_id})
      when is_binary(workflow_definition_id) do
    persisted_workflow(workflow_definition_id)
  end

  def persisted_workflow(workflow_definition_id) when is_binary(workflow_definition_id) do
    case Repo.get(WorkflowDefinition, workflow_definition_id) |> then(&preload_steps(Repo, &1)) do
      nil ->
        {:ok, nil}

      definition ->
        {:ok,
         %{
           workflow_key: definition.workflow_key,
           workflow_version: definition.workflow_version,
           source: :planner_override,
           steps:
             Enum.map(definition.steps, fn step ->
               %{
                 step_key: step.step_key,
                 step_order: step.step_order,
                 channel: step.channel,
                 config: step.config || %{}
               }
             end)
         }}
    end
  end

  @spec active_step_linkage(Ecto.UUID.t() | map()) ::
          {:ok,
           %{
             workflow_run_id: Ecto.UUID.t(),
             workflow_step_id: Ecto.UUID.t(),
             channel: String.t()
           }
           | nil}
          | {:error, term()}
  def active_step_linkage(%{id: notification_id}) when is_binary(notification_id) do
    active_step_linkage(notification_id)
  end

  def active_step_linkage(notification_id) when is_binary(notification_id) do
    query =
      from(wr in WorkflowRun,
        join: ws in WorkflowStep,
        on: wr.current_step_id == ws.id,
        where: wr.notification_id == ^notification_id,
        select: %{
          workflow_run_id: wr.id,
          workflow_step_id: ws.id,
          channel: ws.channel
        }
      )

    {:ok, Repo.one(query)}
  end

  @spec create_initial_run(
          Ecto.Repo.t(),
          Ecto.UUID.t(),
          WorkflowDefinition.t(),
          DateTime.t(),
          String.t()
        ) :: {:ok, WorkflowRun.t()} | {:error, term()}
  def create_initial_run(
        repo,
        notification_id,
        %WorkflowDefinition{} = definition,
        timestamp,
        tenant_id
      )
      when is_binary(notification_id) and is_binary(tenant_id) do
    definition = preload_steps(repo, definition)

    with {:ok, first_step} <- fetch_first_step(definition),
         {:ok, workflow_run} <-
           repo.insert(
             WorkflowRun.changeset(%WorkflowRun{}, %{
               notification_id: notification_id,
               workflow_definition_id: definition.id,
               current_step_id: first_step.id,
               tenant_id: tenant_id,
               state: @active_state,
               started_at: timestamp,
               last_transition_at: timestamp,
               status_reason: @workflow_started_reason,
               status_context: @trigger_context
             })
           ),
         {:ok, _started_transition} <-
           insert_transition(repo, %{
             workflow_run_id: workflow_run.id,
             to_state: @active_state,
             reason: @workflow_started_reason,
             context: @trigger_context,
             inserted_at: timestamp
           }),
         {:ok, _activated_transition} <-
           insert_transition(repo, %{
             workflow_run_id: workflow_run.id,
             workflow_step_id: first_step.id,
             from_state: @active_state,
             to_state: @active_state,
             reason: @step_activated_reason,
             context: Map.put(@trigger_context, "step_key", first_step.step_key),
             inserted_at: timestamp
           }) do
      {:ok, workflow_run}
    end
  end

  @doc """
  Returns the canonical workflow_run row by id, raising if not found. Used by
  the progression service after locking the row inside its transaction.
  """
  @spec get_run!(Ecto.UUID.t()) :: WorkflowRun.t()
  def get_run!(workflow_run_id) when is_binary(workflow_run_id) do
    Repo.get!(WorkflowRun, workflow_run_id)
  end

  @doc """
  Locks a workflow run for update inside the given repo and returns it. Returns
  `{:error, :workflow_run_not_found}` if the row no longer exists. Must be
  invoked inside a transaction.
  """
  @spec lock_run(Ecto.Repo.t(), Ecto.UUID.t()) ::
          {:ok, WorkflowRun.t()} | {:error, :workflow_run_not_found}
  def lock_run(repo, workflow_run_id) when is_binary(workflow_run_id) do
    case repo.one(from(wr in WorkflowRun, where: wr.id == ^workflow_run_id, lock: "FOR UPDATE")) do
      nil -> {:error, :workflow_run_not_found}
      run -> {:ok, run}
    end
  end

  @doc """
  Returns the active workflow_step row for a workflow_run, raising if none.
  """
  @spec get_current_step!(WorkflowRun.t()) :: WorkflowStep.t()
  def get_current_step!(%WorkflowRun{current_step_id: current_step_id})
      when is_binary(current_step_id) do
    Repo.get!(WorkflowStep, current_step_id)
  end

  @doc """
  Looks up a workflow_step by step_key inside the same workflow definition.
  Returns `nil` if the step does not exist — callers treat this as a noop
  rather than crashing the progression transaction.
  """
  @spec fetch_step_by_key(Ecto.UUID.t(), String.t()) :: WorkflowStep.t() | nil
  def fetch_step_by_key(workflow_definition_id, step_key)
      when is_binary(workflow_definition_id) and is_binary(step_key) do
    Repo.one(
      from(ws in WorkflowStep,
        where: ws.workflow_definition_id == ^workflow_definition_id and ws.step_key == ^step_key
      )
    )
  end

  @doc """
  Appends one workflow_transition row using the supplied repo (so callers can
  participate in the progression transaction). Required keys: `workflow_run_id`,
  `to_state`, and `reason`. Optional keys: `workflow_step_id`, `delivery_id`,
  `from_state`, `context`, `inserted_at`.
  """
  @spec append_transition(Ecto.Repo.t(), map()) ::
          {:ok, WorkflowTransition.t()} | {:error, Ecto.Changeset.t()}
  def append_transition(repo, attrs) when is_map(attrs) do
    insert_transition(repo, attrs)
  end

  @doc """
  Updates a workflow run row with the supplied fields. Used by the progression
  service to record waiting state and reason/context, advance the current step
  cursor, or reactivate a previously waiting run.
  """
  @spec update_run(Ecto.Repo.t(), WorkflowRun.t(), map()) ::
          {:ok, WorkflowRun.t()} | {:error, Ecto.Changeset.t()}
  def update_run(repo, %WorkflowRun{} = run, attrs) when is_map(attrs) do
    run
    |> Ecto.Changeset.change(attrs)
    |> repo.update()
  end

  @doc """
  Returns the workflow run state for the given `tenant_id` and `execution_id`
  (the workflow run's primary key). The returned map includes the authoritative
  State Spine fields plus the current step key for operator-friendly inspection.

  Returns `{:error, :not_found}` if the run does not exist or belongs to a
  different tenant — preventing cross-tenant information disclosure (T-27-05).
  """
  @spec explain(String.t(), Ecto.UUID.t()) ::
          {:ok,
           %{
             id: Ecto.UUID.t(),
             tenant_id: String.t(),
             state: atom(),
             status_reason: String.t() | nil,
             current_step_name: String.t() | nil,
             suspended_until: DateTime.t() | nil,
             pending_signals: [String.t()],
             terminal_reason: String.t() | nil
           }}
          | {:error, :not_found}
  def explain(tenant_id, execution_id)
      when is_binary(tenant_id) and is_binary(execution_id) do
    query =
      from(wr in WorkflowRun,
        left_join: ws in WorkflowStep,
        on: wr.current_step_id == ws.id,
        where: wr.id == ^execution_id and wr.tenant_id == ^tenant_id,
        select: %{
          id: wr.id,
          tenant_id: wr.tenant_id,
          state: wr.state,
          status_reason: wr.status_reason,
          current_step_name: ws.step_key,
          suspended_until: wr.suspended_until,
          pending_signals: wr.pending_signals,
          terminal_reason: wr.terminal_reason
        }
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      result -> {:ok, result}
    end
  end

  @doc """
  Returns the structural `WorkflowTransition` records for a given execution,
  strictly scoped to the supplied `tenant_id`.

  Trace context intentionally contains only structural progression metadata
  (e.g., `event_name`, `step_key`). Raw signal payloads are never written to
  transition context, making this surface payload-safe by construction (T-27-04).

  Returns `{:error, :not_found}` if the workflow run does not exist or belongs
  to a different tenant.

  Opts:
    - `:limit` — max number of traces to return (default: all)
  """
  @spec list_traces(String.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, [WorkflowTransition.t()]} | {:error, :not_found}
  def list_traces(tenant_id, execution_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(execution_id) do
    # First confirm the run exists and belongs to this tenant (T-27-04 / T-27-05)
    run_query =
      from(wr in WorkflowRun,
        where: wr.id == ^execution_id and wr.tenant_id == ^tenant_id,
        select: wr.id
      )

    case Repo.one(run_query) do
      nil ->
        {:error, :not_found}

      _run_id ->
        traces_query =
          from(wt in WorkflowTransition,
            where: wt.workflow_run_id == ^execution_id,
            order_by: [asc: wt.inserted_at]
          )

        traces_query =
          case Keyword.get(opts, :limit) do
            limit when is_integer(limit) and limit >= 0 -> from(wt in traces_query, limit: ^limit)
            _ -> traces_query
          end

        traces = Repo.all(traces_query)

        {:ok, traces}
    end
  end

  @doc """
  Routes an incoming signal to all waiting workflow runs for the same tenant
  whose `pending_signals` list contains the signal's `event_name`.

  For each matched run the function:
    1. Transitions the run from `:waiting` to `:active` and clears `pending_signals`.
    2. Appends an immutable `WorkflowTransition` recording the `event_name` (but
       **not** the raw payload — payload safety is enforced here per the threat
       model requirement T-27-03).

  All mutations per run are wrapped in one `Ecto.Multi` transaction so the state
  update and the trace record are always atomically consistent.

  Cross-tenant isolation is enforced structurally: the query always filters by
  `tenant_id = ^signal.tenant_id`, making it structurally impossible for a signal
  from one tenant to resume a run belonging to another.

  Returns `{:ok, results_map}` where `results_map` contains per-run outcomes keyed
  by `{:run_updated, run.id}` and `{:transition_inserted, run.id}`.
  """
  @spec route_signal(Signal.t()) :: {:ok, map()} | {:error, term()}
  def route_signal(
        %Signal{tenant_id: tenant_id, event_name: event_name, actor_id: actor_id} = signal
      )
      when is_binary(tenant_id) and is_binary(event_name) and is_binary(actor_id) do
    Repo.transaction(fn ->
      matched_runs = find_runs_waiting_for_signal(tenant_id, actor_id, event_name)

      now = DateTime.utc_now()

      Enum.reduce_while(matched_runs, %{}, fn run, acc ->
        with {:ok, updated_run} <-
               update_run(Repo, run, %{
                 state: :active,
                 pending_signals: [],
                 status_reason: "signal_received",
                 last_transition_at: now,
                 suspended_until: nil
               }),
             {:ok, transition} <-
               append_transition(Repo, %{
                 workflow_run_id: run.id,
                 from_state: :waiting,
                 to_state: :active,
                 reason: "signal_received",
                 context: %{"event_name" => event_name},
                 delivery_id: Map.get(signal.payload, "delivery_id"),
                 inserted_at: now
               }) do
          {:cont,
           acc
           |> Map.put({:run_updated, run.id}, updated_run)
           |> Map.put({:transition_inserted, run.id}, transition)}
        else
          {:error, reason} -> {:halt, Repo.rollback(reason)}
        end
      end)
    end)
  end

  # Finds all WorkflowRun rows that are:
  #   - owned by the given tenant and actor_id (cross-tenant isolation, T-27-03, T-27-07-01)
  #   - currently in the :waiting state
  #   - have the given event_name present in their pending_signals array
  defp find_runs_waiting_for_signal(tenant_id, actor_id, event_name) do
    Repo.all(
      from(wr in WorkflowRun,
        join: n in Chimeway.Notifications.Notification,
        on: wr.notification_id == n.id,
        where:
          wr.tenant_id == ^tenant_id and
            n.recipient_identity == ^actor_id and
            wr.state == :waiting and
            ^event_name in wr.pending_signals,
        lock: "FOR UPDATE",
        select: wr
      )
    )
  end

  defp preload_steps(_repo, nil), do: nil

  defp preload_steps(repo, definition) do
    repo.preload(
      definition,
      [steps: from(step in WorkflowStep, order_by: [asc: step.step_order])],
      force: true
    )
  end

  defp insert_steps(repo, workflow_definition_id, step_attrs) do
    Enum.reduce_while(step_attrs, {:ok, []}, fn step_attr, {:ok, inserted_steps} ->
      attrs = Map.put(step_attr, :workflow_definition_id, workflow_definition_id)

      case repo.insert(WorkflowStep.changeset(%WorkflowStep{}, attrs)) do
        {:ok, step} -> {:cont, {:ok, [step | inserted_steps]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted_steps} -> {:ok, Enum.reverse(inserted_steps)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_first_step(%WorkflowDefinition{steps: [first_step | _rest]}), do: {:ok, first_step}

  defp fetch_first_step(%WorkflowDefinition{steps: []}),
    do: {:error, :workflow_definition_missing_steps}

  defp insert_transition(repo, attrs) do
    repo.insert(WorkflowTransition.changeset(%WorkflowTransition{}, attrs))
  end

  defp same_steps?(persisted_steps, workflow_steps) do
    normalize_persisted_steps(persisted_steps) == normalize_workflow_steps(workflow_steps)
  end

  defp normalize_persisted_steps(steps) do
    steps
    |> Enum.map(fn step ->
      %{
        step_key: step.step_key,
        step_order: step.step_order,
        channel: step.channel,
        config: step.config || %{}
      }
    end)
    |> Enum.sort_by(& &1.step_order)
  end

  defp normalize_workflow_steps(steps) do
    steps
    |> Enum.map(fn step ->
      %{
        step_key: step.step_key,
        step_order: step.step_order,
        channel: step.channel,
        config: Map.get(step, :config) || Map.get(step, "config") || %{}
      }
    end)
    |> Enum.sort_by(& &1.step_order)
  end
end
