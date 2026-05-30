if Code.ensure_loaded?(Sigra) and not Code.ensure_loaded?(Chimeway.TestSupport.SigraFixtures) do
  defmodule Chimeway.TestSupport.SigraFixtures do
    @moduledoc false

    alias Chimeway.TestSupport.Sigra.User
    alias Sigra.TestRepo, as: Repo

    def configure_chimeway_logger_adapter! do
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      :ok
    end

    def insert_user!(attrs \\ %{}) do
      unique = System.unique_integer([:positive])

      defaults = %{
        email: "sigra-harness-#{unique}@example.test",
        hashed_password: nil,
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      attrs = Map.merge(defaults, Map.new(attrs))

      %User{}
      |> Ecto.Changeset.change(attrs)
      |> Repo.insert!()
    end

    def url_fun(token) when is_binary(token) do
      "https://example.test/magic/#{token}"
    end

    def secret_key_base do
      String.duplicate("a", 64)
    end
  end
end
