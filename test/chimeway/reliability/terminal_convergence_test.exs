defmodule Chimeway.Reliability.TerminalConvergenceTest do
  @moduledoc """
  REL-03 D-12 — every delivery converges to Deliveries.terminal_states/0.

  Phase 14 Wave 0 scaffold. All describes are skipped until Plan 14-07 fills them in.
  """

  use Chimeway.DataCase, async: false

  alias Chimeway.{Deliveries, Repo}

  @moduletag :skip

  describe "succeeded path (D-12)" do
    test "delivery converges to :succeeded after adapter ok" do
      # Filled in by Plan 14-07. Must assert delivery.status in Deliveries.terminal_states().
      # Anchor: keep aliases referenced so --warnings-as-errors passes while skipped.
      _ = {Deliveries.terminal_states(), Repo}
      assert true
    end
  end

  describe "retries_exhausted path (D-12)" do
    test "delivery converges to :cancelled / retries_exhausted after Oban gives up" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "permanent_failure path (D-12)" do
    test "delivery converges to :cancelled / permanent_failure on permanent adapter error" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "bounced path (D-12)" do
    test "delivery converges to :cancelled / bounced on bounced adapter error" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "suppressed path (D-12)" do
    test "policy suppression at planning checkpoint converges to :suppressed" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "manual cancelled path (D-12)" do
    test "manual transition to :cancelled converges as terminal" do
      # Filled in by Plan 14-07.
      assert true
    end
  end
end
