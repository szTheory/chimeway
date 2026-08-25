defmodule Mix.Tasks.Verify.AlphaTwin do
  @moduledoc false
  use Mix.Task

  @shortdoc "Prove the immutable Alpha twin accepted-handoff tracer"
  @usage "Usage: mix verify.alpha_twin"

  @impl Mix.Task
  def run([]) do
    Code.require_file(Path.expand("../../../scripts/prove-alpha-twin.exs", __DIR__))

    case apply(Chimeway.AlphaTwinProofRunner, :run!, []) do
      0 -> :ok
      status -> exit({:shutdown, status})
    end
  end

  def run(_) do
    Mix.shell().error(@usage)
    exit({:shutdown, 64})
  end
end
