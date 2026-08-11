defmodule Mix.Tasks.Verify.AdoptionPaths do
  @moduledoc false

  use Mix.Task

  @shortdoc "Prove one or all adoption paths from a built Chimeway artifact"
  @usage "Usage: mix verify.adoption_paths [--only core|mailglass|accrue]"
  @selectors %{"core" => :core, "mailglass" => :mailglass, "accrue" => :accrue}

  @impl Mix.Task
  def run(argv) do
    case parse(argv) do
      {:ok, paths} ->
        Code.require_file(Path.expand("../../../scripts/prove-adoption-paths.exs", __DIR__))

        case apply(Chimeway.AdoptionProofRunner, :run!, [paths]) do
          0 -> :ok
          status -> exit({:shutdown, status})
        end

      :error ->
        Mix.shell().error(@usage)
        exit({:shutdown, 64})
    end
  end

  defp parse(argv) do
    {options, arguments, invalid} = OptionParser.parse(argv, strict: [only: :string])
    selectors = Keyword.get_values(options, :only)
    only_count = Enum.count(argv, &(&1 == "--only" or String.starts_with?(&1, "--only=")))

    cond do
      invalid != [] or arguments != [] or only_count > 1 ->
        :error

      selectors == [] ->
        {:ok, [:core, :mailglass, :accrue]}

      length(selectors) == 1 ->
        case Map.fetch(@selectors, hd(selectors)) do
          {:ok, selector} -> {:ok, [selector]}
          :error -> :error
        end

      true ->
        :error
    end
  end
end
