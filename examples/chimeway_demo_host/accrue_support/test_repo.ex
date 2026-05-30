defmodule Accrue.TestRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :accrue,
    adapter: Ecto.Adapters.Postgres
end
