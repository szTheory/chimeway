defmodule Chimeway.Notifier do
  @moduledoc """
  Behaviour contract for notification definitions.

  ## Delayed fallback channels

  `delayed_fallback_channels/2` lets notifiers mark outbound channels as delayed
  fallback candidates. Returned channels must be a subset of `channels/2` output
  and must never include `:in_app`.

  ## Workflow progress rules — `temporary_failure` early-fire warning

  `temporary_failure` resolves from a `delivery.status == :failed` row. The
  `:failed` status is **NOT** terminal — `Chimeway.Deliveries`'s
  `@allowed_transitions` permits `failed: [:dispatched]`, which is the path
  Oban uses while a delivery is still being retried. A notifier authoring:

      %{"kind" => "on_outcome", "outcome" => "temporary_failure", "to_step" => "email"}

  will therefore fire the destination step on the **FIRST** transient
  `:failed` row written by `Chimeway.Deliveries.record_attempt/2`, BEFORE any
  retry has been attempted. The original delivery may still succeed on a
  later Oban attempt, in which case the host application will see BOTH a
  successful primary delivery AND the destination-step delivery for the same
  notification — the duplicate-side-effect outcome the workflow exists to
  prevent.

  If the intended semantics are "fire after retries are exhausted", use
  `retries_exhausted` (which resolves only from `:cancelled` +
  `suppression_reason == "retries_exhausted"` — i.e., a guaranteed-terminal
  row). If the intended semantics ARE "fire immediately on the first failure
  so we can try a different channel while the original retries" (a
  legitimate use case), pair the destination step's notifier with an
  idempotency key (e.g., `Chimeway.trigger/3`'s `idempotency_key` argument
  combined with a stable per-notification key in
  `metadata["notification_key"]`) so the host application can collapse the
  primary success and the early-fire escalation to one user-visible
  delivery if both fire.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Chimeway.Notifier
    end
  end

  @callback notification_key() :: String.t()
  @callback version() :: pos_integer()
  @callback recipients(map()) :: {:ok, [map()]} | {:error, term()}
  @callback build(map(), map()) :: {:ok, map()} | {:error, term()}
  @callback channels(map(), map()) :: {:ok, [atom() | String.t()]} | {:error, term()}
  @callback rendering(map(), map()) :: {:ok, map()} | {:error, term()}
  @callback delayed_fallback_channels(map(), map()) ::
              {:ok, [atom() | String.t()]} | {:error, term()}
  @callback orchestration(map(), map()) ::
              {:ok, :immediate | :digest | :digest_held | keyword(atom()) | map()}
              | {:error, term()}
  @callback workflow(map(), map()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks channels: 2
  @optional_callbacks rendering: 2
  @optional_callbacks delayed_fallback_channels: 2
  @optional_callbacks orchestration: 2
  @optional_callbacks workflow: 2

  @spec validate_module!(module()) :: :ok | {:error, term()}
  def validate_module!(module) when is_atom(module) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, :notifier_not_loaded}

      not function_exported?(module, :notification_key, 0) ->
        {:error, :missing_notification_key_callback}

      not function_exported?(module, :version, 0) ->
        {:error, :missing_version_callback}

      not function_exported?(module, :recipients, 1) ->
        {:error, :missing_recipients_callback}

      not function_exported?(module, :build, 2) ->
        {:error, :missing_build_callback}

      true ->
        :ok
    end
  end

  def validate_module!(_module), do: {:error, :invalid_notifier_module}

  @type orchestration_mode :: :immediate | :digest_held
  @type orchestration_resolution :: %{
          default: orchestration_mode(),
          channels: %{String.t() => orchestration_mode()},
          default_digest_key: String.t() | nil,
          digest_keys: %{String.t() => String.t()},
          source: :default | :notifier | :planner_override
        }
  @type workflow_step_resolution :: %{
          step_key: String.t(),
          step_order: pos_integer(),
          channel: String.t(),
          config: map()
        }
  @type workflow_resolution :: %{
          workflow_key: String.t(),
          workflow_version: pos_integer(),
          steps: [workflow_step_resolution()],
          source: :notifier | :planner_override
        }

  @spec resolve_orchestration(module() | nil, map(), map(), term()) ::
          {:ok, orchestration_resolution()} | {:error, term()}
  def resolve_orchestration(notifier, trigger_params, recipient, override \\ :unset)

  def resolve_orchestration(_notifier, _trigger_params, _recipient, override)
      when override != :unset do
    normalize_orchestration(override, :planner_override)
  end

  def resolve_orchestration(nil, _trigger_params, _recipient, _override) do
    {:ok,
     %{
       default: :immediate,
       channels: %{},
       default_digest_key: nil,
       digest_keys: %{},
       source: :default
     }}
  end

  def resolve_orchestration(notifier, trigger_params, recipient, _override)
      when is_atom(notifier) do
    if function_exported?(notifier, :orchestration, 2) do
      notifier
      |> apply(:orchestration, [trigger_params, recipient])
      |> handle_orchestration_result(:notifier)
    else
      {:ok,
       %{
         default: :immediate,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: :default
       }}
    end
  end

  defp handle_orchestration_result({:ok, declaration}, source),
    do: normalize_orchestration(declaration, source)

  defp handle_orchestration_result({:error, reason}, _source),
    do: {:error, {:orchestration_resolution_failed, reason}}

  defp handle_orchestration_result(unexpected, _source),
    do: {:error, {:orchestration_resolution_failed, {:unexpected_result, unexpected}}}

  defp normalize_orchestration(:immediate, source),
    do:
      {:ok,
       %{
         default: :immediate,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(:digest, source),
    do:
      {:ok,
       %{
         default: :digest_held,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(:digest_held, source),
    do:
      {:ok,
       %{
         default: :digest_held,
         channels: %{},
         default_digest_key: nil,
         digest_keys: %{},
         source: source
       }}

  defp normalize_orchestration(declaration, source) when is_list(declaration) do
    declaration
    |> Enum.into(%{})
    |> normalize_orchestration(source)
  end

  defp normalize_orchestration(%{} = declaration, source) do
    {default, channel_entries} =
      case Map.pop(declaration, :default) do
        {nil, rest} -> Map.pop(rest, "default", :immediate)
        result -> result
      end

    with {:ok, {normalized_default, default_digest_key}} <- normalize_mode(default),
         {:ok, {normalized_channels, digest_keys}} <- normalize_channel_modes(channel_entries) do
      {:ok,
       %{
         default: normalized_default,
         channels: normalized_channels,
         default_digest_key: default_digest_key,
         digest_keys: digest_keys,
         source: source
       }}
    end
  end

  defp normalize_orchestration(other, _source),
    do: {:error, {:invalid_orchestration_declaration, other}}

  defp normalize_channel_modes(entries) do
    Enum.reduce_while(entries, {:ok, {%{}, %{}}}, fn {channel, mode}, {:ok, acc} ->
      with {:ok, normalized_channel} <- normalize_channel(channel),
           {:ok, {normalized_mode, digest_key}} <- normalize_mode(mode) do
        {channels, digest_keys} = acc

        {:cont,
         {:ok,
          {Map.put(channels, normalized_channel, normalized_mode), digest_keys}
          |> maybe_put_digest_key(normalized_channel, digest_key)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp maybe_put_digest_key({channels, digest_keys}, _channel, nil), do: {channels, digest_keys}

  defp maybe_put_digest_key({channels, digest_keys}, channel, digest_key) do
    {channels, Map.put(digest_keys, channel, digest_key)}
  end

  defp normalize_channel(channel) when is_atom(channel), do: {:ok, Atom.to_string(channel)}

  defp normalize_channel(channel) when is_binary(channel) do
    normalized_channel = String.trim(channel)

    if normalized_channel == "" do
      {:error, {:invalid_orchestration_channel, channel}}
    else
      {:ok, normalized_channel}
    end
  end

  defp normalize_channel(channel), do: {:error, {:invalid_orchestration_channel, channel}}

  defp normalize_mode({mode, opts}) when mode in [:digest, :digest_held] and is_list(opts) do
    with {:ok, digest_key} <- normalize_digest_key(Keyword.get(opts, :digest_key)) do
      {:ok, {:digest_held, digest_key}}
    end
  end

  defp normalize_mode(:immediate), do: {:ok, {:immediate, nil}}
  defp normalize_mode(:digest), do: {:ok, {:digest_held, nil}}
  defp normalize_mode(:digest_held), do: {:ok, {:digest_held, nil}}
  defp normalize_mode("immediate"), do: {:ok, {:immediate, nil}}
  defp normalize_mode("digest"), do: {:ok, {:digest_held, nil}}
  defp normalize_mode("digest_held"), do: {:ok, {:digest_held, nil}}
  defp normalize_mode(mode), do: {:error, {:invalid_orchestration_mode, mode}}

  defp normalize_digest_key(nil), do: {:ok, nil}

  defp normalize_digest_key(digest_key) when is_binary(digest_key) do
    normalized_digest_key = String.trim(digest_key)

    if normalized_digest_key == "" do
      {:error, {:invalid_digest_key, digest_key}}
    else
      {:ok, normalized_digest_key}
    end
  end

  defp normalize_digest_key(digest_key), do: {:error, {:invalid_digest_key, digest_key}}

  @spec serialize_orchestration(orchestration_resolution()) :: map()
  def serialize_orchestration(orchestration) when is_map(orchestration) do
    %{
      "default" => orchestration.default |> Atom.to_string(),
      "channels" =>
        orchestration.channels
        |> Enum.into(%{}, fn {channel, mode} -> {channel, Atom.to_string(mode)} end),
      "default_digest_key" => Map.get(orchestration, :default_digest_key),
      "digest_keys" => Map.get(orchestration, :digest_keys, %{}),
      "source" => orchestration.source |> Atom.to_string()
    }
  end

  def persisted_orchestration_override(%{} = persisted) do
    if persisted_orchestration_snapshot?(persisted) do
      channels =
        persisted
        |> Map.get("channels", Map.get(persisted, :channels, %{}))
        |> Enum.into(%{})

      digest_keys =
        persisted
        |> Map.get("digest_keys", Map.get(persisted, :digest_keys, %{}))
        |> Enum.into(%{})

      default_digest_key =
        Map.get(persisted, "default_digest_key", Map.get(persisted, :default_digest_key))

      persisted
      |> Map.get("default", Map.get(persisted, :default, "immediate"))
      |> then(&Map.put(channels, "default", &1))
      |> maybe_put_default_digest_key(default_digest_key)
      |> then(fn override ->
        Enum.reduce(digest_keys, override, fn {channel, digest_key}, acc ->
          Map.put(acc, channel, {:digest_held, [digest_key: digest_key]})
        end)
      end)
    else
      persisted
    end
  end

  def persisted_orchestration_override(other), do: other

  defp maybe_put_default_digest_key(channels, nil), do: channels

  defp maybe_put_default_digest_key(channels, digest_key) do
    Map.put(channels, "default", {:digest_held, [digest_key: digest_key]})
  end

  defp persisted_orchestration_snapshot?(persisted) do
    Map.has_key?(persisted, "channels") or
      Map.has_key?(persisted, :channels) or
      Map.has_key?(persisted, "digest_keys") or
      Map.has_key?(persisted, :digest_keys) or
      Map.has_key?(persisted, "source") or
      Map.has_key?(persisted, :source)
  end

  @spec resolve_workflow(module() | nil, map(), map(), term()) ::
          {:ok, workflow_resolution() | nil} | {:error, term()}
  def resolve_workflow(notifier, trigger_params, recipient, override \\ :unset)

  def resolve_workflow(_notifier, _trigger_params, _recipient, override)
      when override != :unset do
    normalize_workflow_declaration(override)
  end

  def resolve_workflow(nil, _trigger_params, _recipient, _override), do: {:ok, nil}

  def resolve_workflow(notifier, trigger_params, recipient, _override) when is_atom(notifier) do
    if function_exported?(notifier, :workflow, 2) do
      notifier
      |> apply(:workflow, [trigger_params, recipient])
      |> handle_workflow_result()
    else
      {:ok, nil}
    end
  end

  @spec normalize_workflow_declaration(map()) :: {:ok, workflow_resolution()} | {:error, term()}
  def normalize_workflow_declaration(%{} = declaration) do
    workflow_key = Map.get(declaration, :workflow_key, Map.get(declaration, "workflow_key"))

    workflow_version =
      Map.get(declaration, :workflow_version, Map.get(declaration, "workflow_version"))

    steps = Map.get(declaration, :steps, Map.get(declaration, "steps"))
    source = Map.get(declaration, :source, Map.get(declaration, "source", :notifier))

    with :ok <- require_workflow_fields(workflow_key, workflow_version, steps),
         {:ok, normalized_source} <- normalize_workflow_source(source),
         {:ok, normalized_workflow_key} <- normalize_workflow_key(workflow_key),
         {:ok, normalized_workflow_version} <- normalize_workflow_version(workflow_version),
         {:ok, normalized_steps} <- normalize_workflow_steps(steps) do
      {:ok,
       %{
         workflow_key: normalized_workflow_key,
         workflow_version: normalized_workflow_version,
         steps: normalized_steps,
         source: normalized_source
       }}
    else
      :error ->
        {:error, {:workflow_resolution_failed, {:invalid_workflow_declaration, declaration}}}

      {:error, reason} ->
        {:error, {:workflow_resolution_failed, reason}}
    end
  end

  def normalize_workflow_declaration(other),
    do: {:error, {:workflow_resolution_failed, {:invalid_workflow_declaration, other}}}

  @spec serialize_workflow(workflow_resolution()) :: map()
  def serialize_workflow(workflow) when is_map(workflow) do
    %{
      "workflow_key" => workflow.workflow_key,
      "workflow_version" => workflow.workflow_version,
      "steps" =>
        Enum.map(workflow.steps, fn step ->
          %{
            "step_key" => step.step_key,
            "step_order" => step.step_order,
            "channel" => step.channel,
            "config" => step.config
          }
        end),
      "source" => Atom.to_string(workflow.source)
    }
  end

  def persisted_workflow_override(%{} = persisted), do: persisted
  def persisted_workflow_override(other), do: other

  @spec resolve_rendering(module(), map(), map()) ::
          {:ok, Chimeway.Rendering.rendering_declaration()} | {:error, term()}
  def resolve_rendering(notifier, trigger_params, recipient) when is_atom(notifier) do
    Chimeway.Rendering.resolve_declaration(notifier, trigger_params, recipient)
  end

  defp handle_workflow_result({:ok, declaration}), do: normalize_workflow_declaration(declaration)

  defp handle_workflow_result({:error, reason}),
    do: {:error, {:workflow_resolution_failed, reason}}

  defp handle_workflow_result(unexpected),
    do: {:error, {:workflow_resolution_failed, {:unexpected_result, unexpected}}}

  defp require_workflow_fields(nil, _workflow_version, _steps), do: :error
  defp require_workflow_fields(_workflow_key, nil, _steps), do: :error

  defp require_workflow_fields(_workflow_key, _workflow_version, steps) when is_list(steps),
    do: :ok

  defp require_workflow_fields(_workflow_key, _workflow_version, _steps), do: :error

  defp normalize_workflow_source(source) when source in [:notifier, :planner_override],
    do: {:ok, source}

  defp normalize_workflow_source("notifier"), do: {:ok, :notifier}
  defp normalize_workflow_source("planner_override"), do: {:ok, :planner_override}
  defp normalize_workflow_source(source), do: {:error, {:invalid_workflow_source, source}}

  defp normalize_workflow_key(workflow_key) when is_binary(workflow_key) do
    normalized_workflow_key = String.trim(workflow_key)

    if normalized_workflow_key == "" do
      {:error, {:blank_workflow_key, workflow_key}}
    else
      {:ok, normalized_workflow_key}
    end
  end

  defp normalize_workflow_key(workflow_key),
    do: {:error, {:blank_workflow_key, workflow_key}}

  defp normalize_workflow_version(workflow_version)
       when is_integer(workflow_version) and workflow_version > 0,
       do: {:ok, workflow_version}

  defp normalize_workflow_version(workflow_version),
    do: {:error, {:invalid_workflow_version, workflow_version}}

  defp normalize_workflow_steps([_ | _] = steps) do
    with {:ok, normalized_steps} <- normalize_workflow_step_list(steps),
         :ok <- validate_unique_workflow_step_keys(normalized_steps),
         :ok <- validate_unique_workflow_step_orders(normalized_steps),
         :ok <- validate_sequential_workflow_step_orders(normalized_steps) do
      {:ok, Enum.sort_by(normalized_steps, & &1.step_order)}
    end
  end

  defp normalize_workflow_steps(steps) when is_list(steps),
    do: {:error, {:invalid_workflow_steps, steps}}

  defp normalize_workflow_steps(other), do: {:error, {:invalid_workflow_steps, other}}

  defp normalize_workflow_step_list(steps) do
    Enum.reduce_while(steps, {:ok, []}, fn step, {:ok, acc} ->
      case normalize_workflow_step(step) do
        {:ok, normalized_step} -> {:cont, {:ok, [normalized_step | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized_steps} -> {:ok, Enum.reverse(normalized_steps)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_workflow_step(%{} = step) do
    step_key = Map.get(step, :step_key, Map.get(step, "step_key"))
    step_order = Map.get(step, :step_order, Map.get(step, "step_order"))
    channel = Map.get(step, :channel, Map.get(step, "channel"))
    config = Map.get(step, :config, Map.get(step, "config", %{}))

    with {:ok, normalized_step_key} <- normalize_workflow_step_key(step_key),
         {:ok, normalized_step_order} <- normalize_workflow_step_order(step_order),
         {:ok, normalized_channel} <- normalize_workflow_channel(channel),
         {:ok, normalized_config} <- normalize_workflow_config(config) do
      {:ok,
       %{
         step_key: normalized_step_key,
         step_order: normalized_step_order,
         channel: normalized_channel,
         config: normalized_config
       }}
    end
  end

  defp normalize_workflow_step(step), do: {:error, {:invalid_workflow_step, step}}

  defp normalize_workflow_step_key(step_key) when is_binary(step_key) do
    normalized_step_key = String.trim(step_key)

    if normalized_step_key == "" do
      {:error, {:invalid_workflow_step_key, step_key}}
    else
      {:ok, normalized_step_key}
    end
  end

  defp normalize_workflow_step_key(step_key),
    do: {:error, {:invalid_workflow_step_key, step_key}}

  defp normalize_workflow_step_order(step_order)
       when is_integer(step_order) and step_order > 0,
       do: {:ok, step_order}

  defp normalize_workflow_step_order(step_order),
    do: {:error, {:invalid_workflow_step_order, step_order}}

  defp normalize_workflow_channel(channel) when is_atom(channel),
    do: {:ok, Atom.to_string(channel)}

  defp normalize_workflow_channel(channel) when is_binary(channel) do
    normalized_channel = String.trim(channel)

    if normalized_channel == "" do
      {:error, {:invalid_workflow_channel, channel}}
    else
      {:ok, normalized_channel}
    end
  end

  defp normalize_workflow_channel(channel),
    do: {:error, {:invalid_workflow_channel, channel}}

  defp normalize_workflow_config(config) when is_map(config) do
    progress = Map.get(config, "progress", Map.get(config, :progress, :unset))

    case progress do
      :unset ->
        {:ok, config}

      rules when is_list(rules) ->
        with {:ok, normalized_rules} <- normalize_workflow_progress_rules(rules) do
          # Persist progress under the durable string key only — replay-safe
          # serialization should not have to decide between atom and string keys
          # later (D-08).
          updated_config =
            config
            |> Map.delete(:progress)
            |> Map.put("progress", normalized_rules)

          {:ok, updated_config}
        end

      other ->
        {:error, {:invalid_workflow_progress_rules, other}}
    end
  end

  defp normalize_workflow_config(config), do: {:error, {:invalid_workflow_config, config}}

  # Curated workflow-outcome vocabulary (D-04). Mirrors the values returned by
  # `Chimeway.Workflows.ProgressionOutcome.from_delivery/2` so authoring rules
  # at declaration time and runtime branch resolution share one stable set.
  #
  # ## Early-fire warning for `temporary_failure` (WR-02)
  #
  # `temporary_failure` resolves from a `delivery.status == :failed` row. The
  # `:failed` status is **NOT** terminal — `Chimeway.Deliveries`'s
  # `@allowed_transitions` permits `failed: [:dispatched]`, which is the path
  # Oban uses while a delivery is still being retried. A notifier authoring:
  #
  #     %{"kind" => "on_outcome", "outcome" => "temporary_failure", "to_step" => "email"}
  #
  # will therefore fire the destination step on the **FIRST** transient
  # `:failed` row written by `Chimeway.Deliveries.record_attempt/2`, BEFORE any
  # retry has been attempted. The original delivery may still succeed on a
  # later Oban attempt, in which case the host application will see BOTH a
  # successful primary delivery AND the destination-step delivery for the same
  # notification — the duplicate-side-effect outcome the workflow exists to
  # prevent.
  #
  # If the intended semantics are "fire after retries are exhausted", use
  # `retries_exhausted` (which resolves only from `:cancelled` +
  # `suppression_reason == "retries_exhausted"` — i.e., a guaranteed-terminal
  # row). If the intended semantics ARE "fire immediately on the first failure
  # so we can try a different channel while the original retries" (a
  # legitimate use case), pair the destination step's notifier with an
  # idempotency key (e.g., `Chimeway.trigger/3`'s `idempotency_key` argument
  # combined with a stable per-notification key in
  # `metadata["notification_key"]`) so the host application can collapse the
  # primary success and the early-fire escalation to one user-visible
  # delivery if both fire.
  #
  # See `Chimeway.Workflows.ProgressionOutcome` moduledoc for the
  # canonical mapping clause and the same warning at the runtime translation
  # site.
  @progress_outcomes ~w(delivered suppressed temporary_failure retries_exhausted permanent_failure bounced)

  # Per D-01 only one wait anchor is supported in Phase 25: the prior
  # delivery's terminal_at timestamp. Other anchors are reserved for later
  # phases and must fail normalization rather than silently no-op at runtime.
  @progress_wait_anchors ~w(prior_delivery_terminal_at)
  @max_cancel_signals 10

  defp normalize_workflow_progress_rules(rules) do
    rules
    |> Enum.reduce_while({:ok, []}, fn rule, {:ok, acc} ->
      case normalize_workflow_progress_rule(rule) do
        {:ok, normalized_rule} ->
          {:cont, {:ok, [normalized_rule | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_workflow_progress_rule, reason}}}
      end
    end)
    |> case do
      {:ok, normalized_rules} -> {:ok, Enum.reverse(normalized_rules)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_workflow_progress_rule(%{} = rule) do
    kind = Map.get(rule, "kind", Map.get(rule, :kind))

    case kind do
      "wait_until" -> normalize_wait_until_rule(rule)
      "on_outcome" -> normalize_on_outcome_rule(rule)
      "stop" -> normalize_stop_rule(rule)
      other -> {:error, {:unknown_rule_kind, other}}
    end
  end

  defp normalize_workflow_progress_rule(other),
    do: {:error, {:invalid_progress_rule_shape, other}}

  defp normalize_wait_until_rule(%{} = rule) do
    # `wait_until` rules carry anchor + delay_seconds + to_step, with optional
    # `cancel_signals`. Mixing in an `outcome` (or any other key) is rejected so
    # the persisted DSL stays one rule-shape per kind per D-06/D-08.
    case extra_keys(rule, ~w(kind anchor delay_seconds to_step cancel_signals)) do
      [] ->
        anchor = Map.get(rule, "anchor", Map.get(rule, :anchor))
        delay_seconds = Map.get(rule, "delay_seconds", Map.get(rule, :delay_seconds))
        to_step = Map.get(rule, "to_step", Map.get(rule, :to_step))

        cancel_signals_raw =
          cond do
            Map.has_key?(rule, "cancel_signals") -> Map.get(rule, "cancel_signals")
            Map.has_key?(rule, :cancel_signals) -> Map.get(rule, :cancel_signals)
            true -> :unset
          end

        with {:ok, normalized_anchor} <- normalize_progress_anchor(anchor),
             {:ok, normalized_delay} <- normalize_progress_delay_seconds(delay_seconds),
             {:ok, normalized_to_step} <- normalize_progress_to_step(to_step),
             {:ok, normalized_cancel_signals} <- normalize_cancel_signals(cancel_signals_raw) do
          base = %{
            "kind" => "wait_until",
            "anchor" => normalized_anchor,
            "delay_seconds" => normalized_delay,
            "to_step" => normalized_to_step
          }

          output =
            if normalized_cancel_signals == [] do
              base
            else
              Map.put(base, "cancel_signals", normalized_cancel_signals)
            end

          {:ok, output}
        end

      extra ->
        {:error, {:mixed_rule_shape, extra}}
    end
  end

  defp normalize_cancel_signals(:unset), do: {:ok, []}

  defp normalize_cancel_signals(signals) when is_list(signals) do
    signals
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case normalize_cancel_signal_entry(entry) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized_list} ->
        normalized_list = normalized_list |> Enum.reverse() |> Enum.uniq()

        if length(normalized_list) > @max_cancel_signals do
          {:error, {:invalid_cancel_signals, {:too_many, length(normalized_list)}}}
        else
          {:ok, normalized_list}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_cancel_signals(other),
    do: {:error, {:invalid_cancel_signals, {:not_a_list, other}}}

  defp normalize_cancel_signal_entry(entry) when is_binary(entry) do
    normalized = String.trim(entry)

    if normalized == "" do
      {:error, {:invalid_cancel_signals, {:blank_entry, entry}}}
    else
      {:ok, normalized}
    end
  end

  defp normalize_cancel_signal_entry(entry),
    do: {:error, {:invalid_cancel_signals, {:invalid_type, entry}}}

  defp normalize_on_outcome_rule(%{} = rule) do
    case extra_keys(rule, ~w(kind outcome to_step)) do
      [] ->
        outcome = Map.get(rule, "outcome", Map.get(rule, :outcome))
        to_step = Map.get(rule, "to_step", Map.get(rule, :to_step))

        with {:ok, normalized_outcome} <- normalize_progress_outcome(outcome),
             {:ok, normalized_to_step} <- normalize_progress_to_step(to_step) do
          {:ok,
           %{
             "kind" => "on_outcome",
             "outcome" => normalized_outcome,
             "to_step" => normalized_to_step
           }}
        end

      extra ->
        {:error, {:mixed_rule_shape, extra}}
    end
  end

  defp normalize_stop_rule(%{} = rule) do
    case extra_keys(rule, ~w(kind outcome)) do
      [] ->
        outcome = Map.get(rule, "outcome", Map.get(rule, :outcome))

        with {:ok, normalized_outcome} <- normalize_progress_outcome(outcome) do
          {:ok,
           %{
             "kind" => "stop",
             "outcome" => normalized_outcome
           }}
        end

      extra ->
        {:error, {:mixed_rule_shape, extra}}
    end
  end

  defp extra_keys(%{} = rule, allowed) do
    rule
    |> Enum.reduce([], fn {key, _value}, acc ->
      key_string = to_string_key(key)

      if key_string in allowed do
        acc
      else
        [key_string | acc]
      end
    end)
    |> Enum.sort()
  end

  defp to_string_key(key) when is_binary(key), do: key
  defp to_string_key(key) when is_atom(key), do: Atom.to_string(key)
  defp to_string_key(key), do: inspect(key)

  defp normalize_progress_anchor(anchor) when anchor in @progress_wait_anchors,
    do: {:ok, anchor}

  defp normalize_progress_anchor(anchor) when is_atom(anchor) and not is_nil(anchor) do
    normalize_progress_anchor(Atom.to_string(anchor))
  end

  defp normalize_progress_anchor(anchor), do: {:error, {:invalid_anchor, anchor}}

  defp normalize_progress_outcome(outcome) when outcome in @progress_outcomes,
    do: {:ok, outcome}

  defp normalize_progress_outcome(outcome) when is_atom(outcome) and not is_nil(outcome) do
    normalize_progress_outcome(Atom.to_string(outcome))
  end

  defp normalize_progress_outcome(outcome), do: {:error, {:invalid_outcome, outcome}}

  defp normalize_progress_delay_seconds(delay_seconds)
       when is_integer(delay_seconds) and delay_seconds > 0,
       do: {:ok, delay_seconds}

  defp normalize_progress_delay_seconds(delay_seconds),
    do: {:error, {:invalid_delay_seconds, delay_seconds}}

  defp normalize_progress_to_step(to_step) when is_binary(to_step) do
    normalized_to_step = String.trim(to_step)

    if normalized_to_step == "" do
      {:error, {:blank_to_step, to_step}}
    else
      {:ok, normalized_to_step}
    end
  end

  defp normalize_progress_to_step(to_step) when is_atom(to_step) and not is_nil(to_step) do
    normalize_progress_to_step(Atom.to_string(to_step))
  end

  defp normalize_progress_to_step(to_step), do: {:error, {:blank_to_step, to_step}}

  defp validate_unique_workflow_step_keys(steps) do
    case find_duplicate(steps, & &1.step_key) do
      nil -> :ok
      duplicate_step_key -> {:error, {:duplicate_workflow_step_key, duplicate_step_key}}
    end
  end

  defp validate_unique_workflow_step_orders(steps) do
    case find_duplicate(steps, & &1.step_order) do
      nil -> :ok
      duplicate_step_order -> {:error, {:duplicate_workflow_step_order, duplicate_step_order}}
    end
  end

  defp validate_sequential_workflow_step_orders(steps) do
    step_orders = steps |> Enum.map(& &1.step_order) |> Enum.sort()
    expected_step_orders = Enum.to_list(1..length(steps))

    if step_orders == expected_step_orders do
      :ok
    else
      invalid_step_order =
        step_orders
        |> Enum.zip(expected_step_orders)
        |> Enum.find_value(fn
          {actual, expected} when actual != expected -> actual
          _ -> nil
        end)

      {:error, {:invalid_workflow_step_order, invalid_step_order}}
    end
  end

  defp find_duplicate(items, fun) do
    Enum.reduce_while(items, MapSet.new(), fn item, seen ->
      value = fun.(item)

      if MapSet.member?(seen, value) do
        {:halt, value}
      else
        {:cont, MapSet.put(seen, value)}
      end
    end)
    |> case do
      %MapSet{} -> nil
      duplicate -> duplicate
    end
  end
end
