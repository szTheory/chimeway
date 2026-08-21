defmodule APNSConsumerTest do
  use ExUnit.Case, async: true

  if System.get_env("CHIMEWAY_APNS_ENABLED") == "1" do
    alias Chimeway.APNS.Transport

    defmodule FakeHttp2Client do
      @behaviour Pigeon.Http2.Client

      @impl true
      def start, do: :ok

      @impl true
      def connect(_uri, _scheme, _options), do: {:ok, :fixture_socket}

      @impl true
      def send_ping(_socket), do: :ok

      @impl true
      def send_request(_socket, headers, _payload) do
        send(Application.fetch_env!(:apns_consumer, :test_pid), {:pigeon_send_request, headers})
        :ok
      end

      @impl true
      def handle_end_stream({:fixture_end_stream, stream}, _state), do: {:ok, stream}
      def handle_end_stream(_message, _state), do: :ignore
    end

    setup do
      previous_client = Application.get_env(:pigeon, :http2_client)
      Application.put_env(:pigeon, :http2_client, FakeHttp2Client)
      Application.put_env(:apns_consumer, :test_pid, self())

      on_exit(fn ->
        if previous_client,
          do: Application.put_env(:pigeon, :http2_client, previous_client),
          else: Application.delete_env(:pigeon, :http2_client)

        Application.delete_env(:apns_consumer, :test_pid)
      end)
    end
  end

  test "core Chimeway API works without APNs configuration" do
    assert %{} == APNSConsumer.core_smoke()
  end

  test "enabled fixture preserves the complete synthetic 410 tuple" do
    assert {:ok, %{status: 410, reason: :expired_token, timestamp: 1_725_000_000}} =
             APNSConsumer.expired_token_result()

    for response <- [
          %{"reason" => "ExpiredToken", "timestamp" => 1},
          %{"status" => 410, "timestamp" => 1},
          %{"status" => 410, "reason" => "ExpiredToken"},
          %{"status" => 400, "reason" => "ExpiredToken", "timestamp" => 1}
        ] do
      assert {:error, :incomplete_provider_response} =
               Chimeway.APNS.Transport.PigeonAdapter.extract_response(response)
    end
  end

  if System.get_env("CHIMEWAY_APNS_ENABLED") == "1" do
    for {status, reason, code} <- [
          {403, "IdleTimeout", :idle_timeout},
          {403, "TooManyProviderTokenUpdates", :too_many_provider_token_updates},
          {429, "TooManyRequests", :too_many_requests},
          {500, "InternalServerError", :internal_server_error},
          {503, "ServiceUnavailable", :service_unavailable},
          {503, "Shutdown", :shutdown}
        ] do
      test "a represented Pigeon retryable response returns a closed transport result for #{reason}" do
        status = unquote(status)
        reason = unquote(reason)
        code = unquote(code)

        state = %{
          config: %Pigeon.APNS.Config{},
          queue: Pigeon.NotificationQueue.new(),
          socket: :fixture_socket,
          stream_id: 1
        }

        {:ok, dispatcher} =
          Pigeon.Dispatcher.start_link(
            adapter: Chimeway.APNS.Transport.PigeonAdapter,
            chimeway_apns_state: state,
            name: nil,
            pool_size: 1
          )

        task = Task.async(fn -> Transport.pigeon_push(dispatcher, APNSConsumer.request()) end)
        assert_receive {:pigeon_send_request, _headers}

        [{_, worker, :worker, _}] = Supervisor.which_children(dispatcher)

        send(
          worker,
          {:fixture_end_stream,
           %Pigeon.Http2.Stream{
             id: 1,
             status: status,
             headers: [],
             body: ~s({"reason":"#{reason}"})
           }}
        )

        assert {:ok,
                %Transport.Result{
                  outcome: :rejected,
                  code: ^code,
                  status: ^status,
                  reason: ^reason
                }} = Task.await(task)
      end
    end

    test "a represented Pigeon 410 response returns a closed transport result through Pigeon.push" do
      state = %{
        config: %Pigeon.APNS.Config{},
        queue: Pigeon.NotificationQueue.new(),
        socket: :fixture_socket,
        stream_id: 1
      }

      {:ok, dispatcher} =
        Pigeon.Dispatcher.start_link(
          adapter: Chimeway.APNS.Transport.PigeonAdapter,
          chimeway_apns_state: state,
          name: nil,
          pool_size: 1
        )

      task = Task.async(fn -> Transport.pigeon_push(dispatcher, APNSConsumer.request()) end)
      assert_receive {:pigeon_send_request, _headers}

      [{_, worker, :worker, _}] = Supervisor.which_children(dispatcher)

      send(
        worker,
        {:fixture_end_stream,
         %Pigeon.Http2.Stream{
           id: 1,
           status: 410,
           headers: [],
           body: ~s({"reason":"Unregistered","timestamp":1725000000})
         }}
      )

      assert {:ok,
              %Transport.Result{
                outcome: :rejected,
                code: :unregistered,
                status: 410,
                reason: "Unregistered",
                timestamp: 1_725_000_000
              }} = Task.await(task)
    end
  end

  test "evidence is a single safe sandbox-only line" do
    evidence = APNSConsumer.evidence()
    assert {:ok, decoded} = Jason.decode(evidence)

    assert decoded == %{
             "environment" => "sandbox",
             "outcome" => "provider_accepted",
             "proof" => "not_live_not_device_not_open",
             "provider" => "apns"
           }

    refute String.contains?(evidence, "fixture-token")
  end
end
