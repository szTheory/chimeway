defmodule Sigra.TestRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :sigra,
    adapter: Ecto.Adapters.Postgres
end
