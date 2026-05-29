if Code.ensure_loaded?(Mailglass) and not Code.ensure_loaded?(Mailglass.TestRepo) do
  defmodule Mailglass.TestRepo do
    @moduledoc false

    use Ecto.Repo,
      otp_app: :mailglass,
      adapter: Ecto.Adapters.Postgres
  end
end
