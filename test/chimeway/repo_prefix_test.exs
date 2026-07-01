defmodule Chimeway.RepoPrefixTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Events.Event
  alias Chimeway.{Repo, Storage}

  @normal_operations [:all, :insert, :update, :delete, :insert_all]

  setup do
    previous_prefix = Application.fetch_env(:chimeway, :prefix)

    on_exit(fn -> restore_prefix(previous_prefix) end)

    :ok
  end

  describe "Repo.default_options/1" do
    test "does not put Chimeway storage prefixes on transaction options" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert Repo.default_options(:transaction) == []
    end

    test "delegates normal operation defaults to Chimeway.Storage.repo_opts/1" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      for operation <- @normal_operations do
        assert Map.new(Repo.default_options(operation)) == %{prefix: "chimeway"}
      end
    end

    test "keeps public-schema legacy mode unprefixed for normal operations" do
      Application.put_env(:chimeway, :prefix, false)

      for operation <- @normal_operations do
        refute Map.has_key?(Map.new(Repo.default_options(operation)), :prefix)
      end
    end
  end

  describe "Storage.repo_opts/1 contract" do
    test "preserves explicit caller prefix probes" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert Storage.repo_opts(prefix: "probe_schema", timeout: 1) == [
               prefix: "probe_schema",
               timeout: 1
             ]
    end

    test "lets an explicit repo operation prefix win over configured storage" do
      Application.put_env(:chimeway, :prefix, "chimeway")

      assert_raise Postgrex.Error, ~r/probe_schema.*chimeway_events|schema "probe_schema"/, fn ->
        Repo.all(Event, prefix: "probe_schema")
      end
    end
  end

  describe "rejected prefix interface shapes" do
    test "does not introduce schema prefixes or a wrapper repo" do
      source =
        ["lib/chimeway/repo.ex", "lib/chimeway/storage.ex"]
        |> Enum.map_join("\n", &File.read!/1)

      refute source =~ "@schema_prefix"
      refute source =~ "schema_prefix"
      refute source =~ "defmodule Chimeway.Storage.Repo"
    end
  end

  defp restore_prefix({:ok, value}) do
    Application.put_env(:chimeway, :prefix, value)
  end

  defp restore_prefix(:error) do
    Application.delete_env(:chimeway, :prefix)
  end
end
