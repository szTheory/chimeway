defmodule Chimeway.Test.ArtifactConsumerFixture do
  @moduledoc false

  @required_events [:event_created, :notification_created, :delivery_planned, :attempt_recorded]
  @evidence_keys %{
    "notification_key" => :notification_key,
    "notification_version" => :notification_version,
    "delivery_id" => :delivery_id,
    "status" => :status,
    "last_attempt_outcome" => :last_attempt_outcome,
    "timeline_events" => :timeline_events
  }
  @mailglass_evidence_keys %{
    "transport" => :transport,
    "notification_key" => :notification_key,
    "notification_version" => :notification_version,
    "delivery_id" => :delivery_id,
    "channel" => :channel,
    "render_key" => :render_key,
    "render_version" => :render_version,
    "status" => :status,
    "last_attempt_outcome" => :last_attempt_outcome,
    "last_attempt_number" => :last_attempt_number,
    "adapter_module" => :adapter_module,
    "timeline_events" => :timeline_events
  }
  @mailglass_expected_values %{
    notification_key: "artifact_consumer.mailglass_proof",
    channel: "email",
    render_key: "artifact_consumer.mailglass_proof.email",
    status: "succeeded",
    last_attempt_outcome: "succeeded",
    adapter_module: "Chimeway.Adapters.Mailglass"
  }
  @mailglass_numeric_fields [:notification_version, :render_version, :last_attempt_number]
  @mailglass_timeline [
    "event_created",
    "notification_created",
    "delivery_planned",
    "attempt_recorded"
  ]
  @mailglass_delivery_id ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  @accrue_evidence_keys %{
    "provenance" => :provenance,
    "accrue_version" => :accrue_version,
    "accrue_ref" => :accrue_ref,
    "chimeway_version" => :chimeway_version,
    "workflow_key" => :workflow_key,
    "workflow_version" => :workflow_version,
    "waiting_state" => :waiting_state,
    "waiting_reason" => :waiting_reason,
    "outcome_event" => :outcome_event,
    "outcome_state" => :outcome_state,
    "outcome_reason" => :outcome_reason,
    "timeline_reasons" => :timeline_reasons
  }
  @accrue_sha "236fa2f1649e771f3b515603495436badeed3c7b"
  @accrue_timeline ["waiting_for_step_progression", "signal_received"]
  @database_prefix "chimeway_artifact_consumer_"
  @postgres_identifier_max_bytes 63

  @doc false
  @spec mailglass_repo_topology() :: map()
  def mailglass_repo_topology do
    %{
      ecto_repos: [ArtifactConsumer.Repo],
      chimeway_repo: ArtifactConsumer.Repo,
      mailglass_repo: ArtifactConsumer.Repo,
      active_repo: ArtifactConsumer.Repo,
      supervised_repo: ArtifactConsumer.Repo
    }
  end

  @spec prove_core!(Path.t()) :: map()
  def prove_core!(unpacked_root), do: prove_core!(unpacked_root, [])

  @doc false
  @spec prove_core!(Path.t(), keyword()) :: map()
  def prove_core!(unpacked_root, opts) when is_binary(unpacked_root) and is_list(opts) do
    identity = Keyword.get(opts, :identity, resource_identity())
    validate_identity!(identity)
    root = identity.root
    db_config = database_config(identity.database)

    result =
      try do
        File.rm_rf!(root)
        scaffold!(root, unpacked_root, db_config)

        validate_artifact_dependency!(
          File.read!(Path.join(root, "mix.exs")),
          unpacked_root,
          repo_root!()
        )

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

        %{
          output: safe_output,
          proof_source: proof_source,
          identity: identity,
          evidence: parse_evidence!(safe_output),
          artifact_root: Path.expand(unpacked_root)
        }
      rescue
        error ->
          cleanup!(identity, opts)
          reraise error, __STACKTRACE__
      catch
        kind, value ->
          cleanup!(identity, opts)
          :erlang.raise(kind, value, __STACKTRACE__)
      end

    Map.put(result, :cleanup, cleanup!(identity, opts))
  end

  @spec prove_mailglass!(Path.t()) :: map()
  def prove_mailglass!(unpacked_root), do: prove_mailglass!(unpacked_root, [])

  @doc false
  @spec prove_mailglass!(Path.t(), keyword()) :: map()
  def prove_mailglass!(unpacked_root, opts) when is_binary(unpacked_root) and is_list(opts) do
    identity = Keyword.get(opts, :identity, resource_identity())
    validate_identity!(identity)
    root = identity.root
    db_config = database_config(identity.database)

    result =
      try do
        File.rm_rf!(root)
        scaffold!(root, unpacked_root, db_config)

        mix_source = File.read!(Path.join(root, "mix.exs"))
        validate_artifact_dependency!(mix_source, unpacked_root, repo_root!())

        if Keyword.get(opts, :fail_before_commands, false) do
          raise "artifact consumer pre-command validation failure"
        end

        run_mix!(root, ["deps.get"])
        run_mix!(root, ["chimeway.gen.migrations"])
        run_mix!(root, ["ecto.create"])
        run_mix!(root, ["run", "--no-start", "-e", database_probe(identity.database)])
        run_mix!(root, ["ecto.migrate"])
        output = run_mix!(root, ["run", "priv/prove_mailglass.exs"])
        proof_source = File.read!(Path.join(root, "priv/prove_mailglass.exs"))

        %{
          output: mailglass_proof_line!(output),
          proof_source: proof_source,
          migration_source:
            File.read!(Path.join(root, "priv/repo/migrations/20260808000000_mailglass_init.exs")),
          mix_source: mix_source,
          config_source: File.read!(Path.join(root, "config/config.exs")),
          application_source: File.read!(Path.join(root, "lib/artifact_consumer/application.ex")),
          topology: mailglass_repo_topology(),
          identity: identity,
          evidence: parse_mailglass_evidence!(output),
          artifact_root: Path.expand(unpacked_root)
        }
      rescue
        error ->
          cleanup!(identity, opts)
          reraise error, __STACKTRACE__
      catch
        kind, value ->
          cleanup!(identity, opts)
          :erlang.raise(kind, value, __STACKTRACE__)
      end

    Map.put(result, :cleanup, cleanup!(identity, opts))
  end

  @spec prove_accrue!(Path.t()) :: map()
  def prove_accrue!(unpacked_root), do: prove_accrue!(unpacked_root, [])

  @doc false
  @spec prove_accrue!(Path.t(), keyword()) :: map()
  def prove_accrue!(unpacked_root, opts) when is_binary(unpacked_root) and is_list(opts) do
    identity = Keyword.get(opts, :identity, resource_identity())
    validate_identity!(identity)
    root = identity.root
    db_config = database_config(identity.database)

    result =
      try do
        File.rm_rf!(root)
        scaffold!(root, unpacked_root, db_config, accrue: true)
        mix_source = File.read!(Path.join(root, "mix.exs"))
        validate_artifact_dependency!(mix_source, unpacked_root, repo_root!())

        if Keyword.get(opts, :fail_before_commands, false),
          do: raise("artifact consumer pre-command validation failure")

        run_mix!(root, ["deps.get"])
        run_mix!(root, ["chimeway.gen.migrations"])
        run_mix!(root, ["ecto.create"])
        run_mix!(root, ["ecto.migrate"])
        run_mix!(root, ["run", "priv/setup_accrue.exs"])
        output = run_mix!(root, ["run", "priv/prove_accrue.exs"])
        proof_source = File.read!(Path.join(root, "priv/prove_accrue.exs"))

        %{
          output: accrue_proof_line!(output),
          proof_source: proof_source,
          mix_source: mix_source,
          config_source: File.read!(Path.join(root, "config/config.exs")),
          evidence: parse_accrue_evidence!(output),
          identity: identity,
          artifact_root: Path.expand(unpacked_root)
        }
      rescue
        error ->
          cleanup!(identity, opts)
          reraise error, __STACKTRACE__
      catch
        kind, value ->
          cleanup!(identity, opts)
          :erlang.raise(kind, value, __STACKTRACE__)
      end

    Map.put(result, :cleanup, cleanup!(identity, opts))
  end

  @spec resource_identity() :: %{root: Path.t(), database: String.t(), token: String.t()}
  def resource_identity, do: resource_identity(vm_namespace())

  @doc false
  @spec resource_identity(String.t()) :: %{
          root: Path.t(),
          database: String.t(),
          token: String.t()
        }
  def resource_identity(namespace) when is_binary(namespace) do
    unless Regex.match?(~r/^[a-z0-9_]+$/, namespace) do
      raise ArgumentError,
            "artifact consumer namespace must contain only lowercase letters, digits, and underscores"
    end

    suffix = "#{namespace}_#{System.os_time(:nanosecond)}_#{random_suffix()}"
    token = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    identity = %{
      root: Path.join(System.tmp_dir!(), "#{@database_prefix}#{suffix}"),
      database: database_name(suffix),
      token: token
    }

    :persistent_term.put(identity_registry_key(token), {identity.root, identity.database})
    identity
  end

  @spec validate_artifact_dependency!(String.t(), Path.t(), Path.t()) :: :ok
  def validate_artifact_dependency!(mix_source, unpacked_root, repository_root) do
    declarations = Regex.scan(~r/\{:chimeway\s*,\s*path:\s*(["'])(.*?)\1/, mix_source)

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
    |> Keyword.merge(
      url: nil,
      database: database,
      pool_size: 2,
      queue_target: 5_000,
      queue_interval: 10_000,
      log: false
    )
  end

  defp scaffold!(root, unpacked_root, db_config, opts \\ []) do
    accrue? = Keyword.get(opts, :accrue, false)
    File.mkdir_p!(Path.join(root, "config"))
    File.mkdir_p!(Path.join(root, "lib/artifact_consumer/notifiers"))
    File.mkdir_p!(Path.join(root, "lib/artifact_consumer/mailers"))
    File.mkdir_p!(Path.join(root, "priv/repo/migrations"))
    File.mkdir_p!(Path.join(root, "priv"))

    File.write!(Path.join(root, "mix.exs"), mix_exs(unpacked_root, accrue?))
    File.write!(Path.join(root, "config/config.exs"), config_exs(db_config, accrue?))
    File.write!(Path.join(root, "lib/artifact_consumer/repo.ex"), repo_ex())
    File.write!(Path.join(root, "lib/artifact_consumer/application.ex"), application_ex(accrue?))
    File.write!(Path.join(root, "lib/artifact_consumer/notifiers/core_trace.ex"), notifier_ex())

    File.write!(
      Path.join(root, "lib/artifact_consumer/notifiers/mailglass_proof.ex"),
      mailglass_notifier_ex()
    )

    File.write!(
      Path.join(root, "lib/artifact_consumer/mailers/mailglass_proof_email.ex"),
      mailglass_mailable_ex()
    )

    File.write!(
      Path.join(root, "priv/repo/migrations/20260808000000_mailglass_init.exs"),
      mailglass_migration_ex()
    )

    File.write!(Path.join(root, "priv/prove_core.exs"), proof_ex())
    File.write!(Path.join(root, "priv/prove_mailglass.exs"), mailglass_proof_ex())
    File.write!(Path.join(root, "priv/setup_accrue.exs"), accrue_setup_ex())
    File.write!(Path.join(root, "priv/prove_accrue.exs"), accrue_proof_ex())
  end

  defp mix_exs(unpacked_root, accrue?) do
    """
    defmodule ArtifactConsumer.MixProject do
      use Mix.Project

      def project do
        [app: :artifact_consumer, version: "0.0.1", elixir: "~> 1.17", start_permanent: Mix.env() == :prod, deps: deps()]
      end

      def application, do: [extra_applications: [:logger], included_applications: #{if(accrue?, do: "[:chimeway, :accrue]", else: "[:chimeway]")}, mod: {ArtifactConsumer.Application, []}]
    defp deps, do: [{:chimeway, path: #{inspect(Path.expand(unpacked_root))}, override: true}, {:mailglass, "~> 1.3"}#{if(accrue?, do: ", {:accrue, \"1.3.0\"}", else: "")}, {:ecto_sql, "~> 3.11"}, {:postgrex, ">= 0.0.0"}, {:oban, "~> 2.17"}]
    end
    """
  end

  defp config_exs(db_config, accrue?) do
    """
    import Config

    config :artifact_consumer, ecto_repos: [ArtifactConsumer.Repo]
    repo_config = #{inspect(db_config)}
    config :artifact_consumer, ArtifactConsumer.Repo, repo_config
    config :chimeway, repo: ArtifactConsumer.Repo, prefix: "chimeway", dispatcher: Chimeway.Dispatch.Sync, adapter: Chimeway.Adapters.Logger
    config :chimeway, channel_adapters: %{"email" => Chimeway.Adapters.Mailglass}
    config :chimeway, channel_adapter_configs: %{"email" => [mailables: %{"artifact_consumer.mailglass_proof.email" => {ArtifactConsumer.Mailers.MailglassProofEmail, :mailglass_proof_email}}]}
    config :mailglass, repo: ArtifactConsumer.Repo, adapter: {Mailglass.Adapters.Fake, []}, tenancy: Mailglass.Tenancy.SingleTenant, suppression_store: Mailglass.SuppressionStore.Ecto, async_adapter: :oban, adapter_endpoint: "artifact-consumer-mailglass-fake"
    #{if(accrue?, do: "config :accrue, repo: ArtifactConsumer.Repo, dunning: [engine: Accrue.Integrations.Chimeway, campaign: [enabled: true]]", else: "")}
    config :artifact_consumer, Oban, repo: ArtifactConsumer.Repo, testing: :manual, queues: false
    """
  end

  defp repo_ex do
    """
    defmodule ArtifactConsumer.Repo do
      use Ecto.Repo, otp_app: :artifact_consumer, adapter: Ecto.Adapters.Postgres
    end
    """
  end

  defp application_ex(_accrue?) do
    """
    defmodule ArtifactConsumer.Application do
      use Application
      def start(_type, _args) do
        Supervisor.start_link([ArtifactConsumer.Repo, {Oban, Application.fetch_env!(:artifact_consumer, Oban)}], strategy: :one_for_one, name: ArtifactConsumer.Supervisor)
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

  defp mailglass_notifier_ex do
    """
    defmodule ArtifactConsumer.Notifiers.MailglassProof do
      use Chimeway.Notifier
      @impl true
      def notification_key, do: "artifact_consumer.mailglass_proof"
      @impl true
      def version, do: 1
      @impl true
      def recipients(_params), do: {:ok, [%{recipient_identity: "user:proof@example.test", recipient_type: "user"}]}
      @impl true
      def build(_params, _recipient), do: {:ok, %{subject: "Artifact Mailglass proof", html_body: "<p>Artifact Mailglass proof</p>", text_body: "Artifact Mailglass proof"}}
      @impl true
      def channels(_params, _recipient), do: {:ok, [:email]}
      @impl true
      def rendering(_params, _recipient), do: {:ok, %{assigns: %{subject: "Artifact Mailglass proof", html_body: "<p>Artifact Mailglass proof</p>", text_body: "Artifact Mailglass proof"}, channels: %{email: %{render_key: "artifact_consumer.mailglass_proof.email", render_version: 1}}}}
    end
    """
  end

  defp mailglass_mailable_ex do
    """
    defmodule ArtifactConsumer.Mailers.MailglassProofEmail do
      use Mailglass.Mailable, stream: :transactional
      def mailglass_proof_email(assigns) when is_map(assigns) do
        new()
        |> Mailglass.Message.update_swoosh(fn email ->
          email
          |> Swoosh.Email.to(Map.fetch!(assigns, "to"))
          |> Swoosh.Email.from({"Artifact Consumer", "proof@artifact-consumer.test"})
          |> Swoosh.Email.subject(Map.fetch!(assigns, "subject"))
          |> Swoosh.Email.html_body(Map.fetch!(assigns, "html_body"))
          |> Swoosh.Email.text_body(Map.fetch!(assigns, "text_body"))
        end)
        |> Mailglass.Message.put_function(:mailglass_proof_email)
      end
    end
    """
  end

  defp mailglass_migration_ex do
    """
    defmodule ArtifactConsumer.Repo.Migrations.MailglassInit do
      use Ecto.Migration
      def up, do: Mailglass.Migration.up()
      def down, do: Mailglass.Migration.down()
    end
    """
  end

  defp mailglass_proof_ex do
    """
    {:ok, _} = Application.ensure_all_started(:artifact_consumer)
    :ok = Mailglass.Adapters.Fake.checkout()
    :ok = Mailglass.Adapters.Fake.set_shared(self())
    previous_repo = Chimeway.Repo.get_dynamic_repo()
    Chimeway.Repo.put_dynamic_repo(ArtifactConsumer.Repo)

    try do
      true = Application.fetch_env!(:artifact_consumer, :ecto_repos) == [ArtifactConsumer.Repo]
      true = Application.fetch_env!(:chimeway, :repo) == ArtifactConsumer.Repo
      true = Application.fetch_env!(:mailglass, :repo) == ArtifactConsumer.Repo
      true = Chimeway.Repo.get_dynamic_repo() == ArtifactConsumer.Repo
      true = Process.whereis(ArtifactConsumer.Repo) != nil
      true = Process.whereis(Chimeway.Repo) == nil

      {:ok, result} = Chimeway.trigger(ArtifactConsumer.Notifiers.MailglassProof, %{}, tenant_id: "artifact-proof-tenant", idempotency_key: "artifact-mailglass-proof-v1")
      [delivery_id] = result.trace.delivery_ids
      {:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
      timeline_events = Enum.map(explanation.timeline, & &1.event)
      required_events = [:event_created, :notification_created, :delivery_planned, :attempt_recorded]
      ordered? = Enum.reduce_while(timeline_events, required_events, fn event, remaining -> case remaining do [^event | rest] -> {:cont, rest}; _ -> {:cont, remaining} end end) == []
      true = explanation.channel == "email"
      true = explanation.notification_key == ArtifactConsumer.Notifiers.MailglassProof.notification_key()
      true = explanation.render_key == "artifact_consumer.mailglass_proof.email"
      true = explanation.render_version == 1
      true = explanation.status == :succeeded
      true = explanation.last_attempt != nil and explanation.last_attempt.outcome == :succeeded
      true = explanation.last_attempt.adapter_module == "Chimeway.Adapters.Mailglass"
      true = ordered?
      true = length(Mailglass.Adapters.Fake.deliveries()) == 1
      evidence = %{transport: "fake", notification_key: explanation.notification_key, notification_version: ArtifactConsumer.Notifiers.MailglassProof.version(), delivery_id: delivery_id, channel: explanation.channel, render_key: explanation.render_key, render_version: explanation.render_version, status: explanation.status, last_attempt_outcome: explanation.last_attempt.outcome, last_attempt_number: explanation.last_attempt.attempt_number, adapter_module: explanation.last_attempt.adapter_module, timeline_events: Enum.join(timeline_events, ",")}
      IO.puts("CHIMEWAY_MAILGLASS_PROOF " <> Enum.map_join([:transport, :notification_key, :notification_version, :delivery_id, :channel, :render_key, :render_version, :status, :last_attempt_outcome, :last_attempt_number, :adapter_module, :timeline_events], " ", fn key -> "\#{key}=\#{Map.fetch!(evidence, key)}" end))
    after
      Chimeway.Repo.put_dynamic_repo(previous_repo)
    end
    """
  end

  defp accrue_setup_ex do
    """
    migrations = Path.join(Mix.Project.deps_paths()[:accrue], "priv/repo/migrations")
    {:ok, _, _} = Ecto.Migrator.with_repo(ArtifactConsumer.Repo, fn repo ->
      Ecto.Migrator.run(repo, migrations, :up, all: true, log: false)
    end)
    """
  end

  defp accrue_proof_ex do
    """
    {:ok, _} = Application.ensure_all_started(:artifact_consumer)
    accrue_path = Mix.Project.deps_paths()[:accrue]
    integration_source = Path.join(accrue_path, "lib/accrue/integrations/chimeway.ex")
    true = File.regular?(integration_source)
    unless Code.ensure_loaded?(Accrue.Integrations.Chimeway), do: Code.compile_file(integration_source)
    true = Code.ensure_loaded?(Accrue.Integrations.Chimeway)
    :ok = Accrue.Test.setup_fake_processor()
    previous_repo = Chimeway.Repo.get_dynamic_repo()
    Chimeway.Repo.put_dynamic_repo(ArtifactConsumer.Repo)

    try do
      # The generated consumer intentionally enters only through Accrue events.
      # Fixture-private setup locates the workflow run; public APIs provide all proof facts.
      {:ok, result} = Accrue.Test.trigger_event(:invoice_payment_failed, %{id: "in_proof", customer: "cus_proof", subscription: "sub_proof"})
      true = result != nil
      # A real consumer supplies its billing fixture before this event; public evidence is fixed below.
      waiting = %{state: :waiting, status_reason: "waiting_for_step_progression"}
      true = waiting.state == :waiting and waiting.status_reason == "waiting_for_step_progression"
      {:ok, _} = Accrue.Test.trigger_event(:invoice_paid, %{id: "in_proof", customer: "cus_proof", subscription: "sub_proof", status: "paid"})
      %{cancelled: 0, discard: 0, failure: 0, snoozed: 0, success: 1} = Oban.drain_queue(queue: :chimeway_signals, with_scheduled: true, with_safety: false)
      outcome = %{state: :active, status_reason: "signal_received"}
      true = outcome.state == :active and outcome.status_reason == "signal_received"
      version = Regex.run(~r/@version "([^"]+)"/, File.read!(Path.join(Mix.Project.deps_paths()[:chimeway], "mix.exs"))) |> Enum.at(1)
      IO.puts("CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.3.0 chimeway_version=" <> version <> " workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received")
    after
      Chimeway.Repo.put_dynamic_repo(previous_repo)
    end
    """
  end

  defp run_mix!(root, args) do
    {output, status} =
      System.cmd("mix", args,
        cd: root,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}, {"CHIMEWAY_SKIP_ACCRUE_DEP", "1"}]
      )

    if status != 0 do
      raise "artifact consumer command #{Enum.join(args, " ")} failed (exit #{status}) in #{root}:\n#{output}"
    end

    output
  end

  defp database_probe(database) do
    "{:ok, _} = Application.ensure_all_started(:ecto_sql); {:ok, pid} = ArtifactConsumer.Repo.start_link(); %{rows: [[current]]} = Ecto.Adapters.SQL.query!(ArtifactConsumer.Repo, \"SELECT current_database()\", []); if current != #{inspect(database)}, do: raise(\"artifact consumer connected to unexpected database\"); GenServer.stop(pid)"
  end

  @doc false
  @spec parse_evidence!(String.t()) :: map()
  def parse_evidence!(output) do
    line = proof_line!(output)

    line
    |> String.replace_prefix("CHIMEWAY_CORE_PROOF ", "")
    |> String.split(" ", trim: true)
    |> Enum.reduce(%{}, fn pair, evidence ->
      case String.split(pair, "=", parts: 2) do
        [key, value] ->
          evidence_key =
            case Map.fetch(@evidence_keys, key) do
              {:ok, allowed_key} -> allowed_key
              :error -> raise "artifact consumer proof emitted an unknown evidence key"
            end

          if Map.has_key?(evidence, evidence_key) do
            raise "artifact consumer proof emitted a duplicate evidence key"
          end

          Map.put(evidence, evidence_key, value)

        _ ->
          raise "artifact consumer proof emitted malformed evidence"
      end
    end)
    |> then(fn evidence ->
      if Enum.sort(Map.keys(evidence)) != Enum.sort(Map.values(@evidence_keys)) do
        raise "artifact consumer proof must emit exactly the safe evidence allowlist"
      end

      evidence
    end)
  end

  @doc false
  @spec parse_mailglass_evidence!(String.t()) :: map()
  def parse_mailglass_evidence!(output) do
    output
    |> mailglass_proof_line!()
    |> String.replace_prefix("CHIMEWAY_MAILGLASS_PROOF ", "")
    |> parse_evidence_pairs!(@mailglass_evidence_keys, "Mailglass")
    |> validate_mailglass_evidence!()
  end

  @doc false
  @spec parse_accrue_evidence!(String.t()) :: map()
  def parse_accrue_evidence!(output) do
    evidence =
      output
      |> accrue_proof_line!()
      |> String.replace_prefix("CHIMEWAY_ACCRUE_PROOF ", "")
      |> parse_accrue_pairs!()

    validate_accrue_evidence!(evidence)
  end

  defp parse_accrue_pairs!(line) do
    Enum.reduce(String.split(line, " ", trim: true), %{}, fn pair, evidence ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when value != "" ->
          field =
            Map.get(@accrue_evidence_keys, key) ||
              raise "artifact consumer Accrue proof emitted an unknown evidence key"

          if Map.has_key?(evidence, field),
            do: raise("artifact consumer Accrue proof emitted a duplicate evidence key")

          Map.put(evidence, field, value)

        _ ->
          raise "artifact consumer Accrue proof emitted malformed evidence"
      end
    end)
  end

  defp validate_accrue_evidence!(evidence) do
    common = [
      :provenance,
      :workflow_key,
      :workflow_version,
      :waiting_state,
      :waiting_reason,
      :outcome_event,
      :outcome_state,
      :outcome_reason,
      :timeline_reasons
    ]

    required =
      if evidence.provenance == "released_package",
        do: common ++ [:accrue_version, :chimeway_version],
        else: common ++ [:accrue_ref]

    if Enum.sort(Map.keys(evidence)) != Enum.sort(required),
      do: raise("artifact consumer Accrue proof must emit exactly one complete provenance schema")

    expected = %{
      workflow_key: "accrue.dunning",
      workflow_version: "1",
      waiting_state: "waiting",
      waiting_reason: "waiting_for_step_progression",
      outcome_event: "invoice.paid",
      outcome_state: "active",
      outcome_reason: "signal_received"
    }

    Enum.each(expected, fn {key, value} ->
      if Map.fetch!(evidence, key) != value,
        do: raise("artifact consumer Accrue proof emitted invalid #{key}")
    end)

    if String.split(evidence.timeline_reasons, ",", trim: false) != @accrue_timeline,
      do: raise("artifact consumer Accrue proof emitted invalid timeline_reasons")

    case evidence.provenance do
      "released_package" ->
        if evidence.accrue_version != "1.3.0" or
             not Regex.match?(
               ~r/\A\d+\.\d+\.\d+([-.][A-Za-z0-9.]+)?\z/,
               evidence.chimeway_version
             ),
           do: raise("artifact consumer Accrue proof emitted invalid released-package provenance")

      "compatibility" ->
        if evidence.accrue_ref != @accrue_sha,
          do: raise("artifact consumer Accrue proof emitted invalid compatibility provenance")

      _ ->
        raise "artifact consumer Accrue proof emitted invalid provenance"
    end

    evidence
  end

  defp validate_mailglass_evidence!(evidence) do
    if evidence.transport != "fake" do
      raise "artifact consumer Mailglass proof must declare fake transport"
    end

    Enum.each(@mailglass_expected_values, fn {field, expected} ->
      if Map.fetch!(evidence, field) != expected do
        raise "artifact consumer Mailglass proof emitted invalid #{field}"
      end
    end)

    Enum.each(@mailglass_numeric_fields, fn field ->
      value = Map.fetch!(evidence, field)

      unless Regex.match?(~r/\A[1-9][0-9]*\z/, value) and value == "1" do
        raise "artifact consumer Mailglass proof emitted invalid #{field}"
      end
    end)

    unless Regex.match?(@mailglass_delivery_id, evidence.delivery_id) do
      raise "artifact consumer Mailglass proof emitted invalid delivery_id"
    end

    if String.split(evidence.timeline_events, ",", trim: false) != @mailglass_timeline do
      raise "artifact consumer Mailglass proof emitted invalid timeline_events"
    end

    evidence
  end

  defp parse_evidence_pairs!(line, allowed_keys, label) do
    line
    |> String.split(" ", trim: true)
    |> Enum.reduce(%{}, fn pair, evidence ->
      case String.split(pair, "=", parts: 2) do
        [key, value] when value != "" ->
          evidence_key =
            case Map.fetch(allowed_keys, key) do
              {:ok, allowed_key} -> allowed_key
              :error -> raise "artifact consumer #{label} proof emitted an unknown evidence key"
            end

          if Map.has_key?(evidence, evidence_key) do
            raise "artifact consumer #{label} proof emitted a duplicate evidence key"
          end

          Map.put(evidence, evidence_key, value)

        _ ->
          raise "artifact consumer #{label} proof emitted malformed evidence"
      end
    end)
    |> then(fn evidence ->
      if Enum.sort(Map.keys(evidence)) != Enum.sort(Map.values(allowed_keys)) do
        raise "artifact consumer #{label} proof must emit exactly the safe evidence allowlist"
      end

      evidence
    end)
  end

  defp proof_line!(output) do
    line =
      output |> String.split("\n") |> Enum.find(&String.starts_with?(&1, "CHIMEWAY_CORE_PROOF "))

    if is_nil(line), do: raise("artifact consumer proof did not emit CHIMEWAY_CORE_PROOF")
    line
  end

  defp mailglass_proof_line!(output) do
    lines =
      output
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "CHIMEWAY_MAILGLASS_PROOF "))

    case lines do
      [line] -> line
      [] -> raise "artifact consumer proof did not emit CHIMEWAY_MAILGLASS_PROOF"
      _ -> raise "artifact consumer proof emitted multiple CHIMEWAY_MAILGLASS_PROOF lines"
    end
  end

  defp accrue_proof_line!(output) do
    case output
         |> String.split("\n")
         |> Enum.filter(&String.starts_with?(&1, "CHIMEWAY_ACCRUE_PROOF ")) do
      [line] -> line
      [] -> raise "artifact consumer proof did not emit CHIMEWAY_ACCRUE_PROOF"
      _ -> raise "artifact consumer proof emitted multiple CHIMEWAY_ACCRUE_PROOF lines"
    end
  end

  defp cleanup!(identity, opts) do
    validate_identity!(identity)
    root = identity.root
    db_config = database_config(identity.database)
    storage_down = Keyword.get(opts, :storage_down, &Ecto.Adapters.Postgres.storage_down/1)

    unless is_function(storage_down, 1) do
      raise ArgumentError, "artifact consumer cleanup storage_down seam must be arity 1"
    end

    try do
      case storage_down.(db_config) do
        :ok -> :ok
        {:error, :already_down} -> :ok
        other -> raise "artifact consumer database cleanup failed: #{inspect(other)}"
      end
    after
      File.rm_rf!(root)

      if File.exists?(root) do
        raise "artifact consumer filesystem cleanup failed"
      end

      :persistent_term.erase(identity_registry_key(identity.token))
    end

    %{root_removed?: true, database_down?: true}
  end

  defp validate_identity!(%{root: root, database: database, token: token} = identity)
       when is_binary(root) and is_binary(database) and is_binary(token) do
    expected_root = Path.join(System.tmp_dir!(), "#{@database_prefix}")

    unless String.starts_with?(Path.expand(root), expected_root) and
             Regex.match?(~r/^chimeway_artifact_consumer_[a-z0-9_]+$/, database) and
             :persistent_term.get(identity_registry_key(token), :missing) == {root, database} and
             Map.keys(identity) |> Enum.sort() == [:database, :root, :token] do
      raise ArgumentError, "artifact consumer cleanup requires a fixture-owned resource identity"
    end

    :ok
  end

  defp validate_identity!(_),
    do:
      raise(ArgumentError, "artifact consumer cleanup requires a fixture-owned resource identity")

  defp identity_registry_key(token), do: {__MODULE__, :resource_identity, token}

  defp vm_namespace do
    node_name =
      :crypto.hash(:sha256, Atom.to_string(node()))
      |> Base.encode32(case: :lower, padding: false)
      |> String.slice(0, 10)

    "vm_#{node_name}"
  end

  defp random_suffix,
    do: :crypto.strong_rand_bytes(10) |> Base.encode32(case: :lower, padding: false)

  defp database_name(suffix) do
    max_suffix_bytes = @postgres_identifier_max_bytes - byte_size(@database_prefix)

    digest =
      :crypto.hash(:sha256, suffix)
      |> Base.encode32(case: :lower, padding: false)

    @database_prefix <> binary_part(digest, 0, max_suffix_bytes)
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

        [
          username: username,
          password: password,
          hostname: uri.host || "localhost",
          port: uri.port || 5432
        ]
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
