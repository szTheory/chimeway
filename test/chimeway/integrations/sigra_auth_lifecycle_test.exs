if Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
  defmodule Chimeway.Integrations.SigraAuthLifecycleTest do
    @moduledoc false

    use Sigra.DataCase, async: false

    @moduletag :sigra

    alias Chimeway.Traces
    alias Chimeway.TestSupport.Sigra.User
    alias Sigra.Integrations.Chimeway, as: SigraChimeway
    alias Sigra.TestRepo, as: Repo

    describe "sigra auth → chimeway delivery (ECOS-09)" do
      setup do
        configure_chimeway_logger_adapter!()
        configure_sigra_chimeway_integration!()

        handler_id = attach_sigra_telemetry_handler!()

        on_exit(fn ->
          :telemetry.detach(handler_id)
          cleanup_pending_deliveries!()
        end)

        :ok
      end

      test "magic link dispatch creates durable delivery with redacted trace" do
        user = insert_user!()
        correlation_id = "sigra-ml-#{Ecto.UUID.generate()}"

        opts = [
          user_schema: User,
          user_token_schema: Chimeway.TestSupport.Sigra.UserToken,
          url_fun: &url_fun/1,
          correlation_id: correlation_id
        ]

        assert {:ok, {raw_token, url, result}} =
                 SigraChimeway.dispatch_magic_link_after_request(Repo, user.email, opts)

        event_id = result.event.id

        assert {:ok, trace} = Traces.get_trace(event_id)
        assert trace.notification_key == "sigra.auth.magic_link"
        assert trace.correlation_id == correlation_id

        assert trace.notifications != []

        deliveries =
          trace.notifications
          |> Enum.flat_map(& &1.deliveries)

        assert deliveries != []
        assert Enum.all?(deliveries, &delivery_attempted?/1)

        refute_sensitive_in_trace!(trace, [raw_token, url])
        refute_sensitive_in_telemetry!([raw_token, url])
      end

      test "confirmation code dispatch creates durable delivery with redacted trace" do
        user = insert_user!(confirmed_at: nil)
        correlation_id = "sigra-confirm-#{Ecto.UUID.generate()}"

        opts = [
          user_schema: User,
          user_token_schema: Chimeway.TestSupport.Sigra.UserToken,
          secret_key_base: secret_key_base(),
          confirmation_url_fun: &confirmation_url_fun/1,
          correlation_id: correlation_id
        ]

        assert {:ok, {_encoded_token, code, url, result}} =
                 SigraChimeway.dispatch_confirmation_after_generate(Repo, user, opts)

        event_id = result.event.id

        assert {:ok, trace} = Traces.get_trace(event_id)
        assert trace.notification_key == "sigra.auth.confirmation_code"
        assert trace.correlation_id == correlation_id

        deliveries =
          trace.notifications
          |> Enum.flat_map(& &1.deliveries)

        assert deliveries != []
        assert Enum.all?(deliveries, &delivery_attempted?/1)

        refute_sensitive_in_trace!(trace, [code, url])
        refute_sensitive_in_telemetry!([code, url])
      end
    end

    defp delivery_attempted?(%{status: status, attempts: attempts}) do
      status in ["succeeded", "dispatched", "failed", "suppressed"] or
        Enum.any?(attempts || [], fn _ -> true end)
    end
  end
end
