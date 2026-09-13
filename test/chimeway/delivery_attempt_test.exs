defmodule Chimeway.DeliveryAttemptTest do
  @moduledoc """
  REL-02 (Phase 14 Plan 14-02): unit tests for the DeliveryAttempt changeset extensions
  — attempt_number positive-integer validation and error_class whitelist validation.

  Plan 14-04 Task 3 promoted `:attempt_number` to `@required_fields` once
  `Deliveries.record_attempt/2` was wired to inject the value via the
  `:next_attempt_number` Multi step. Direct-construction call sites (these unit
  tests) now must include `attempt_number` in the base attrs.
  """

  use ExUnit.Case, async: true

  alias Chimeway.DeliveryAttempt

  # The changeset only tests cast/validate — it does not require a DB hit.
  # We construct attrs with a bogus delivery_id (UUID format) since validate_required
  # only checks presence, not referential integrity.

  defp valid_attrs(overrides \\ %{}) do
    %{
      delivery_id: "00000000-0000-0000-0000-000000000001",
      outcome: :succeeded,
      attempt_number: 1
    }
    |> Map.merge(overrides)
  end

  describe "changeset/2 — base contract (additive change)" do
    test "is valid with delivery_id, outcome, and attempt_number (Plan 14-04 Task 3 promotes attempt_number to required)" do
      changeset = DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs())

      assert changeset.valid?,
             "expected base attrs to remain valid; errors=#{inspect(changeset.errors)}"
    end

    test "requires delivery_id" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{outcome: :succeeded, attempt_number: 1})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:delivery_id]
    end

    test "requires outcome" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{
          delivery_id: "00000000-0000-0000-0000-000000000001",
          attempt_number: 1
        })

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:outcome]
    end

    test "requires attempt_number (Plan 14-04 Task 3)" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{
          delivery_id: "00000000-0000-0000-0000-000000000001",
          outcome: :succeeded
        })

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:attempt_number]
    end

    test "casts provider_response when present" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{provider_response: %{"id" => "abc"}})
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :provider_response) == %{"id" => "abc"}
    end
  end

  describe "changeset/2 — error_class whitelist (REL-02)" do
    test "accepts \"temporary\"" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{outcome: :failed, error_class: "temporary"})
        )

      assert changeset.valid?, "errors=#{inspect(changeset.errors)}"
      assert Ecto.Changeset.get_change(changeset, :error_class) == "temporary"
    end

    test "accepts \"permanent\"" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{outcome: :rejected, error_class: "permanent"})
        )

      assert changeset.valid?, "errors=#{inspect(changeset.errors)}"
    end

    test "accepts \"bounced\"" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{outcome: :bounced, error_class: "bounced"})
        )

      assert changeset.valid?, "errors=#{inspect(changeset.errors)}"
    end

    test "rejects values outside the whitelist with validate_inclusion error" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{outcome: :failed, error_class: "unknown"})
        )

      refute changeset.valid?
      assert {_msg, opts} = changeset.errors[:error_class]
      assert Keyword.get(opts, :validation) == :inclusion
    end

    test "allows error_class to be nil (succeeded outcome)" do
      changeset =
        DeliveryAttempt.changeset(
          %DeliveryAttempt{},
          valid_attrs(%{outcome: :succeeded, error_class: nil})
        )

      assert changeset.valid?, "errors=#{inspect(changeset.errors)}"
    end
  end

  describe "changeset/2 — attempt_number positive-integer validation (REL-02)" do
    test "accepts positive integer >= 1" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs(%{attempt_number: 1}))

      assert changeset.valid?, "errors=#{inspect(changeset.errors)}"
      assert Ecto.Changeset.get_change(changeset, :attempt_number) == 1
    end

    test "accepts higher positive integers" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs(%{attempt_number: 5}))

      assert changeset.valid?
    end

    test "rejects 0 with \"must be a positive integer\" message" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs(%{attempt_number: 0}))

      refute changeset.valid?
      assert {"must be a positive integer", _} = changeset.errors[:attempt_number]
    end

    test "rejects negative integers with \"must be a positive integer\" message" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, valid_attrs(%{attempt_number: -1}))

      refute changeset.valid?
      assert {"must be a positive integer", _} = changeset.errors[:attempt_number]
    end

    test "rejects omitted attempt_number with \"can't be blank\" message (Plan 14-04 Task 3)" do
      changeset =
        DeliveryAttempt.changeset(%DeliveryAttempt{}, %{
          delivery_id: "00000000-0000-0000-0000-000000000001",
          outcome: :succeeded
        })

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:attempt_number]
    end
  end

  describe "error_classes/0 helper" do
    test "returns the canonical whitelist as strings" do
      assert DeliveryAttempt.error_classes() == [
               "temporary",
               "permanent",
               "bounced",
               "render_context_unavailable",
               "unknown_classification"
             ]
    end
  end
end
