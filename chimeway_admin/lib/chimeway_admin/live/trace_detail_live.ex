defmodule ChimewayAdmin.Live.TraceDetailLive do
  @moduledoc """
  Operator trace detail with unified timeline from `Chimeway.Traces.explain_delivery/1` (OPER-02).
  """
  use ChimewayAdmin.Live, :live_view

  alias Chimeway.Traces
  alias ChimewayAdmin.Components.TimelineEvent
  alias ChimewayAdmin.Redaction

  @impl true
  def mount(%{"delivery_id" => delivery_id}, _session, socket) do
    case Traces.explain_delivery(delivery_id) do
      {:ok, explanation} ->
        {:ok, assign(socket, explanation: explanation, not_found: false)}

      {:error, :not_found} ->
        {:ok, assign(socket, explanation: nil, not_found: true, delivery_id: delivery_id)}
    end
  end

  @impl true
  def render(%{not_found: true} = assigns) do
    ~H"""
    <div class="chimeway-admin">
      <h1>Trace not found</h1>
      <p>No delivery exists for ID {@delivery_id}.</p>
      <a href="/" data-phx-link="redirect" data-phx-link-state="push">Back to search</a>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="chimeway-admin">
      <h1>Trace detail</h1>
      <a href="/" data-phx-link="redirect" data-phx-link-state="push">Back to search</a>

      <dl class="chimeway-admin-summary">
        <dt>Status</dt>
        <dd>{@explanation.status}</dd>
        <dt>Suppression reason</dt>
        <dd>{@explanation.suppression_reason || "—"}</dd>
        <dt>Planning reason</dt>
        <dd>{@explanation.planning_reason || "—"}</dd>
        <dt>Correlation ID</dt>
        <dd>{@explanation.correlation_id || "—"}</dd>
        <dt>Notification key</dt>
        <dd>{@explanation.notification_key}</dd>
        <dt>Channel</dt>
        <dd>{@explanation.channel}</dd>
        <dt>Recipient</dt>
        <dd>{Redaction.redact_recipient(@explanation.recipient_id)}</dd>
        <dt>Last attempt</dt>
        <dd>{format_last_attempt(@explanation.last_attempt)}</dd>
      </dl>

      <TimelineEvent.timeline timeline={@explanation.timeline} />

      <footer>
        <p>Trace lookup only — bell inbox, campaigns, and health dashboards are out of scope.</p>
      </footer>
    </div>
    """
  end

  defp format_last_attempt(nil), do: "—"

  defp format_last_attempt(%{outcome: outcome, error_class: error_class}) do
    parts = [Atom.to_string(outcome)]
    parts = if error_class, do: parts ++ ["(#{error_class})"], else: parts
    Enum.join(parts, " ")
  end

  defp format_last_attempt(_), do: "—"
end
