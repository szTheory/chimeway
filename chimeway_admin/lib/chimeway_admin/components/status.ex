defmodule ChimewayAdmin.Components.Status do
  @moduledoc false

  use Phoenix.Component

  attr(:status, :any, required: true)
  attr(:label, :string, default: nil)

  def status_badge(assigns) do
    lifecycle = lifecycle_label(assigns.status)

    assigns =
      assigns
      |> assign(:normalized, lifecycle.normalized)
      |> assign(:display_label, assigns.label || lifecycle.label)

    ~H"""
    <span class={["cw-status", "cw-status--#{@normalized}"]}>
      <span class="cw-status__dot" aria-hidden="true"></span>
      <span>{@display_label}</span>
    </span>
    """
  end

  @doc """
  Returns display-only lifecycle copy for admin UI surfaces.

  Durable core delivery atoms remain unchanged; this function translates existing
  facts into operator-facing labels.
  """
  def lifecycle_label(facts) do
    facts = normalize_facts(facts)

    cond do
      delivered_feedback?(facts) ->
        %{status: facts.status, normalized: "delivered", label: "Delivered", tone: :success}

      suppressed?(facts) ->
        %{status: facts.status, normalized: "suppressed", label: "Suppressed", tone: :warning}

      terminal_failure?(facts) ->
        %{
          status: facts.status,
          normalized: "terminal-failure",
          label: "Terminal failure",
          tone: :danger
        }

      retryable_failure?(facts) ->
        %{
          status: facts.status,
          normalized: "retryable-failure",
          label: "Retryable failure",
          tone: :warning
        }

      provider_accepted?(facts) ->
        %{
          status: facts.status,
          normalized: "provider-accepted",
          label: "Provider accepted",
          tone: :success
        }

      sent?(facts) ->
        %{status: facts.status, normalized: "sent", label: "Sent", tone: :info}

      true ->
        normalized = normalize(facts.status)
        %{status: facts.status, normalized: normalized, label: humanize(normalized), tone: :neutral}
    end
  end

  attr(:value, :integer, default: 0)
  attr(:label, :string, required: true)
  attr(:tone, :atom, default: :neutral, values: [:neutral, :success, :warning, :danger, :info])

  def metric(assigns) do
    ~H"""
    <div class={["cw-metric", "cw-metric--#{@tone}"]}>
      <span class="cw-metric__value">{@value}</span>
      <span class="cw-metric__label">{@label}</span>
    </div>
    """
  end

  defp normalize(nil), do: "unknown"
  defp normalize(value), do: value |> to_string() |> String.replace("_", "-")

  defp humanize(value) do
    value |> String.replace("-", " ") |> String.capitalize()
  end

  defp normalize_facts(%{__struct__: _struct} = facts) do
    facts
    |> Map.from_struct()
    |> normalize_facts()
  end

  defp normalize_facts(facts) when is_map(facts) do
    %{
      status: Map.get(facts, :status) || Map.get(facts, "status"),
      last_attempt: Map.get(facts, :last_attempt) || Map.get(facts, "last_attempt"),
      suppression_reason: Map.get(facts, :suppression_reason) || Map.get(facts, "suppression_reason"),
      timeline: Map.get(facts, :timeline) || Map.get(facts, "timeline") || []
    }
  end

  defp normalize_facts(status) do
    %{status: status, last_attempt: nil, suppression_reason: nil, timeline: []}
  end

  defp delivered_feedback?(%{status: status, timeline: timeline})
       when status in [:succeeded, "succeeded"] do
    Enum.any?(timeline, fn entry ->
      detail = Map.get(entry, :detail) || Map.get(entry, "detail") || %{}
      event_name = Map.get(detail, :event_name) || Map.get(detail, "event_name")
      signal_event_name = Map.get(detail, :signal_event_name) || Map.get(detail, "signal_event_name")
      status = Map.get(detail, :status) || Map.get(detail, "status")
      outcome = Map.get(detail, :outcome) || Map.get(detail, "outcome")

      event_name in ["chimeway.delivery.delivered", "delivered"] or
        signal_event_name in ["chimeway.delivery.delivered", "delivered"] or
        status in [:delivered, "delivered"] or outcome in [:delivered, "delivered"]
    end)
  end

  defp delivered_feedback?(_facts), do: false

  defp suppressed?(%{status: status}), do: status in [:suppressed, "suppressed"]

  defp terminal_failure?(%{status: status, suppression_reason: reason, last_attempt: attempt}) do
    status in [:cancelled, "cancelled", :digested, "digested"] or
      reason in ["retries_exhausted", "permanent_failure", "bounced"] or
      attempt_error_class(attempt) in ["permanent", "bounced"]
  end

  defp retryable_failure?(%{status: status, last_attempt: attempt}) do
    status in [:failed, "failed"] and attempt_error_class(attempt) in [nil, "temporary"]
  end

  defp provider_accepted?(%{status: status, last_attempt: attempt}) do
    status in [:succeeded, "succeeded"] or attempt_outcome(attempt) in [:succeeded, "succeeded"]
  end

  defp sent?(%{status: status}), do: status in [:pending, "pending", :dispatched, "dispatched"]

  defp attempt_error_class(nil), do: nil
  defp attempt_error_class(attempt), do: Map.get(attempt, :error_class) || Map.get(attempt, "error_class")

  defp attempt_outcome(nil), do: nil
  defp attempt_outcome(attempt), do: Map.get(attempt, :outcome) || Map.get(attempt, "outcome")
end
