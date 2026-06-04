defmodule ChimewayAdmin.Live.RecoveryLive do
  @moduledoc """
  Safe operator recovery queue.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.{Context, LiveAuth}

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign_new(:chimeway_admin_context, fn -> Context.from(params, session, socket) end)
      |> assign_new(:chimeway_admin_session, fn -> session end)

    {:ok,
     assign(socket,
       candidates: recovery_candidates(socket),
       selected: nil,
       reason: "operator_reviewed_stuck_work",
       confirmation_marker: false,
       flash_result: nil
     )}
  end

  @impl true
  def handle_event("choose", %{"id" => id, "type" => type}, socket) do
    selected = Enum.find(socket.assigns.candidates, &(&1.id == id and &1.type == type))
    {:noreply, assign(socket, selected: selected, confirmation_marker: false, flash_result: nil)}
  end

  def handle_event("validate_recovery", params, socket) do
    {:noreply,
     assign(socket,
       reason: normalized_reason(params["reason"]),
       confirmation_marker: confirmation_marker?(params)
     )}
  end

  def handle_event("recover", %{"candidate_id" => id, "type" => type} = params, socket) do
    reason = normalized_reason(params["reason"])
    confirmation_marker = confirmation_marker?(params)

    with :ok <- validate_confirmation(reason, confirmation_marker),
         {:ok, candidate} <- selected_candidate(socket, id, type),
         {:ok, socket} <- authorize_recovery(socket, candidate),
         {:ok, result} <- do_recover(socket, candidate, reason) do
      {:noreply,
       assign(socket,
         candidates: recovery_candidates(socket),
         selected: nil,
         reason: reason,
         confirmation_marker: false,
         flash_result: success_message(type, result)
       )}
    else
      {:error, :confirmation_required} ->
        {:noreply,
         assign(socket,
           reason: reason,
           confirmation_marker: confirmation_marker,
           flash_result:
             "Recovery failed. Confirm the recovery reason and marker before retrying."
         )}

      {:error, :stale_candidate} ->
        {:noreply, skipped(socket)}

      {:noop, _result} ->
        {:noreply, skipped(socket)}

      {:error, socket_or_reason} ->
        if match?(%Phoenix.LiveView.Socket{}, socket_or_reason) do
          {:noreply, socket_or_reason}
        else
          {:noreply,
           assign(
             socket,
             flash_result:
               "Recovery failed. The row may no longer be eligible; refresh Recovery and try again with a current candidate."
           )}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_shell
      title="Recovery"
      active={:recovery}
      description="Safely replay events or deliveries that Chimeway can prove are recoverable."
    >
      <p :if={@flash_result} class={["cw-alert", alert_class(@flash_result)]} role="status">
        {@flash_result}
      </p>

      <section class="cw-grid cw-grid--two">
        <.card>
          <div class="cw-section-heading">
            <div>
              <h2>Eligible work</h2>
              <p>Only pending ready deliveries and events with no planned deliveries are listed.</p>
            </div>
          </div>

          <p :if={tenant_id(@chimeway_admin_context)} class="cw-scope-label">
            Tenant scope: <code>{tenant_id(@chimeway_admin_context)}</code>
          </p>

          <.empty_state
            :if={@candidates == []}
            title="No recoverable work"
            body="Nothing currently meets the recovery safety threshold."
          />

          <div class="cw-list">
            <button
              :for={candidate <- @candidates}
              type="button"
              class={[
                "cw-row-link",
                "cw-row-link--button",
                selected_candidate?(@selected, candidate) && "cw-row-link--selected"
              ]}
              phx-click="choose"
              phx-value-id={candidate.id}
              phx-value-type={candidate.type}
            >
              <div>
                <strong>{String.capitalize(candidate.type)} · {candidate.notification_key}</strong>
                <span>{candidate.reason}</span>
              </div>
              <.status_badge status={candidate.type} />
            </button>
          </div>
        </.card>

        <.card>
          <div class="cw-section-heading">
            <div>
              <h2>Confirm recovery</h2>
              <p>Recovery stamps durable metadata and reuses Chimeway's existing recovery spine.</p>
            </div>
          </div>

          <.empty_state
            :if={is_nil(@selected)}
            title="Choose a candidate"
            body="Select one eligible row to review the exact recovery action."
          />

          <form :if={@selected} phx-change="validate_recovery" phx-submit="recover" class="cw-confirm-form">
            <input type="hidden" name="candidate_id" value={@selected.id} />
            <input type="hidden" name="type" value={@selected.type} />
            <dl class="cw-summary-list">
              <dt>Type</dt>
              <dd>{@selected.type}</dd>
              <dt>Resource ID</dt>
              <dd><code>{@selected.id}</code></dd>
              <dt>Notification key</dt>
              <dd><code>{@selected.notification_key}</code></dd>
              <dt>Reason</dt>
              <dd>{@selected.reason}</dd>
              <dt :if={@selected.tenant_id}>Tenant</dt>
              <dd :if={@selected.tenant_id}><code>{@selected.tenant_id}</code></dd>
              <dt>Correlation</dt>
              <dd>{@selected.correlation_id || "—"}</dd>
            </dl>
            <.text_input
              label="Recovery reason"
              name="reason"
              value={@reason}
              required
              phx-debounce="blur"
            />
            <label class="cw-confirm-marker">
              <input
                type="checkbox"
                name="confirmation_marker"
                value="operator_confirmed_recovery"
                checked={@confirmation_marker}
              />
              <span>I understand this will recover the selected {@selected.type} through Chimeway.</span>
            </label>
            <button
              type="submit"
              class="cw-button cw-button--danger"
              disabled={!recovery_ready?(@reason, @confirmation_marker)}
            >
              Recover this {@selected.type}
            </button>
          </form>
        </.card>
      </section>
    </.admin_shell>
    """
  end

  defp authorize_recovery(socket, candidate) do
    action = if candidate.type == "event", do: :recover_event, else: :recover_delivery

    LiveAuth.ensure_authorized(socket, action, %{
      resource_id: candidate.id,
      recovery_type: candidate.type,
      candidate: Context.candidate_facts(candidate)
    })
  end

  defp do_recover(socket, %{type: "event", id: id}, reason) do
    Chimeway.recover_event(id, recovery_opts(socket, reason))
  end

  defp do_recover(socket, %{type: "delivery", id: id}, reason) do
    Chimeway.recover_delivery(id, recovery_opts(socket, reason))
  end

  defp success_message("event", %{deliveries: deliveries}) do
    "Event recovery started: #{length(deliveries)} delivery row(s) replayed."
  end

  defp success_message("delivery", %{dispatch_state: state}) do
    "Delivery recovery #{state}."
  end

  defp success_message(type, _), do: "#{String.capitalize(type)} recovery started."

  defp recovery_candidates(socket) do
    socket.assigns[:chimeway_admin_context]
    |> Context.read_opts(limit: 50)
    |> Chimeway.admin_recovery_candidates()
  end

  defp recovery_opts(socket, reason) do
    socket.assigns[:chimeway_admin_context]
    |> Context.recovery_opts(reason, "operator_confirmed_recovery")
  end

  defp validate_confirmation(reason, true) when is_binary(reason) and reason != "", do: :ok
  defp validate_confirmation(_reason, _confirmation_marker), do: {:error, :confirmation_required}

  defp selected_candidate(socket, id, type) do
    case Enum.find(socket.assigns.candidates, &(&1.id == id and &1.type == type)) do
      nil -> {:error, :stale_candidate}
      candidate -> {:ok, candidate}
    end
  end

  defp skipped(socket) do
    assign(socket,
      candidates: recovery_candidates(socket),
      selected: nil,
      confirmation_marker: false,
      flash_result:
        "Recovery skipped: the row is no longer eligible. Refresh Recovery to review current candidates."
    )
  end

  defp normalized_reason(reason) when is_binary(reason), do: String.trim(reason)
  defp normalized_reason(_reason), do: ""

  defp confirmation_marker?(%{"confirmation_marker" => "operator_confirmed_recovery"}), do: true
  defp confirmation_marker?(_params), do: false

  defp recovery_ready?(reason, confirmation_marker),
    do: normalized_reason(reason) != "" and confirmation_marker == true

  defp selected_candidate?(%{id: id, type: type}, %{id: id, type: type}), do: true
  defp selected_candidate?(_selected, _candidate), do: false

  defp tenant_id(%{tenant_id: tenant_id}) when is_binary(tenant_id) and tenant_id != "",
    do: tenant_id

  defp tenant_id(_context), do: nil

  defp alert_class("Recovery skipped" <> _), do: "cw-alert--warning"
  defp alert_class("Recovery failed" <> _), do: "cw-alert--danger"
  defp alert_class(_message), do: "cw-alert--success"
end
