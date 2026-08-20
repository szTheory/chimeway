defmodule Chimeway.Test.APNSFakeTransport do
  @behaviour Chimeway.APNS.Transport

  @impl true
  def push(dispatcher_ref, request, _opts) do
    send(
      Application.fetch_env!(:chimeway, :apns_fake_transport_pid),
      {:apns_push, dispatcher_ref, redact(request)}
    )

    Application.get_env(
      :chimeway,
      :apns_fake_transport_result,
      {:ok, %Chimeway.APNS.Transport.Result{outcome: :accepted, code: :accepted}}
    )
  end

  defp redact(%Chimeway.APNS.Transport.Request{} = request),
    do: %{request | device_token: "[REDACTED]"}
end
