defmodule Chimeway.PrivacyTest do
  use ExUnit.Case, async: true

  alias Chimeway.{Privacy, SafeEvidence}

  test "redacts mixed-case forbidden keys recursively while retaining ordered duplicate allowed keywords" do
    value = %{
      "safe" => [
        [allowed: 1, TOKEN: "first", TOKEN: "second", allowed: 1],
        %{"renderedContent" => "hidden", "kept" => "value"}
      ],
      "DEVICE_TOKEN" => "hidden"
    }

    assert Privacy.redact(value) == %{
             "safe" => [[allowed: 1, allowed: 1], %{"kept" => "value"}]
           }
  end

  test "has stable empty, nil, singleton, and ordinary-list behavior" do
    assert Privacy.redact(%{}) == %{}
    assert Privacy.redact([]) == []
    assert Privacy.redact(nil) == nil
    assert Privacy.redact([%{"safe" => "value"}]) == [%{"safe" => "value"}]
    assert Privacy.redact([1, %{"Authorization" => "hidden"}, 2]) == [1, %{}, 2]
  end

  test "does not traverse forbidden values or create atoms from arbitrary binary keys" do
    forbidden_value = fn -> raise "must not be traversed" end
    assert Privacy.redact(%{"Provider_Body" => forbidden_value}) == %{}

    Privacy.redact(%{"warmup" => "value"})
    SafeEvidence.provider_facts(%{})

    for n <- 1..10 do
      key = "warmup_key_#{n}"
      Privacy.redact(%{key => "value"})
      SafeEvidence.provider_facts(%{key => "value"})
    end

    before = :erlang.system_info(:atom_count)

    for n <- 1..4_000 do
      key = "untrusted_key_#{n}_#{System.unique_integer([:positive])}"
      assert Privacy.redact(%{key => "value"}) == %{key => "value"}
      assert {:ok, %{}} = SafeEvidence.provider_facts(%{key => "value"})
    end

    # The test application starts optional integration processes concurrently; retain
    # a bounded process-level allowance while still catching caller-key atomization.
    assert :erlang.system_info(:atom_count) - before < 1_000
  end

  test "provider facts retain only bounded validated values" do
    assert {:ok, facts} =
             SafeEvidence.provider_facts(%{
               provider_code: "accepted",
               retry_after_ms: 0,
               accepted_at: ~U[2026-08-12 12:00:00Z],
               unknown: "discarded"
             })

    assert facts == %{
             "provider_code" => "accepted",
             "retry_after_ms" => 0,
             "accepted_at" => "2026-08-12T12:00:00Z"
           }

    assert {:error, :unsafe_evidence} =
             SafeEvidence.provider_facts(%{provider_code: String.duplicate("x", 81)})

    assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(%{retry_after_ms: -1})
    assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(%{accepted_at: "not-a-date"})
  end
end
