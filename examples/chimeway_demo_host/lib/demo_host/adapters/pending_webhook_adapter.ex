defmodule DemoHost.Adapters.PendingWebhookAdapter do
  @moduledoc """
  Fixture adapter that leaves deliveries in a retryable `:failed` state.

  Use in TeamPulse escalation seeds so the email channel awaits inbound webhook
  feedback instead of completing synchronously. Copy the pattern — do not use in
  production.
  """

  @behaviour Chimeway.Adapter

  @impl true
  def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "awaiting_webhook"}}

  @impl true
  def verify_webhook(_body, headers, _config) do
    if Enum.any?(headers, fn {k, v} -> k == "signature" and v == "valid" end) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def resolve_delivery(%{"delivery_id" => did}) when is_binary(did), do: {:ok, %{delivery_id: did}}
  def resolve_delivery(_), do: :error

  @impl true
  def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
  def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
  def normalize_feedback(_), do: :error
end
