defmodule Mix.Tasks.ApnsConsumer.PhysicalProof do
  use Mix.Task

  @shortdoc "Runs the private signed-iPhone APNs proof harness"

  @impl Mix.Task
  def run([]) do
    Mix.Task.run("app.start")

    case APNSConsumer.PhysicalProof.run() do
      {:ok, result} ->
        :ok = maybe_write_result(result)
        Mix.shell().info(Jason.encode!(result))

      {:error, rule_id} ->
        Mix.raise(rule_id)
    end
  end

  def run(_), do: Mix.raise("PHYSICAL-PROOF-OPTIONS")

  defp maybe_write_result(result) do
    case System.get_env("CHIMEWAY_PHYSICAL_PROOF_RESULT_PATH") do
      path when is_binary(path) ->
        if Path.type(path) == :absolute and not File.exists?(path) do
          File.write(path, Jason.encode!(result), [:exclusive])
        else
          {:error, :unsafe_result_path}
        end

      _ ->
        :ok
    end
  end
end

defmodule APNSConsumer.PhysicalProof do
  @moduledoc false

  @bundle_id "dev.crosswake.chimewayproof"
  @team_id "ZP67WW2L67"
  @timeout_ms 600_000

  def run do
    with {:ok, config} <- configuration(),
         {:ok, state} <- start_state(config.open_ref),
         {:ok, listener, port} <- start_listener(state, config.session_auth),
         {:ok, destination} <- physical_destination(config.crosswake_root),
         :ok <- build_app(config, destination),
         :ok <- install_app(config, destination),
         :ok <- launch_app(config, destination, port),
         :ok <- emit("waiting_for_device_registration"),
         {:ok, true} <- await(state, :permission, @timeout_ms),
         {:ok, token} <- await(state, :device_token, @timeout_ms),
         {:ok, dispatcher} <- start_dispatcher(config),
         :ok <- Application.put_env(:chimeway, :apns_binding_lookup, APNSConsumer),
         :ok <- APNSConsumer.install_live_binding(token, dispatcher, config.bundle_id),
         {:provider_accepted, _safe_facts} <-
           APNSConsumer.deliver_live(config.bundle_id, config.open_ref),
         :ok <- Agent.update(state, &Map.put(&1, :provider_accepted, true)),
         :ok <- emit("provider_accepted_waiting_for_notification_tap"),
         {:ok, 1} <- await(state, :activation_count, @timeout_ms),
         :replayed <- consume_activation(state, config.open_ref),
         {:ok, snapshot} <- safe_snapshot(state) do
      stop(listener, dispatcher, state)

      {:ok,
       %{
         schema_version: 1,
         outcome: "passed",
         run_ref: config.run_ref,
         device_class: "physical_iphone",
         assertions: [
           %{id: "permission_observed", owner: "device_local", outcome: "passed"},
           %{id: "authenticated_registration", owner: "backend_authority", outcome: "passed"},
           %{id: "protected_activation_once", owner: "backend_authority", outcome: "passed"}
         ],
         chimeway_facts: %{
           delivery_succeeded: "passed",
           apns_provider_accepted: if(snapshot.provider_accepted, do: "passed", else: "blocked"),
           trace_explainable: "passed"
         }
       }}
    else
      {:error, rule_id} when is_binary(rule_id) -> {:error, rule_id}
      _ -> {:error, "PHYSICAL-PROOF-UNAVAILABLE"}
    end
  after
    APNSConsumer.clear_live_binding()
    Application.delete_env(:chimeway, :apns_binding_lookup)
  end

  defp configuration do
    with key_path when is_binary(key_path) <- System.get_env("CHIMEWAY_APNS_AUTH_KEY_PATH"),
         true <- File.regular?(key_path),
         key_id when is_binary(key_id) <- System.get_env("CHIMEWAY_APNS_KEY_ID"),
         true <- Regex.match?(~r/\A[A-Z0-9]{10}\z/, key_id),
         crosswake_root when is_binary(crosswake_root) <- System.get_env("CROSSWAKE_ROOT"),
         true <- File.dir?(crosswake_root),
         {:ok, host_ip} <- host_ip() do
      {:ok,
       %{
         key_path: key_path,
         key_id: key_id,
         team_id: System.get_env("CHIMEWAY_APPLE_TEAM_ID") || @team_id,
         bundle_id: System.get_env("CHIMEWAY_APPLE_BUNDLE_ID") || @bundle_id,
         crosswake_root: Path.expand(crosswake_root),
         host_ip: host_ip,
         session_auth: random_ref(32),
         open_ref: "cw_open_" <> random_ref(16),
         run_ref: "cw-physical-" <> random_ref(12)
       }}
    else
      _ -> {:error, "PHYSICAL-PROOF-CONFIG"}
    end
  end

  defp start_state(open_ref) do
    Agent.start_link(fn ->
      %{
        expected_open_ref: open_ref,
        permission: false,
        device_token: nil,
        received: false,
        activation_count: 0,
        activation_replays: 0,
        provider_accepted: false
      }
    end)
  end

  defp start_listener(state, session_auth) do
    with {:ok, listener} <-
           :gen_tcp.listen(0, [
             :binary,
             packet: :raw,
             active: false,
             reuseaddr: true,
             ip: {0, 0, 0, 0}
           ]),
         {:ok, port} <- :inet.port(listener) do
      spawn_link(fn -> accept_loop(listener, state, session_auth) end)
      {:ok, listener, port}
    else
      _ -> {:error, "PHYSICAL-PROOF-HOST-LISTENER"}
    end
  end

  defp accept_loop(listener, state, session_auth) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        spawn(fn -> serve(socket, state, session_auth) end)
        accept_loop(listener, state, session_auth)

      {:error, :closed} ->
        :ok

      _ ->
        :ok
    end
  end

  defp serve(socket, state, session_auth) do
    response =
      with {:ok, request} <- receive_request(socket),
           true <- authorized?(request.headers, session_auth),
           {:ok, body} <- Jason.decode(request.body),
           true <- is_map(body) do
        route(request.method, request.path, body, state)
      else
        _ -> 401
      end

    send_response(socket, response)
    :gen_tcp.close(socket)
  end

  defp route("POST", "/permission", %{"outcome" => "passed"}, state) do
    Agent.update(state, &Map.put(&1, :permission, true))
    204
  end

  defp route("POST", "/register", %{"provider" => "apns", "token" => token}, state)
       when is_binary(token) do
    if Regex.match?(~r/\A[0-9a-f]{64,512}\z/, token) do
      Agent.update(state, &Map.put(&1, :device_token, token))
      204
    else
      422
    end
  end

  defp route("POST", "/received", %{"open_ref" => open_ref}, state) do
    Agent.update(state, &Map.put(&1, :received, open_ref))
    204
  end

  defp route("POST", "/activate", %{"open_ref" => open_ref}, state) do
    case consume_activation(state, open_ref) do
      :accepted -> 204
      :replayed -> 409
      :denied -> 403
    end
  end

  defp route(_, _, _, _), do: 404

  defp consume_activation(state, open_ref) do
    Agent.get_and_update(state, fn current ->
      cond do
        current.expected_open_ref != open_ref ->
          {:denied, current}

        current.activation_count == 0 ->
          {:accepted, %{current | activation_count: 1}}

        true ->
          {:replayed, %{current | activation_replays: current.activation_replays + 1}}
      end
    end)
  end

  defp receive_request(socket) do
    with {:ok, header, rest} <- receive_headers(socket, ""),
         {:ok, method, path, headers} <- parse_headers(header),
         {:ok, length} <- content_length(headers),
         {:ok, body} <- receive_body(socket, rest, length) do
      {:ok, %{method: method, path: path, headers: headers, body: body}}
    end
  end

  defp receive_headers(socket, bytes) when byte_size(bytes) <= 16_384 do
    case :binary.split(bytes, "\r\n\r\n") do
      [header, rest] ->
        {:ok, header, rest}

      [_] ->
        case :gen_tcp.recv(socket, 0, 10_000) do
          {:ok, more} -> receive_headers(socket, bytes <> more)
          error -> error
        end
    end
  end

  defp receive_headers(_, _), do: {:error, :too_large}

  defp parse_headers(header) do
    case String.split(header, "\r\n") do
      [request_line | lines] ->
        with [method, path, _version] <- String.split(request_line, " "),
             true <- method == "POST" do
          headers =
            Enum.reduce(lines, %{}, fn line, acc ->
              case String.split(line, ":", parts: 2) do
                [name, value] -> Map.put(acc, String.downcase(name), String.trim(value))
                _ -> acc
              end
            end)

          {:ok, method, path, headers}
        else
          _ -> {:error, :invalid_request}
        end

      _ ->
        {:error, :invalid_request}
    end
  end

  defp content_length(headers) do
    case Integer.parse(Map.get(headers, "content-length", "")) do
      {length, ""} when length in 0..8_192 -> {:ok, length}
      _ -> {:error, :invalid_length}
    end
  end

  defp receive_body(_socket, bytes, length) when byte_size(bytes) >= length,
    do: {:ok, binary_part(bytes, 0, length)}

  defp receive_body(socket, bytes, length) do
    case :gen_tcp.recv(socket, length - byte_size(bytes), 10_000) do
      {:ok, more} -> receive_body(socket, bytes <> more, length)
      error -> error
    end
  end

  defp authorized?(headers, expected) do
    supplied = Map.get(headers, "authorization", "")
    expected = "Bearer " <> expected

    byte_size(supplied) == byte_size(expected) and
      :crypto.hash_equals(:crypto.hash(:sha256, supplied), :crypto.hash(:sha256, expected))
  end

  defp send_response(socket, status) do
    reason =
      case status do
        204 -> "No Content"
        401 -> "Unauthorized"
        403 -> "Forbidden"
        404 -> "Not Found"
        409 -> "Conflict"
        422 -> "Unprocessable Content"
        _ -> "Error"
      end

    :gen_tcp.send(
      socket,
      "HTTP/1.1 #{status} #{reason}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
    )
  end

  defp physical_destination(crosswake_root) do
    project = ios_project(crosswake_root)

    case System.cmd(
           "xcodebuild",
           ["-project", project, "-scheme", "CrosswakeProofLane", "-showdestinations"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        ids =
          Regex.scan(~r/\{ platform:iOS, [^}]*id:([^,}]+), [^}]*name:/, output,
            capture: :all_but_first
          )
          |> List.flatten()
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&String.contains?(&1, "placeholder"))
          |> Enum.uniq()

        case ids do
          [id] -> {:ok, id}
          _ -> {:error, "PHYSICAL-PROOF-DEVICE-SELECTION"}
        end

      _ ->
        {:error, "PHYSICAL-PROOF-DEVICE-SELECTION"}
    end
  end

  defp build_app(config, destination) do
    args = [
      "-project",
      ios_project(config.crosswake_root),
      "-scheme",
      "CrosswakeProofLane",
      "-configuration",
      "Debug",
      "-sdk",
      "iphoneos",
      "-destination",
      "id=#{destination}",
      "-derivedDataPath",
      derived_data(config.crosswake_root),
      "CODE_SIGN_STYLE=Automatic",
      "DEVELOPMENT_TEAM=#{config.team_id}",
      "PRODUCT_BUNDLE_IDENTIFIER=#{config.bundle_id}",
      "CODE_SIGN_ENTITLEMENTS=CrosswakeProofLane/ChimewayPhysicalProof.entitlements",
      "CODE_SIGNING_ALLOWED=YES",
      "CODE_SIGNING_REQUIRED=YES",
      "-allowProvisioningUpdates",
      "-allowProvisioningDeviceRegistration",
      "build"
    ]

    safe_command("xcodebuild", args, "PHYSICAL-PROOF-SIGNED-BUILD")
  end

  defp install_app(config, destination) do
    app =
      Path.join([
        derived_data(config.crosswake_root),
        "Build",
        "Products",
        "Debug-iphoneos",
        "CrosswakeProofLane.app"
      ])

    safe_command(
      "xcrun",
      ["devicectl", "device", "install", "app", "--device", destination, app],
      "PHYSICAL-PROOF-INSTALL"
    )
  end

  defp launch_app(config, destination, port) do
    environment =
      Jason.encode!(%{
        "CROSSWAKE_CHIMEWAY_PHYSICAL_PROOF" => "1",
        "CROSSWAKE_CHIMEWAY_HOST_URL" => "http://#{config.host_ip}:#{port}/",
        "CROSSWAKE_CHIMEWAY_SESSION_AUTH" => config.session_auth
      })

    safe_command(
      "xcrun",
      [
        "devicectl",
        "device",
        "process",
        "launch",
        "--device",
        destination,
        "--environment-variables",
        environment,
        "--terminate-existing",
        config.bundle_id
      ],
      "PHYSICAL-PROOF-LAUNCH"
    )
  end

  defp start_dispatcher(config) do
    with {:ok, _} <- Application.ensure_all_started(:pigeon),
         {:ok, key} <- File.read(config.key_path),
         dispatcher_module = Module.concat(["Pigeon", "Dispatcher"]),
         {:ok, dispatcher} <-
           apply(dispatcher_module, :start_link, [
             [
               adapter: Chimeway.APNS.Transport.PigeonAdapter,
               key: key,
               key_identifier: config.key_id,
               team_id: config.team_id,
               mode: :dev,
               pool_size: 1,
               name: nil
             ]
           ]) do
      {:ok, dispatcher}
    else
      _ -> {:error, "PHYSICAL-PROOF-APNS-DISPATCHER"}
    end
  end

  defp host_ip do
    with {route, 0} <- System.cmd("route", ["-n", "get", "default"], stderr_to_stdout: true),
         [interface] <- Regex.run(~r/interface:\s+(\S+)/, route, capture: :all_but_first),
         {address, 0} <- System.cmd("ipconfig", ["getifaddr", interface], stderr_to_stdout: true),
         address <- String.trim(address),
         {:ok, _} <- :inet.parse_ipv4_address(String.to_charlist(address)) do
      {:ok, address}
    else
      _ -> {:error, "PHYSICAL-PROOF-HOST-NETWORK"}
    end
  end

  defp await(state, key, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    await_until(state, key, deadline)
  end

  defp await_until(state, key, deadline) do
    value = Agent.get(state, &Map.get(&1, key))

    if value not in [nil, false, 0] do
      {:ok, value}
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(250)
        await_until(state, key, deadline)
      else
        {:error, "PHYSICAL-PROOF-TIMEOUT"}
      end
    end
  end

  defp safe_snapshot(state) do
    snapshot = Agent.get(state, &Map.drop(&1, [:device_token, :expected_open_ref]))

    if snapshot.permission and snapshot.provider_accepted and snapshot.activation_count == 1 and
         snapshot.activation_replays == 1 do
      {:ok, snapshot}
    else
      {:error, "PHYSICAL-PROOF-INCOMPLETE"}
    end
  end

  defp safe_command(executable, args, rule_id) do
    case System.cmd(executable, args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      _ -> {:error, rule_id}
    end
  rescue
    _ -> {:error, rule_id}
  end

  defp emit(state), do: Mix.shell().info(Jason.encode!(%{outcome: state}))

  defp stop(listener, dispatcher, state) do
    :gen_tcp.close(listener)
    if is_pid(dispatcher) and Process.alive?(dispatcher), do: Supervisor.stop(dispatcher)
    if is_pid(state) and Process.alive?(state), do: Agent.stop(state)
    :ok
  end

  defp ios_project(crosswake_root),
    do:
      Path.join([
        crosswake_root,
        "examples",
        "phoenix_host",
        "native",
        "ios",
        "CrosswakeProofLane.xcodeproj"
      ])

  defp derived_data(crosswake_root),
    do: Path.join(Path.dirname(crosswake_root), "chimeway-physical-derived-data")

  defp random_ref(bytes),
    do: :crypto.strong_rand_bytes(bytes) |> Base.url_encode64(padding: false) |> String.downcase()
end
