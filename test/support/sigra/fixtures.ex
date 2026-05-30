if Code.ensure_loaded?(Sigra) and not Code.ensure_loaded?(Chimeway.TestSupport.SigraFixtures) do
  defmodule Chimeway.TestSupport.SigraFixtures do
    @moduledoc false

    @compile {:no_warn_undefined, [Sigra.Integrations.Chimeway.PendingDelivery]}

    import ExUnit.Assertions

    alias Chimeway.TestSupport.Sigra.User
    alias Sigra.TestRepo, as: Repo

    @telemetry_stop_events [
      [:chimeway, :dispatch, :sync, :stop],
      [:chimeway, :attempts, :record, :stop]
    ]

    @telemetry_pii_keys ~w(url code raw_token magic_link_url email body payload)a

    def configure_chimeway_logger_adapter! do
      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => {Chimeway.Adapters.Logger, []}
      })

      :ok
    end

    def configure_sigra_chimeway_integration! do
      unless Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
        raise "Sigra.Integrations.Chimeway is not loaded — compile sigra with optional chimeway dep"
      end

      Application.put_env(:sigra, :chimeway, enabled: true)

      unless Application.get_env(:sigra, :repo) do
        Application.put_env(:sigra, :repo, Sigra.TestRepo)
      end

      Application.put_env(:chimeway, :dispatcher, Chimeway.Dispatch.Sync)

      :ok
    end

    def attach_sigra_telemetry_handler! do
      test_pid = self()
      handler_id = :"sigra_chimeway_telemetry_#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        @telemetry_stop_events,
        fn event, _measurements, metadata, _config ->
          send(test_pid, {:sigra_telemetry_stop, event, metadata})
        end,
        nil
      )

      handler_id
    end

    def refute_sensitive_in_telemetry!(secrets, timeout \\ 1_000) do
      secrets = normalize_secrets(secrets)
      deadline = System.monotonic_time(:millisecond) + timeout

      drain_telemetry_until(deadline, fn _event, metadata ->
        pii_found = Enum.filter(@telemetry_pii_keys, &Map.has_key?(metadata, &1))

        assert pii_found == [],
               "PII keys #{inspect(pii_found)} found in telemetry metadata: #{inspect(metadata)}"

        metadata_str = inspect(metadata)

        for secret <- secrets do
          refute String.contains?(metadata_str, secret),
                 "secret substring found in telemetry metadata"
        end
      end)

      :ok
    end

    def refute_sensitive_in_trace!(trace, secrets) do
      secrets = normalize_secrets(secrets)
      trace_str = inspect(trace)
      payload_str = trace.payload |> normalize_payload_string()

      for secret <- secrets do
        refute String.contains?(trace_str, secret),
               "secret #{inspect(secret)} found in trace inspect"

        refute String.contains?(payload_str, secret),
               "secret #{inspect(secret)} found in event payload"
      end

      for notification <- trace.notifications || [] do
        metadata_str = inspect(notification.metadata || %{})

        for secret <- secrets do
          refute String.contains?(metadata_str, secret),
                 "secret found in notification metadata"
        end

        for delivery <- notification.deliveries || [] do
          render_data = delivery.render_data || %{}

          for field <- ["subject", "html_body", "text_body"] do
            value = Map.get(render_data, field, "")
            value_str = if is_binary(value), do: value, else: inspect(value)

            for secret <- secrets do
              refute String.contains?(value_str, secret),
                     "secret found in delivery render_data #{field}"
            end
          end
        end
      end

      :ok
    end

    def cleanup_pending_deliveries! do
      if Code.ensure_loaded?(Sigra.Integrations.Chimeway.PendingDelivery) do
        Sigra.Integrations.Chimeway.PendingDelivery.delete_all()
      end

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

    def confirmation_url_fun(token) when is_binary(token) do
      "https://example.test/users/confirm/#{token}"
    end

    def secret_key_base do
      String.duplicate("a", 64)
    end

    defp normalize_secrets(secrets) when is_list(secrets) do
      secrets
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.uniq()
    end

    defp normalize_payload_string(payload) when is_map(payload) do
      case Jason.encode(payload) do
        {:ok, json} -> json
        _ -> inspect(payload)
      end
    end

    defp normalize_payload_string(payload), do: inspect(payload)

    defp drain_telemetry_until(deadline, assert_fn) do
      remaining = deadline - System.monotonic_time(:millisecond)

      if remaining <= 0 do
        :ok
      else
        receive do
          {:sigra_telemetry_stop, event, metadata} ->
            assert_fn.(event, metadata)
            drain_telemetry_until(deadline, assert_fn)
        after
          trunc(max(remaining, 0)) -> :ok
        end
      end
    end
  end
end
