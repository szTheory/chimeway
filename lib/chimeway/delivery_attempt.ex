defmodule Chimeway.DeliveryAttempt do
  @moduledoc """
  Ecto schema for chimeway_delivery_attempts — immutable append-only record of each
  provider call for a delivery. No updated_at — attempts are never mutated.

  ## REL-02 fields (Phase 14 D-07)

  - `attempt_number` :integer — 1-indexed ordinal of this attempt for its delivery,
    computed at insert time inside the same `Ecto.Multi` as the attempt insert.
    Plan 14-02 leaves this in `@optional_fields`; Plan 14-04 Task 3 promotes it to
    `@required_fields` after `Deliveries.record_attempt/2` is wired to inject the
    value via the new `:next_attempt_number` Multi step. The two-step landing keeps
    `mix test` green between Plan 14-02 and Plan 14-04.
  - `error_class` :string — one of `"temporary" | "permanent" | "bounced"` for
    `:failed | :rejected | :bounced` outcomes; `nil` for `:succeeded`. Persisted
    as a plain string with changeset whitelist validation (NOT `Ecto.Enum`) to
    match the project's string-channel idiom from Phase 11.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @error_classes ~w(temporary permanent bounced unknown_classification)

  @doc """
  Returns the canonical list of allowed error_class string values.
  Used by `Chimeway.Dispatch.Executor.classify/1` to validate that the dispatcher
  only emits whitelisted classifications. `"unknown_classification"` is the BL-02
  fallback value emitted by `classify/1` for unexpected adapter return shapes.
  """
  @spec error_classes() :: [String.t()]
  def error_classes, do: @error_classes

  schema "chimeway_delivery_attempts" do
    field(:outcome, Ecto.Enum, values: [:succeeded, :failed, :bounced, :rejected])
    field(:provider_response, :map)
    field(:attempt_number, :integer)
    field(:error_class, :string)
    field(:adapter_module, :string)
    field(:provider_message_id, :string)
    field(:inserted_at, :utc_datetime_usec)

    belongs_to(:delivery, Chimeway.Delivery)
  end

  # Plan 14-04 Task 3 promoted :attempt_number to @required_fields after
    # Deliveries.record_attempt/2 was wired to inject the value via the
    # :next_attempt_number Multi step (Plan 14-04 Task 2).
    @required_fields ~w(delivery_id outcome attempt_number)a
    @optional_fields ~w(error_class provider_response adapter_module provider_message_id)a

  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:error_class, @error_classes)
    |> validate_attempt_number_positive()
    |> put_inserted_at()
  end

  defp validate_attempt_number_positive(changeset) do
    case get_field(changeset, :attempt_number) do
      n when is_integer(n) and n >= 1 -> changeset
      nil -> changeset
      _ -> add_error(changeset, :attempt_number, "must be a positive integer")
    end
  end

  defp put_inserted_at(changeset) do
    if get_field(changeset, :inserted_at) do
      changeset
    else
      put_change(changeset, :inserted_at, DateTime.utc_now() |> DateTime.truncate(:microsecond))
    end
  end
end
