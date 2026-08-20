defmodule APNSConsumerTest do
  use ExUnit.Case, async: true

  test "core Chimeway API works without APNs configuration" do
    assert %{} == APNSConsumer.core_smoke()
  end

  test "enabled fixture preserves the complete synthetic 410 tuple" do
    assert {:ok, %{status: 410, reason: :expired_token, timestamp: 1_725_000_000}} =
             APNSConsumer.expired_token_result()

    for response <- [
          %{"reason" => "ExpiredToken", "timestamp" => 1},
          %{"status" => 410, "timestamp" => 1},
          %{"status" => 410, "reason" => "ExpiredToken"},
          %{"status" => 400, "reason" => "ExpiredToken", "timestamp" => 1}
        ] do
      assert {:error, :incomplete_provider_response} =
               Chimeway.APNS.Transport.PigeonAdapter.extract_response(response)
    end
  end

  test "evidence is a single safe sandbox-only line" do
    evidence = APNSConsumer.evidence()
    assert {:ok, decoded} = Jason.decode(evidence)
    assert decoded == %{
             "environment" => "sandbox",
             "outcome" => "provider_accepted",
             "proof" => "not_live_not_device_not_open",
             "provider" => "apns"
           }
    refute String.contains?(evidence, "fixture-token")
  end
end
