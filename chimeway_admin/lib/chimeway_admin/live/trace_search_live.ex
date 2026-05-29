defmodule ChimewayAdmin.Live.TraceSearchLive do
  @moduledoc """
  Operator trace search by recipient ID or correlation ID (OPER-01).
  """
  use ChimewayAdmin.Live, :live_view

  alias Chimeway.Traces
  alias ChimewayAdmin.Redaction

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       results: [],
       query: "",
       mode: "recipient",
       notification_key: "",
       searched: false
     )}
  end

  @impl true
  def handle_event("search", params, socket) do
    mode = params["mode"] || socket.assigns.mode
    query = String.trim(params["query"] || "")
    notification_key = String.trim(params["notification_key"] || "")

    results =
      case {mode, query} do
        {_, ""} ->
          []

        {"recipient", q} ->
          opts = [limit: 50]
          opts = if notification_key != "", do: Keyword.put(opts, :notification_key, notification_key), else: opts
          q |> Traces.find_traces_for_recipient(opts) |> flatten_recipient_results()

        {"correlation", q} ->
          q |> Traces.find_traces_by_correlation_id() |> flatten_correlation_results()

        _ ->
          []
      end

    {:noreply,
     assign(socket,
       mode: mode,
       query: query,
       notification_key: notification_key,
       results: results,
       searched: true
     )}
  end

  @impl true
  def handle_event("open_delivery", %{"delivery_id" => delivery_id}, socket) do
    {:noreply, push_navigate(socket, to: "/deliveries/#{delivery_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chimeway-admin">
      <h1>Trace search</h1>

      <form phx-submit="search" id="trace-search-form">
        <label>
          Mode
          <select name="mode" value={@mode}>
            <option value="recipient" selected={@mode == "recipient"}>Recipient ID</option>
            <option value="correlation" selected={@mode == "correlation"}>Correlation ID</option>
          </select>
        </label>
        <label>
          Query
          <input type="text" name="query" value={@query} required />
        </label>
        <label :if={@mode == "recipient"}>
          Notification key (optional)
          <input type="text" name="notification_key" value={@notification_key} />
        </label>
        <button type="submit">Search</button>
      </form>

      <p :if={@searched and @results == []}>No deliveries found.</p>

      <ul :if={@results != []} id="trace-results">
        <%= for row <- @results do %>
          <li>
            <button type="button" phx-click="open_delivery" phx-value-delivery_id={row.delivery_id}>
              {row.notification_key} — {row.channel} — {row.status} — {row.redacted_recipient}
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp flatten_recipient_results(notifications) do
    Enum.flat_map(notifications, fn notification ->
      key = notification.event.notification_key

      Enum.map(notification.deliveries, fn delivery ->
        %{
          delivery_id: delivery.id,
          notification_key: key,
          channel: delivery.channel,
          status: delivery.status,
          inserted_at: delivery.inserted_at,
          redacted_recipient: Redaction.redact_recipient(notification.recipient_identity)
        }
      end)
    end)
  end

  defp flatten_correlation_results(events) do
    Enum.flat_map(events, fn event ->
      Enum.flat_map(event.notifications, fn notification ->
        Enum.map(notification.deliveries, fn delivery ->
          %{
            delivery_id: delivery.id,
            notification_key: event.notification_key,
            channel: delivery.channel,
            status: delivery.status,
            inserted_at: delivery.inserted_at,
            redacted_recipient: Redaction.redact_recipient(notification.recipient_identity)
          }
        end)
      end)
    end)
  end
end
