defmodule ChimewayAdmin.Components.TimelineEvent do
  @moduledoc """
  Renders `Explanation.timeline` entries for OPER-02.

  Supported events include `:attempt_recorded`, `:suppressed`, `:cancelled`,
  `:webhook_received`, `:workflow_progressed`, `:workflow_waiting`,
  `:workflow_stopped`, `:workflow_completed`, and other atoms projected by
  `Chimeway.Traces.explain_delivery/1`.
  """
  use Phoenix.Component

  alias ChimewayAdmin.Redaction

  attr(:timeline, :list, required: true)

  def timeline(assigns) do
    ~H"""
    <section class="chimeway-admin-timeline">
      <h2>Timeline</h2>
      <ol class="cw-timeline">
        <%= for entry <- @timeline do %>
          <li class="cw-timeline__item">
            <time datetime={DateTime.to_iso8601(entry.at)}>
              {format_at(entry.at)}
            </time>
            <strong>{humanize_event(entry.event)}</strong>
            <dl class="cw-timeline__details">
              <%= for {key, value} <- Redaction.safe_timeline_detail(entry.detail) do %>
                <dt>{key}</dt>
                <dd>{format_detail_value(value)}</dd>
              <% end %>
            </dl>
          </li>
        <% end %>
      </ol>
    </section>
    """
  end

  defp format_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp humanize_event(event) when is_atom(event) do
    event |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp format_detail_value(value) when is_binary(value), do: value
  defp format_detail_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_detail_value(value), do: inspect(value)
end
