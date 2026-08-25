defmodule AlphaTwin.ScriptedAPNSTransport do
  @moduledoc false
  use GenServer
  @behaviour Chimeway.APNS.Transport
  alias Chimeway.APNS.Transport.{Request, Result}

  def start_link(opts),
    do:
      GenServer.start_link(__MODULE__, %{
        script: Keyword.fetch!(opts, :script),
        observer: Keyword.fetch!(opts, :observer)
      })

  def assert_drained(pid), do: GenServer.call(pid, :assert_drained)
  @impl true
  def push(_dispatcher, %Request{} = request, opts),
    do: GenServer.call(Keyword.fetch!(opts, :script_pid), {:push, request})

  @impl true
  def init(state), do: {:ok, state}
  @impl true
  def handle_call(:assert_drained, _from, %{script: []} = state), do: {:reply, :ok, state}
  def handle_call(:assert_drained, _from, state), do: {:reply, {:error, :script_remaining}, state}

  def handle_call(
        {:push, request},
        _from,
        %{script: [outcome | rest], observer: observer} = state
      ) do
    with :ok <- validate(request) do
      send(observer, {:alpha_twin_apns_request, redact(request)})
      {:reply, result(outcome), %{state | script: rest}}
    else
      :error -> {:reply, {:error, :rejected}, state}
    end
  end

  def handle_call({:push, _request}, _from, state), do: {:reply, {:error, :ambiguous}, state}

  defp validate(%Request{
         device_token: token,
         topic: topic,
         environment: env,
         payload: %{bytes: bytes}
       })
       when is_binary(token) and byte_size(token) > 0 and is_binary(topic) and
              byte_size(topic) in 1..255 and env in [:sandbox, :production] and is_integer(bytes) and
              bytes in 1..4096, do: :ok

  defp validate(_), do: :error

  defp redact(%Request{} = request),
    do: %{
      topic: request.topic,
      environment: request.environment,
      expiration: request.expiration,
      priority: request.priority,
      push_type: request.push_type,
      payload_bytes: request.payload.bytes
    }

  defp result({:accepted}), do: {:ok, %Result{outcome: :accepted, code: :accepted}}

  defp result({:retryable}),
    do:
      {:ok,
       %Result{
         outcome: :rejected,
         code: :too_many_requests,
         status: 429,
         reason: "TooManyRequests"
       }}

  defp result({:permanent}),
    do:
      {:ok,
       %Result{outcome: :rejected, code: :bad_device_token, status: 400, reason: "BadDeviceToken"}}

  defp result({:invalidating, timestamp}),
    do:
      {:ok,
       %Result{
         outcome: :rejected,
         code: :unregistered,
         status: 410,
         reason: "Unregistered",
         timestamp: timestamp
       }}

  defp result({:ambiguous}), do: {:error, :ambiguous}
end
