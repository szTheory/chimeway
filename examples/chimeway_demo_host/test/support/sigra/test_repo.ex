if Code.ensure_loaded?(Sigra) and not Code.ensure_loaded?(Sigra.TestRepo) do
  defmodule Sigra.TestRepo do
    @moduledoc false

    use Ecto.Repo,
      otp_app: :sigra,
      adapter: Ecto.Adapters.Postgres
  end
end
