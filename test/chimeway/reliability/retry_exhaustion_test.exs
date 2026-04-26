defmodule Chimeway.Test.RetryFailingAdapter do
  @moduledoc """
  Test adapter that always returns {:error, :temporary, _}. Used by retry_exhaustion_test.exs.
  Defined at file top-level so it compiles before the test module references it.
  """
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Reliability.RetryExhaustionTest do
  @moduledoc """
  REL-02 — Oban-driven retry contract: transient -> {:error, _} for retry,
  permanent/bounced -> :ok no retry, max_attempts -> :cancelled retries_exhausted.

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

  describe "transient failure on attempt 1..n-1 returns {:error, _} (REL-02)" do
    test "perform_job/3 with attempt: 1 returns {:error, _} when adapter is :temporary" do
      # Filled in by Plan 14-07.
      # Anchor: keep aliases + helper imports referenced so --warnings-as-errors passes while skipped.
      _ = {Deliveries.terminal_states(), DeliveryAttempt, ObanWorker, Repo, &create_pending_delivery/0}
      assert true
    end

    test "delivery row stays :failed (not yet :cancelled) on intermediate attempts" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "exhaustion on final attempt (REL-02 / D-10 / D-11)" do
    test "perform_job/3 with attempt: max_attempts writes :cancelled retries_exhausted and returns :ok" do
      # Filled in by Plan 14-07.
      assert true
    end

    test "exhaustion sets suppression_reason to \"retries_exhausted\"" do
      # Filled in by Plan 14-07.
      assert true
    end
  end

  describe "drain_queue end-to-end exhaustion (REL-02 integration)" do
    @tag :integration
    test "always-failing adapter drains 5 attempts then converges to terminal :cancelled" do
      # Filled in by Plan 14-07.
      assert true
    end
  end
end
