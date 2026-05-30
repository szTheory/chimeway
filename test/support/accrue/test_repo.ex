if Code.ensure_loaded?(Accrue) and not Code.ensure_loaded?(Accrue.TestRepo) do
  defmodule Accrue.TestRepo do
    @moduledoc false

    use Ecto.Repo,
      otp_app: :accrue,
      adapter: Ecto.Adapters.Postgres
  end
end
