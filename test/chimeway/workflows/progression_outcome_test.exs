defmodule Chimeway.Workflows.ProgressionOutcomeTest do
  use ExUnit.Case, async: true

  alias Chimeway.Delivery
  alias Chimeway.DeliveryAttempt
  alias Chimeway.Workflows.ProgressionOutcome

  describe "from_delivery/2 — curated workflow outcome vocabulary (D-04)" do
    test "delivered: succeeded delivery resolves to {:branchable, :delivered, evidence}" do
      delivery = %Delivery{status: :succeeded, suppression_reason: nil}

      assert {:branchable, :delivered, evidence} = ProgressionOutcome.from_delivery(delivery, nil)

      assert evidence.delivery_status == "succeeded"
      assert evidence.suppression_reason == nil
      assert evidence.attempt_outcome == nil
      assert evidence.attempt_error_class == nil
    end

    test "suppressed: suppressed delivery resolves to {:branchable, :suppressed, evidence}" do
      delivery = %Delivery{status: :suppressed, suppression_reason: "channel_disabled"}

      assert {:branchable, :suppressed, evidence} =
               ProgressionOutcome.from_delivery(delivery, nil)

      assert evidence.delivery_status == "suppressed"
      assert evidence.suppression_reason == "channel_disabled"
    end

    test "temporary_failure: failed delivery resolves to {:branchable, :temporary_failure, evidence}" do
      delivery = %Delivery{status: :failed, suppression_reason: nil}
      attempt = %DeliveryAttempt{outcome: :failed, error_class: "temporary"}

      assert {:branchable, :temporary_failure, evidence} =
               ProgressionOutcome.from_delivery(delivery, attempt)

      assert evidence.delivery_status == "failed"
      assert evidence.attempt_outcome == "failed"
      assert evidence.attempt_error_class == "temporary"
    end

    test "retries_exhausted: cancelled delivery with retries_exhausted reason resolves to {:branchable, :retries_exhausted, evidence}" do
      delivery = %Delivery{status: :cancelled, suppression_reason: "retries_exhausted"}

      assert {:branchable, :retries_exhausted, evidence} =
               ProgressionOutcome.from_delivery(delivery, nil)

      assert evidence.delivery_status == "cancelled"
      assert evidence.suppression_reason == "retries_exhausted"
    end

    test "permanent_failure: cancelled delivery with permanent_failure reason resolves to {:branchable, :permanent_failure, evidence}" do
      delivery = %Delivery{status: :cancelled, suppression_reason: "permanent_failure"}
      attempt = %DeliveryAttempt{outcome: :rejected, error_class: "permanent"}

      assert {:branchable, :permanent_failure, evidence} =
               ProgressionOutcome.from_delivery(delivery, attempt)

      assert evidence.delivery_status == "cancelled"
      assert evidence.suppression_reason == "permanent_failure"
      assert evidence.attempt_outcome == "rejected"
      assert evidence.attempt_error_class == "permanent"
    end

    test "bounced: cancelled delivery with bounced reason resolves to {:branchable, :bounced, evidence}" do
      delivery = %Delivery{status: :cancelled, suppression_reason: "bounced"}
      attempt = %DeliveryAttempt{outcome: :bounced, error_class: "bounced"}

      assert {:branchable, :bounced, evidence} =
               ProgressionOutcome.from_delivery(delivery, attempt)

      assert evidence.delivery_status == "cancelled"
      assert evidence.suppression_reason == "bounced"
      assert evidence.attempt_outcome == "bounced"
      assert evidence.attempt_error_class == "bounced"
    end
  end

  describe "from_delivery/2 — non-branchable states (D-05)" do
    test "pending delivery resolves to :not_branchable_yet" do
      delivery = %Delivery{status: :pending, suppression_reason: nil}

      assert ProgressionOutcome.from_delivery(delivery, nil) == :not_branchable_yet
    end

    test "dispatched delivery resolves to :not_branchable_yet" do
      delivery = %Delivery{status: :dispatched, suppression_reason: nil}

      assert ProgressionOutcome.from_delivery(delivery, nil) == :not_branchable_yet
    end

    test "digested delivery resolves to :not_branchable_yet" do
      delivery = %Delivery{status: :digested, suppression_reason: nil}

      assert ProgressionOutcome.from_delivery(delivery, nil) == :not_branchable_yet
    end

    test "non-terminal rows stay unbranchable even when attempt evidence exists" do
      delivery = %Delivery{status: :pending, suppression_reason: nil}
      attempt = %DeliveryAttempt{outcome: :failed, error_class: "temporary"}

      assert ProgressionOutcome.from_delivery(delivery, attempt) == :not_branchable_yet
    end

    test "dispatched delivery with attempt evidence stays unbranchable" do
      delivery = %Delivery{status: :dispatched, suppression_reason: nil}
      attempt = %DeliveryAttempt{outcome: :succeeded, error_class: nil}

      assert ProgressionOutcome.from_delivery(delivery, attempt) == :not_branchable_yet
    end
  end

  describe "from_delivery/2 — degenerate cancelled buckets" do
    test "cancelled delivery with unknown suppression_reason returns :not_branchable_yet" do
      delivery = %Delivery{status: :cancelled, suppression_reason: "operator_intervention"}

      assert ProgressionOutcome.from_delivery(delivery, nil) == :not_branchable_yet
    end

    test "cancelled delivery with nil suppression_reason returns :not_branchable_yet" do
      delivery = %Delivery{status: :cancelled, suppression_reason: nil}

      assert ProgressionOutcome.from_delivery(delivery, nil) == :not_branchable_yet
    end
  end
end
