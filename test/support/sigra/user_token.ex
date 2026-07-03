defmodule Chimeway.TestSupport.Sigra.UserToken do
  @moduledoc """
  Minimal Postgres-backed user token schema for Sigra auth integration harness.

  Uses integer primary keys (`binary_id: false`) — distinct from Sigra install
  golden templates which use `:binary_id`.
  """

  use Ecto.Schema

  schema "user_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)
    belongs_to(:user, Chimeway.TestSupport.Sigra.User)

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
