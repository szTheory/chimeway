defmodule ChimewayAdmin.Live.FeedLive do
  @moduledoc """
  Operator-only notification feed debugging.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.{Context, Redaction}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, query: "", rows: [], searched: false)}
  end

  @impl true
  def handle_event("search", %{"recipient_id" => recipient_id}, socket) do
    recipient_id = String.trim(recipient_id || "")

    rows =
      if recipient_id == "",
        do: [],
        else:
          socket.assigns[:chimeway_admin_context]
          |> Context.read_opts(limit: 50)
          |> Keyword.put(:recipient_id, recipient_id)
          |> Chimeway.admin_feed()

    {:noreply, assign(socket, query: "", rows: rows, searched: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Feed Debug"
      active={:feed}
      description="Inspect a recipient's notification lifecycle without entering the end-user inbox product surface."
    >
      <.card>
        <form phx-submit="search" class="cw-search-form" id="feed-search-form">
          <.text_input
            label="Recipient identity"
            name="recipient_id"
            value={@query}
            required
            hint="Example: user:alex@teampulse.test"
          />
          <.button type="submit" variant={:primary}>Inspect feed</.button>
        </form>
      </.card>

      <.card>
        <.empty_state
          :if={@searched and @rows == []}
          title="No feed rows found"
          body="Try a full recipient identity from the host app."
        />

        <div class="cw-table-wrap" :if={@rows != []}>
          <table class="cw-table">
            <thead>
              <tr>
                <th>Notification</th>
                <th>Recipient</th>
                <th>State</th>
                <th>Channels</th>
                <th>Correlation</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @rows}>
                <td><strong>{row.notification_key}</strong><br /><span>v{row.notification_version}</span></td>
                <td>{Redaction.redact_recipient(row.recipient_id)}</td>
                <td><.status_badge status={row.state} /></td>
                <td>{Enum.join(row.channel_summary, ", ")}</td>
                <td><.copyable_id label="corr" value={row.correlation_id || "—"} /></td>
              </tr>
            </tbody>
          </table>
        </div>
      </.card>
    </.admin_shell>
    """
  end
end
