defmodule Chimeway.APNS.Transport do
  @moduledoc "Closed APNs provider handoff contract with an optional dynamic Pigeon path."

  defmodule Request do
    @enforce_keys [
      :device_token,
      :topic,
      :environment,
      :id,
      :expiration,
      :priority,
      :push_type,
      :payload
    ]
    defstruct [
      :device_token,
      :topic,
      :environment,
      :id,
      :expiration,
      :collapse_id,
      :priority,
      :push_type,
      :payload
    ]
  end

  defmodule Result do
    @enforce_keys [:outcome, :code]
    defstruct [:outcome, :code, :status, :reason, :timestamp, :retry_after_ms]
  end

  @callback push(term(), Request.t(), keyword()) ::
              {:ok, Result.t()} | {:error, :ambiguous | :rejected}

  @spec push(term(), Request.t(), keyword()) ::
          {:ok, Result.t()} | {:error, :ambiguous | :rejected | :pigeon_unavailable}
  def push(dispatcher_ref, %Request{} = request, opts \\ []) do
    transport = Keyword.get(opts, :transport, Application.get_env(:chimeway, :apns_transport))

    if is_atom(transport) do
      transport.push(dispatcher_ref, request, opts)
    else
      pigeon_push(dispatcher_ref, request)
    end
  rescue
    _ -> {:error, :ambiguous}
  catch
    _, _ -> {:error, :ambiguous}
  end

  @spec pigeon_push(term(), Request.t()) ::
          {:ok, Result.t()} | {:error, :ambiguous | :rejected | :pigeon_unavailable}
  def pigeon_push(dispatcher_ref, %Request{} = request) do
    pigeon = Module.concat(["Pigeon"])
    notification_module = Module.concat(["Pigeon", "APNS", "Notification"])

    if Code.ensure_loaded?(pigeon) and Code.ensure_loaded?(notification_module) do
      notification =
        struct(notification_module,
          device_token: request.device_token,
          topic: request.topic,
          id: request.id,
          expiration: request.expiration,
          collapse_id: request.collapse_id,
          priority: request.priority,
          push_type: Atom.to_string(request.push_type),
          payload: request.payload.json
        )

      pigeon
      |> apply(:push, [dispatcher_ref, notification, [timeout: 5_000]])
      |> classify_pigeon_response()
    else
      {:error, :pigeon_unavailable}
    end
  rescue
    _ -> {:error, :ambiguous}
  catch
    _, _ -> {:error, :ambiguous}
  end

  defp classify_pigeon_response(%{response: :success}),
    do: {:ok, %Result{outcome: :accepted, code: :accepted}}

  defp classify_pigeon_response(%{response: %Result{} = result}), do: {:ok, result}
  defp classify_pigeon_response(%{response: :not_started}), do: {:error, :pigeon_unavailable}
  defp classify_pigeon_response(%{response: :timeout}), do: {:error, :ambiguous}
  defp classify_pigeon_response(%{response: _}), do: {:error, :rejected}
  defp classify_pigeon_response(_), do: {:error, :ambiguous}

  defmodule PigeonAdapter do
    @moduledoc false

    @spec extract_response(map()) ::
            {:ok,
             %{status: 410, reason: :expired_token | :unregistered, timestamp: non_neg_integer()}}
            | {:error, :incomplete_provider_response}
    def extract_response(%{"status" => 410, "reason" => reason, "timestamp" => timestamp})
        when reason in ["ExpiredToken", "Unregistered"] and is_integer(timestamp) and
               timestamp >= 0 do
      {:ok,
       %{
         status: 410,
         reason: if(reason == "ExpiredToken", do: :expired_token, else: :unregistered),
         timestamp: timestamp
       }}
    end

    def extract_response(_), do: {:error, :incomplete_provider_response}

    # The optional Pigeon implementation is compiled only by hosts that add Pigeon.
    # Keeping every Pigeon reference in this guard preserves package consumers that
    # never opt into APNs.
    if Code.ensure_loaded?(Pigeon.Adapter) do
      @behaviour Pigeon.Adapter

      alias Chimeway.APNS.Transport.Result

      @max_error_body_bytes 4_096
      @retryable_reasons [
        "IdleTimeout",
        "TooManyProviderTokenUpdates",
        "TooManyRequests",
        "InternalServerError",
        "ServiceUnavailable",
        "Shutdown"
      ]

      @impl true
      def init(opts) do
        case Keyword.fetch(opts, :chimeway_apns_state) do
          {:ok, state} -> {:ok, state}
          :error -> Pigeon.APNS.init(opts)
        end
      end

      @impl true
      def handle_push(notification, %{config: config, queue: queue} = state) do
        headers = Pigeon.Configurable.push_headers(config, notification, [])
        payload = Pigeon.Configurable.push_payload(config, notification, [])

        Pigeon.Http2.Client.default().send_request(state.socket, headers, payload)

        {:noreply,
         state
         |> Map.put(:queue, Pigeon.NotificationQueue.add(queue, state.stream_id, notification))
         |> Map.update!(:stream_id, &(&1 + 2))}
      end

      @impl true
      def handle_info(:ping, state) do
        Pigeon.Http2.Client.default().send_ping(state.socket)
        Pigeon.Configurable.schedule_ping(state.config)
        {:noreply, state}
      end

      def handle_info(message, state) do
        case Pigeon.Http2.Client.default().handle_end_stream(message, state) do
          {:ok, %Pigeon.Http2.Stream{} = stream} -> process_end_stream(stream, state)
          _ -> {:noreply, state}
        end
      end

      @doc false
      def process_end_stream(
            %Pigeon.Http2.Stream{id: stream_id} = stream,
            %{queue: queue} = state
          ) do
        case Pigeon.NotificationQueue.pop(queue, stream_id) do
          {nil, new_queue} ->
            {:noreply, %{state | queue: new_queue}}

          {notification, new_queue} ->
            case close_response(notification, stream, state.config) do
              {:closed, response} -> Pigeon.Tasks.process_on_response(response)
              :normalized -> :ok
            end

            {:noreply, %{state | queue: new_queue}}
        end
      end

      defp close_response(notification, %Pigeon.Http2.Stream{} = stream, config) do
        case closed_result(stream) do
          {:ok, result} ->
            {:closed, %{notification | response: result}}

          :error ->
            Pigeon.Configurable.handle_end_stream(config, stream, notification)
            :normalized
        end
      end

      defp closed_result(%Pigeon.Http2.Stream{status: 410, body: body} = stream)
           when is_binary(body) and byte_size(body) <= @max_error_body_bytes do
        with {:ok, response} <- Pigeon.json_library().decode(body),
             {:ok, %{reason: reason, timestamp: timestamp}} <-
               extract_response(Map.put(response, "status", stream.status)) do
          {:ok,
           %Result{
             outcome: :rejected,
             code: normalize_code(reason),
             status: 410,
             reason: reason,
             timestamp: timestamp
           }}
        else
          _ -> :error
        end
      rescue
        _ -> :error
      end

      defp closed_result(%Pigeon.Http2.Stream{status: status, body: body})
           when status in [403, 429, 500, 503] and is_binary(body) and
                  byte_size(body) <= @max_error_body_bytes do
        with {:ok, %{"reason" => reason}} <- Pigeon.json_library().decode(body),
             true <- reason in @retryable_reasons do
          {:ok,
           %Result{
             outcome: :rejected,
             code: normalize_code(reason),
             status: status,
             reason: reason
           }}
        else
          _ -> :error
        end
      rescue
        _ -> :error
      end

      defp closed_result(_stream), do: :error

      defp normalize_code(:expired_token), do: :expired_token
      defp normalize_code(:unregistered), do: :unregistered
      defp normalize_code("IdleTimeout"), do: :idle_timeout
      defp normalize_code("TooManyProviderTokenUpdates"), do: :too_many_provider_token_updates
      defp normalize_code("TooManyRequests"), do: :too_many_requests
      defp normalize_code("InternalServerError"), do: :internal_server_error
      defp normalize_code("ServiceUnavailable"), do: :service_unavailable
      defp normalize_code("Shutdown"), do: :shutdown
    end
  end
end
