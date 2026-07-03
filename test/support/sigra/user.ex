defmodule Chimeway.TestSupport.Sigra.User do
  @moduledoc """
  Minimal Postgres-backed user schema for Sigra auth integration harness.

  Uses integer primary keys (`binary_id: false`) — distinct from Sigra install
  golden templates which use `:binary_id`.
  """

  use Ecto.Schema

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:confirmed_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end
end
