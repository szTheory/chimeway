if Code.ensure_loaded?(Threadline) and
     not Code.ensure_loaded?(Chimeway.TestSupport.ThreadlineFixtures) do
  defmodule Chimeway.TestSupport.ThreadlineFixtures do
    @moduledoc false

    alias Threadline.Semantics.ActorRef

    def configure_threadline_reporter! do
      {:ok, actor} = ActorRef.new(:system, "chimeway")

      Application.put_env(:chimeway, :threadline_reporter,
        repo: Threadline.Test.Repo,
        actor: actor
      )

      :ok
    end

    def detach_threadline_reporter! do
      :telemetry.detach(:chimeway_threadline_reporter)
      :ok
    catch
      :error, {:not_found, :chimeway_threadline_reporter} -> :ok
    end

    def configure_chimeway_logger_adapter! do
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      :ok
    end
  end
end
