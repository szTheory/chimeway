defmodule Chimeway.Test.ObanWorkerFailingAdapter do
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "test_failure"}}
end

defmodule Chimeway.Test.ObanWorkerCaptureConfigAdapter do
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, config) do
    capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

    if is_pid(capture_pid) do
      send(capture_pid, {:adapter_config, config})
    end

    {:ok, %{adapter: "capture"}}
  end
end

defmodule Chimeway.Test.ObanWorkerExecutionNotifier do
  @behaviour Chimeway.Notifier

  def notification_key, do: "oban.worker.execution"
  def version, do: 1
  def recipients(_params), do: {:ok, []}
  def build(_params, _recipient), do: {:ok, %{}}
  def channels(_params, _recipient), do: {:ok, [:email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "private subject",
         "html_body" => "<p>private body</p>",
         "text_body" => "private body"
       },
       channels: %{email: %{render_key: "oban.worker.execution.email", render_version: 1}}
     }}
  end
end

defmodule Chimeway.Test.ObanWorkerExecutionResolver do
  @behaviour Chimeway.RenderContextResolver

  @impl true
  def resolve("oban.worker.execution", 1, recipient_ref) do
    if pid = Application.get_env(:chimeway, :oban_worker_resolver_pid), do: send(pid, :resolved)

    {:ok,
     %{
       notifier: Chimeway.Test.ObanWorkerExecutionNotifier,
       params: %{},
       recipient: %{recipient_ref: recipient_ref, recipient_identity: "user:private@example.test"}
     }}
  end

  def resolve(_, _, _), do: {:error, :render_context_unavailable}
end

defmodule Chimeway.Test.ObanWorkerUnavailableContextResolver do
  @behaviour Chimeway.RenderContextResolver

  @impl true
  def resolve(_, _, _),
    do:
      {:error,
       {:host_context_unavailable,
        %{recipient: "raw-recipient-sentinel@example.test", rendered: "raw-render-sentinel"}}}
end

defmodule Chimeway.Test.ObanWorkerCaptureDeliveryAdapter do
  @behaviour Chimeway.Adapter

  @impl true
  def deliver(delivery, _config) do
    if pid = Application.get_env(:chimeway, :adapter_capture_pid),
      do: send(pid, {:delivery, delivery})

    {:ok, %{adapter: "capture"}}
  end
end

