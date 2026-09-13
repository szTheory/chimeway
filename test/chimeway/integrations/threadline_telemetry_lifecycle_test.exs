if Code.ensure_loaded?(Threadline) do
  defmodule Chimeway.Integrations.ThreadlineTelemetryLifecycleTest do
    @moduledoc false

    use Threadline.DataCase, async: false

    @moduletag :threadline

    import Ecto.Query

    alias Chimeway.{Preferences, Trigger}
    alias Chimeway.Policy.Settings
    alias Threadline.Query
    alias Threadline.Semantics.AuditAction
    alias Threadline.Test.Repo, as: ThreadlineRepo

    defmodule SuppressLifecycleNotifier do
      @behaviour Chimeway.Notifier

      @impl true
      def notification_key, do: "threadline.lifecycle.suppress"

      @impl true
      def version, do: 1

      @impl true
      def recipients(%{recipient_id: recipient_id}) do
        {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}
      end

      @impl true
      def build(_params, _recipient) do
        {:ok,
         %{
           "headline" => "suppress",
           "body" => "suppress",
           "primary_action" => %{"label" => "view", "url" => "http://example.test/view"}
         }}
      end
    end

    defmodule DeferLifecycleNotifier do
      @behaviour Chimeway.Notifier

      @impl true
      def notification_key, do: "threadline.lifecycle.defer"

      @impl true
      def version, do: 1

      @impl true
      def recipients(%{recipient_id: recipient_id}) do
        {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}
      end

      @impl true
      def build(_params, _recipient) do
        {:ok,
         %{
           "headline" => "defer",
           "body" => "defer",
           "primary_action" => %{"label" => "view", "url" => "http://example.test/view"}
         }}
      end
    end

    defmodule DispatchLifecycleNotifier do
      @behaviour Chimeway.Notifier

      @impl true
      def notification_key, do: "threadline.lifecycle.dispatch"

      @impl true
      def version, do: 1

      @impl true
      def recipients(%{recipient_id: recipient_id}) do
        {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}
      end

      @impl true
      def build(_params, _recipient) do
        {:ok,
         %{
           "headline" => "dispatch",
           "body" => "dispatch",
           "primary_action" => %{"label" => "view", "url" => "http://example.test/view"}
         }}
      end
    end

    defmodule FailedLifecycleNotifier do
      @behaviour Chimeway.Notifier

      @impl true
      def notification_key, do: "threadline.lifecycle.failed"

      @impl true
      def version, do: 1

      @impl true
      def recipients(%{recipient_id: recipient_id}) do
        {:ok, [%{recipient_identity: recipient_id, recipient_type: "user"}]}
      end

      @impl true
      def build(_params, _recipient) do
        {:ok,
         %{
           "headline" => "failed",
           "body" => "failed",
           "primary_action" => %{"label" => "view", "url" => "http://example.test/view"}
         }}
      end
    end

    defmodule TemporaryErrorAdapter do
      @behaviour Chimeway.Adapter

      @impl Chimeway.Adapter
      def deliver(_delivery, _config), do: {:error, :temporary, %{reason: "timeout"}}
    end

    setup do
      attach_threadline_reporter!()
      configure_chimeway_logger_adapter!()

      on_exit(fn -> detach_threadline_reporter!() end)

      :ok
    end

    describe "notification lifecycle → Threadline audit (ECOS-08)" do
      test ":notification_suppressed maps policy suppress span to audit_actions row" do
        recipient_id = "cw_tl_suppress_#{System.unique_integer([:positive])}"
        correlation_id = "tl-suppress-#{Ecto.UUID.generate()}"

        Preferences.upsert_preference(%{
          recipient_id: recipient_id,
          notification_key: "threadline.lifecycle.suppress",
          channel: "in_app",
          enabled: false
        })

        assert {:ok, _result} =
                 Trigger.trigger(
                   SuppressLifecycleNotifier,
                   %{recipient_id: recipient_id},
                   idempotency_key: "tl-suppress-#{System.unique_integer([:positive])}",
                   correlation_id: correlation_id,
                   tenant_id: "acme"
                 )

        audit_row =
          assert_audit_action!(:notification_suppressed, correlation_id,
            reason_contains: "channel_disabled"
          )

        assert_correlation_timeline_filter!(correlation_id, audit_row)
      end

      test ":notification_deferred maps quiet-hours planning span to audit_actions row" do
        recipient_id = "cw_tl_defer_#{System.unique_integer([:positive])}"
        correlation_id = "tl-defer-#{Ecto.UUID.generate()}"

        assert {:ok, _} =
                 Settings.upsert_settings(%{
                   recipient_id: recipient_id,
                   quiet_hours_start_minute: 22 * 60,
                   quiet_hours_end_minute: 8 * 60,
                   time_zone: "America/New_York"
                 })

        assert {:ok, _result} =
                 Trigger.trigger(
                   DeferLifecycleNotifier,
                   %{recipient_id: recipient_id},
                   idempotency_key: "tl-defer-#{System.unique_integer([:positive])}",
                   correlation_id: correlation_id,
                   tenant_id: "acme",
                   evaluation_time: ~U[2026-01-15 03:30:00Z]
                 )

        audit_row =
          assert_audit_action!(:notification_deferred, correlation_id,
            reason_contains: "quiet_hours"
          )

        assert audit_row.reason == "quiet_hours"
      end

      test ":notification_dispatched maps sync dispatch span to audit_actions row" do
        recipient_id = "cw_tl_dispatch_#{System.unique_integer([:positive])}"
        correlation_id = "tl-dispatch-#{Ecto.UUID.generate()}"

        assert {:ok, _result} =
                 Trigger.trigger(
                   DispatchLifecycleNotifier,
                   %{recipient_id: recipient_id},
                   idempotency_key: "tl-dispatch-#{System.unique_integer([:positive])}",
                   correlation_id: correlation_id,
                   tenant_id: "acme"
                 )

        audit_row =
          assert_audit_action!(:notification_dispatched, correlation_id, reason: "dispatched")

        assert_correlation_timeline_filter!(correlation_id, audit_row)
      end

      test ":notification_failed maps failed attempt span to audit_actions row" do
        recipient_id = "cw_tl_failed_#{System.unique_integer([:positive])}"
        correlation_id = "tl-failed-#{Ecto.UUID.generate()}"
        previous_adapter = Application.get_env(:chimeway, :adapter)

        Application.put_env(:chimeway, :adapter, TemporaryErrorAdapter)

        on_exit(fn ->
          case previous_adapter do
            nil -> Application.delete_env(:chimeway, :adapter)
            mod -> Application.put_env(:chimeway, :adapter, mod)
          end
        end)

        assert {:ok, _result} =
                 Trigger.trigger(
                   FailedLifecycleNotifier,
                   %{recipient_id: recipient_id},
                   idempotency_key: "tl-failed-#{System.unique_integer([:positive])}",
                   correlation_id: correlation_id,
                   tenant_id: "acme"
                 )

        assert_audit_action!(:notification_failed, correlation_id, reason: "failed")
      end
    end

    defp assert_audit_action!(action_name, correlation_id, opts) do
      action_string = Atom.to_string(action_name)

      rows =
        ThreadlineRepo.all(
          from(a in AuditAction,
            where: a.name == ^action_string and a.correlation_id == ^correlation_id
          )
        )

      assert length(rows) == 1,
             "expected exactly one #{action_string} audit row for #{correlation_id}, got #{length(rows)}"

      [audit_row] = rows

      assert audit_row.category == "notifications"
      assert audit_row.correlation_id == correlation_id

      assert audit_row.comment =~ "delivery_id=" or audit_row.comment =~ "notification_key=",
             "expected bounded comment summary, got: #{inspect(audit_row.comment)}"

      case Keyword.get(opts, :reason) do
        nil -> :ok
        expected -> assert audit_row.reason == expected
      end

      case Keyword.get(opts, :reason_contains) do
        nil -> :ok
        fragment -> assert String.contains?(audit_row.reason || "", fragment)
      end

      assert_no_pii_in_audit_fields!(audit_row)
      audit_row
    end

    defp assert_correlation_timeline_filter!(correlation_id, %AuditAction{} = audit_row) do
      assert audit_row.correlation_id == correlation_id

      assert [] =
               Query.timeline(correlation_id: correlation_id, repo: ThreadlineRepo)
    end
  end
end
