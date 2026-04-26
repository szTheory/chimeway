defmodule Chimeway.Reliability.AttemptHistoryTest do
  @moduledoc """
  REL-02 D-07 / D-14 — attempt history schema additions.

  - `attempt_number` is 1-indexed and contiguous per delivery.
  - `error_class` persists "temporary" | "permanent" | "bounced" on failures, nil on success.
  - Changeset whitelist rejects values outside the taxonomy.
  - Concurrent `record_attempt` calls do not duplicate attempt_number for the same
    delivery (deterministic via Plan 14-04 W8 SELECT ... FOR UPDATE lock).
  - Telemetry [:attempts, :record, :stop] event metadata carries attempt_number
    and error_class (W3 — Phase 10 enrichment preserved).
  """

  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers
  import Ecto.Query, only: [from: 2]

  alias Chimeway.{Deliveries, DeliveryAttempt, Repo}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "attempt_number ordinality (REL-02 D-07)" do
    test "first attempt for a delivery has attempt_number == 1" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{
                 outcome: :succeeded,
                 error_class: nil,
                 provider_response: %{}
               })

      assert attempt.attempt_number == 1
    end

    test "subsequent attempts increment 1, 2, 3 contiguously" do
      %{delivery: delivery} = create_pending_delivery()

      attempt_numbers =
        for _ <- 1..3 do
          {:ok, dispatched} = Deliveries.transition_status(refresh(delivery), :dispatched)

          {:ok, %{attempt: attempt}} =
            Deliveries.record_attempt(dispatched, %{
              outcome: :failed,
              error_class: "temporary",
              provider_response: %{reason: "x"}
            })

          attempt.attempt_number
        end

      assert attempt_numbers == [1, 2, 3]
    end
  end

  describe "error_class taxonomy (REL-02 D-07)" do
    test ":succeeded outcome -> error_class is nil" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{
                 outcome: :succeeded,
                 error_class: nil,
                 provider_response: %{}
               })

      assert attempt.error_class == nil
    end

    test ":failed temporary outcome -> error_class == \"temporary\"" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{
                 outcome: :failed,
                 error_class: "temporary",
                 provider_response: %{}
               })

      assert attempt.error_class == "temporary"
    end

    test ":rejected permanent outcome -> error_class == \"permanent\"" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{
                 outcome: :rejected,
                 error_class: "permanent",
                 provider_response: %{}
               })

      assert attempt.error_class == "permanent"
    end

    test ":bounced outcome -> error_class == \"bounced\"" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      assert {:ok, %{attempt: attempt}} =
               Deliveries.record_attempt(dispatched, %{
                 outcome: :bounced,
                 error_class: "bounced",
                 provider_response: %{}
               })

      assert attempt.error_class == "bounced"
    end

    test "changeset rejects error_class outside the whitelist" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{
          delivery_id: Ecto.UUID.generate(),
          outcome: :failed,
          attempt_number: 1,
          error_class: "unknown_class"
        })

      refute changeset.valid?

      assert {"is invalid", _opts} = changeset.errors[:error_class]
    end

    test "DeliveryAttempt.error_classes/0 returns the canonical whitelist" do
      assert DeliveryAttempt.error_classes() == ["temporary", "permanent", "bounced"]
    end
  end

  describe "telemetry stop metadata (W3 — Phase 10 enrichment preserved)" do
    test "[:attempts, :record, :stop] event meta carries attempt_number and error_class" do
      handler_id = "test-attempts-record-#{:erlang.unique_integer([:positive])}"
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        handler_id,
        [:chimeway, :attempts, :record, :stop],
        fn _event, _measurements, meta, _config ->
          send(test_pid, {ref, meta})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      {:ok, %{attempt: _}} =
        Deliveries.record_attempt(dispatched, %{
          outcome: :failed,
          error_class: "temporary",
          provider_response: %{reason: "test"}
        })

      assert_receive {^ref, meta}, 1_000

      assert meta.attempt_number == 1
      assert meta.error_class == "temporary"
      # Phase 10 enrichment preserved (notification_key from delivery metadata).
      assert Map.has_key?(meta, :delivery_id)
      assert meta.delivery_id == delivery.id
    end
  end

  describe "concurrent attempt_number race (D-14 / RESEARCH Pitfall 3)" do
    test "10 concurrent W8 lock acquirers each get a unique attempt_number 1..10" do
      # W3 Approach B: prove the W8 SELECT FOR UPDATE lock prevents attempt_number
      # collisions, WITHOUT coupling the assertion to terminal-transition serialization.
      # The prior test let only 1-of-N tasks reach record_attempt/2 because
      # @allowed_transitions[:dispatched] does not include :dispatched (so the racing
      # transition_status calls returned :invalid_transition for 4-of-5). Here we hold the
      # delivery in :dispatched and exercise ONLY the (lock + count + insert) primitive
      # that record_attempt/2 itself uses for attempt_number contiguity.
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)
      parent = self()
      n = 10

      results =
        1..n
        |> Task.async_stream(
          fn _ ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

            Repo.transaction(fn ->
              # (a) Acquire SELECT FOR UPDATE on the delivery row — same primitive
              # record_attempt/2's :lock_delivery step uses.
              locked =
                Repo.one(
                  from(d in Chimeway.Delivery,
                    where: d.id == ^dispatched.id,
                    lock: "FOR UPDATE"
                  )
                )

              # (b) count(*) + 1 — same primitive record_attempt/2's
              # :next_attempt_number step uses (post-Task-1, scoped to locked.id).
              next_n =
                from(a in DeliveryAttempt,
                  where: a.delivery_id == ^locked.id,
                  select: count(a.id)
                )
                |> Repo.one()
                |> Kernel.+(1)

              # (c) Insert a DeliveryAttempt with the computed attempt_number.
              {:ok, attempt} =
                %DeliveryAttempt{}
                |> DeliveryAttempt.changeset(%{
                  delivery_id: locked.id,
                  outcome: :failed,
                  error_class: "temporary",
                  attempt_number: next_n,
                  provider_response: %{}
                })
                |> Repo.insert()

              attempt
            end)
          end,
          ordered: false,
          max_concurrency: n,
          timeout: 30_000
        )
        |> Enum.map(fn {:ok, {:ok, attempt}} -> attempt end)

      # Every acquirer must have committed its transaction (the lock serializes them).
      assert length(results) == n,
             "expected all #{n} W8 lock acquirers to commit; got #{length(results)}"

      attempt_numbers = Enum.map(results, & &1.attempt_number) |> Enum.sort()

      # Contiguous 1..n with no duplicates and no gaps — the W8 lock's whole purpose.
      assert attempt_numbers == Enum.to_list(1..n),
             "expected contiguous 1..#{n}; got #{inspect(attempt_numbers)}"

      # Persisted state matches what the tasks returned (no rollback drift).
      persisted =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^dispatched.id,
            order_by: a.attempt_number
          )
        )

      assert length(persisted) == n
      assert Enum.map(persisted, & &1.attempt_number) == Enum.to_list(1..n)
    end

    test "BL-01 regression: concurrent metadata writer (probe key) survives record_attempt/2" do
      # W4 fix: prove cancel_with_reason reads metadata from the LOCKED row, NOT
      # the closure snapshot. The probe key is written AFTER the snapshot but
      # BEFORE the lock acquisition — pre-fix, cancel_with_reason rebuilds metadata
      # from the stale snapshot and the probe key vanishes; post-fix, it reads from
      # the locked row and the probe key survives the Map.put("policy_checkpoint",
      # "perform") merge.
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      # SNAPSHOT: this is what record_attempt's closure will work from. Crucially,
      # at this moment delivery.metadata does NOT contain "test_marker".
      stale_snapshot = Deliveries.get_delivery!(dispatched.id)
      refute Map.has_key?(stale_snapshot.metadata || %{}, "test_marker")

      # CONCURRENT WRITER: write the probe key directly via Repo.update. This is
      # the metadata write that BL-01 silently clobbers in the pre-fix code path.
      # We use Repo.update (not suppress_delivery/3) because suppress_delivery/3
      # does not accept arbitrary metadata via opts (deliveries.ex:138-159).
      pre_record_metadata =
        (stale_snapshot.metadata || %{})
        |> Map.put("test_marker", "from_concurrent_writer")

      {:ok, _} =
        dispatched
        |> Ecto.Changeset.change(metadata: pre_record_metadata)
        |> Repo.update()

      # NOW call record_attempt with the STALE snapshot. The closure delivers
      # `dispatched` (no test_marker) into record_attempt; the :lock_delivery step
      # SELECT FOR UPDATEs the row (which DOES have test_marker because the
      # writer above committed); the post-Task-1 fix threads `locked` (with
      # test_marker) into cancel_with_reason via terminal_or_failed_transition.
      #
      # error_class "permanent" routes to cancel_with_reason, which is the BL-01
      # site (deliveries.ex:318-331).
      {:ok, %{delivery: returned}} =
        Deliveries.record_attempt(stale_snapshot, %{
          outcome: :rejected,
          error_class: "permanent",
          provider_response: %{}
        })

      reloaded = Deliveries.get_delivery!(delivery.id)

      # Sanity: cancel_with_reason DID run (proving the test_marker survival is
      # not because the cancel path was skipped).
      assert reloaded.status == :cancelled
      assert reloaded.suppression_reason == "permanent_failure"
      assert returned.status == :cancelled
      assert reloaded.metadata["policy_checkpoint"] == "perform"

      # THE CORE ASSERTION: a metadata write that the closure snapshot CANNOT
      # have seen MUST survive cancel_with_reason. If this assertion fails,
      # cancel_with_reason rebuilt metadata from the stale closure snapshot
      # (BL-01 has regressed).
      assert reloaded.metadata["test_marker"] == "from_concurrent_writer",
             "BL-01 regression: probe key written between snapshot and lock " <>
               "acquisition was clobbered by stale-closure metadata write. " <>
               "reloaded.metadata = #{inspect(reloaded.metadata)}"
    end
  end

  defp refresh(%Chimeway.Delivery{id: id}), do: Deliveries.get_delivery!(id)
end
