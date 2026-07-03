defmodule Chimeway.Telemetry.ThreadlineReporter do
  @moduledoc false

  if Code.ensure_loaded?(Threadline) do
    require Logger

    @handler_id :chimeway_threadline_reporter

    @stop_events (
                   base = [
                     [:chimeway, :policy, :evaluate, :stop],
                     [:chimeway, :dispatch, :sync, :stop],
                     [:chimeway, :attempts, :record, :stop]
                   ]

                   if Code.ensure_loaded?(Oban) do
                     base ++ [[:chimeway, :dispatch, :perform, :stop]]
                   else
                     base
                   end
                 )

    @comment_keys ~w(
      delivery_id notification_key channel attempt_id outcome attempt_number error_class
    )a

    @max_comment_bytes 512

    @doc """
    Attaches the Threadline telemetry bridge handler.

    Idempotent — safe to call multiple times. Host applications must call this
    explicitly; Chimeway does not auto-attach at library boot.

    Sync vs Oban perform both emit `:notification_dispatched` on dispatch `:stop`
    when outcome is not `:failed`. Default test config uses sync dispatch only;
    do not expect dedupe across both paths in the same delivery without host wiring.
    """
    @spec attach() :: :ok
    def attach do
      try do
        :telemetry.attach_many(
          @handler_id,
          @stop_events,
          &__MODULE__.handle_event/4,
          nil
        )
      catch
        :error, {:already_exists, @handler_id} -> :ok
      end

      :ok
    end

    @doc false
    def handle_event(event, _measurements, meta, _config) do
      try do
        with {:ok, repo, actor} <- fetch_config(),
             {:ok, action, reason} <- map_outcome(event, meta) do
          case Threadline.record_action(action,
                 repo: repo,
                 actor: actor,
                 correlation_id: meta[:correlation_id],
                 category: "notifications",
                 reason: reason,
                 comment: build_comment(meta)
               ) do
            {:ok, _action} ->
              :ok

            {:error, reason} ->
              Logger.debug("[chimeway] threadline reporter record_action failed",
                reason: inspect(reason)
              )
          end
        else
          :skip ->
            :ok

          {:error, :missing_config} ->
            :ok
        end
      rescue
        error ->
          Logger.debug("[chimeway] threadline reporter handler error",
            error: Exception.message(error)
          )

          :ok
      end
    end

    defp fetch_config do
      config = Application.get_env(:chimeway, :threadline_reporter, [])
      repo = Keyword.get(config, :repo)
      actor = Keyword.get(config, :actor)

      cond do
        is_nil(repo) ->
          Logger.debug("[chimeway] threadline reporter missing repo config")
          {:error, :missing_config}

        is_nil(actor) ->
          Logger.debug("[chimeway] threadline reporter missing actor config")
          {:error, :missing_config}

        true ->
          {:ok, repo, actor}
      end
    end

    defp map_outcome([:chimeway, :policy, :evaluate, :stop], meta) do
      cond do
        Map.has_key?(meta, :suppression_reason) ->
          {:ok, :notification_suppressed, meta.suppression_reason}

        Map.has_key?(meta, :planning_reason) ->
          {:ok, :notification_deferred, meta.planning_reason}

        true ->
          :skip
      end
    end

    defp map_outcome([:chimeway, :dispatch, :sync, :stop], meta),
      do: map_dispatch_outcome(meta)

    defp map_outcome([:chimeway, :dispatch, :perform, :stop], meta),
      do: map_dispatch_outcome(meta)

    defp map_outcome([:chimeway, :attempts, :record, :stop], %{outcome: :failed} = _meta) do
      {:ok, :notification_failed, "failed"}
    end

    defp map_outcome([:chimeway, :attempts, :record, :stop], _meta), do: :skip
    defp map_outcome(_event, _meta), do: :skip

    defp map_dispatch_outcome(meta) do
      if Map.get(meta, :outcome) == :failed do
        :skip
      else
        {:ok, :notification_dispatched, "dispatched"}
      end
    end

    defp build_comment(meta) when is_map(meta) do
      meta
      |> Map.take(@comment_keys)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map_join("; ", fn {key, value} -> "#{key}=#{value}" end)
      |> truncate_comment(@max_comment_bytes)
    end

    defp truncate_comment(comment, max) when byte_size(comment) <= max, do: comment

    defp truncate_comment(comment, max) do
      comment
      |> String.slice(0, max - 3)
      |> Kernel.<>("...")
    end
  end
end
