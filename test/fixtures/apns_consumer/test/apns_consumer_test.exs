defmodule APNSConsumerTest do
  use ExUnit.Case, async: false

  if System.get_env("CHIMEWAY_APNS_ENABLED") == "1" do
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
    test "a missing Pigeon dispatcher is reported as unavailable before provider handoff" do
      assert {:error, :pigeon_unavailable} =
               Chimeway.APNS.Transport.pigeon_push(
                 :fixture_missing_dispatcher,
                 APNSConsumer.request()
               )
    end

    @tag :apns_bridge_to_cas
    test "the public adapter bridges only correlated authoritative streams to the original host CAS" do
      for {reason, timestamp} <- [
            {"ExpiredToken", 1_725_000_000},
            {"Unregistered", 1_725_000_001}
          ] do
        with_bridge(fn dispatcher ->
          task = Task.async(fn -> APNSConsumer.deliver(dispatcher) end)

          assert_receive {:pigeon_send_request, _headers}

          deliver_end_stream(dispatcher, %Pigeon.Http2.Stream{
            id: 1,
            status: 410,
            headers: [],
            body: ~s({"reason":"#{reason}","timestamp":#{timestamp}})
          })

          assert {:invalidated,
                  %{
                    provider_status: 410,
                    provider_reason: provider_reason,
                    provider_timestamp: ^timestamp
                  }} = result = Task.await(task)

          assert provider_reason == Macro.underscore(reason)

          expected_key = APNSConsumer.original_binding_key()
          assert_receive {:binding_invalidation, ^expected_key}

          assert %{successful_invalidations: 1, original: :invalidated, replacement: :active} =
                   APNSConsumer.binding_state()

          assert_safe_result(result)
        end)
      end
    end

    @tag :apns_runtime_success
    test "the public adapter returns provider accepted for a correlated ordinary Pigeon success" do
      with_bridge(fn dispatcher ->
        task = Task.async(fn -> APNSConsumer.deliver(dispatcher) end)

        assert_receive {:pigeon_send_request, _headers}

        deliver_end_stream(dispatcher, %Pigeon.Http2.Stream{
          id: 1,
          status: 200,
          headers: [],
          body: ""
        })

        assert {:provider_accepted, facts} = result = Task.await(task)
        assert is_map(facts)
        refute_receive {:binding_invalidation, _}

        assert %{successful_invalidations: 0, original: :active, replacement: :active} =
                 APNSConsumer.binding_state()

        assert_safe_result(result)
      end)
    end

    @tag :apns_bridge_to_cas
    test "the public adapter rejects non-authoritative streams without a successful host CAS" do
      non_authoritative_streams = [
        %Pigeon.Http2.Stream{id: 1, status: 410, headers: [], body: "not-json"},
        %Pigeon.Http2.Stream{
          id: 1,
          status: 410,
          headers: [],
          body: ~s({"reason":"ExpiredToken"})
        },
        %Pigeon.Http2.Stream{id: 1, status: 410, headers: [], body: ~s({"timestamp":1})},
        %Pigeon.Http2.Stream{
          id: 1,
          status: 410,
          headers: [],
          body: ~s({"reason":"ExpiredToken","timestamp":-1})
        },
        %Pigeon.Http2.Stream{
          id: 1,
          status: 400,
          headers: [],
          body: ~s({"reason":"Unregistered","timestamp":1})
        },
        %Pigeon.Http2.Stream{
          id: 1,
          status: 410,
          headers: [],
          body: ~s({"reason":"BadDeviceToken","timestamp":1})
        },
        %Pigeon.Http2.Stream{id: 1, status: 410, headers: [], body: String.duplicate("x", 4_097)}
      ]

      for stream <- non_authoritative_streams do
        with_bridge(fn dispatcher ->
          task = Task.async(fn -> APNSConsumer.deliver(dispatcher) end)
          assert_receive {:pigeon_send_request, _headers}
          deliver_end_stream(dispatcher, stream)
          assert {:permanent, _facts} = result = Task.await(task)
          refute_receive {:binding_invalidation, _}

          assert %{successful_invalidations: 0, original: :active, replacement: :active} =
                   APNSConsumer.binding_state()

          assert_safe_result(result)
        end)
      end
    end

    @tag :apns_bridge_to_cas
    test "an uncorrelated stream neither completes nor observes the CAS before correlated resolution" do
      with_bridge(fn dispatcher ->
        task = Task.async(fn -> APNSConsumer.deliver(dispatcher) end)
        assert_receive {:pigeon_send_request, _headers}

        deliver_end_stream(dispatcher, %Pigeon.Http2.Stream{
          id: 3,
          status: 410,
          headers: [],
          body: ~s({"reason":"Unregistered","timestamp":1})
        })

        assert nil == Task.yield(task, 50)
        refute_receive {:binding_invalidation, _}

        assert %{successful_invalidations: 0, original: :active, replacement: :active} =
                 APNSConsumer.binding_state()

        deliver_end_stream(dispatcher, %Pigeon.Http2.Stream{
          id: 1,
          status: 410,
          headers: [],
          body: ~s({"reason":"BadDeviceToken","timestamp":1})
        })

        assert {:permanent, _facts} = Task.await(task)
        refute_receive {:binding_invalidation, _}
      end)
    end

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

        task =
          Task.async(fn ->
            Chimeway.APNS.Transport.pigeon_push(dispatcher, APNSConsumer.request())
          end)

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
                %Chimeway.APNS.Transport.Result{
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

      task =
        Task.async(fn ->
          Chimeway.APNS.Transport.pigeon_push(dispatcher, APNSConsumer.request())
        end)

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
              %Chimeway.APNS.Transport.Result{
                outcome: :rejected,
                code: :unregistered,
                status: 410,
                reason: "Unregistered",
                timestamp: 1_725_000_000
              }} = Task.await(task)
    end
  end

  if System.get_env("CHIMEWAY_APNS_ENABLED") == "1" do
    defp with_bridge(fun) do
      {:ok, dispatcher} = APNSConsumer.start_dispatcher()
      {:ok, registry} = APNSConsumer.start_binding_registry(self(), dispatcher)

      previous_lookup = Application.get_env(:chimeway, :apns_binding_lookup)
      previous_transport = Application.get_env(:chimeway, :apns_transport)
      previous_registry = Application.get_env(:apns_consumer, :binding_registry)

      Application.put_env(:chimeway, :apns_binding_lookup, APNSConsumer)
      Application.delete_env(:chimeway, :apns_transport)
      Application.put_env(:apns_consumer, :binding_registry, registry)

      try do
        fun.(dispatcher)
      after
        if Process.alive?(dispatcher), do: Supervisor.stop(dispatcher)
        if Process.alive?(registry), do: Agent.stop(registry)
        restore_env(:apns_consumer, :binding_registry, previous_registry)
        restore_env(:chimeway, :apns_binding_lookup, previous_lookup)
        restore_env(:chimeway, :apns_transport, previous_transport)
      end
    end

    defp deliver_end_stream(dispatcher, stream) do
      [{_, worker, :worker, _}] = Supervisor.which_children(dispatcher)
      send(worker, {:fixture_end_stream, stream})
    end

    defp restore_env(app, key, nil), do: Application.delete_env(app, key)
    defp restore_env(app, key, value), do: Application.put_env(app, key, value)

    defp assert_safe_result(result) do
      evidence = inspect(result)
      refute evidence =~ "fixture-token-never-emitted"
      refute evidence =~ "dispatcher"
      refute evidence =~ "not-json"
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
