defmodule ChimewayAdmin.Live.TraceSearchLive do
  @moduledoc """
  Operator trace search by recipient ID or correlation ID (OPER-01).
  """
  use ChimewayAdmin.Live, :live_view

  alias Chimeway.Traces
  alias ChimewayAdmin.{Context, LiveAuth}
  alias ChimewayAdmin.Redaction
  alias ChimewayAdmin.Routes

  @search_limit 50

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
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :search_traces) do
      do_search(params, socket)
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("open_delivery", %{"delivery_id" => delivery_id}, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :search_traces) do
      {:noreply, push_navigate(socket, to: Routes.delivery_path(delivery_id))}
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  defp do_search(params, socket) do
    mode = params["mode"] || socket.assigns.mode
    query = String.trim(params["query"] || "")
    notification_key = String.trim(params["notification_key"] || "")

    results =
      case {Context.read_opts(socket.assigns[:chimeway_admin_context], limit: @search_limit),
            mode, query} do
        {{:error, :invalid_tenant}, _mode, _query} ->
          []

        {_opts, _, ""} ->
          []

        {opts, "recipient", q} ->
          opts =
            if notification_key != "",
              do: Keyword.put(opts, :notification_key, notification_key),
              else: opts

          q |> Traces.find_traces_for_recipient(opts) |> flatten_recipient_results()

        {opts, "correlation", q} ->
          q
          |> Traces.find_traces_by_correlation_id(opts)
          |> flatten_correlation_results()

        _ ->
          []
      end

    {:noreply,
     assign(socket,
       mode: mode,
       query: "",
       notification_key: notification_key,
       results: results,
       searched: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Trace Lookup"
      active={:traces}
      description="Search by recipient or correlation ID, then open the delivery timeline that explains the outcome."
    >
      <.card>
        <form phx-submit="search" id="trace-search-form" class="cw-search-form">
          <.select
            label="Mode"
            name="mode"
            value={@mode}
            options={[{"Recipient ID", "recipient"}, {"Correlation ID", "correlation"}]}
          />
          <.text_input label="Query" name="query" value={@query} required />
          <.text_input
            :if={@mode == "recipient"}
            label="Notification key"
            name="notification_key"
            value={@notification_key}
            hint="Optional"
          />
          <.button type="submit" variant={:primary}>Search traces</.button>
        </form>
      </.card>

      <.card>
        <.empty_state
          :if={@searched and @results == []}
          title="No deliveries found"
          body="Try a full recipient identity, correlation ID, or remove the notification key filter."
        />

        <div class="cw-list" :if={@results != []} id="trace-results">
          <button
            :for={row <- @results}
            type="button"
            class="cw-row-link cw-row-link--button"
            phx-click="open_delivery"
            phx-value-delivery_id={row.delivery_id}
          >
            <div>
              <strong>{row.notification_key}</strong>
              <span>{row.redacted_recipient} · {row.channel}</span>
            </div>
            <.status_badge status={row.status} />
          </button>
        </div>
      </.card>
    </.admin_shell>
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
