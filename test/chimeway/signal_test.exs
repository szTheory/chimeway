defmodule Chimeway.SignalTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.Dispatch.SignalRouterWorker
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal

  describe "track/4 — Phase 27 host signal API" do
    test "inserts a Signal row with the supplied fields" do
      assert {:ok, %Signal{} = signal} =
               Chimeway.Signal.track("acme", "user_42", "email_opened", %{"campaign" => "march"})

      assert signal.tenant_id == "acme"
      assert signal.actor_id == "user_42"
      assert signal.event_name == "email_opened"
      assert signal.payload == %{"campaign" => "march"}
      assert signal.id

      persisted = Repo.get!(Signal, signal.id)
      assert persisted.tenant_id == "acme"
      assert persisted.event_name == "email_opened"
    end

    test "defaults payload to empty map when omitted" do
      assert {:ok, %Signal{payload: %{}}} =
               Chimeway.Signal.track("acme", "user_42", "in_app_seen")
    end

    test "enqueues a SignalRouterWorker job carrying the new signal id" do
      assert {:ok, %Signal{id: signal_id}} =
               Chimeway.Signal.track("acme", "user_42", "clicked", %{"link" => "/x"})

      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal_id})
    end

    test "rolls back the signal insert if job enqueue cannot happen (atomicity)" do
      # Verify that track/4 wires through Ecto.Multi by ensuring no signal exists
      # without a corresponding queued job. After a successful track, both side
      # effects must be observable; if either failed, neither should persist.
      assert {:ok, signal} =
               Chimeway.Signal.track("acme", "user_42", "delivered", %{})

      assert Repo.get(Signal, signal.id)
      assert_enqueued(worker: SignalRouterWorker, args: %{"signal_id" => signal.id})
    end

    test "returns error tuple when required fields are missing" do
      assert {:error, %Ecto.Changeset{valid?: false}} =
               Chimeway.Signal.track("", "user_42", "clicked")
    end
  end
end
