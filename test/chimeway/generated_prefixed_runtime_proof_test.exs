defmodule ChimewayTest.Notifiers.GeneratedPrefixedRuntime do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test.generated_prefixed_runtime"
  def version, do: 1

  def recipients(%{recipient_id: recipient_id}),
    do: {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}

  def build(params, _recipient) do
    {:ok,
     %{
       title: Map.get(params, :title, "Generated prefixed runtime"),
       body: Map.get(params, :body, "Generated prefixed runtime body"),
       category: Map.get(params, :category, "runtime")
     }}
  end

  def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

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

defmodule Chimeway.GeneratedPrefixedRuntimeProofTest do
  use Chimeway.GeneratedPrefixedRuntimeCase

  alias Chimeway.Traces

  setup do
    previous_adapter = Application.fetch_env(:chimeway, :adapter)
    previous_dispatcher = Application.fetch_env(:chimeway, :dispatcher)

    Application.put_env(:chimeway, :adapter, Chimeway.Adapters.Test)
    Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)
    Chimeway.Adapters.Test.clear()

    on_exit(fn ->
      restore_env(:adapter, previous_adapter)
      restore_env(:dispatcher, previous_dispatcher)
      Chimeway.Adapters.Test.clear()
    end)

    :ok
  end

  test "generated prefixed migrations support trigger-to-trace runtime behavior through Chimeway.Repo" do
    assert_generated_prefixed_runtime_tables!()
    assert generated_migration_count() == 31

    recipient_id = unique_recipient("trigger")

    assert {:ok, result} =
             Chimeway.trigger(
               ChimewayTest.Notifiers.GeneratedPrefixedRuntime,
               %{recipient_id: recipient_id, title: "Generated prefixed proof"},
               trigger_opts("trigger")
             )

    assert {:ok, reloaded_event} = Traces.get_trace(result.event.id)
    assert reloaded_event.id == result.event.id

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", 2)
    assert_prefixed_only("chimeway_delivery_attempts", 2)
  end

  defp trigger_opts(label) do
    [
      idempotency_key:
        "generated-prefixed-runtime-#{label}-#{System.unique_integer([:positive])}",
      tenant_id: "acme"
    ]
  end

  defp unique_recipient(label),
    do: "user:generated-prefixed-runtime:#{label}:#{System.unique_integer([:positive])}"

  defp restore_env(key, {:ok, value}), do: Application.put_env(:chimeway, key, value)
  defp restore_env(key, :error), do: Application.delete_env(:chimeway, key)
end
