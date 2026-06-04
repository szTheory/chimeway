defmodule ChimewayAdmin.Live.HealthLive do
  @moduledoc """
  Notification lifecycle health overview.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.{Context, Redaction, Routes}

  @impl true
  def mount(_params, _session, socket) do
    context = socket.assigns[:chimeway_admin_context]

    {:ok,
     assign(socket,
       outcomes: Chimeway.admin_outcome_totals(Context.read_opts(context)),
       problems: Chimeway.admin_recent_problem_deliveries(Context.read_opts(context, limit: 25)),
       recovery_candidates:
         Chimeway.admin_recovery_candidates(Context.read_opts(context, limit: 25))
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Health"
      active={:health}
      description="Lifecycle-level health: outcome buckets, recent problem traces, and recoverable work."
    >
      <section class="cw-metric-grid">
        <.metric label="Pending" value={metric(@outcomes, "pending")} tone={:info} />
        <.metric label="Succeeded" value={metric(@outcomes, "succeeded")} tone={:success} />
        <.metric label="Failed" value={metric(@outcomes, "failed")} tone={:danger} />
        <.metric label="Suppressed" value={metric(@outcomes, "suppressed")} tone={:warning} />
        <.metric label="Cancelled" value={metric(@outcomes, "cancelled")} tone={:warning} />
        <.metric label="Recoverable" value={length(@recovery_candidates)} tone={:info} />
      </section>

      <.card>
        <div class="cw-section-heading">
          <div>
            <h2>Problem traces</h2>
            <p>Representative deliveries to inspect before changing host policy or adapter configuration.</p>
          </div>
          <.link_button navigate={Routes.recovery_path()} variant={:ghost}>Recovery</.link_button>
        </div>
        <div class="cw-table-wrap">
          <table class="cw-table">
            <thead>
              <tr>
                <th>Key</th>
                <th>Recipient</th>
                <th>Channel</th>
                <th>Status</th>
                <th>Reason</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @problems}>
                <td><code>{row.notification_key}</code></td>
                <td>{Redaction.redact_recipient(row.recipient_id)}</td>
                <td>{row.channel}</td>
                <td><.status_badge status={row.status} /></td>
                <td>{row.suppression_reason || row.planning_reason || "—"}</td>
                <td><.link navigate={Routes.delivery_path(row.delivery_id)} class="cw-text-link">Open trace</.link></td>
              </tr>
            </tbody>
          </table>
        </div>
      </.card>
    </.admin_shell>
    """
  end

  defp metric(map, key), do: Map.get(map || %{}, key, 0)
end
