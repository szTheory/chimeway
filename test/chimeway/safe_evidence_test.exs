defmodule Chimeway.SafeEvidenceTest do
  use ExUnit.Case, async: true

  alias Chimeway.SafeEvidence

  test "APNs target evidence retains only the bounded closed response vocabulary" do
    assert {:ok,
            %{
              "provider_status" => 429,
              "provider_reason" => "too_many_requests",
              "provider_timestamp" => 1,
              "provider_code" => "too_many_requests",
              "retry_after_ms" => 1_000,
              "corrective_action" => "retry_later",
              "accepted_at" => "2026-08-20T00:00:00Z"
            }} =
             SafeEvidence.target_attempt_facts(%{
               provider_status: 429,
               provider_reason: "too_many_requests",
               provider_timestamp: 1,
               provider_code: "too_many_requests",
               retry_after_ms: 1_000,
               corrective_action: "retry_later",
               accepted_at: "2026-08-20T00:00:00Z",
               raw_token: "must-not-persist"
             })

    for facts <- [
          %{provider_status: 99},
          %{provider_reason: String.duplicate("a", 81)},
          %{provider_timestamp: -1},
          %{retry_after_ms: 86_400_001},
          %{"provider_status" => 200, provider_status: 200},
          %{provider_reason: %{"body" => "must-not-persist"}}
        ] do
      assert {:error, :unsafe_evidence} = SafeEvidence.target_attempt_facts(facts)
    end
  end
end
