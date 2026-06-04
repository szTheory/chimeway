defmodule ChimewayAdmin.Components.StatusTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.Components.Status

  describe "lifecycle_label/1" do
    test "labels dispatched or internal-send-only facts as Sent" do
      assert %{label: "Sent", tone: :info, normalized: "sent"} =
               Status.lifecycle_label(%{status: :dispatched})

      assert %{label: "Sent"} = Status.lifecycle_label(:dispatched)
    end

    test "labels succeeded attempts without durable delivery feedback as Provider accepted" do
      assert %{label: "Provider accepted", tone: :success, normalized: "provider-accepted"} =
               Status.lifecycle_label(%{
                 status: :succeeded,
                 last_attempt: %{outcome: :succeeded}
               })
    end

    test "labels explicit durable feedback as Delivered" do
      assert %{label: "Delivered", tone: :success, normalized: "delivered"} =
               Status.lifecycle_label(%{
                 status: :succeeded,
                 timeline: [
                   %{event: :webhook_received, detail: %{event_name: "chimeway.delivery.delivered"}}
                 ]
               })
    end

    test "labels suppressed deliveries as Suppressed" do
      assert %{label: "Suppressed", tone: :warning, normalized: "suppressed"} =
               Status.lifecycle_label(%{
                 status: :suppressed,
                 suppression_reason: "channel_disabled"
               })
    end

    test "labels temporary failed deliveries as Retryable failure" do
      assert %{label: "Retryable failure", tone: :warning, normalized: "retryable-failure"} =
               Status.lifecycle_label(%{
                 status: :failed,
                 last_attempt: %{outcome: :failed, error_class: "temporary"}
               })
    end

    test "labels cancelled, permanent, bounced, and exhausted facts as Terminal failure" do
      terminal_facts = [
        %{status: :cancelled},
        %{status: :failed, last_attempt: %{outcome: :rejected, error_class: "permanent"}},
        %{status: :failed, last_attempt: %{outcome: :bounced, error_class: "bounced"}},
        %{status: :cancelled, suppression_reason: "retries_exhausted"}
      ]

      for fact <- terminal_facts do
        assert %{label: "Terminal failure", tone: :danger, normalized: "terminal-failure"} =
                 Status.lifecycle_label(fact)
      end
    end
  end
end
