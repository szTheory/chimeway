defmodule Chimeway.WebhooksTest do
  use Chimeway.DataCase, async: true
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.Repo
  alias Chimeway.Webhooks
  import Chimeway.Test.DispatchHelpers, only: [create_pending_delivery: 0]

  defmodule MockAdapter do
    @behaviour Chimeway.Adapter

    def deliver(_delivery, _config), do: {:ok, %{}}

    def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
    def verify_webhook(_, _, _config), do: {:error, :unauthorized}

    # Loosened to accept any binary id so UUID-shaped values pass the
    # schema's :binary_id cast cleanly (literal "del_123" would Postgrex-error
    # at insert because it is not a valid UUID). Phase 33 plan 02 Task 3.
    def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}

    def resolve_delivery(%{"msg_id" => pid}) when is_binary(pid),
      do: {:ok, %{provider_message_id: pid}}

    def resolve_delivery(_), do: :error

    def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
    def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
    def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
    def normalize_feedback(_), do: :error

    # Optional A4 callback for dedup tests (resolve_provider_event_id/1).
    def resolve_provider_event_id(%{"event_id" => id}) when is_binary(id), do: {:ok, id}
    def resolve_provider_event_id(_), do: :none
  end

  defmodule ParseBodyAdapter do
    @behaviour Chimeway.Adapter

    def deliver(_delivery, _config), do: {:ok, %{}}

    def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
    def verify_webhook(_, _, _config), do: {:error, :unauthorized}

    def parse_webhook_body(_raw_body, _headers, _config), do: {:ok, %{"custom" => true}}

    def resolve_delivery(%{"custom" => true}),
      do: {:ok, %{provider_message_id: "parsed-msg-id"}}

    def resolve_delivery(_), do: :error

    def normalize_feedback(%{"custom" => true}), do: {:ok, %{status: :delivered}}
    def normalize_feedback(_), do: :error
  end

  # FailingOnInsertAdapter is used for rollback tests (T-33-ATOMIC).
  # Its normalize_feedback/1 returns {:ok, %{status: :unknown_status}} — a status
  # atom NOT in ~w(delivered bounced failed). This passes the with-chain
  # (process/4 accepts {:ok, _} shapes), so execution reaches Multi.new().
  # The Ingress changeset's validate_inclusion(:normalized_status, ...) then fails
  # the :ingress Multi step at the CHANGESET level, yielding
  # {:error, :ingress, %Ecto.Changeset{}, _} from Repo.transaction/1.
  # This is exactly the rollback path that proves T-33-ATOMIC.
  # Using a real UUID for delivery_id ensures the :binary_id cast passes cleanly;
  # the failure is isolated to validate_inclusion, not a Postgrex cast error.
  defmodule FailingOnInsertAdapter do
    @behaviour Chimeway.Adapter

    def deliver(_, _), do: {:ok, %{}}
    def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
    def verify_webhook(_, _, _), do: {:error, :unauthorized}

    # Returns a real UUID so the :delivery_id field passes binary_id cast.
    # The changeset failure mechanism is normalize_feedback below — NOT delivery_id.
    def resolve_delivery(%{"id" => id}) when is_binary(id), do: {:ok, %{delivery_id: id}}
    def resolve_delivery(_), do: :error

    # FAILURE MECHANISM: returns a status atom NOT in ~w(delivered bounced failed).
    # validate_inclusion(:normalized_status, ...) fails the changeset at the :ingress
    # Multi step, which is exactly the rollback path we need to exercise.
    def normalize_feedback(_), do: {:ok, %{status: :unknown_status}}
  end

  describe "process/4" do
    test "returns {:error, :unauthorized} if verification fails" do
      assert {:error, :unauthorized} =
               Webhooks.process(MockAdapter, "invalid_body", [{"signature", "invalid"}], [])
    end

    test "returns {:error, :unresolvable_delivery} if delivery cannot be resolved" do
      body = Jason.encode!(%{"status" => "ok"})

      assert {:error, :unresolvable_delivery} =
               Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
    end

    test "returns {:error, :unnormalizable_feedback} if feedback cannot be normalized" do
      body = Jason.encode!(%{"msg_id" => "some-msg", "status" => "unknown"})

      assert {:error, :unnormalizable_feedback} =
               Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
    end

    test "returns {:error, :unparseable_body} if body is not valid JSON" do
      assert {:error, :unparseable_body} =
               Webhooks.process(MockAdapter, "not-json", [{"signature", "valid"}], [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
    end

    test "uses parse_webhook_body/3 when exported instead of Jason.decode" do
      assert {:ok, %Chimeway.Webhooks.Ingress{} = ingress} =
               Webhooks.process(ParseBodyAdapter, "not-json", [{"signature", "valid"}], [])

      assert persisted = Repo.get!(Chimeway.Webhooks.Ingress, ingress.id)
      assert persisted.provider_message_id == "parsed-msg-id"
      assert persisted.normalized_status == "delivered"
      assert persisted.ingress_state == :queued

      assert_enqueued(
        worker: Chimeway.Webhooks.ProcessFeedbackWorker,
        args: %{"ingress_id" => ingress.id}
      )
    end

    test "returns {:ok, %Ingress{}} on success with provider_message_id and atomically enqueues job" do
      body = Jason.encode!(%{"msg_id" => "msg_123", "status" => "bounce"})

      assert {:ok, %Chimeway.Webhooks.Ingress{} = ingress} =
               Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      # Ingress row durably committed
      assert persisted = Repo.get!(Chimeway.Webhooks.Ingress, ingress.id)
      assert persisted.adapter_module == to_string(MockAdapter)
      assert persisted.provider_message_id == "msg_123"
      assert persisted.delivery_id == nil
      assert persisted.normalized_status == "bounced"
      assert persisted.ingress_state == :queued

      # T-33-PII: persisted ingress row has NO raw payload columns
      refute Map.has_key?(Map.from_struct(persisted), :provider_response)
      refute Map.has_key?(Map.from_struct(persisted), :headers)

      # Atomic Oban handoff
      assert_enqueued(
        worker: Chimeway.Webhooks.ProcessFeedbackWorker,
        args: %{"ingress_id" => ingress.id}
      )
    end

    test "returns {:ok, %Ingress{}} on success with delivery_id and atomically enqueues job" do
      # Requires a real delivery row because chimeway_webhook_ingress.delivery_id
      # has a FK to chimeway_deliveries (on_delete: :nilify_all). Using a random UUID
      # would raise Ecto.ConstraintError at the DB level.
      %{delivery: delivery} = create_pending_delivery()
      delivery_uuid = delivery.id
      body = Jason.encode!(%{"id" => delivery_uuid, "status" => "bounce"})

      assert {:ok, %Chimeway.Webhooks.Ingress{} = ingress} =
               Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      # Ingress row durably committed
      assert persisted = Repo.get!(Chimeway.Webhooks.Ingress, ingress.id)
      assert persisted.adapter_module == to_string(MockAdapter)
      assert persisted.delivery_id == delivery_uuid
      assert persisted.normalized_status == "bounced"
      assert persisted.ingress_state == :queued

      # T-33-PII: persisted ingress row has NO raw payload columns
      refute Map.has_key?(Map.from_struct(persisted), :provider_response)
      refute Map.has_key?(Map.from_struct(persisted), :headers)

      # Atomic Oban handoff
      assert_enqueued(
        worker: Chimeway.Webhooks.ProcessFeedbackWorker,
        args: %{"ingress_id" => ingress.id}
      )
    end
  end

  describe "process/4 — dedup convergence (T-33-DEDUP / D-05)" do
    test "duplicate provider retries with same (adapter_module, provider_event_id) collapse to ONE ingress row" do
      # Use "msg_id" so resolve_delivery/1 sets provider_message_id (not delivery_id),
      # avoiding a FK constraint against chimeway_deliveries on a random UUID.
      body =
        Jason.encode!(%{"msg_id" => "msg_dedup_001", "status" => "ok", "event_id" => "evt_001"})

      headers = [{"signature", "valid"}]

      assert {:ok, %Chimeway.Webhooks.Ingress{} = first} =
               Webhooks.process(MockAdapter, body, headers, [])

      assert first.provider_event_id == "evt_001"

      # Provider retry — same body, same headers, same event_id
      assert {:ok, %Chimeway.Webhooks.Ingress{} = second} =
               Webhooks.process(MockAdapter, body, headers, [])

      # Both calls return success cleanly — neither surfaces the partial-unique conflict
      # to the host (D-03: 2xx on both).
      # Crucially: ONE durable ingress row, not two. The on_conflict: :nothing in
      # Multi.insert(:ingress, ..., conflict_target: ..., where: provider_event_id IS NOT NULL)
      # absorbs the duplicate at the DB level (T-33-DEDUP closed).
      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 1
      assert first.provider_event_id == second.provider_event_id
    end

    test "different event_ids for same adapter produce TWO ingress rows (negative control)" do
      # Use "msg_id" so resolve_delivery/1 sets provider_message_id (not delivery_id),
      # avoiding a FK constraint against chimeway_deliveries.
      body1 =
        Jason.encode!(%{"msg_id" => "msg_neg_001", "status" => "ok", "event_id" => "evt_001"})

      body2 =
        Jason.encode!(%{"msg_id" => "msg_neg_002", "status" => "ok", "event_id" => "evt_002"})

      headers = [{"signature", "valid"}]

      assert {:ok, _first} = Webhooks.process(MockAdapter, body1, headers, [])
      assert {:ok, _second} = Webhooks.process(MockAdapter, body2, headers, [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2
    end

    test "missing event_id (NULL provider_event_id) does NOT trigger dedup — exercises NULL-distinct semantics that the partial index preserves" do
      # NOTE on what this test actually verifies (warning #9 disposition):
      # This exercises PostgreSQL's standard NULL-distinct semantics — two NULL
      # values do not collide on a unique index regardless of the WHERE clause
      # on PG <= 14. The partial index `WHERE provider_event_id IS NOT NULL`
      # PRESERVES that semantic by excluding NULL rows from the index entirely.
      # On PG >= 15, `NULLS NOT DISTINCT` could change this behavior on a full
      # unique index, but the partial index defended-by-WHERE here remains
      # NULL-distinct by construction.
      # The test's verification value is in describing the design intent —
      # the assertion (`count == 2`) holds equally with or without the WHERE clause
      # on PG <= 14, but the WHERE clause is what makes the design correct on
      # arbitrary PG versions and explicitly documents the NULL-tolerant intent.
      # Two distinct deliveries (different UUIDs) are used so the rows are not
      # collapsed by some other adapter-side dedup mechanism.
      # Use "msg_id" so resolve_delivery/1 sets provider_message_id (not delivery_id),
      # avoiding a FK constraint against chimeway_deliveries.
      # no "event_id"
      body1 = Jason.encode!(%{"msg_id" => "msg_null_001", "status" => "ok"})
      # no "event_id"
      body2 = Jason.encode!(%{"msg_id" => "msg_null_002", "status" => "ok"})
      headers = [{"signature", "valid"}]

      assert {:ok, first} = Webhooks.process(MockAdapter, body1, headers, [])
      assert first.provider_event_id == nil

      assert {:ok, second} = Webhooks.process(MockAdapter, body2, headers, [])
      assert second.provider_event_id == nil

      # Pitfall 5 design: partial index `WHERE provider_event_id IS NOT NULL`
      # means NULLs are excluded from the index — NULL rows do not collide.
      # See PG >= 15 NULLS NOT DISTINCT for completeness.
      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 2
    end
  end

  describe "process/4 — atomic handoff (T-33-ATOMIC)" do
    test "rolls back the ingress row when the :ingress Multi step changeset fails" do
      # Use FailingOnInsertAdapter — its normalize_feedback/1 returns
      # {:ok, %{status: :unknown_status}}, which fails the schema's
      # validate_inclusion(:normalized_status, ~w(delivered bounced failed))
      # AT THE CHANGESET LEVEL inside the :ingress Multi step. This produces
      # an Ecto.Changeset error (the assertion target), unlike a raw
      # binary_id-cast/Postgres failure which would surface as Postgrex.Error.
      # delivery_id uses a real delivery so the FK cast passes; the failure
      # is isolated to validate_inclusion on :normalized_status.
      %{delivery: delivery} = create_pending_delivery()
      body = Jason.encode!(%{"id" => delivery.id, "status" => "ok"})

      assert {:error, %Ecto.Changeset{} = cs} =
               Webhooks.process(FailingOnInsertAdapter, body, [{"signature", "valid"}], [])

      # The changeset error is on :normalized_status (validate_inclusion failure).
      assert cs.errors[:normalized_status]

      # T-33-ATOMIC: NO ingress row, NO Oban job — both side effects rolled back atomically
      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
      refute_enqueued(worker: Chimeway.Webhooks.ProcessFeedbackWorker)
    end

    test "unauthorized signature creates NO ingress row (D-09 / T-33-AUTH-LEAK)" do
      assert {:error, :unauthorized} =
               Webhooks.process(MockAdapter, "any", [{"signature", "invalid"}], [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
      refute_enqueued(worker: Chimeway.Webhooks.ProcessFeedbackWorker)
    end

    test "unparseable body creates NO ingress row (D-09)" do
      # Note: body is sent BEFORE Jason.decode happens because verify_webhook
      # runs first; valid signature header lets us reach Jason.decode
      assert {:error, :unparseable_body} =
               Webhooks.process(MockAdapter, "not-json", [{"signature", "valid"}], [])

      assert Repo.aggregate(Chimeway.Webhooks.Ingress, :count) == 0
      refute_enqueued(worker: Chimeway.Webhooks.ProcessFeedbackWorker)
    end
  end
end
