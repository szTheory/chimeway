defmodule Chimeway.Webhooks.IngressTest do
  @moduledoc """
  Phase 33 Plan 01: schema validation tests for `Chimeway.Webhooks.Ingress`.

  Uses `ExUnit.Case, async: true` (no DB needed for changeset validation).
  DB integration tests are in `Chimeway.Webhooks.IngressDBTest` below.
  """

  use ExUnit.Case, async: true

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

    test "rejects empty-string :adapter_module — validate_required + validate_length both guard the field" do
      # Ecto's validate_required treats "" as blank for :string fields, so the error
      # comes from :required validation. validate_length(:adapter_module, min: 1) provides
      # an additional guard for non-required callers; together they ensure the field is
      # always a non-empty string.
      changeset =
        Ingress.changeset(%Ingress{}, valid_attrs(%{adapter_module: ""}))

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:adapter_module]
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
end

defmodule Chimeway.Webhooks.IngressDBTest do
  @moduledoc """
  Phase 33 Plan 01: DB integration tests for the partial composite unique index
  on `chimeway_webhook_ingress`.

  Uses `Chimeway.DataCase, async: true` (must hit Repo to surface the constraint).

  Note: DB tests use `provider_message_id` as the correlation key (no FK constraint)
  to avoid needing a real `chimeway_deliveries` row. The `delivery_id` FK uses
  `on_delete: :nilify_all` so it is always nullable in practice.
  """

  use Chimeway.DataCase, async: true

  alias Chimeway.Webhooks.Ingress

  defp valid_attrs(overrides) do
    %{
      adapter_module: "MyAdapter",
      normalized_status: "delivered",
      ingress_state: :queued,
      provider_message_id: "msg_#{System.unique_integer([:positive])}"
    }
    |> Map.merge(overrides)
  end

  describe "DB constraints — partial composite unique index" do
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
               opts[:constraint_name] == "chimeway_webhook_ingress_adapter_provider_event_uniq" or
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
                   provider_message_id: "msg_b_1"
                 })
               )
               |> Chimeway.Repo.insert()

      assert {:ok, _second} =
               %Ingress{}
               |> Ingress.changeset(
                 valid_attrs(%{
                   provider_event_id: nil,
                   adapter_module: "AdapterB",
                   provider_message_id: "msg_b_2"
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
