defmodule Chimeway.PrivacyBoundaryTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.{Deliveries, DeliveryAttempt, Repo, Traces}
  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification

  @sentinels [
    "raw-device-token-sentinel",
    "authorization-secret-sentinel",
    "recipient-identity-sentinel",
    "trusted-link-sentinel",
    "rendered-content-sentinel",
    "provider-body-sentinel"
  ]

  setup do
    previous = Application.get_env(:chimeway, :single_tenant_compatibility)
    Application.put_env(:chimeway, :single_tenant_compatibility, tenant_id: "tenant-safe")

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:chimeway, :single_tenant_compatibility),
        else: Application.put_env(:chimeway, :single_tenant_compatibility, previous)
    end)
  end

  test "hostile adapter detail becomes safe durable evidence and a tenant-scoped explanation" do
    delivery = delivery_for("tenant-safe")
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    assert {:ok, %{delivery: updated, attempt: attempt}} =
             Deliveries.record_attempt(dispatched, %{
               outcome: :failed,
               error_class: "temporary",
               adapter_module: "test_adapter",
               provider_message_id: "cw_provider_opaque-123",
               provider_response: %{
                 provider_code: "retryable",
                 retry_after_ms: 250,
                 accepted_at: ~U[2026-08-12 12:00:00Z],
                 provider_body: "provider-body-sentinel",
                 nested: [
                   %{
                     token: "raw-device-token-sentinel",
                     authorization: "authorization-secret-sentinel"
                   },
                   recipient: "recipient-identity-sentinel",
                   trusted_link: "trusted-link-sentinel",
                   content: "rendered-content-sentinel"
                 ]
               }
             })

    reloaded = Repo.get!(DeliveryAttempt, attempt.id)
    refute_sentinels(reloaded)

    assert reloaded.provider_response == %{
             "provider_code" => "retryable",
             "retry_after_ms" => 250,
             "accepted_at" => "2026-08-12T12:00:00Z"
           }

    assert {:ok, explanation} = Traces.explain_delivery(updated.id, tenant_id: "tenant-safe")
    assert explanation.last_attempt.outcome == :failed
    assert explanation.last_attempt.error_class == "temporary"
    assert explanation.last_attempt.attempt_number == 1

    assert explanation.last_attempt.provider_message_id =~
             ~r/^cw_provider_message_id_[0-9a-f]{32}$/

    assert Enum.any?(explanation.timeline, &(&1.event == :attempt_recorded))
    refute_sentinels(explanation)
  end

  test "invalid diagnostic values cannot become provider-response fallbacks" do
    delivery = delivery_for("tenant-safe")
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    assert {:error, :unsafe_evidence, :provider_facts, %{}} =
             Deliveries.record_attempt(dispatched, %{
               outcome: :failed,
               error_class: "temporary",
               provider_response: "provider-body-sentinel"
             })

    assert Repo.aggregate(DeliveryAttempt, :count, :id) == 0
  end

  test "ambiguous attempt evidence returns before persistence while a singleton representation persists" do
    delivery = delivery_for("tenant-safe")
    {:ok, dispatched} = Deliveries.transition_status(delivery, :dispatched)

    ambiguous = [
      outcome: :failed,
      error_class: "temporary",
      provider_response: [{:provider_code, "accepted"}, {"provider_code", "recipient@example.test"}]
    ]

    assert {:error, :unsafe_evidence, :provider_facts, %{}} =
             Deliveries.record_attempt(dispatched, ambiguous)

    assert Repo.aggregate(DeliveryAttempt, :count, :id) == 0

    assert {:ok, %{attempt: attempt}} =
             Deliveries.record_attempt(dispatched, [
               outcome: :failed,
               error_class: "temporary",
               provider_response: [provider_code: "accepted"]
             ])

    assert Repo.get!(DeliveryAttempt, attempt.id).provider_response == %{"provider_code" => "accepted"}
  end

  test "wrong-tenant explanation remains not found" do
    delivery = delivery_for("tenant-safe")
    assert {:error, :not_found} = Traces.explain_delivery(delivery.id, tenant_id: "tenant-other")
  end

  test "hostile digest resolution text is omitted from durable and trace evidence" do
    source = delivery_for("tenant-safe")

    {:ok, held} =
      Deliveries.apply_planning_decision(source, %{
        orchestration_state: :digest_held,
        planning_reason: "digest_rule",
        planning_context: %{"rule_identity" => "digest.privacy:v1"},
        next_eligible_at: nil
      })

    digest_delivery = delivery_for("tenant-safe")
    hostile_reason = "reset-token=abc"

    assert {:ok, resolved} =
             Deliveries.mark_digested(held, digest_delivery.id, hostile_reason,
               resolved_at: ~U[2026-08-12 12:00:00Z]
             )

    assert Repo.get!(Chimeway.Delivery, resolved.id).digest_flush_reason == nil
    assert {:ok, explanation} = Traces.explain_delivery(resolved.id, tenant_id: "tenant-safe")
    refute :erlang.term_to_binary(explanation) |> :binary.match(hostile_reason) != :nomatch
  end

  defp delivery_for(tenant_id) do
    event =
      Repo.insert!(%Event{
        notification_key: "privacy.boundary",
        notification_version: 1,
        idempotency_key: "privacy-#{System.unique_integer([:positive])}",
        tenant_id: tenant_id,
        payload: %{}
      })

    notification =
      Repo.insert!(%Notification{
        event_id: event.id,
        recipient_identity: "host-owned-recipient",
        recipient_type: "user",
        tenant_id: tenant_id,
        metadata: %{}
      })

    {:ok, delivery} =
      Deliveries.plan_delivery(notification.id, :in_app, tenant_id: tenant_id, actor_id: "system")

    delivery
  end

  defp refute_sentinels(term) do
    encoded = :erlang.term_to_binary(term)

    Enum.each(@sentinels, fn sentinel ->
      refute :binary.match(encoded, sentinel) != :nomatch, "leaked #{sentinel}"
    end)
  end
end
