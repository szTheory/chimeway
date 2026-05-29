defmodule DemoHost.Notifiers.TraceDemo do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "trace_demo"

  @impl true
  def version, do: 1

  @impl true
  def recipients(%{user_id: user_id}) do
    {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}
  end

  @impl true
  def build(_params, _recipient) do
    {:ok, %{"headline" => "Trace demo", "body" => "Explainability walkthrough"}}
  end
end
