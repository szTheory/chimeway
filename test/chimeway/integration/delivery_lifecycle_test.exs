# Test notifiers defined at module level so they are compiled as named modules.
# Each uses a unique notification_key to prevent cross-scenario idempotency collisions.

defmodule ChimewayTest.Notifiers.LifecycleA do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_a"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test A"}}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test A",
         "body" => "Test A body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/a"}
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_a.in_app", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleB do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_b"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test B"}}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test B",
         "body" => "Test B body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/b"}
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_b.in_app", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleC do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_c"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test C"}}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test C",
         "body" => "Test C body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/c"}
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_c.in_app", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleFanout do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_fanout"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test Fanout"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test Fanout",
         "body" => "Fanout body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/fanout"},
         "subject" => "Test Fanout",
         "html_body" => "<p>Fanout body</p>",
         "text_body" => "Fanout body"
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_fanout.in_app", render_version: 1},
         email: %{render_key: "test.lifecycle_fanout.email", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleDelayedFallback do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_delayed_fallback"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test Delayed Fallback"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}
  def delayed_fallback_channels(_params, _recipient), do: {:ok, [:email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test Delayed Fallback",
         "body" => "Delayed fallback body",
         "primary_action" => %{"label" => "Review", "url" => "https://example.test/fallback"},
         "subject" => "Test Delayed Fallback",
         "html_body" => "<p>Delayed fallback body</p>",
         "text_body" => "Delayed fallback body"
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_delayed_fallback.in_app", render_version: 1},
         email: %{render_key: "test.lifecycle_delayed_fallback.email", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleNoDelayedFallback do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_no_delayed_fallback"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Test No Delayed Fallback"}}

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Test No Delayed Fallback",
         "body" => "No delayed fallback body",
         "primary_action" => %{"label" => "Open", "url" => "https://example.test/no-fallback"},
         "subject" => "Test No Delayed Fallback",
         "html_body" => "<p>No delayed fallback body</p>",
         "text_body" => "No delayed fallback body"
       },
       channels: %{
         in_app: %{render_key: "test.lifecycle_no_delayed_fallback.in_app", render_version: 1},
         email: %{render_key: "test.lifecycle_no_delayed_fallback.email", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleCustomChannel do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_custom_channel"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Custom Channel"}}
  def channels(_params, _recipient), do: {:ok, ["webhook_partner"]}
end

defmodule ChimewayTest.Notifiers.LifecycleDigestHeld do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_digest_held"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Digest Held"}}
  def channels(_params, _recipient), do: {:ok, [:email]}
  def orchestration(_params, _recipient), do: {:ok, :digest_held}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "Digest Held",
         "html_body" => "<p>Digest Held</p>",
         "text_body" => "Digest Held"
       },
       channels: %{
         email: %{render_key: "test.lifecycle_digest_held.email", render_version: 1}
       }
     }}
  end
end

defmodule ChimewayTest.Notifiers.LifecycleRenderedEmail do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_rendered_email"
  def version, do: 3

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient) do
    if test_pid = test_pid(), do: send(test_pid, {:build_called, self()})
    {:ok, %{legacy: true}}
  end

  def channels(_params, _recipient), do: {:ok, [:email]}

  def rendering(_params, _recipient) do
    if test_pid = test_pid(), do: send(test_pid, {:rendering_called, self()})

    {:ok,
     %{
       assigns: %{
         "subject" => "Render subject",
         "html_body" => "<p>Render body</p>",
         "text_body" => "Render body"
       },
       channels: %{
         email: %{render_key: "test.lifecycle_rendered_email.email", render_version: 3}
       }
     }}
  end

  defp test_pid do
    :chimeway
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:test_pid)
  end
end

