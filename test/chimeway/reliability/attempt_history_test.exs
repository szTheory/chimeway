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
    test "concurrent record_attempt calls produce contiguous attempt_numbers (W8 row lock)" do
      %{delivery: delivery} = create_pending_delivery()
      parent = self()

      _results =
        1..5
        |> Task.async_stream(
          fn n ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            current = Deliveries.get_delivery!(delivery.id)

            with {:ok, dispatched} <- Deliveries.transition_status(current, :dispatched) do
              Deliveries.record_attempt(dispatched, %{
                outcome: :failed,
                error_class: "temporary",
                provider_response: %{seq: n}
              })
            else
              {:error, _} = err -> err
            end
          end,
          ordered: false,
          max_concurrency: 5,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id,
            order_by: a.attempt_number
          )
        )

      attempt_numbers = Enum.map(attempts, & &1.attempt_number)

      # The W8 row lock in record_attempt/2 (Plan 14-04 Task 2 — SELECT FOR UPDATE)
      # serializes concurrent callers. Duplicate attempt_number is impossible.
      assert length(attempts) == length(Enum.uniq(attempt_numbers)),
             "duplicate attempt_number observed: #{inspect(attempt_numbers)}"

      sorted = Enum.sort(attempt_numbers)
      expected = Enum.to_list(1..length(attempts))

      assert sorted == expected,
             "attempt_numbers should be contiguous 1..N; got #{inspect(sorted)}, expected #{inspect(expected)}"
    end
  end

  defp refresh(%Chimeway.Delivery{id: id}), do: Deliveries.get_delivery!(id)
end
