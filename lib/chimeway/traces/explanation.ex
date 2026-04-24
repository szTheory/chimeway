defmodule Chimeway.Traces.Explanation do
  @moduledoc """
  Structured explanation of a single delivery — the primary operator debugging artifact.

  Returned by `Chimeway.Traces.explain_delivery/1`. Contains the full context
  needed to answer "why was this delivery suppressed/failed/succeeded?" without
  requiring additional queries.

  ## Fields

  - `delivery_id` — UUID of the delivery row
  - `event_id` — UUID of the parent event
  - `correlation_id` — host-app correlation string (request_id, trace_id), or nil
  - `notification_key` — stable notification type identifier
  - `recipient_id` — recipient identity string
  - `channel` — delivery channel atom (e.g. :in_app)
  - `status` — final delivery status: :succeeded | :failed | :suppressed | :pending | :cancelled
  - `suppression_reason` — reason atom string when status is :suppressed, else nil
  - `last_attempt` — map with :outcome and :inserted_at for the most recent attempt, or nil
  - `timeline` — chronological list of lifecycle events, each a map with :at, :event, :detail
  """

  @type timeline_entry :: %{at: DateTime.t(), event: atom(), detail: map()}

  @type t :: %__MODULE__{
          delivery_id: String.t(),
          event_id: String.t(),
          correlation_id: String.t() | nil,
          notification_key: String.t(),
          recipient_id: String.t(),
          channel: atom(),
          status: :succeeded | :failed | :suppressed | :pending | :cancelled | :dispatched,
          suppression_reason: String.t() | nil,
          last_attempt: %{outcome: atom(), inserted_at: DateTime.t()} | nil,
          timeline: [timeline_entry()]
        }

  defstruct [
    :delivery_id,
    :event_id,
    :correlation_id,
    :notification_key,
    :recipient_id,
    :channel,
    :status,
    :suppression_reason,
    :last_attempt,
    :timeline
  ]
end