defmodule Chimeway.Dispatch.ObanWorkerTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :oban

  import Chimeway.Test.DispatchHelpers

  alias Chimeway.{Deliveries, DeliveryAttempt, Dispatch.ObanWorker, Repo, Traces}

  setup do
    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    end)

    :ok
  end

  describe "perform/1 success path" do
    test "records one attempt and transitions delivery to :succeeded" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded

      attempts =
        Repo.all(from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id))

      assert length(attempts) == 1
      assert hd(attempts).outcome == :succeeded
    end
  end

  describe "execution-time email hydration" do
    test "resolves private email context only immediately before adapter handoff" do
      previous_adapter = Application.get_env(:chimeway, :adapter)
      previous_resolvers = Application.get_env(:chimeway, :render_context_resolvers)

      on_exit(fn ->
        Application.put_env(:chimeway, :adapter, previous_adapter)
        Application.put_env(:chimeway, :render_context_resolvers, previous_resolvers)
        Application.delete_env(:chimeway, :adapter_capture_pid)
        Application.delete_env(:chimeway, :oban_worker_resolver_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerCaptureDeliveryAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())
      Application.put_env(:chimeway, :oban_worker_resolver_pid, self())

      Application.put_env(:chimeway, :render_context_resolvers, %{
        {"oban.worker.execution", 1} => Chimeway.Test.ObanWorkerExecutionResolver
      })

      %{notification: notification, delivery: delivery} =
        create_pending_delivery(
          channel: :email,
          notification_key: "oban.worker.execution",
          recipient_identity: "opaque-recipient-ref"
        )

      {:ok, _notification} =
        notification
        |> Ecto.Changeset.change(
          render_channels: %{
            "email" => %{
              "render_key" => "oban.worker.execution.email",
              "render_version" => 1
            }
          }
        )
        |> Repo.update()

      {:ok, _delivery} =
        delivery
        |> Ecto.Changeset.change(render_key: "oban.worker.execution.email", render_version: 1)
        |> Repo.update()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert_receive :resolved

      assert_receive {:delivery, hydrated}
      assert hydrated.recipient_address == "private@example.test"
      assert hydrated.render_data["html_body"] == "<p>private body</p>"

      reloaded = Deliveries.get_delivery!(delivery.id)
      assert reloaded.render_data == %{}
      refute inspect(reloaded) =~ "private@example.test"
      refute inspect(reloaded) =~ "private body"
    end
  end

  describe "unavailable execution context" do
    test "records bounded safe evidence before retry and retains it through exhaustion" do
      previous_resolvers = Application.get_env(:chimeway, :render_context_resolvers)

      on_exit(fn ->
        restore_env(:render_context_resolvers, previous_resolvers)
      end)

      Application.put_env(:chimeway, :render_context_resolvers, %{
        {"oban.worker.unavailable-context", 1} =>
          Chimeway.Test.ObanWorkerUnavailableContextResolver
      })

      %{notification: notification, delivery: delivery} =
        create_pending_delivery(
          channel: :email,
          notification_key: "oban.worker.unavailable-context",
          recipient_identity: "cw_recipient_safe_reference",
          tenant_id: "unavailable-context-tenant"
        )

      {:ok, _notification} =
        notification
        |> Ecto.Changeset.change(
          render_channels: %{
            "email" => %{
              "render_key" => "oban.worker.unavailable-context.email",
              "render_version" => 1
            }
          }
        )
        |> Repo.update()

      {:ok, _delivery} =
        delivery
        |> Ecto.Changeset.change(
          render_key: "oban.worker.unavailable-context.email",
          render_version: 1
        )
        |> Repo.update()

      assert {:error, :render_context_unavailable} =
               perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1, max_attempts: 5)

      [first_attempt] = attempts_for(delivery.id)
      assert first_attempt.outcome == :failed
      assert first_attempt.error_class == "render_context_unavailable"
      assert first_attempt.provider_message_id == nil
      assert first_attempt.provider_response == %{}
      assert first_attempt.attempt_number == 1
      assert Deliveries.get_delivery!(delivery.id).status == :failed

      for attempt <- 2..4 do
        assert {:error, :render_context_unavailable} =
                 perform_job(ObanWorker, %{delivery_id: delivery.id},
                   attempt: attempt,
                   max_attempts: 5
                 )
      end

      assert :ok =
               perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5, max_attempts: 5)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "retries_exhausted"

      attempts = attempts_for(delivery.id)
      assert Enum.map(attempts, & &1.attempt_number) == [1, 2, 3, 4, 5]

      assert {:ok, trace} = Traces.explain_delivery(delivery.id, tenant_id: delivery.tenant_id)
      assert trace.status == :cancelled
      assert trace.suppression_reason == "retries_exhausted"
      assert trace.last_attempt.outcome == :failed
      assert trace.last_attempt.error_class == "render_context_unavailable"

      serialized = inspect(%{attempts: attempts, result: trace, delivery: updated})
      refute serialized =~ "raw-recipient-sentinel@example.test"
      refute serialized =~ "raw-render-sentinel"
      refute serialized =~ "host_context_unavailable"
    end
  end

  describe "perform/1 idempotency" do
    test "running perform twice creates exactly one attempt row" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})

      attempts =
        Repo.all(from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^delivery.id))

      assert length(attempts) == 1
    end
  end

  describe "terminal state short-circuit" do
    test "returns :ok for :succeeded delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

      {:ok, _result} =
        Deliveries.record_attempt(dispatched, %{outcome: :succeeded, provider_response: %{}})

      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :suppressed delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _suppressed} = Deliveries.suppress_delivery(delivery, :channel_disabled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end

    test "returns :ok for :cancelled delivery without adapter call" do
      %{delivery: delivery} = create_pending_delivery()
      {:ok, _cancelled} = Deliveries.transition_status(delivery, :cancelled)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert Chimeway.Adapters.Test.delivered_messages() == []
    end
  end

  describe "adapter error path and retry (REL-02 D-04 / D-13 rewrite)" do
    test "transient failure on attempt 1 returns {:error, _} so Oban schedules retry" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      assert {:error, _reason} =
               perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :failed
      assert updated.suppression_reason == nil
      refute updated.status in Deliveries.terminal_states()

      [attempt] = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
      assert attempt.outcome == :failed
      assert attempt.error_class == "temporary"
      assert attempt.attempt_number == 1
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end

    test "succeeded retry: subsequent attempt with healthy adapter completes the delivery" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      # Attempt 1 fails with temporary, returns {:error, _}.
      assert {:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 1)
      assert Deliveries.get_delivery!(delivery.id).status == :failed

      # Adapter recovers; attempt 2 succeeds.
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Chimeway.Adapters.Test.clear()
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 2)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :succeeded
      assert updated.status in Deliveries.terminal_states()

      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 2
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end

    test "exhaustion on final attempt writes :cancelled retries_exhausted and returns :ok (Pitfall 1)" do
      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerFailingAdapter)
      %{delivery: delivery} = create_pending_delivery()

      # Attempts 1..4 fail and return {:error, _}.
      for n <- 1..4 do
        assert {:error, _} = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: n)
      end

      # Attempt 5 == max_attempts: in-band exhaustion guard writes :cancelled retries_exhausted
      # then returns :ok so Oban marks the job :completed (not :discarded).
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id}, attempt: 5)

      updated = Deliveries.get_delivery!(delivery.id)
      assert updated.status == :cancelled
      assert updated.suppression_reason == "retries_exhausted"
      assert updated.status in Deliveries.terminal_states()
    after
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    end
  end

  describe "perform-time delayed fallback suppression" do
    test "already-read delayed fallback delivery records no attempts (POLC-03)" do
      fixture =
        create_pending_delivery(
          notification_key: "oban.worker.delayed.fallback",
          delay_fallback: true
        )

      mark_notification_read(fixture)
      Chimeway.Adapters.Test.clear()

      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})

      updated = Deliveries.get_delivery!(fixture.delivery.id)
      assert delivery_signature(updated) == already_read_suppression_signature()
      assert Chimeway.Adapters.Test.delivered_messages() == []

      attempt_count =
        Repo.aggregate(
          from(attempt in DeliveryAttempt, where: attempt.delivery_id == ^fixture.delivery.id),
          :count
        )

      assert attempt_count == 0
    end
  end

  describe "custom channel adapter config resolution" do
    test "INTG-02: oban worker uses channel_adapter_configs for sms_custom" do
      # INTG-02: shared executor resolves preferred string-keyed custom channel config.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "sms_custom" => [provider: "acme_sms", timeout_ms: 1500]
      })

      Application.delete_env(:chimeway, :adapter_sms_custom)

      fixture = create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "acme_sms", timeout_ms: 1500]}
      assert Deliveries.get_delivery!(fixture.delivery.id).status == :succeeded
    end

    test "INTG-02: oban worker supports legacy adapter_sms_custom fallback" do
      # INTG-02: legacy adapter_<channel> key lookup remains backward compatible.
      previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)
      previous_legacy_config = Application.get_env(:chimeway, :adapter_sms_custom)
      previous_capture_pid = Application.get_env(:chimeway, :adapter_capture_pid)

      on_exit(fn ->
        restore_env(:channel_adapter_configs, previous_channel_configs)
        restore_env(:adapter_sms_custom, previous_legacy_config)
        restore_env(:adapter_capture_pid, previous_capture_pid)
      end)

      Application.put_env(:chimeway, :adapter, Chimeway.Test.ObanWorkerCaptureConfigAdapter)
      Application.put_env(:chimeway, :adapter_capture_pid, self())
      Application.delete_env(:chimeway, :channel_adapter_configs)
      Application.put_env(:chimeway, :adapter_sms_custom, provider: "legacy_sms")

      fixture = create_pending_delivery(channel: "sms_custom")
      assert :ok = perform_job(ObanWorker, %{delivery_id: fixture.delivery.id})
      assert_receive {:adapter_config, [provider: "legacy_sms"]}
      assert Deliveries.get_delivery!(fixture.delivery.id).status == :succeeded
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:chimeway, key)
  defp restore_env(key, value), do: Application.put_env(:chimeway, key, value)

  defp attempts_for(delivery_id) do
    Repo.all(
      from(attempt in DeliveryAttempt,
        where: attempt.delivery_id == ^delivery_id,
        order_by: [asc: attempt.attempt_number]
      )
    )
  end

  describe "map_outcome_to_oban_return/4 catch-all (BL-02 regression)" do
    defmodule UnexpectedAdapter do
      @moduledoc false
      @behaviour Chimeway.Adapter

      @impl true
      def deliver(_delivery, _config), do: {:error, :throttled, %{reason: "rate limit hit"}}
    end

    setup do
      prior = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, UnexpectedAdapter)
      on_exit(fn -> Application.put_env(:chimeway, :adapter, prior) end)
      :ok
    end

    test "branch A: converges via exhaust_delivery/1 on final attempt with :failed delivery" do
      %{delivery: delivery} = create_pending_delivery()

      assert :ok =
               perform_job(ObanWorker, %{"delivery_id" => delivery.id},
                 attempt: 5,
                 max_attempts: 5
               )

      reloaded = Deliveries.get_delivery!(delivery.id)
      assert reloaded.status == :cancelled
      assert reloaded.suppression_reason == "retries_exhausted"
      assert reloaded.status in Deliveries.terminal_states()

      # An attempt row was recorded with the unknown-classification shape
      attempts = Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))
      assert length(attempts) == 1
      [%DeliveryAttempt{outcome: outcome, error_class: error_class}] = attempts
      assert outcome == :rejected
      assert error_class == "unknown_classification"
    end

    test "branch B: raises UnhandledOutcomeError on non-final attempt with unexpected outcome shape" do
      %{delivery: delivery} = create_pending_delivery()

      assert_raise Chimeway.Dispatch.UnhandledOutcomeError, fn ->
        perform_job(ObanWorker, %{"delivery_id" => delivery.id},
          attempt: 1,
          max_attempts: 5
        )
      end

      # W6 fix: assert the DeliveryAttempt row was persisted BEFORE the raise.
      # Without this, the test would also pass if the worker raised before
      # record_attempt ran — silently masking a regression that breaks the
      # invariant "every adapter call produces an attempt row regardless of
      # downstream worker behavior". `from/2` is available via `Chimeway.DataCase`,
      # which imports `Ecto.Query`.
      attempts =
        Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id))

      assert length(attempts) == 1
      assert hd(attempts).outcome == :rejected
      assert hd(attempts).error_class == "unknown_classification"

      # The attempt row exists; delivery is :failed (terminal_or_failed_transition's
      # catch-all clause writes :failed for unknown error_class). NOT terminal — the raise
      # signals the contract violation; convergence happens on a future final attempt or
      # via operator action.
      reloaded = Deliveries.get_delivery!(delivery.id)
      assert reloaded.status == :failed
      refute reloaded.status in Deliveries.terminal_states()
    end
  end
end
