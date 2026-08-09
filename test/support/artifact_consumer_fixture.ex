defmodule Chimeway.Test.ArtifactConsumerFixture do
  @moduledoc false

  @required_events [:event_created, :notification_created, :delivery_planned, :attempt_recorded]
  @spec prove_core!(Path.t()) :: map()
  def prove_core!(unpacked_root), do: prove_core!(unpacked_root, [])

  @doc false
  @spec prove_core!(Path.t(), keyword()) :: map()
  def prove_core!(unpacked_root, opts) when is_binary(unpacked_root) and is_list(opts) do
    identity = Keyword.get(opts, :identity, resource_identity())
    root = identity.root
    db_config = database_config(identity.database)

    cleanup = fn -> cleanup!(root, db_config) end

    try do
      File.rm_rf!(root)
      scaffold!(root, unpacked_root, db_config)
      validate_artifact_dependency!(File.read!(Path.join(root, "mix.exs")), unpacked_root, repo_root!())

      if Keyword.get(opts, :fail_before_commands, false) do
        raise "artifact consumer pre-command validation failure"
      end

      run_mix!(root, ["deps.get"])
      run_mix!(root, ["chimeway.gen.migrations"])
      run_mix!(root, ["ecto.create"])
      run_mix!(root, ["run", "--no-start", "-e", database_probe(identity.database)])
      run_mix!(root, ["ecto.migrate"])
      output = run_mix!(root, ["run", "priv/prove_core.exs"])
      proof_source = File.read!(Path.join(root, "priv/prove_core.exs"))
      safe_output = proof_line!(output)
      evidence = parse_evidence!(safe_output)

      %{
        output: safe_output,
        proof_source: proof_source,
        identity: identity,
        evidence: evidence,
        cleanup: %{root_removed?: true, database_down?: true},
        artifact_root: Path.expand(unpacked_root)
      }
    after
      cleanup.()
    end
  end

  @spec resource_identity() :: %{root: Path.t(), database: String.t()}
  def resource_identity do
    suffix = System.unique_integer([:positive])

    %{
      root: Path.join(System.tmp_dir!(), "chimeway_artifact_consumer_#{suffix}"),
      database: "chimeway_artifact_consumer_#{suffix}"
    }
  end

  @spec validate_artifact_dependency!(String.t(), Path.t(), Path.t()) :: :ok
  def validate_artifact_dependency!(mix_source, unpacked_root, repository_root) do
    declarations = Regex.scan(~r/\{:chimeway\s*,\s*path:\s*(["'])(.*?)\1\}/, mix_source)

    if length(declarations) != 1 do
      raise "artifact provenance requires exactly one :chimeway dependency"
    end

    [[_, _quote, dependency_path]] = declarations
    expected_root = Path.expand(unpacked_root)
    resolved_dependency_path = Path.expand(dependency_path)

    if resolved_dependency_path != expected_root do
      raise "artifact provenance requires :chimeway path to equal the unpacked artifact root"
    end

    if String.contains?(mix_source, Path.expand(repository_root)) do
      raise "artifact provenance must not reference the repository source root"
    end

    :ok
  end

  @spec ordered_subsequence?([atom()], [atom()]) :: boolean()
  def ordered_subsequence?(required, events) do
    Enum.reduce_while(events, required, fn event, remaining ->
      case remaining do
        [^event | rest] -> {:cont, rest}
        _ -> {:cont, remaining}
      end
    end) == []
  end

  @spec build_safe_evidence!(module(), Chimeway.Traces.Explanation.t()) :: map()
  def build_safe_evidence!(notifier, explanation) do
    delivery_id = explanation.delivery_id
    timeline_events = Enum.map(explanation.timeline || [], & &1.event)

    unless is_binary(delivery_id) and delivery_id != "" do
      raise "public proof requires exactly one delivery ID"
    end

    if timeline_events == [] do
      raise "public proof requires non-empty explanation timeline"
    end

    unless explanation.last_attempt && explanation.last_attempt.outcome do
      raise "public proof requires a last attempt outcome"
    end

    unless explanation.status == :succeeded do
      raise "public proof requires succeeded delivery status"
    end

    unless explanation.last_attempt.outcome == :succeeded do
      raise "public proof requires succeeded last attempt outcome"
    end

    unless ordered_subsequence?(@required_events, timeline_events) do
      raise "public proof requires ordered lifecycle events"
    end

    %{
      notification_key: notifier.notification_key(),
      notification_version: notifier.version(),
      delivery_id: delivery_id,
      status: explanation.status,
      last_attempt_outcome: explanation.last_attempt.outcome,
      timeline_events: timeline_events
    }
  end

  @doc false
  def database_config(database) do
    base_database_config()
    |> Keyword.merge(url: nil, database: database, pool_size: 2, queue_target: 5_000, queue_interval: 10_000, log: false)
  end

  defp scaffold!(root, unpacked_root, db_config) do
    File.mkdir_p!(Path.join(root, "config"))
    File.mkdir_p!(Path.join(root, "lib/artifact_consumer/notifiers"))
    File.mkdir_p!(Path.join(root, "priv"))

    File.write!(Path.join(root, "mix.exs"), mix_exs(unpacked_root))
    File.write!(Path.join(root, "config/config.exs"), config_exs(db_config))
    File.write!(Path.join(root, "lib/artifact_consumer/repo.ex"), repo_ex())
    File.write!(Path.join(root, "lib/artifact_consumer/application.ex"), application_ex())
    File.write!(Path.join(root, "lib/artifact_consumer/notifiers/core_trace.ex"), notifier_ex())
    File.write!(Path.join(root, "priv/prove_core.exs"), proof_ex())
  end

  defp mix_exs(unpacked_root) do
    """
    defmodule ArtifactConsumer.MixProject do
      use Mix.Project

      def project do
        [app: :artifact_consumer, version: "0.0.1", elixir: "~> 1.17", start_permanent: Mix.env() == :prod, deps: deps()]
      end

      def application, do: [extra_applications: [:logger], mod: {ArtifactConsumer.Application, []}]
      defp deps, do: [{:chimeway, path: #{inspect(Path.expand(unpacked_root))}}, {:ecto_sql, "~> 3.11"}, {:postgrex, ">= 0.0.0"}, {:oban, "~> 2.17"}]
    end
    """
  end

  defp config_exs(db_config) do
    """
    import Config

    config :artifact_consumer, ecto_repos: [ArtifactConsumer.Repo]
    repo_config = #{inspect(db_config)}
    config :artifact_consumer, ArtifactConsumer.Repo, repo_config
    config :chimeway, Chimeway.Repo, repo_config
    config :chimeway, repo: Chimeway.Repo, prefix: "chimeway", dispatcher: Chimeway.Dispatch.Sync, adapter: Chimeway.Adapters.Logger
    """
  end

  defp repo_ex do
    """
    defmodule ArtifactConsumer.Repo do
      use Ecto.Repo, otp_app: :artifact_consumer, adapter: Ecto.Adapters.Postgres
    end
    """
  end

  defp application_ex do
    """
    defmodule ArtifactConsumer.Application do
      use Application
      def start(_type, _args) do
        # Mix starts the Chimeway dependency application before this host application.
        # The host supervises its own Repo while Chimeway.Application owns Chimeway.Repo.
        Supervisor.start_link([ArtifactConsumer.Repo], strategy: :one_for_one, name: ArtifactConsumer.Supervisor)
      end
    end
    """
  end

  defp notifier_ex do
    """
    defmodule ArtifactConsumer.Notifiers.CoreTrace do
      use Chimeway.Notifier
      @impl true
      def notification_key, do: "artifact_consumer.core_trace"
      @impl true
      def version, do: 1
      @impl true
      def recipients(_params), do: {:ok, [%{recipient_identity: "proof-user", recipient_type: "user"}]}
      @impl true
      def build(_params, _recipient), do: {:ok, %{title: "Artifact Core proof"}}
      @impl true
      def rendering(_params, _recipient), do: {:ok, %{assigns: %{"headline" => "Artifact Core proof", "body" => "Artifact Core proof", "primary_action" => %{"label" => "Open", "url" => "https://example.test/artifact-core-proof"}}, channels: %{in_app: %{render_key: "artifact_consumer.core_trace.in_app", render_version: 1}}}}
    end
    """
  end

  defp proof_ex do
    """
    {:ok, _} = Application.ensure_all_started(:artifact_consumer)
    {:ok, result} = Chimeway.trigger(ArtifactConsumer.Notifiers.CoreTrace, %{user_id: "proof-user"}, tenant_id: "artifact-proof-tenant", idempotency_key: "artifact-core-proof-v1")
    [delivery_id] = result.trace.delivery_ids
    {:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
    timeline_events = Enum.map(explanation.timeline, & &1.event)
    required_events = [:event_created, :notification_created, :delivery_planned, :attempt_recorded]
    ordered? = Enum.reduce_while(timeline_events, required_events, fn event, remaining -> case remaining do [^event | rest] -> {:cont, rest}; _ -> {:cont, remaining} end end) == []
    true = explanation.notification_key == ArtifactConsumer.Notifiers.CoreTrace.notification_key()
    true = explanation.status == :succeeded
    true = explanation.last_attempt != nil and explanation.last_attempt.outcome == :succeeded
    true = ordered?
    evidence = %{notification_key: ArtifactConsumer.Notifiers.CoreTrace.notification_key(), notification_version: ArtifactConsumer.Notifiers.CoreTrace.version(), delivery_id: delivery_id, status: explanation.status, last_attempt_outcome: explanation.last_attempt.outcome, timeline_events: Enum.join(timeline_events, ",")}
    IO.puts("CHIMEWAY_CORE_PROOF " <> Enum.map_join([:notification_key, :notification_version, :delivery_id, :status, :last_attempt_outcome, :timeline_events], " ", fn key -> "\#{key}=\#{Map.fetch!(evidence, key)}" end))
    """
  end

  defp run_mix!(root, args) do
    {output, status} = System.cmd("mix", args, cd: root, stderr_to_stdout: true, env: [{"MIX_ENV", "dev"}])

    if status != 0 do
      raise "artifact consumer command #{Enum.join(args, " ")} failed (exit #{status}) in #{root}:\n#{output}"
    end

    output
  end

  defp database_probe(database) do
    "{:ok, _} = Application.ensure_all_started(:ecto_sql); {:ok, pid} = ArtifactConsumer.Repo.start_link(); %{rows: [[current]]} = Ecto.Adapters.SQL.query!(ArtifactConsumer.Repo, \"SELECT current_database()\", []); if current != #{inspect(database)}, do: raise(\"artifact consumer connected to unexpected database\"); GenServer.stop(pid)"
  end

  defp parse_evidence!(output) do
    line = proof_line!(output)

    line
    |> String.replace_prefix("CHIMEWAY_CORE_PROOF ", "")
    |> String.split(" ", trim: true)
    |> Enum.map(fn pair ->
      [key, value] = String.split(pair, "=", parts: 2)
      {String.to_atom(key), value}
    end)
    |> Map.new()
  end

  defp proof_line!(output) do
    line = output |> String.split("\n") |> Enum.find(&String.starts_with?(&1, "CHIMEWAY_CORE_PROOF "))
    if is_nil(line), do: raise("artifact consumer proof did not emit CHIMEWAY_CORE_PROOF")
    line
  end

  defp cleanup!(root, db_config) do
    _ = Ecto.Adapters.Postgres.storage_down(db_config)
    File.rm_rf!(root)
    :ok
  end

  defp base_database_config do
    case System.get_env("DATABASE_URL") do
      nil ->
        Chimeway.Repo.config()
        |> Keyword.drop([:database, :pool, :url, :pool_size])
        |> Keyword.put_new(:hostname, "localhost")

      database_url ->
        uri = URI.parse(database_url)
        {username, password} = parse_userinfo(uri.userinfo)
        [username: username, password: password, hostname: uri.host || "localhost", port: uri.port || 5432]
    end
  end

  defp parse_userinfo(nil), do: {"postgres", nil}
  defp parse_userinfo(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> {URI.decode(username), URI.decode(password)}
      [username] -> {URI.decode(username), nil}
    end
  end

  defp repo_root!, do: File.cwd!()
end
