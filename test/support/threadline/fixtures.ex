if Code.ensure_loaded?(Threadline) and
     not Code.ensure_loaded?(Chimeway.TestSupport.ThreadlineFixtures) do
  defmodule Chimeway.TestSupport.ThreadlineFixtures do
    @moduledoc false

    import ExUnit.Assertions

    alias Threadline.Semantics.ActorRef
    alias Threadline.Semantics.AuditAction

    @pii_markers ~w(html_body text_body password)

    def configure_threadline_reporter! do
      Application.put_env(:chimeway, :threadline_reporter,
        repo: Threadline.Test.Repo,
        actor: default_actor_ref()
      )

      :ok
    end

    def attach_threadline_reporter! do
      configure_threadline_reporter!()
      Chimeway.Telemetry.ThreadlineReporter.attach()
      :ok
    end

    def detach_threadline_reporter! do
      :telemetry.detach(:chimeway_threadline_reporter)
      :ok
    catch
      :error, {:not_found, :chimeway_threadline_reporter} -> :ok
    end

    def default_actor_ref do
      {:ok, actor} = ActorRef.new(:system, "chimeway")
      actor
    end

    def configure_chimeway_logger_adapter! do
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []},
        "in_app" => {Chimeway.Adapters.Logger, []}
      })

      :ok
    end

    def assert_no_pii_in_audit_fields!(%AuditAction{} = action) do
      comment = action.comment || ""
      reason = to_string(action.reason || "")

      refute String.match?(comment, ~r/@/),
             "comment must not contain email-like content: #{inspect(comment)}"

      refute String.match?(reason, ~r/@/),
             "reason must not contain email-like content: #{inspect(reason)}"

      Enum.each(@pii_markers, fn marker ->
        refute String.contains?(comment, marker),
               "comment must not contain #{marker}: #{inspect(comment)}"

        refute String.contains?(reason, marker),
               "reason must not contain #{marker}: #{inspect(reason)}"
      end)

      :ok
    end
  end
end
