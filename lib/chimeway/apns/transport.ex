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

    # Hosts opt into this dispatcher adapter; it intentionally stores only the parsed closed facts.
    def init(state), do: {:ok, state}
    def push(state, notification), do: {:ok, state, notification}
  end
end
