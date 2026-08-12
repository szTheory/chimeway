defmodule ChimewayInbox.Live.BellDropdownLive do
  @moduledoc """
  End-user bell dropdown inbox surface (INBX-02).

  Unstyled structural markup with `data-cw-inbox-*` hooks per UI-SPEC.
  Calls the `Chimeway` public API only — no direct inbox module access from this package.
  """
  use ChimewayInbox.Live, :live_view

  alias ChimewayInbox.LiveAuth

  @impl true
  def mount(_params, _session, socket) do
    recipient_identity = socket.assigns.recipient_identity
    tenant_id = socket.assigns.tenant_id

    socket =
      socket
      |> assign(
        panel_open: false,
        unread_count: 0,
        items: [],
        has_more: false,
        load_error: nil,
        item_link_fun: nil
      )
      |> load_inbox(recipient_identity, tenant_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_panel", _params, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      {:noreply, assign(socket, :panel_open, !socket.assigns.panel_open)}
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      recipient_identity = socket.assigns.recipient_identity
      tenant_id = socket.assigns.tenant_id
      _ = Chimeway.mark_read(id, recipient_identity, tenant_id: tenant_id)
      {:noreply, load_inbox(socket, recipient_identity, tenant_id)}
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("mark_all_read", _params, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      recipient_identity = socket.assigns.recipient_identity
      tenant_id = socket.assigns.tenant_id

      socket.assigns.items
      |> Enum.filter(&unread?/1)
      |> Enum.each(fn item ->
        Chimeway.mark_read(item["id"], recipient_identity, tenant_id: tenant_id)
      end)

      {:noreply, load_inbox(socket, recipient_identity, tenant_id)}
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("load_more", _params, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      recipient_identity = socket.assigns.recipient_identity
      tenant_id = socket.assigns.tenant_id

      case fetch_page(recipient_identity, tenant_id, cursor_from_last(socket.assigns.items)) do
        {:ok, %{items: items, has_more: has_more}} ->
          {:noreply,
           assign(socket,
             items: socket.assigns.items ++ items,
             has_more: has_more,
             load_error: nil
           )}

        {:error, _reason} ->
          {:noreply, assign(socket, :load_error, :fetch_failed)}
      end
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("retry_load", _params, socket) do
    with {:ok, socket} <- LiveAuth.ensure_authorized(socket, :inbox_bell) do
      {:noreply,
       load_inbox(
         assign(socket, :load_error, nil),
         socket.assigns.recipient_identity,
         socket.assigns.tenant_id
       )}
    else
      {:error, socket} -> {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chimeway-inbox">
      <button
        type="button"
        data-cw-inbox-bell
        aria-expanded={to_string(@panel_open)}
        aria-label={bell_aria_label(@unread_count)}
        phx-click="toggle_panel"
      >
        <span data-cw-inbox-badge aria-live="polite" hidden={@unread_count == 0}>
          {@unread_count}
        </span>
      </button>

      <div
        :if={@panel_open}
        data-cw-inbox-panel
        role="dialog"
        aria-labelledby="chimeway-inbox-panel-title"
      >
        <header>
          <h2 id="chimeway-inbox-panel-title">Notifications</h2>
        </header>

        <div :if={@load_error} data-cw-inbox-error>
          <h3>Couldn't load notifications</h3>
          <p>Check your connection and try again.</p>
          <button type="button" phx-click="retry_load">Try again</button>
        </div>

        <div :if={is_nil(@load_error) and @items == []} data-cw-inbox-empty>
          <h3>No notifications yet</h3>
          <p>When something needs your attention, it will show up here.</p>
        </div>

        <ul
          :if={is_nil(@load_error) and @items != []}
          role="list"
          id="chimeway-inbox-items"
          data-cw-inbox-items
        >
          <li
            :for={item <- @items}
            role="listitem"
            data-notification-id={item["id"]}
            data-unread={to_string(unread?(item))}
          >
            <span>{item["title"]}</span>
            <span :if={item["body_preview"] != ""}>{item["body_preview"]}</span>
            <span>{item["inserted_at"]}</span>
            <button
              :if={unread?(item)}
              type="button"
              phx-click="mark_read"
              phx-value-id={item["id"]}
            >
              Mark as read
            </button>
          </li>
        </ul>

        <footer>
          <button
            :if={is_nil(@load_error) and any_unread?(@items)}
            type="button"
            phx-click="mark_all_read"
          >
            Mark all as read
          </button>
          <button :if={is_nil(@load_error) and @has_more} type="button" phx-click="load_more">
            Load more notifications
          </button>
        </footer>
      </div>
    </div>
    """
  end

  defp load_inbox(socket, recipient_identity, tenant_id) do
    unread_count =
      try do
        Chimeway.unread_count(recipient_identity, tenant_id: tenant_id)
      rescue
        _ -> 0
      catch
        _, _ -> 0
      end

    case fetch_page(recipient_identity, tenant_id, []) do
      {:ok, %{items: items, has_more: has_more}} ->
        assign(socket,
          unread_count: unread_count,
          items: items,
          has_more: has_more,
          load_error: nil
        )

      {:error, _reason} ->
        assign(socket,
          unread_count: unread_count,
          items: [],
          has_more: false,
          load_error: :fetch_failed
        )
    end
  end

  defp fetch_page(recipient_identity, tenant_id, cursor_opts) do
    opts = [limit: page_size(), tenant_id: tenant_id] ++ cursor_opts

    case Chimeway.list_for_recipient(recipient_identity, opts) do
      %{items: items, has_more: has_more} ->
        {:ok, %{items: items, has_more: has_more}}

      _other ->
        {:error, :unexpected_shape}
    end
  rescue
    error -> {:error, error}
  end

  defp cursor_from_last([]), do: []

  defp cursor_from_last(items) do
    last = List.last(items)

    with inserted_at when is_binary(inserted_at) <- last["inserted_at"],
         id when is_binary(id) <- last["id"],
         {:ok, datetime, _} <- DateTime.from_iso8601(inserted_at) do
      [before_inserted_at: datetime, before_id: id]
    else
      _ -> []
    end
  end

  defp page_size do
    Application.get_env(:chimeway_inbox, :page_size, 20)
  end

  defp bell_aria_label(0), do: "Notifications"

  defp bell_aria_label(count) do
    "Notifications, #{count} unread"
  end

  defp unread?(item), do: is_nil(item["read_at"])

  defp any_unread?(items), do: Enum.any?(items, &unread?/1)
end
