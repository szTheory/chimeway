# Tracing a Notification

Chimeway emits standard `:telemetry` events at every stage of the notification lifecycle: triggering, policy evaluation, delivery planning, and actual delivery attempts. You can hook into these events to emit logs, record metrics, or debug why a notification wasn't sent.

## Core Principles of Chimeway Telemetry

1. **Safety First**: Chimeway intentionally does **not** include the notification payload in telemetry metadata. This prevents accidentally leaking PII, passwords, or sensitive financial data into logs or APM systems.
2. **Correlation IDs**: To trace a notification through its lifecycle, rely on safe correlation IDs instead of payload data. Every step of the pipeline includes a consistent `correlation_id` and the original `notification_key`.

## Available Telemetry Events

Chimeway emits the following key events (each has a `:start`, `:stop`, and `:exception` variant):

- `[:chimeway, :deliveries, :plan, *]` - Emitted when a notification is triggered and a delivery plan is created.
- `[:chimeway, :policy, :evaluate, *]` - Emitted when policy rules (quiet hours, frequency caps) are evaluated.
- `[:chimeway, :delivery, :attempt, *]` - Emitted for each adapter delivery attempt (e.g., sending the actual email).
- `[:chimeway, :oban, :worker, *]` - Emitted by the Oban worker during async dispatch.

## Attaching to Telemetry Events

To trace deliveries, you can create a module that attaches to these events. Here is an example of a simple logger that listens to the `[:chimeway, :delivery, :attempt, :stop]` event to see whether an attempt succeeded or failed.

```elixir
defmodule MyApp.ChimewayLogger do
  require Logger

  def setup do
    :telemetry.attach(
      "chimeway-logger-delivery-stop",
      [:chimeway, :delivery, :attempt, :stop],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event(_event, measurements, metadata, _config) do
    # ⚠️ Notice that `metadata` only contains safe correlation IDs and state.
    # The actual payload is intentionally omitted.
    delivery_id = metadata[:delivery_id]
    correlation_id = metadata[:correlation_id]
    notification_key = metadata[:notification_key]
    status = metadata[:status]
    
    Logger.info(
      "Delivery Attempt Finished [#{status}] " <>
      "delivery_id=#{delivery_id} " <>
      "correlation_id=#{correlation_id} " <>
      "key=#{notification_key} " <>
      "duration=#{measurements.duration}"
    )
  end
end
```

To enable this, call `MyApp.ChimewayLogger.setup()` in your application's start function (e.g., in `application.ex`).

## Diagnosing "Why wasn't this sent?"

If you're using IEx and need to know why a specific notification was suppressed, you can use the built-in `Chimeway.Traces` module. The traces provide an explainable view of the delivery's policy evaluations.

```elixir
# In IEx
alias Chimeway.Traces

# If you have the delivery_id:
Traces.explain_delivery(delivery_id)

# If you only have the correlation_id (useful if you found it in your logs!):
Traces.find_traces_by_correlation_id(correlation_id)
```

The trace will explicitly tell you if a notification was blocked by a frequency cap, suppressed during quiet hours, or rejected due to opt-out preferences.
