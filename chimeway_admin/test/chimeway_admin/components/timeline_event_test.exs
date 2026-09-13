defmodule ChimewayAdmin.Components.TimelineEventTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ChimewayAdmin.Components.TimelineEvent

  test "renders notification lifecycle labels, stable hooks, timestamps, and empty details" do
    seen_at = ~U[2026-09-12 14:30:00.123456Z]
    read_at = ~U[2026-09-12 14:31:00.654321Z]

    html =
      render_component(&TimelineEvent.timeline/1,
        timeline: [
          %{at: seen_at, event: :notification_seen, detail: %{}},
          %{at: read_at, event: :notification_read, detail: %{}}
        ]
      )

    assert html =~ "Notification seen"
    assert html =~ "Notification read"
    assert html =~ ~s(data-cw-timeline-event="notification_seen")
    assert html =~ ~s(data-cw-timeline-event="notification_read")
    assert html =~ ~s(datetime="2026-09-12T14:30:00.123456Z")
    assert html =~ ~s(datetime="2026-09-12T14:31:00.654321Z")
    assert length(Regex.scan(~r/<dl class="cw-timeline__details">\s*<\/dl>/, html)) == 2
  end

  test "retains generic event rendering and re-redacts hostile detail" do
    html =
      render_component(&TimelineEvent.timeline/1,
        timeline: [
          %{
            at: ~U[2026-09-12 15:00:00.000000Z],
            event: :delivery_planned,
            detail: %{
              channel: "in_app",
              reason: "immediate",
              password: "hostile-detail-sentinel",
              caller_metadata: "caller-metadata-sentinel"
            }
          }
        ]
      )

    assert html =~ "Delivery planned"
    assert html =~ ~s(data-cw-timeline-event="delivery_planned")
    assert html =~ "channel"
    assert html =~ "in_app"
    assert html =~ "reason"
    assert html =~ "immediate"
    refute html =~ "hostile-detail-sentinel"
    refute html =~ "caller-metadata-sentinel"
  end
end
