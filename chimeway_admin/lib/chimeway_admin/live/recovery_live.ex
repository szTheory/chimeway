defmodule ChimewayAdmin.Live.RecoveryLive do
  @moduledoc """
  Safe operator recovery queue.
  """
  use ChimewayAdmin.Live, :live_view

  alias ChimewayAdmin.{Context, LiveAuth}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       candidates: recovery_candidates(socket),
       selected: nil,
       reason: "operator_reviewed_stuck_work",
       flash_result: nil
     )}
  end

  @impl true
  def handle_event("choose", %{"id" => id, "type" => type}, socket) do
    selected = Enum.find(socket.assigns.candidates, &(&1.id == id and &1.type == type))
    {:noreply, assign(socket, selected: selected, flash_result: nil)}
  end

  def handle_event("recover", %{"candidate_id" => id, "type" => type, "reason" => reason}, socket) do
    action = if type == "event", do: :recover_event, else: :recover_delivery

    with {:ok, socket} <-
           LiveAuth.ensure_authorized(socket, action, %{resource_id: id, recovery_type: type}),
         {:ok, result} <- do_recover(type, id, reason) do
      {:noreply,
       assign(socket,
         candidates: recovery_candidates(socket),
         selected: nil,
         flash_result: success_message(type, result)
       )}
    else
      {:noop, _result} ->
        {:noreply,
         assign(socket,
           candidates: recovery_candidates(socket),
           selected: nil,
           flash_result: "Recovery skipped: the row is no longer eligible."
         )}

      {:error, socket_or_reason} ->
        if match?(%Phoenix.LiveView.Socket{}, socket_or_reason) do
          {:noreply, socket_or_reason}
        else
          {:noreply,
           assign(socket, flash_result: "Recovery failed: #{inspect(socket_or_reason)}")}
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
      <p :if={@flash_result} class="cw-alert" role="status">{@flash_result}</p>

      <section class="cw-grid cw-grid--two">
        <.card>
          <div class="cw-section-heading">
            <div>
              <h2>Eligible work</h2>
              <p>Only pending ready deliveries and events with no planned deliveries are listed.</p>
            </div>
          </div>

          <.empty_state
            :if={@candidates == []}
            title="No recoverable work"
            body="Nothing currently meets the recovery safety threshold."
          />

          <div class="cw-list">
            <button
              :for={candidate <- @candidates}
              type="button"
              class="cw-row-link cw-row-link--button"
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

          <form :if={@selected} phx-submit="recover" class="cw-confirm-form">
            <input type="hidden" name="candidate_id" value={@selected.id} />
            <input type="hidden" name="type" value={@selected.type} />
            <dl class="cw-summary-list">
              <dt>Type</dt>
              <dd>{@selected.type}</dd>
              <dt>Notification key</dt>
              <dd><code>{@selected.notification_key}</code></dd>
              <dt>Reason</dt>
              <dd>{@selected.reason}</dd>
              <dt>Correlation</dt>
              <dd>{@selected.correlation_id || "—"}</dd>
            </dl>
            <.text_input label="Recovery reason" name="reason" value={@reason} required />
            <.button type="submit" variant={:danger}>Recover this {@selected.type}</.button>
          </form>
        </.card>
      </section>
    </.admin_shell>
    """
  end

  defp do_recover("event", id, reason) do
    Chimeway.recover_event(id, source: "chimeway_admin", reason: reason)
  end

  defp do_recover("delivery", id, reason) do
    Chimeway.recover_delivery(id, source: "chimeway_admin", reason: reason)
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
end
