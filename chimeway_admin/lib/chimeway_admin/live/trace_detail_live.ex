defmodule ChimewayAdmin.Live.TraceDetailLive do
  @moduledoc """
  Operator trace detail with unified timeline from `Chimeway.Traces.explain_delivery/1` (OPER-02).
  """
  use ChimewayAdmin.Live, :live_view

  alias Chimeway.Traces
  alias ChimewayAdmin.{Components.TimelineEvent, Context}
  alias ChimewayAdmin.Redaction
  alias ChimewayAdmin.Routes

  @impl true
  def mount(%{"delivery_id" => delivery_id}, _session, socket) do
    case explain_delivery(socket, delivery_id) do
      {:ok, explanation} ->
        {:ok, assign(socket, explanation: explanation, not_found: false)}

      {:error, :not_found} ->
        {:ok, assign(socket, explanation: nil, not_found: true, delivery_id: delivery_id)}
    end
  end

  defp explain_delivery(socket, delivery_id) do
    case Context.read_opts(socket.assigns[:chimeway_admin_context]) do
      opts when is_list(opts) -> Traces.explain_delivery(delivery_id, opts)
      {:error, :invalid_tenant} -> {:error, :not_found}
    end
  end

  @impl true
  def render(%{not_found: true} = assigns) do
    ~H"""
    <.admin_shell title="Trace not found" active={:traces}>
      <.empty_state title="No delivery exists" body={"No delivery exists for ID #{@delivery_id}."} tone={:warning} />
      <.link_button navigate={Routes.traces_path()}>Back to Trace Lookup</.link_button>
    </.admin_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Trace Detail"
      active={:traces}
      description="A redacted, chronological explanation of one delivery row."
    >
      <:actions>
        <.link_button navigate={Routes.traces_path()} variant={:ghost}>Back to Trace Lookup</.link_button>
      </:actions>

      <section class="cw-detail-hero">
        <div>
          <p class="cw-eyebrow">Current state</p>
          <h2><.status_badge status={@explanation} /></h2>
        </div>
        <div class="cw-detail-hero__ids">
          <.copyable_id label="delivery" value={@explanation.delivery_id} />
          <.copyable_id label="event" value={@explanation.event_id} />
          <.copyable_id label="corr" value={@explanation.correlation_id || "—"} />
        </div>
      </section>

      <section class="cw-grid cw-grid--two">
        <.card>
          <h2>Why</h2>
          <dl class="cw-summary-list">
            <dt>Suppression reason</dt>
            <dd>{@explanation.suppression_reason || "—"}</dd>
            <dt>Planning reason</dt>
            <dd>{@explanation.planning_reason || "—"}</dd>
            <dt>Last attempt</dt>
            <dd>{format_last_attempt(@explanation.last_attempt)}</dd>
            <dt>Next eligible</dt>
            <dd>{format_at(@explanation.next_eligible_at)}</dd>
          </dl>
        </.card>

        <.card>
          <h2>What</h2>
          <dl class="cw-summary-list">
            <dt>Notification key</dt>
            <dd><code>{@explanation.notification_key}</code></dd>
            <dt>Channel</dt>
            <dd>{@explanation.channel}</dd>
            <dt>Recipient</dt>
            <dd>{Redaction.redact_recipient(@explanation.recipient_id)}</dd>
            <dt>Render identity</dt>
            <dd>{render_identity(@explanation)}</dd>
          </dl>
        </.card>
      </section>

      <.card>
        <TimelineEvent.timeline timeline={@explanation.timeline} />
      </.card>
    </.admin_shell>
    """
  end

  defp format_last_attempt(nil), do: "—"

  defp format_last_attempt(%{outcome: outcome, error_class: error_class}) do
    parts = [Atom.to_string(outcome)]

    parts =
      if error_class, do: parts ++ ["(#{Redaction.safe_error_class(error_class)})"], else: parts

    Enum.join(parts, " ")
  end

  defp format_last_attempt(_), do: "—"

  defp format_at(nil), do: "—"
  defp format_at(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  defp render_identity(%{render_key: nil}), do: "—"
  defp render_identity(%{render_key: key, render_version: nil}), do: key
  defp render_identity(%{render_key: key, render_version: version}), do: "#{key} v#{version}"
end
