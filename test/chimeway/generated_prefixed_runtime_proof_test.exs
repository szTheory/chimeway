defmodule ChimewayTest.Notifiers.GeneratedPrefixedRuntime do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.generated_prefixed_runtime"
  def version, do: 1

  def recipients(%{recipient_id: recipient_id}),
    do:
      {:ok,
       [%{recipient_identity: recipient_id, recipient_ref: recipient_id, recipient_type: "user"}]}

  def build(params, _recipient) do
    {:ok,
     %{
       title: Map.get(params, :title, "Generated prefixed runtime"),
       body: Map.get(params, :body, "Generated prefixed runtime body"),
       category: Map.get(params, :category, "runtime")
     }}
  end

  def channels(_params, _recipient), do: {:ok, [:in_app]}

  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{
         "headline" => "Generated prefixed runtime",
         "body" => "Generated prefixed runtime body",
         "primary_action" => %{
           "label" => "Open",
           "url" => "https://example.test/generated-prefixed-runtime"
         },
         "subject" => "Generated prefixed runtime",
         "html_body" => "<p>Generated prefixed runtime</p>",
         "text_body" => "Generated prefixed runtime"
       },
       channels: %{
         in_app: %{
           render_key: "test.generated_prefixed_runtime.in_app",
           render_version: 1
         },
         email: %{
           render_key: "test.generated_prefixed_runtime.email",
           render_version: 1
         }
       }
     }}
  end
end

defmodule ChimewayTest.GeneratedPrefixedRuntimeRenderContextResolver do
  @behaviour Chimeway.RenderContextResolver

  @impl true
  def resolve("test.generated_prefixed_runtime", 1, recipient_ref) do
    {:ok,
     %{
       notifier: ChimewayTest.Notifiers.GeneratedPrefixedRuntime,
       params: %{},
       recipient: %{
         recipient_identity: recipient_ref,
         recipient_ref: recipient_ref,
         recipient_type: "user"
       }
     }}
  end

  def resolve(_, _, _), do: {:error, :render_context_unavailable}
end

defmodule Chimeway.GeneratedPrefixedRuntimeProofTest do
  use Chimeway.GeneratedPrefixedRuntimeCase

  alias Chimeway.{Reconciliation, Traces}

  setup do
    previous_adapter = Application.fetch_env(:chimeway, :adapter)
    previous_dispatcher = Application.fetch_env(:chimeway, :dispatcher)
    previous_resolvers = Application.fetch_env(:chimeway, :render_context_resolvers)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

    Application.put_env(:chimeway, :render_context_resolvers, %{
      {"test.generated_prefixed_runtime", 1} =>
        ChimewayTest.GeneratedPrefixedRuntimeRenderContextResolver
    })

    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      restore_env(:adapter, previous_adapter)
      restore_env(:dispatcher, previous_dispatcher)
      restore_env(:render_context_resolvers, previous_resolvers)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  test "generated prefixed migrations support trigger-to-trace runtime behavior through Chimeway.Repo" do
    assert_generated_prefixed_runtime_tables!()
    assert generated_migration_count() == 36

    recipient_id = unique_recipient("trigger")

    assert {:ok, result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.GeneratedPrefixedRuntime,
               %{recipient_id: recipient_id, title: "Generated prefixed proof"},
               trigger_opts("trigger")
             )

    assert {:ok, reloaded_event} = Traces.get_trace(result.event.id, tenant_id: "acme")
    assert reloaded_event.id == result.event.id

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 1)
    assert_prefixed_only("chimeway_delivery_attempts", 1)
    assert_prefixed_only("chimeway_delivery_targets", 0)
    assert %{events: 0, notifications: 0} = Reconciliation.report().counts
  end

  defp trigger_opts(label) do
    [
      idempotency_key:
        "generated-prefixed-runtime-#{label}-#{System.unique_integer([:positive])}",
      tenant_id: "acme"
    ]
  end

  defp unique_recipient(label),
    do: "cw_generated_prefixed_runtime_#{label}_#{System.unique_integer([:positive])}"

  defp restore_env(key, {:ok, value}), do: Application.put_env(:chimeway, key, value)
  defp restore_env(key, :error), do: Application.delete_env(:chimeway, key)
end
