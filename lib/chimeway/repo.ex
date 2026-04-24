defmodule Chimeway.Repo do
  use Ecto.Repo,
    otp_app: :chimeway,
    adapter: Ecto.Adapters.Postgres
end
