defmodule ChimewayAdmin.Live.DashboardLive do
  @moduledoc """
  Operator command center for the mounted admin UI.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.{Context, Redaction, Routes}

  @impl true
  def mount(_params, _session, socket) do
    opts = Context.read_opts(socket.assigns[:chimeway_admin_context], limit: 8)
    {:ok, assign(socket, :snapshot, Chimeway.admin_command_center(opts))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Command Center"
      active={:home}
      description="Find notification traces, spot delivery problems, and recover eligible stuck work without exposing raw payloads."
    >
      <section class="cw-hero-panel">
        <div>
          <p class="cw-hero-panel__kicker">Headline job</p>
          <h2>Why did this notification happen?</h2>
          <p>Search by recipient or correlation ID, then follow the trace from event to delivery attempt.</p>
        </div>
        <.link_button navigate={Routes.traces_path()} variant={:primary}>Open Trace Lookup</.link_button>
      </section>

      <section class="cw-metric-grid" aria-label="Delivery status overview">
        <.metric label="Sent" value={metric(@snapshot.outcomes, "succeeded")} tone={:success} />
        <.metric label="Suppressed" value={metric(@snapshot.outcomes, "suppressed")} tone={:warning} />
        <.metric label="Failed" value={metric(@snapshot.outcomes, "failed")} tone={:danger} />
        <.metric label="Recoverable" value={length(@snapshot.recovery_candidates)} tone={:info} />
      </section>

      <section class="cw-grid cw-grid--two">
        <.card>
          <div class="cw-section-heading">
            <div>
              <h2>Recent problem traces</h2>
              <p>Failed, cancelled, or suppressed deliveries that deserve operator attention.</p>
            </div>
            <.link_button navigate={Routes.health_path()} variant={:ghost}>Health</.link_button>
          </div>
          <div class="cw-list">
            <.empty_state
              :if={@snapshot.recent_problems == []}
              title="No recent problem deliveries"
              body="When failures or suppressions appear, they will show up here with safe trace links."
            />
            <.problem_row :for={row <- @snapshot.recent_problems} row={row} />
          </div>
        </.card>

        <.card>
          <div class="cw-section-heading">
            <div>
              <h2>Recovery queue</h2>
              <p>Rows eligible for safe replay through Chimeway's recovery spine.</p>
            </div>
            <.link_button navigate={Routes.recovery_path()} variant={:ghost}>Review</.link_button>
          </div>
          <div class="cw-list">
            <.empty_state
              :if={@snapshot.recovery_candidates == []}
              title="No recoverable work"
              body="Recoverable events and pending ready deliveries will appear here after the safety threshold."
            />
            <.recovery_row :for={row <- @snapshot.recovery_candidates} row={row} />
          </div>
        </.card>
      </section>

      <.card>
        <div class="cw-section-heading">
          <div>
            <h2>Definitions seen in this app</h2>
            <p>Durable notification keys inferred from persisted event and delivery rows.</p>
          </div>
          <.link_button navigate={Routes.definitions_path()} variant={:ghost}>Definitions</.link_button>
        </div>
        <div class="cw-definition-strip">
          <div :for={definition <- @snapshot.definitions} class="cw-definition-chip">
            <strong>{definition.notification_key}</strong>
            <span>v{definition.notification_version} · {channel_summary(definition.channels)}</span>
          </div>
        </div>
      </.card>
    </.admin_shell>
    """
  end

  defp channel_summary([]), do: "no deliveries"
  defp channel_summary(channels), do: Enum.join(channels, ", ")

  attr(:row, :map, required: true)

  defp problem_row(assigns) do
    ~H"""
    <.link navigate={Routes.delivery_path(@row.delivery_id)} class="cw-row-link">
      <div>
        <strong>{@row.notification_key}</strong>
        <span>{Redaction.redact_recipient(@row.recipient_id)} · {@row.channel}</span>
      </div>
      <.status_badge status={@row.status} />
    </.link>
    """
  end

  attr(:row, :map, required: true)

  defp recovery_row(assigns) do
    ~H"""
    <div class="cw-row">
      <div>
        <strong>{String.capitalize(@row.type)} recovery</strong>
        <span>{@row.notification_key} · {@row.reason}</span>
      </div>
      <.status_badge status={@row.type} />
    </div>
    """
  end

  defp metric(map, key), do: Map.get(map || %{}, key, 0)
end
