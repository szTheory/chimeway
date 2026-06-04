defmodule ChimewayAdmin.Live.DefinitionsLive do
  @moduledoc """
  Persisted notification definition history.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.Context

  @impl true
  def mount(_params, _session, socket) do
    opts = Context.read_opts(socket.assigns[:chimeway_admin_context], limit: 100)
    {:ok, assign(socket, definitions: Chimeway.admin_definitions(opts))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Definitions"
      active={:definitions}
      description="Durable notification keys and versions inferred from persisted Chimeway events and deliveries."
    >
      <.card>
        <div class="cw-section-heading">
          <div>
            <h2>Definitions seen in this app</h2>
            <p>Durable notification keys and versions inferred from persisted Chimeway events and deliveries.</p>
          </div>
        </div>
        <.empty_state
          :if={@definitions == []}
          title="No definitions seen"
          body="Persisted notification keys and versions will appear after Chimeway records events or deliveries."
        />
        <div class="cw-table-wrap">
          <table :if={@definitions != []} class="cw-table">
            <thead>
              <tr>
                <th>Notification key</th>
                <th>Version</th>
                <th>Channels</th>
                <th>Events</th>
                <th>Recipients</th>
                <th>Deliveries</th>
                <th>Last seen</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={definition <- @definitions}>
                <td><code>{definition.notification_key}</code></td>
                <td>v{definition.notification_version}</td>
                <td>{channel_text(definition.channels)}</td>
                <td>{definition.event_count}</td>
                <td>{definition.recipient_count}</td>
                <td>{definition.delivery_count}</td>
                <td>{format_at(definition.last_seen_at)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.card>
    </.admin_shell>
    """
  end

  defp channel_text([]), do: "No deliveries yet"
  defp channel_text(channels), do: Enum.join(channels, ", ")

  defp format_at(nil), do: "—"
  defp format_at(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
end
