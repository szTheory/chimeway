defmodule Chimeway.Reliability.AttemptHistoryTest do
  @moduledoc """
  REL-02 — attempt history schema additions (D-07): attempt_number ordinality,
  error_class taxonomy, concurrent attempt_number race.

  Phase 14 Wave 0 scaffold. All describes are skipped until Plan 14-07 fills them in.
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban
  @moduletag :skip

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.ObanWorker, Repo}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "attempt_number ordinality (REL-02)" do
    test "first attempt for a delivery has attempt_number == 1" do
      # Filled in by Plan 14-07.
      # Anchor: keep aliases + helper imports referenced so --warnings-as-errors passes while skipped.
      _ = {Deliveries.terminal_states(), DeliveryAttempt, ObanWorker, Repo, &create_pending_delivery/0}
      assert true
    end

    test "subsequent attempts increment 1, 2, 3... contiguously" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "error_class taxonomy (REL-02)" do
    test "succeeded outcome -> error_class is nil" do
      # Filled in by Plan 14-07.
      assert true
    end

    test "temporary outcome -> error_class == \"temporary\"" do
      # Filled in by Plan 14-07.
      assert true
    end

    test "permanent outcome -> error_class == \"permanent\"" do
      # Filled in by Plan 14-07.
      assert true
    end

    test "bounced outcome -> error_class == \"bounced\"" do
      # Filled in by Plan 14-07.
      assert true
    end

    test "changeset rejects error_class outside the whitelist" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "concurrent attempt_number race (D-14, RESEARCH Pitfall 3)" do
    test "concurrent record_attempt calls do not duplicate attempt_number" do
      # Filled in by Plan 14-07. Pattern: Task.async_stream + Sandbox.allow.
      assert true
    end
  end
end