defmodule ChimewayTest.Notifiers.LifecycleWorkflow do
  @behaviour Chimeway.Notifier
  def notification_key, do: "test.lifecycle_workflow"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{title: "Workflow lifecycle"}}
  def channels(_params, _recipient), do: {:ok, [:email]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "subject" => "Workflow lifecycle",
         "html_body" => "<p>Workflow lifecycle</p>",
         "text_body" => "Workflow lifecycle"
       },
       channels: %{
         email: %{render_key: "test.lifecycle_workflow.email", render_version: 1}
       }
     }}
  end

  def workflow(_params, _recipient) do
    {:ok,
     %{
       workflow_key: "test.lifecycle.workflow",
       workflow_version: 1,
       steps: [
         %{
           step_key: "email-first",
           step_order: 1,
           channel: :email,
           config: %{"template" => "first"}
         },
         %{
           step_key: "in-app-followup",
           step_order: 2,
           channel: :in_app,
           config: %{"template" => "followup"}
         }
       ]
     }}
  end
end

defmodule Chimeway.Integration.DeliveryLifecycleTest do
  use Chimeway.DataCase, async: false
  use Oban.Testing, repo: Chimeway.Repo

  @moduletag :integration

  import Ecto.Query

  alias Chimeway.Adapters.Test, as: TestAdapter
  alias Chimeway.{Deliveries, Delivery, DeliveryAttempt, Dispatch.ObanWorker, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Policy.Settings

  # ---- Scenario A — in-app delivery via default (Logger) adapter ----

  describe "Scenario A: trigger → event → notification → delivery → attempt (in-app)" do
    test "all records in the chain are created and have correct state" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 1},
                 idempotency_key: "lifecycle_a_001",
                 tenant_id: "acme"
               )

      # Event row
      events =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_a" and
                e.idempotency_key == "lifecycle_a_001"
          )
        )

      assert length(events) == 1
      [event] = events

      # Notification row
      notifications =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:1"
          )
        )

      assert length(notifications) == 1
      [notification] = notifications

      # Delivery row
      deliveries =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "in_app"
          )
        )

      assert length(deliveries) == 1
      [delivery] = deliveries
      assert delivery.status == :succeeded

      # Attempt row
      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id
          )
        )

      assert length(attempts) == 1
      [attempt] = attempts
      assert attempt.outcome == :succeeded
    end
  end

  # ---- Scenario B — outbound delivery via Test adapter ----

  describe "Scenario B: Test adapter captures delivery; attempt records provider_response" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "delivery and attempt rows exist; assert_delivered passes; provider_response is non-nil" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleB,
                 %{user_id: 2},
                 idempotency_key: "lifecycle_b_001",
                 tenant_id: "acme"
               )

      # Get notification
      [notification] =
        Repo.all(
          from(n in Notification,
            join: e in Event,
            on: n.event_id == e.id,
            where:
              e.notification_key == "test.lifecycle_b" and
                n.recipient_identity == "user:2"
          )
        )

      # Delivery row
      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id
          )
        )

      assert delivery.status == :succeeded

      # Attempt row
      [attempt] =
        Repo.all(
          from(a in DeliveryAttempt,
            where: a.delivery_id == ^delivery.id
          )
        )

      assert attempt.outcome == :succeeded
      assert attempt.provider_response != nil

      # D-20: adapter_module persisted as inspect(module) string on the attempt row.
      assert attempt.adapter_module == inspect(Chimeway.Adapters.Test)

      # Test adapter captured the delivery
      TestAdapter.assert_delivered(delivery)

      # D-23: channel-tagged mailbox send fires for the in_app channel of LifecycleB.
      assert_receive {:chimeway_delivery, "in_app", %Chimeway.Delivery{}}
    end

    # D-21: same delivery identity, two separate dispatch runs with different adapters,
    # produces two attempts whose adapter_module values differ. Phase 29's per-attempt
    # adapter_module persistence must reflect the runtime adapter at attempt time.
    test "adapter_module differs across attempts when adapter is reconfigured between attempts (D-21)" do
      # Attempt 1: dispatch with Adapters.Test (set in scenario setup).
      ctx_a =
        Chimeway.Test.DispatchHelpers.create_pending_delivery(
          notification_key: "test.adapter_diff_a",
          channel: :in_app
        )

      assert {:ok, _} =
               Chimeway.Dispatch.Sync.dispatch_delivery(ctx_a.delivery, [])

      [attempt1] =
        Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^ctx_a.delivery.id))

      assert attempt1.adapter_module == inspect(Chimeway.Adapters.Test)

      # Attempt 2: reconfigure global :adapter to Adapters.Logger and drive a fresh delivery.
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Logger)

      ctx_b =
        Chimeway.Test.DispatchHelpers.create_pending_delivery(
          notification_key: "test.adapter_diff_b",
          channel: :in_app
        )

      assert {:ok, _} =
               Chimeway.Dispatch.Sync.dispatch_delivery(ctx_b.delivery, [])

      [attempt2] =
        Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^ctx_b.delivery.id))

      assert attempt2.adapter_module == inspect(Chimeway.Adapters.Logger)

      # D-21: per-attempt adapter_module reflects the runtime adapter at attempt time.
      assert attempt1.adapter_module != attempt2.adapter_module
    end
  end

  # ---- Scenario C — duplicate trigger is idempotent ----

  describe "Scenario C: duplicate trigger produces single rows in all four tables" do
    test "second trigger returns :duplicate and does not create new rows" do
      # First trigger — persists all rows and dispatches
      assert {:ok, _} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleC,
                 %{user_id: 3},
                 idempotency_key: "lifecycle_c_001",
                 tenant_id: "acme"
               )

      # Second trigger — same idempotency_key returns {:duplicate, event}
      assert {:duplicate, _event} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleC,
                 %{user_id: 3},
                 idempotency_key: "lifecycle_c_001",
                 tenant_id: "acme"
               )

      # Exactly one event row
      event_count =
        Repo.aggregate(
          from(e in Event, where: e.idempotency_key == "lifecycle_c_001"),
          :count,
          :id
        )

      assert event_count == 1

      # Exactly one notification row for the recipient
      [event] = Repo.all(from(e in Event, where: e.idempotency_key == "lifecycle_c_001"))

      notification_count =
        Repo.aggregate(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:3"
          ),
          :count,
          :id
        )

      assert notification_count == 1

      # Exactly one delivery row per channel per recipient
      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:3"
          )
        )

      delivery_count =
        Repo.aggregate(
          from(d in Delivery, where: d.notification_id == ^notification.id),
          :count,
          :id
        )

      assert delivery_count == 1

      # Exactly one attempt row (second trigger dispatches nothing)
      [delivery] =
        Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))

      attempt_count =
        Repo.aggregate(
          from(a in DeliveryAttempt, where: a.delivery_id == ^delivery.id),
          :count,
          :id
        )

      assert attempt_count == 1
    end
  end

  # DLVR-01 / INTG-02: outbound fanout remains durable across notification -> delivery -> attempt.
  describe "Scenario D: multi-channel fanout creates durable delivery and attempt records" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "one notification fans out to two channel deliveries and attempts for dispatchable channels" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleFanout,
                 %{user_id: 4},
                 idempotency_key: "lifecycle_fanout_001",
                 tenant_id: "acme"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_fanout" and
                e.idempotency_key == "lifecycle_fanout_001"
          )
        )

      notification_count =
        Repo.aggregate(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:4"
          ),
          :count,
          :id
        )

      assert notification_count == 1

      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:4"
          )
        )

      deliveries = Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))
      assert length(deliveries) == 2
      assert MapSet.new(Enum.map(deliveries, & &1.channel)) == MapSet.new(["email", "in_app"])

      dispatchable_delivery_ids =
        deliveries
        |> Enum.reject(&(&1.status == :suppressed))
        |> Enum.map(& &1.id)
        |> MapSet.new()

      attempts =
        Repo.all(
          from(a in DeliveryAttempt,
            join: d in Delivery,
            on: a.delivery_id == d.id,
            where: d.notification_id == ^notification.id
          )
        )

      assert length(attempts) == MapSet.size(dispatchable_delivery_ids)
      assert MapSet.new(Enum.map(attempts, & &1.delivery_id)) == dispatchable_delivery_ids
      assert Enum.all?(attempts, &(&1.outcome == :succeeded))

      Enum.each(deliveries, &TestAdapter.assert_delivered/1)
    end
  end

  # POLC-03: trigger-driven planner wiring persists delay_fallback semantics and provenance.
  describe "Scenario E: trigger-driven delayed fallback persistence" do
    setup do
      original = Application.get_env(:chimeway, :adapter)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:chimeway, :adapter)
          mod -> Application.put_env(:chimeway, :adapter, mod)
        end

        TestAdapter.clear()
      end)

      :ok
    end

    test "planner persists delay_fallback and delayed_fallback_source from notifier callback" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleDelayedFallback,
                 %{user_id: 5},
                 idempotency_key: "lifecycle_delayed_fallback_001",
                 tenant_id: "acme"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_delayed_fallback" and
                e.idempotency_key == "lifecycle_delayed_fallback_001"
          )
        )

      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:5"
          )
        )

      deliveries =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id,
            order_by: [asc: d.channel]
          )
        )

      assert length(deliveries) == 2
      assert MapSet.new(Enum.map(deliveries, & &1.channel)) == MapSet.new(["email", "in_app"])

      deliveries_by_channel =
        deliveries
        |> Map.new(fn delivery -> {delivery.channel, delivery} end)

      email_delivery = Map.fetch!(deliveries_by_channel, "email")
      in_app_delivery = Map.fetch!(deliveries_by_channel, "in_app")

      assert email_delivery.delay_fallback
      assert email_delivery.metadata["delayed_fallback_source"] == "notifier"
      refute in_app_delivery.delay_fallback
      assert in_app_delivery.metadata["delayed_fallback_source"] == "default"
    end

    test "notifier without delayed_fallback callback keeps planned rows at delay_fallback false" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleNoDelayedFallback,
                 %{user_id: 6},
                 idempotency_key: "lifecycle_no_delayed_fallback_001",
                 tenant_id: "acme"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_no_delayed_fallback" and
                e.idempotency_key == "lifecycle_no_delayed_fallback_001"
          )
        )

      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:6"
          )
        )

      deliveries = Repo.all(from(d in Delivery, where: d.notification_id == ^notification.id))

      assert length(deliveries) == 2
      assert Enum.all?(deliveries, &(!&1.delay_fallback))
      assert Enum.all?(deliveries, &(&1.metadata["delayed_fallback_source"] == "default"))
    end
  end

  # OPS-01: trigger-to-trace explainability must remain stable for custom channels.
  describe "Scenario F: trigger-driven custom channel explainability (OPS-01)" do
    test "trigger persists webhook_partner delivery and explain_delivery keeps channel string" do
      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleCustomChannel,
                 %{user_id: 7},
                 idempotency_key: "lifecycle_custom_channel_001",
                 tenant_id: "acme"
               )

      [event] =
        Repo.all(
          from(e in Event,
            where:
              e.notification_key == "test.lifecycle_custom_channel" and
                e.idempotency_key == "lifecycle_custom_channel_001"
          )
        )

      [notification] =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^event.id and n.recipient_identity == "user:7"
          )
        )

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "webhook_partner"
          )
        )

      assert delivery.status == :succeeded

      assert {:ok, %Chimeway.Traces.Explanation{channel: "webhook_partner", timeline: timeline}} =
               Traces.explain_delivery(delivery.id)

      assert :delivery_planned in Enum.map(timeline, & &1.event)
    end
  end

  describe "Scenario G: trigger outcome trace pointers resolve through trace APIs" do
    test "trigger response trace fields map to durable trace and delivery rows" do
      assert {:ok, result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 8},
                 idempotency_key: "lifecycle_trace_contract_001",
                 correlation_id: "phase8-trace-001",
                 tenant_id: "acme"
               )

      assert result.dispatch_outcome == :ok or match?({:error, _}, result.dispatch_outcome)
      assert is_map(result.trace)
      assert result.trace.event_id == result.event.id
      assert Map.has_key?(result.trace, :correlation_id)
      assert is_list(result.trace.delivery_ids)

      assert {:ok, trace_event} = Traces.get_trace(result.trace.event_id)
      assert trace_event.id == result.event.id

      events = Traces.find_traces_by_correlation_id(result.trace.correlation_id)
      assert Enum.any?(events, &(&1.id == result.event.id))

      notification_ids =
        Repo.all(
          from(n in Notification,
            where: n.event_id == ^result.event.id,
            select: n.id
          )
        )

      durable_delivery_ids =
        Repo.all(
          from(d in Delivery,
            where: d.notification_id in ^notification_ids,
            select: d.id
          )
        )

      assert MapSet.new(result.trace.delivery_ids) == MapSet.new(durable_delivery_ids)
    end
  end

  describe "Scenario H: held deliveries remain planned-but-not-dispatched in Phase 17" do
    test "quiet-hours deferral stays pending with zero attempts and explainable planning facts" do
      assert {:ok, _settings} =
               Settings.upsert_settings(%{
                 recipient_id: "user:9",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:ok, result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 9},
                 idempotency_key: "lifecycle_deferred_001",
                 evaluation_time: ~U[2026-01-15 03:30:00Z],
                 tenant_id: "acme"
               )

      assert result.dispatch_outcome == :ok
      assert length(result.trace.delivery_ids) == 1

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.id in ^result.trace.delivery_ids
          )
        )

      assert delivery.status == :pending
      assert delivery.orchestration_state == :deferred
      assert delivery.planning_reason == "quiet_hours"
      assert DateTime.compare(delivery.next_eligible_at, ~U[2026-01-15 13:00:00Z]) == :eq
      assert attempt_count(delivery.id) == 0

      assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
      assert explanation.status == :pending
      assert explanation.last_attempt == nil
    end

    test "digest-held planning stays pending with zero attempts" do
      assert {:ok, result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleDigestHeld,
                 %{user_id: 10},
                 idempotency_key: "lifecycle_digest_held_001",
                 tenant_id: "acme"
               )

      assert result.dispatch_outcome == :ok
      assert length(result.trace.delivery_ids) == 1

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.id in ^result.trace.delivery_ids
          )
        )

      assert delivery.status == :pending
      assert delivery.orchestration_state == :digest_held
      assert delivery.planning_reason == "digest_rule"
      assert delivery.next_eligible_at == nil
      assert attempt_count(delivery.id) == 0

      assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
      assert explanation.status == :pending
      assert explanation.last_attempt == nil
    end
  end

  describe "Scenario I: deferred rows resume and cancel on the same delivery identity" do
    setup do
      previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        Application.put_env(:chimeway, :adapter, previous_adapter)
        Application.delete_env(:chimeway, ChimewayTest.Notifiers.LifecycleRenderedEmail)
        TestAdapter.clear()
      end)

      :ok
    end

    test "resume_deferred_delivery keeps the canonical row lifecycle-safe when perform-time policy re-evaluates" do
      assert {:ok, _settings} =
               Settings.upsert_settings(%{
                 recipient_id: "user:11",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:ok, result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 11},
                 idempotency_key: "lifecycle_deferred_resume_001",
                 evaluation_time: ~U[2026-01-15 03:30:00Z],
                 tenant_id: "acme"
               )

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.id in ^result.trace.delivery_ids
          )
        )

      original_id = delivery.id
      assert delivery.orchestration_state == :deferred
      assert attempt_count(delivery.id) == 0

      assert {:ok, resumed_delivery} =
               Chimeway.Deliveries.resume_deferred_delivery(
                 delivery.id,
                 now: ~U[2026-01-15 13:00:00Z],
                 source: "scheduled_resume"
               )

      assert resumed_delivery.id == original_id
      assert resumed_delivery.status == :pending
      assert resumed_delivery.orchestration_state == :ready
      assert resumed_delivery.metadata["resume_source"] == "scheduled_resume"
      assert resumed_delivery.metadata["resume_scheduled_at"] == "2026-01-15T13:00:00.000000Z"
      assert resumed_delivery.metadata["resumed_at"] == "2026-01-15T13:00:00.000000Z"
      assert DateTime.compare(resumed_delivery.updated_at, ~U[2026-01-15 13:00:00Z]) == :eq
      assert attempt_count(resumed_delivery.id) == 0

      assert Repo.aggregate(
               from(d in Delivery, where: d.notification_id == ^delivery.notification_id),
               :count,
               :id
             ) == 1

      assert :ok = perform_job(ObanWorker, %{delivery_id: resumed_delivery.id})

      updated_delivery = Repo.get!(Delivery, resumed_delivery.id)

      assert updated_delivery.id == original_id
      assert updated_delivery.metadata["resume_source"] == "scheduled_resume"
      assert updated_delivery.metadata["resume_scheduled_at"] == "2026-01-15T13:00:00.000000Z"
      assert updated_delivery.metadata["resumed_at"] == "2026-01-15T13:00:00.000000Z"

      assert Repo.aggregate(
               from(d in Delivery, where: d.notification_id == ^delivery.notification_id),
               :count,
               :id
             ) == 1

      assert {:ok, explanation} = Traces.explain_delivery(updated_delivery.id)
      assert Map.get(explanation, :resume_source) == "scheduled_resume"

      assert DateTime.compare(
               Map.get(explanation, :resume_scheduled_at),
               ~U[2026-01-15 13:00:00Z]
             ) ==
               :eq

      assert DateTime.compare(Map.get(explanation, :resumed_at), ~U[2026-01-15 13:00:00Z]) == :eq

      case updated_delivery do
        %Delivery{status: :pending, orchestration_state: :deferred} = re_deferred_delivery ->
          assert re_deferred_delivery.planning_reason == "quiet_hours"
          assert re_deferred_delivery.planning_context["time_zone"] == "America/New_York"

          assert DateTime.compare(
                   re_deferred_delivery.next_eligible_at,
                   resumed_delivery.next_eligible_at
                 ) ==
                   :gt

          assert attempt_count(re_deferred_delivery.id) == 0

          assert explanation.status == :pending
          assert explanation.planning_reason == "quiet_hours"
          assert explanation.planning_context["time_zone"] == "America/New_York"

          assert DateTime.compare(
                   explanation.next_eligible_at,
                   re_deferred_delivery.next_eligible_at
                 ) ==
                   :eq

        %Delivery{status: :succeeded, orchestration_state: :ready} = succeeded_delivery ->
          assert succeeded_delivery.planning_reason == "quiet_hours"
          assert succeeded_delivery.planning_context["time_zone"] == "America/New_York"

          assert DateTime.compare(
                   succeeded_delivery.next_eligible_at,
                   resumed_delivery.next_eligible_at
                 ) ==
                   :eq

          assert attempt_count(succeeded_delivery.id) == 1

          assert explanation.status == :succeeded
          assert explanation.planning_reason == "quiet_hours"
          assert explanation.planning_context["time_zone"] == "America/New_York"

          assert DateTime.compare(
                   explanation.next_eligible_at,
                   succeeded_delivery.next_eligible_at
                 ) ==
                   :eq

          assert explanation.last_attempt.outcome == :succeeded

        other ->
          flunk("unexpected post-resume delivery state: #{inspect(other)}")
      end
    end

    test "cancel_deferred_delivery keeps the same row and marks supersession on suppression_reason == \"superseded\"" do
      assert {:ok, _settings} =
               Settings.upsert_settings(%{
                 recipient_id: "user:12",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60,
                 time_zone: "America/New_York"
               })

      assert {:ok, result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleA,
                 %{user_id: 12},
                 idempotency_key: "lifecycle_deferred_resume_002",
                 evaluation_time: ~U[2026-01-15 03:30:00Z],
                 tenant_id: "acme"
               )

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.id in ^result.trace.delivery_ids
          )
        )

      original_id = delivery.id

      assert {:ok, cancelled_delivery} =
               Chimeway.Deliveries.cancel_deferred_delivery(
                 delivery,
                 "superseded",
                 now: ~U[2026-01-15 12:55:00Z]
               )

      assert cancelled_delivery.id == original_id
      assert cancelled_delivery.status == :cancelled
      assert cancelled_delivery.orchestration_state == :deferred
      assert cancelled_delivery.suppression_reason == "superseded"
      assert DateTime.compare(cancelled_delivery.updated_at, ~U[2026-01-15 12:55:00Z]) == :eq
      assert attempt_count(cancelled_delivery.id) == 0

      assert :ok = perform_job(ObanWorker, %{delivery_id: cancelled_delivery.id})

      assert {:ok, explanation} = Traces.explain_delivery(cancelled_delivery.id)
      assert explanation.status == :cancelled
      assert explanation.suppression_reason == "superseded"
      assert explanation.last_attempt == nil
      assert attempt_count(cancelled_delivery.id) == 0

      assert Enum.map(explanation.timeline, & &1.event) == [
               :event_created,
               :notification_created,
               :delivery_planned,
               :deferred,
               :cancelled
             ]

      [%{at: cancelled_at}] = Enum.filter(explanation.timeline, &(&1.event == :cancelled))
      assert DateTime.compare(cancelled_at, ~U[2026-01-15 12:55:00Z]) == :eq
    end
  end

  describe "Scenario J: rendered deliveries stay precomputed through dispatch and traces" do
    setup do
      previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      TestAdapter.clear()

      on_exit(fn ->
        Application.put_env(:chimeway, :adapter, previous_adapter)
        TestAdapter.clear()
      end)

      :ok
    end

    test "dispatch uses preplanned render_data without a second rendering callback" do
      Application.put_env(:chimeway, ChimewayTest.Notifiers.LifecycleRenderedEmail,
        test_pid: self()
      )

      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleRenderedEmail,
                 %{user_id: 13},
                 idempotency_key: "lifecycle_rendered_email_001",
                 tenant_id: "acme"
               )

      assert_receive {:rendering_called, _}, 1000
      refute_receive {:rendering_called, _}, 50
      refute_receive {:build_called, _}, 50

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.render_key == "test.lifecycle_rendered_email.email"
          )
        )

      assert delivery.render_data == %{
               "subject" => "Render subject",
               "html_body" => "<p>Render body</p>",
               "text_body" => "Render body"
             }

      assert [delivered] = TestAdapter.delivered_messages()
      assert delivered.id == delivery.id
      assert delivered.render_data == delivery.render_data
    end

    test "explanations expose render identity without render bodies or raw render_data" do
      Application.put_env(:chimeway, ChimewayTest.Notifiers.LifecycleRenderedEmail,
        test_pid: self()
      )

      assert {:ok, _result} =
               Chimeway.trigger(
                 ChimewayTest.Notifiers.LifecycleRenderedEmail,
                 %{user_id: 14},
                 idempotency_key: "lifecycle_rendered_email_002",
                 tenant_id: "acme"
               )

      [delivery] =
        Repo.all(
          from(d in Delivery,
            where: d.render_key == "test.lifecycle_rendered_email.email",
            order_by: [desc: d.inserted_at],
            limit: 1
          )
        )

      assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
      assert explanation.render_key == "test.lifecycle_rendered_email.email"
      assert explanation.render_version == 3
      refute Map.has_key?(Map.from_struct(explanation), :render_data)
      refute Map.has_key?(Map.from_struct(explanation), :html_body)
      refute Map.has_key?(Map.from_struct(explanation), :text_body)
    end
  end

  describe "Scenario K: recoverable ready rows re-drive through the canonical delivery identity" do
    setup do
      previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
      previous_dispatcher = Application.get_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

      Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Oban)
      TestAdapter.clear()

      on_exit(fn ->
        Application.put_env(:chimeway, :adapter, previous_adapter)
        Application.put_env(:chimeway, :dispatcher, previous_dispatcher)
        TestAdapter.clear()
      end)

      :ok
    end

    test "recover_delivery reuses the same row, stamps recovery_source, and dispatches once" do
      fixture =
        Chimeway.Test.DispatchHelpers.create_notification(
          notification_key: "test.lifecycle_recovery",
          recipient_identity: "user:15"
        )

      {:ok, delivery} =
        Deliveries.plan_delivery(fixture.notification.id, :email,
          tenant_id: "default",
          actor_id: "system"
        )

      delivery =
        delivery
        |> Ecto.Changeset.change(updated_at: ~U[2026-01-15 11:00:00.000000Z])
        |> Repo.update!()

      assert attempt_count(delivery.id) == 0

      assert {:ok, recovery} =
               Chimeway.recover_delivery(delivery.id,
                 tenant_id: delivery.tenant_id,
                 now: ~U[2026-01-15 12:30:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "stuck_after_trigger"
               )

      assert recovery.delivery.id == delivery.id
      assert recovery.delivery.status == :pending
      assert recovery.recovery.source == "ops_console"
      assert recovery.recovery.reason == "stuck_after_trigger"
      assert recovery.recovery.recovered_at == ~U[2026-01-15 12:30:00.000000Z]

      assert_enqueued(worker: ObanWorker, args: %{delivery_id: delivery.id})
      assert :ok = perform_job(ObanWorker, %{delivery_id: delivery.id})
      assert attempt_count(delivery.id) == 1

      recovered = Repo.get!(Delivery, delivery.id)
      assert recovered.status == :succeeded
      assert recovered.metadata["recovery_source"] == "ops_console"
      assert recovered.metadata["recovery_reason"] == "stuck_after_trigger"
      assert recovered.metadata["recovered_at"] == "2026-01-15T12:30:00.000000Z"

      assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
      assert explanation.status == :succeeded
      assert Enum.any?(explanation.timeline, &(&1.event == :delivery_planned))

      TestAdapter.assert_delivered(recovered)

      assert {:noop, duplicate} =
               Chimeway.recover_delivery(delivery.id,
                 tenant_id: delivery.tenant_id,
                 now: ~U[2026-01-15 12:31:00Z],
                 older_than: 60,
                 source: "ops_console",
                 reason: "duplicate_attempt"
               )

      assert duplicate.delivery.id == delivery.id
      assert attempt_count(delivery.id) == 1
    end
  end

  describe "Scenario L: workflow-linked canonical deliveries remain derivable from durable run state" do
    test "active-step delivery row persists workflow_run_id and workflow_step_id" do
      assert {:ok, result} =
               Chimeway.Trigger.trigger(
                 ChimewayTest.Notifiers.LifecycleWorkflow,
                 %{user_id: 24},
                 idempotency_key: "idem-lifecycle-workflow-linkage",
                 tenant_id: "acme"
               )

      notification =
        Repo.one!(
          from(n in Chimeway.Notifications.Notification,
            where: n.event_id == ^result.event.id
          )
        )

      workflow_run =
        Repo.one!(
          from(wr in "chimeway_workflow_runs",
            where: field(wr, :notification_id) == ^Ecto.UUID.dump!(notification.id),
            select: %{
              id: field(wr, :id),
              current_step_id: field(wr, :current_step_id),
              state: field(wr, :state)
            }
          )
        )

      delivery =
        Repo.one!(
          from(d in Delivery,
            where: d.notification_id == ^notification.id and d.channel == "email"
          )
        )

      assert delivery.workflow_run_id == Ecto.UUID.load!(workflow_run.id)
      assert delivery.workflow_step_id == Ecto.UUID.load!(workflow_run.current_step_id)

      current_step =
        Repo.one!(
          from(ws in "chimeway_workflow_steps",
            where: field(ws, :id) == ^workflow_run.current_step_id,
            select: %{
              id: field(ws, :id),
              step_key: field(ws, :step_key),
              step_order: field(ws, :step_order)
            }
          )
        )

      assert workflow_run.state == "completed"
      assert current_step.step_key == "email-first"
      assert current_step.step_order == 1

      activated_transition =
        Repo.one!(
          from(wt in "chimeway_workflow_transitions",
            where:
              field(wt, :workflow_run_id) == ^workflow_run.id and
                field(wt, :workflow_step_id) == ^Ecto.UUID.dump!(delivery.workflow_step_id) and
                field(wt, :reason) == "step_activated",
            select: %{
              workflow_step_id: field(wt, :workflow_step_id),
              delivery_id: field(wt, :delivery_id)
            }
          )
        )

      assert Ecto.UUID.load!(activated_transition.workflow_step_id) == delivery.workflow_step_id
      assert delivery.id
    end
  end

  defp attempt_count(delivery_id) do
    Repo.aggregate(from(a in DeliveryAttempt, where: a.delivery_id == ^delivery_id), :count, :id)
  end
end
