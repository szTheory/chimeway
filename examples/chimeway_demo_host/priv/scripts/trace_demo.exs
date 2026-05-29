{:ok, _} = Application.ensure_all_started(:chimeway)

{:ok, result} =
  Chimeway.trigger(
    DemoHost.Notifiers.TraceDemo,
    %{user_id: "demo_user_1"},
    idempotency_key: "trace-demo-script-#{System.system_time(:second)}",
    tenant_id: "demo"
  )

[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)

IO.inspect(explanation.status, label: "status")
IO.inspect(explanation.timeline, label: "timeline")
