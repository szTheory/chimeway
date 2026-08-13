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

  test "provider facts reject duplicate logical fields in maps and tuple lists regardless of value or order" do
    for input <- [
          %{"provider_code" => "accepted", provider_code: "accepted"},
          %{"provider_code" => "recipient@example.test", provider_code: "accepted"},
          [{:provider_code, "accepted"}, {"provider_code", "accepted"}],
          [
            {"provider_code", "recipient@example.test"},
            {:retry_after_ms, 5},
            {:provider_code, "accepted"}
          ],
          [
            {:provider_code, "accepted"},
            {:accepted_at, ~U[2026-08-12 12:00:00Z]},
            {"provider_code", "accepted"}
          ]
        ] do
      assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(input)
    end

    for input <- [
          %{"retry_after_ms" => 5, retry_after_ms: 5},
          [{:retry_after_ms, 5}, {"retry_after_ms", 6}],
          %{"accepted_at" => "2026-08-12T12:00:00Z", accepted_at: ~U[2026-08-12 12:00:00Z]},
          [{"accepted_at", "2026-08-12T12:00:00Z"}, {:accepted_at, "2026-08-12T12:00:00Z"}]
        ] do
      assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(input)
    end
  end

  test "attempt attributes reject duplicate logical fields and retain a singleton representation" do
    valid = [
      outcome: :failed,
      error_class: "temporary",
      adapter_module: "test_adapter",
      provider_message_id: "cw_provider_opaque-123",
      provider_response: [provider_code: "accepted", retry_after_ms: 5]
    ]

    assert {:ok, attrs} = SafeEvidence.attempt_attrs(valid)
    assert attrs.outcome == :failed
    assert attrs.provider_response == %{"provider_code" => "accepted", "retry_after_ms" => 5}

    for attrs <- [
          [{:outcome, :failed}, {"outcome", :failed}],
          [{"outcome", :failed}, {:error_class, "temporary"}, {:outcome, :failed}],
          [{:outcome, :failed}, {:error_class, "temporary"}, {"error_class", "temporary"}],
          [
            {:outcome, :failed},
            {:adapter_module, "test_adapter"},
            {"adapter_module", "test_adapter"}
          ],
          [
            {:outcome, :failed},
            {:provider_message_id, "cw_provider_opaque-123"},
            {"provider_message_id", "cw_provider_opaque-123"}
          ],
          [{:outcome, :failed}, {:provider_response, %{}}, {"provider_response", %{}}]
        ] do
      assert {:error, :unsafe_evidence, _field} = SafeEvidence.attempt_attrs(attrs)
    end
  end

  test "render channels omit atom string channel and render identity collisions" do
    assert SafeEvidence.render_channels(%{
             "email" => %{render_key: "welcome", render_version: 1},
             email: %{render_key: "welcome", render_version: 1}
           }) == %{}

    assert SafeEvidence.render_channels(%{
             "email" => [
               {:render_key, "welcome"},
               {"render_key", "welcome"},
               {:render_version, 1}
             ]
           }) == %{}

    assert SafeEvidence.render_channels(%{
             "email" => [{:render_key, "welcome"}, {:render_version, 1}, {"render_version", 1}]
           }) == %{}

    assert SafeEvidence.render_channels(email: %{render_key: "welcome", render_version: 1}) == %{
             "email" => %{"render_key" => "welcome", "render_version" => 1}
           }
  end

  test "provider codes use the closed categorical grammar" do
    for code <- [
          "email-delivery",
          "https://provider.test/status",
          "bearer-token",
          "recipient-42",
          "body-content",
          " accepted",
          "accepted ",
          "accepted\n",
          "prefix_token_suffix",
          String.duplicate("a", 81)
        ] do
      assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(%{provider_code: code})
    end

    assert {:ok, %{"provider_code" => "accepted-v1"}} =
             SafeEvidence.provider_facts(%{provider_code: "accepted-v1"})
  end

  test "empty and nil optional evidence remains safe" do
    assert {:ok, %{}} = SafeEvidence.provider_facts(%{})
    assert {:ok, %{}} = SafeEvidence.provider_facts([])
    assert {:error, :unsafe_evidence} = SafeEvidence.provider_facts(nil)

    assert {:ok, %{outcome: :failed, provider_response: %{}}} =
             SafeEvidence.attempt_attrs(%{outcome: :failed, provider_response: nil})
  end
end
