defmodule Chimeway.Webhooks.IngressTest do
  @moduledoc """
  Phase 33 Plan 01: schema validation tests + partial unique index integration tests
  for `Chimeway.Webhooks.Ingress`.

  Tests 1-7 use `ExUnit.Case, async: true` (no DB needed for changeset validation).
  Tests 8-10 use `Chimeway.DataCase, async: true` (must hit Repo to surface the
  partial composite unique constraint).
  """

  alias Chimeway.Webhooks.Ingress

  defp valid_attrs(overrides \\ %{}) do
    %{
      adapter_module: "MyAdapter",
      normalized_status: "delivered",
      ingress_state: :queued,
      delivery_id: Ecto.UUID.generate()
    }
    |> Map.merge(overrides)
  end

  describe "changeset/2 — validation" do
    use ExUnit.Case, async: true

    test "is valid with required fields present" do
      changeset = Ingress.changeset(%Ingress{}, valid_attrs())

      assert changeset.valid?,
             "expected base attrs to remain valid; errors=#{inspect(changeset.errors)}"
    end

    test "requires :adapter_module" do
      changeset =
        Ingress.changeset(%Ingress{}, Map.delete(valid_attrs(), :adapter_module))

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:adapter_module]
    end

    test "requires :normalized_status" do
      changeset =
        Ingress.changeset(%Ingress{}, Map.delete(valid_attrs(), :normalized_status))

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:normalized_status]
    end

    test "rejects :normalized_status not in ~w(delivered bounced failed)" do
      changeset =
        Ingress.changeset(%Ingress{}, valid_attrs(%{normalized_status: "unknown"}))

      refute changeset.valid?
      assert {_msg, opts} = changeset.errors[:normalized_status]
      assert Keyword.get(opts, :validation) == :inclusion
    end

    test "rejects empty-string :adapter_module via validate_length min:1" do
      changeset =
        Ingress.changeset(%Ingress{}, valid_attrs(%{adapter_module: ""}))

      refute changeset.valid?
      assert {_msg, opts} = changeset.errors[:adapter_module]
      assert Keyword.get(opts, :validation) == :length
    end

    test "is valid when :ingress_state is :ignored with :ignored_reason and no correlation keys" do
      attrs = %{
        adapter_module: "MyAdapter",
        normalized_status: "delivered",
        ingress_state: :ignored,
        ignored_reason: :delivery_not_found
      }

      changeset = Ingress.changeset(%Ingress{}, attrs)

      assert changeset.valid?,
             "expected :ignored with reason to be valid without correlation keys; errors=#{inspect(changeset.errors)}"
    end

    test "is invalid when no correlation key is present and ingress is not :ignored with a reason" do
      attrs = %{
        adapter_module: "MyAdapter",
        normalized_status: "delivered",
        ingress_state: :queued
      }

      changeset = Ingress.changeset(%Ingress{}, attrs)

      refute changeset.valid?
      assert {"must be present, or provider_message_id must be present, or ingress must be :ignored with a reason",
              _} = changeset.errors[:delivery_id]
    end
  end

  describe "DB constraints — partial composite unique index" do
    use Chimeway.DataCase, async: true

    test "inserting duplicate (adapter_module, provider_event_id) triggers unique constraint" do
      {:ok, _first} =
        %Ingress{}
        |> Ingress.changeset(
          valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterA"})
        )
        |> Chimeway.Repo.insert()

      {:error, changeset} =
        %Ingress{}
        |> Ingress.changeset(
          valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterA"})
        )
        |> Chimeway.Repo.insert()

      refute changeset.valid?

      assert Enum.any?(changeset.errors, fn {_, {_, opts}} ->
               opts[:constraint_name] == :chimeway_webhook_ingress_adapter_provider_event_uniq
             end)
    end

    test "two rows with same adapter_module but provider_event_id = nil can both be inserted (partial index does not collide on NULLs)" do
      assert {:ok, _first} =
               %Ingress{}
               |> Ingress.changeset(
                 valid_attrs(%{
                   provider_event_id: nil,
                   adapter_module: "AdapterB",
                   provider_message_id: "msg_1"
                 })
               )
               |> Chimeway.Repo.insert()

      assert {:ok, _second} =
               %Ingress{}
               |> Ingress.changeset(
                 valid_attrs(%{
                   provider_event_id: nil,
                   adapter_module: "AdapterB",
                   provider_message_id: "msg_2"
                 })
               )
               |> Chimeway.Repo.insert()
    end

    test "two rows with same provider_event_id but different adapter_module can both be inserted (composite prevents cross-adapter collision)" do
      assert {:ok, _first} =
               %Ingress{}
               |> Ingress.changeset(
                 valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterC"})
               )
               |> Chimeway.Repo.insert()

      assert {:ok, _second} =
               %Ingress{}
               |> Ingress.changeset(
                 valid_attrs(%{provider_event_id: "evt_001", adapter_module: "AdapterD"})
               )
               |> Chimeway.Repo.insert()
    end
  end
end
