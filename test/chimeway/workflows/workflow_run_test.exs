defmodule Chimeway.Workflows.WorkflowRunTest do
  use ExUnit.Case, async: true

  alias Chimeway.Workflows.WorkflowRun

  describe "changeset/2 — Phase 27 State Spine fields" do
    @base_required %{
      notification_id: Ecto.UUID.generate(),
      workflow_definition_id: Ecto.UUID.generate(),
      current_step_id: Ecto.UUID.generate(),
      state: :active,
      started_at: DateTime.utc_now(),
      last_transition_at: DateTime.utc_now(),
      status_reason: "started"
    }

    test "accepts all four spine fields when tenant_id is provided" do
      now = DateTime.utc_now()

      attrs =
        Map.merge(@base_required, %{
          tenant_id: "acme",
          suspended_until: now,
          pending_signals: ["read", "clicked"],
          terminal_reason: "exhausted"
        })

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :tenant_id) == "acme"
      assert Ecto.Changeset.get_field(changeset, :suspended_until) == now
      assert Ecto.Changeset.get_field(changeset, :pending_signals) == ["read", "clicked"]
      assert Ecto.Changeset.get_field(changeset, :terminal_reason) == "exhausted"
    end

    test "tenant_id is required" do
      changeset = WorkflowRun.changeset(%WorkflowRun{}, @base_required)

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:tenant_id]
    end

    test "spine fields other than tenant_id are optional" do
      attrs = Map.put(@base_required, :tenant_id, "acme")

      changeset = WorkflowRun.changeset(%WorkflowRun{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :suspended_until) == nil
      assert Ecto.Changeset.get_field(changeset, :pending_signals) == []
      assert Ecto.Changeset.get_field(changeset, :terminal_reason) == nil
    end
  end
end
