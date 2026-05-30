if Code.ensure_loaded?(Threadline) do
  defmodule Chimeway.Integrations.ThreadlineTelemetryHarnessTest do
    @moduledoc false

    use Threadline.DataCase, async: false

    @moduletag :threadline

    alias Threadline.Semantics.AuditAction
    alias Threadline.Semantics.ActorRef
    alias Threadline.Test.Repo, as: ThreadlineRepo

    describe "threadline telemetry harness (ECOS-08 wave 1)" do
      test "reporter config round-trip sets repo and actor" do
        configure_threadline_reporter!()

        config = Application.get_env(:chimeway, :threadline_reporter)

        assert config[:repo] == Threadline.Test.Repo
        assert %ActorRef{} = config[:actor]
      end

      test "Threadline module loaded exports record_action/2" do
        assert function_exported?(Threadline, :record_action, 2)
      end

      test "TestRepo reachable after setup cleanup" do
        assert ThreadlineRepo.aggregate(AuditAction, :count) == 0
      end
    end
  end
end
