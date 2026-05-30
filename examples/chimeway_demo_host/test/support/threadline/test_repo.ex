if Code.ensure_loaded?(Threadline) and not Code.ensure_loaded?(Threadline.Test.Repo) do
  defmodule Threadline.Test.Repo do
    @moduledoc false

    use Ecto.Repo,
      otp_app: :threadline,
      adapter: Ecto.Adapters.Postgres
  end
end
