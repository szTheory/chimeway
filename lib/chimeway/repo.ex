defmodule Chimeway.Repo do
  use Ecto.Repo,
    otp_app: :chimeway,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def default_options(:transaction), do: []
  def default_options(_operation), do: Chimeway.Storage.repo_opts()
end
