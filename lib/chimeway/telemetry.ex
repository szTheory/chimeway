defmodule Chimeway.Telemetry do
  @moduledoc """
  Instrumentation façade for Chimeway telemetry spans.

  All lifecycle telemetry in Chimeway routes through this module so that
  event naming is consistent and metadata is redacted before emission.

  ## Event Catalog

  Chimeway emits the following `:telemetry` span events. Each span produces
  three events: `[:..., :start]`, `[:..., :stop]`, and `[:..., :exception]`.

  | Span | Event name | Metadata keys |
  |------|-----------|--------------|
  | Event creation | `[:chimeway, :events, :create]` | `notification_key`, `event_id`, `correlation_id` |
  | Delivery planning | `[:chimeway, :deliveries, :plan]` | `notification_key`, `event_id`, `recipient_id` |
  | Policy evaluation | `[:chimeway, :policy, :evaluate]` | `delivery_id`, `notification_key`, `channel`, `suppression_reason`, `planning_reason`, `correlation_id` |
  | Sync dispatch | `[:chimeway, :dispatch, :sync]` | `delivery_id`, `notification_key`, `channel`, `correlation_id` |
  | Oban enqueue *(optional)* | `[:chimeway, :dispatch, :enqueue]` | `delivery_id`, `notification_key` |
  | Oban perform *(optional)* | `[:chimeway, :dispatch, :perform]` | `delivery_id`, `notification_key`, `correlation_id` |
  | Attempt record | `[:chimeway, :attempts, :record]` | `attempt_id`, `delivery_id`, `outcome`, `correlation_id` |

  The two Oban spans are only emitted when Oban is present in the dependency tree.

  ## PII Redaction

  `safe_meta/1` strips any key not in the allowed set before metadata is passed
  to `:telemetry.span/3`. This prevents sensitive payload fields (email addresses,
  template content, provider API responses) from appearing in telemetry handlers.

  **Allowed keys:** `notification_key`, `event_id`, `recipient_id`, `channel`,
  `delivery_id`, `attempt_id`, `outcome`, `suppression_reason`, `planning_reason`,
  `correlation_id`, `attempt_number`, `error_class`, `adapter_module`

  All metadata that call sites pass to `span/3` must be pre-filtered:

      Chimeway.Telemetry.span([:events, :create], safe_meta(%{
        notification_key: key,
        event_id: id,
        correlation_id: cid
      }), fn ->
        result = do_create_event()
        {result, %{event_id: id}}
      end)

  ## Attaching Handlers

  Chimeway does NOT auto-attach handlers at library startup. Call
  `attach_default_handlers/0` explicitly in your application's `start/2`:

      def start(_type, _args) do
        Chimeway.Telemetry.attach_default_handlers()
        # ...
      end

  To attach a custom handler:

      :telemetry.attach_many(
        :my_handler,
        [
          [:chimeway, :events, :create, :stop],
          [:chimeway, :dispatch, :sync, :stop]
        ],
        &MyApp.TelemetryHandler.handle/4,
        nil
      )

  ## Example: Forwarding to StatsD / Datadog

      defmodule MyApp.ChimewayStatsD do
        def handle([:chimeway, :dispatch, :sync, :stop], measurements, meta, _config) do
          tags = ["channel:\#{meta.channel}", "key:\#{meta.notification_key}"]
          Statix.timing("chimeway.dispatch.sync", measurements.duration, tags: tags)
        end
      end
  """

  require Logger

  @doc """
  Wraps a function with a `:telemetry` span using Chimeway's 4-level event prefix.

  `event_suffix` is appended to `[:chimeway]`, e.g. `[:events, :create]`
  produces `[:chimeway, :events, :create, :start/stop/exception]`.

  The function `func` must return `{result, extra_stop_meta}` where
  `extra_stop_meta` is merged into the stop event metadata by `:telemetry.span/3`.
  Pass through `safe_meta/1` on any extra stop metadata to prevent PII leakage
  from the stop event.

  Returns `result`.
  """
  @spec span(list(), map(), (-> {term(), map()})) :: term()
  def span(event_suffix, meta, func)
      when is_list(event_suffix) and is_map(meta) and is_function(func, 0) do
    event = [:chimeway | event_suffix]
    safe_initial = safe_meta(meta)
    start_time = System.monotonic_time()

    :telemetry.execute(event ++ [:start], %{system_time: System.system_time()}, safe_initial)

    try do
      {result, extra} = func.()

      :telemetry.execute(
        event ++ [:stop],
        %{duration: System.monotonic_time() - start_time},
        safe_initial |> Map.merge(safe_meta(extra)) |> safe_meta()
      )

      result
    catch
      kind, reason ->
        :telemetry.execute(
          event ++ [:exception],
          %{duration: System.monotonic_time() - start_time},
          safe_initial
        )

        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  @doc """
  Filters a metadata map to the allowed telemetry keys only.

  Drops any key not in the allowed set. Normalizes both atom and string keys
  to atoms before filtering. This is the single enforcement point for PII
  redaction in Chimeway telemetry.

  ## Allowed keys

  Lifecycle identifiers, channel, outcome, bounded reasons/classifications, attempt number,
  and adapter identity. Each value is validated by `Chimeway.SafeEvidence` before emission.

  ## Example

      iex> Chimeway.Telemetry.safe_meta(%{notification_key: "order_shipped", email: "user@example.com"})
      %{notification_key: "order_shipped"}
  """
  @spec safe_meta(map()) :: map()
  def safe_meta(meta) when is_map(meta), do: Chimeway.SafeEvidence.telemetry_meta(meta)

  @doc """
  Attaches a Logger-based default telemetry handler for all Chimeway spans.

  Logs `:stop` events at `:debug` level and `:exception` events at `:warning` level.
  Idempotent — calling this function multiple times does not crash or double-attach.

  **Must be called explicitly** by the host application. Chimeway does not
  auto-attach handlers at startup. A typical place is `Application.start/2`:

      def start(_type, _args) do
        Chimeway.Telemetry.attach_default_handlers()
        children = [...]
        Supervisor.start_link(children, strategy: :one_for_one)
      end
  """
  @spec attach_default_handlers() :: :ok
  def attach_default_handlers do
    stop_events = [
      [:chimeway, :events, :create, :stop],
      [:chimeway, :deliveries, :plan, :stop],
      [:chimeway, :policy, :evaluate, :stop],
      [:chimeway, :dispatch, :sync, :stop],
      [:chimeway, :attempts, :record, :stop]
    ]

    exception_events = [
      [:chimeway, :events, :create, :exception],
      [:chimeway, :deliveries, :plan, :exception],
      [:chimeway, :policy, :evaluate, :exception],
      [:chimeway, :dispatch, :sync, :exception],
      [:chimeway, :attempts, :record, :exception]
    ]

    oban_events =
      if Code.ensure_loaded?(Oban) do
        [
          [:chimeway, :dispatch, :enqueue, :stop],
          [:chimeway, :dispatch, :enqueue, :exception],
          [:chimeway, :dispatch, :perform, :stop],
          [:chimeway, :dispatch, :perform, :exception]
        ]
      else
        []
      end

    try do
      :telemetry.attach_many(
        :chimeway_default_logger,
        stop_events ++ exception_events ++ oban_events,
        &handle_event/4,
        nil
      )
    catch
      :error, {:already_exists, :chimeway_default_logger} -> :ok
    end

    :ok
  end

  # --- Private ---

  defp handle_event([:chimeway | _rest] = event, _measurements, meta, _config) do
    level =
      case List.last(event) do
        :exception -> :warning
        _ -> :debug
      end

    safe = safe_meta(meta)

    Logger.log(level, "[chimeway] telemetry event",
      notification_key: Map.get(safe, :notification_key),
      event_id: Map.get(safe, :event_id),
      delivery_id: Map.get(safe, :delivery_id)
    )
  end
end
