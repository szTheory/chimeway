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
  - `channel` — delivery channel string (for example "in_app", "email", "webhook_partner")
  - `status` — final delivery status: :succeeded | :failed | :suppressed | :pending | :cancelled
  - `planning_reason` — orchestration/planning reason when the delivery is intentionally held, else nil
  - `planning_context` — sanitized persisted planning facts for explainability, else nil
  - `next_eligible_at` — UTC timestamp for the next dispatchable moment when deferred, else nil
  - `resume_source` — sanitized scheduler/source label when a deferred row later resumes, else nil
  - `resume_scheduled_at` — original UTC time the deferred row was scheduled to resume, else nil
  - `resumed_at` — UTC timestamp when the canonical delivery row left deferred state, else nil
  - `suppression_reason` — reason atom string when status is `:suppressed` OR `:cancelled`,
    else nil. The four documented reason strings are:
      * `"channel_disabled"` — set when status is `:suppressed` (policy preference blocked the channel)
      * `"retries_exhausted"` — set when status is `:cancelled` (Oban exhausted max_attempts on transient failures, REL-03 D-10/D-11)
      * `"permanent_failure"` — set when status is `:cancelled` (adapter returned a permanent error)
      * `"bounced"` — set when status is `:cancelled` (adapter returned a bounce)
  - `last_attempt` — map with :outcome, :inserted_at, :attempt_number, :error_class for the most recent attempt, or nil
  - `digest` — digest-specific reasoning for source or emitted digest rows, else nil
  - `timeline` — chronological list of lifecycle events, each a map with :at, :event, :detail
  """

  @type timeline_entry :: %{at: DateTime.t(), event: atom(), detail: map()}

  @type t :: %__MODULE__{
          delivery_id: String.t(),
          event_id: String.t(),
          correlation_id: String.t() | nil,
          notification_key: String.t(),
          recipient_id: String.t(),
          channel: String.t(),
          status: :succeeded | :failed | :suppressed | :pending | :cancelled | :dispatched,
          planning_reason: String.t() | nil,
          planning_context: map() | nil,
          next_eligible_at: DateTime.t() | nil,
          resume_source: String.t() | nil,
          resume_scheduled_at: DateTime.t() | nil,
          resumed_at: DateTime.t() | nil,
          suppression_reason: String.t() | nil,
          digest: map() | nil,
          last_attempt:
            %{
              outcome: atom(),
              inserted_at: DateTime.t(),
              attempt_number: pos_integer() | nil,
              error_class: String.t() | nil
            }
            | nil,
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
    :planning_reason,
    :planning_context,
    :next_eligible_at,
    :resume_source,
    :resume_scheduled_at,
    :resumed_at,
    :suppression_reason,
    :digest,
    :last_attempt,
    :timeline
  ]
end
