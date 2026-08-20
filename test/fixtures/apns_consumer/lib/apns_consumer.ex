defmodule APNSConsumer do
  @moduledoc false

  alias Chimeway.APNS.Transport
  alias Chimeway.APNS.Transport.{Request, Result}

  def core_smoke, do: Chimeway.SafeEvidence.delivery_metadata(%{"source" => "apns-consumer"})

  def accepted_result do
    {:ok, %Result{outcome: :accepted, code: :accepted}}
  end

  def expired_token_result do
    Transport.PigeonAdapter.extract_response(%{
      "status" => 410,
      "reason" => "ExpiredToken",
      "timestamp" => 1_725_000_000
    })
  end

  def request do
    %Request{
      device_token: "fixture-token-never-emitted",
      topic: "com.example.chimeway",
      environment: :sandbox,
      id: "9a2c7c14-9876-4bca-aabb-0123456789ab",
      expiration: 1_725_003_600,
      priority: 10,
      push_type: :alert,
      payload: %{json: %{"aps" => %{"alert" => %{"title" => "Fixture", "body" => "Accepted"}}}}
    }
  end

  def evidence do
    ~s({"provider":"apns","outcome":"provider_accepted","environment":"sandbox","proof":"not_live_not_device_not_open"})
  end
end
