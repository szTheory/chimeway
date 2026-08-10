defmodule Chimeway.DocContractTest do
  use ExUnit.Case, async: true

  alias Chimeway.Test.ArtifactConsumerFixture

  @moduledoc false

  @public_modules [
    Chimeway,
    Chimeway.Notifier,
    Chimeway.Traces,
    Chimeway.Telemetry
  ]

  for mod <- @public_modules do
    test "#{inspect(mod)} has a moduledoc" do
      case Code.fetch_docs(unquote(mod)) do
        {:docs_v1, _, _, _, module_doc, _, _} ->
          refute module_doc == :none,
                 "#{inspect(unquote(mod))} is missing @moduledoc — public modules must be documented"

          refute module_doc == :hidden,
                 "#{inspect(unquote(mod))} has @moduledoc false — public modules must be documented"

        {:error, reason} ->
          flunk("Could not fetch docs for #{inspect(unquote(mod))}: #{inspect(reason)}")
      end
    end
  end

  @journey_guide "guides/flows/multi-step-journeys.md"

  describe "journey guide doc contract (DOCS-03)" do
    setup do
      content = File.read!(@journey_guide)
      %{content: content}
    end

    @forbidden_strings ~w(
      stop_conditions
      Workflows.Workers
      Chimeway.Trigger.trigger
      PT2H
      Engine gap today
    )

    @forbidden_phrases [
      "type: :wait",
      "does **not** emit",
      "READ-02 (Phase 49)",
      "Deferred / Future (READ Milestone)",
      "not inbox-read cancellation"
    ]

    for forbidden <- @forbidden_strings do
      test "forbids #{forbidden} in journey guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "guides/flows/multi-step-journeys.md must not reference #{unquote(forbidden)}"
      end
    end

    for phrase <- @forbidden_phrases do
      test "forbids #{phrase} in journey guide", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "guides/flows/multi-step-journeys.md must not reference #{unquote(phrase)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in journey guide", %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "guides/flows/multi-step-journeys.md must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      wait_until
      on_outcome
      Chimeway.trigger
      Chimeway.Signal.track
      Chimeway.Dispatch.WorkflowProgressionWorker
      Chimeway.Dispatch.SignalRouterWorker
      pending_signals
      cancel_signals
      Chimeway.mark_read
      Chimeway.mark_seen
      chimeway.notification.read
      chimeway.notification.seen
    )

    for required <- @required do
      test "requires #{required} in journey guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "guides/flows/multi-step-journeys.md must reference #{unquote(required)}"
      end
    end

    test "documents inbox lifecycle signal emission (READ-02 shipped)", %{content: content} do
      assert String.contains?(content, "Chimeway.mark_read")
      assert String.contains?(content, "chimeway.notification.read")
    end
  end

  @password_reset_recipe "guides/recipes/password-reset-support-trace.md"
  @feedback_recipe "guides/recipes/feedback-escalation-workflow.md"
  @mention_escalation_recipe "guides/recipes/mention-escalation.md"

  @recipe_forbidden_strings ~w(
    stop_conditions
    Workflows.Workers
    Chimeway.Trigger.trigger
  )

  describe "password reset recipe doc contract (RECP-01)" do
    setup do
      content = File.read!(@password_reset_recipe)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in password reset recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "password reset recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in password reset recipe", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "password reset recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Chimeway.trigger
      find_traces_for_recipient
      explain_delivery
      password_reset
    )

    for required <- @required do
      test "requires #{required} in password reset recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "password reset recipe must reference #{unquote(required)}"
      end
    end
  end

  describe "feedback escalation recipe doc contract (RECP-02)" do
    setup do
      content = File.read!(@feedback_recipe)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in feedback escalation recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "feedback escalation recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in feedback escalation recipe", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "feedback escalation recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Chimeway.trigger
      Chimeway.Signal.track
      ProcessFeedbackWorker
      SignalRouterWorker
      explain_delivery
      chimeway.delivery.succeeded
      webhook_received
    )

    for required <- @required do
      test "requires #{required} in feedback escalation recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "feedback escalation recipe must reference #{unquote(required)}"
      end
    end
  end

  describe "mention escalation recipe doc contract (RECP-03 / DEMO-04)" do
    setup do
      content = File.read!(@mention_escalation_recipe)
      %{content: content}
    end

    @mention_forbidden_strings ~w(
      stop_conditions
      Workflows.Workers
      Chimeway.Trigger.trigger
      stage_escalation_webhook
      PendingWebhookAdapter
      waiting_for_signal
      chimeway.delivery.succeeded
    )

    @mention_forbidden_phrases [
      "not inbox-read cancellation",
      "Engine gap today"
    ]

    for forbidden <- @mention_forbidden_strings do
      test "forbids #{forbidden} in mention escalation recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "mention escalation recipe must not reference #{unquote(forbidden)}"
      end
    end

    for phrase <- @mention_forbidden_phrases do
      test "forbids #{phrase} in mention escalation recipe", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "mention escalation recipe must not reference #{unquote(phrase)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in mention escalation recipe", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "mention escalation recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Chimeway.trigger
      Chimeway.mark_read
      cancel_signals
      wait_until
      delay_seconds
      chimeway.notification.read
      prior_delivery_terminal_at
      SignalRouterWorker
      to_step
    )

    for required <- @required do
      test "requires #{required} in mention escalation recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "mention escalation recipe must reference #{unquote(required)}"
      end
    end
  end

  @demo_host_readme "examples/chimeway_demo_host/README.md"
  @admin_integration_guide "guides/introduction/admin-console-integration.md"

  describe "demo-host admin console doc contract (ADMIN-03)" do
    setup do
      content = File.read!(@demo_host_readme)
      %{content: content}
    end

    @admin_required_strings [
      "Command Center",
      "Trace Lookup",
      "Trace Detail",
      "Feed Debug",
      "Definitions",
      "Health",
      "Recovery",
      "/admin/chimeway"
    ]

    for required <- @admin_required_strings do
      test "requires #{required} in demo-host admin copy", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "examples/chimeway_demo_host/README.md must reference #{unquote(required)}"
      end
    end

    @admin_forbidden_strings [
      "trace lookup only",
      "health aggregates dashboard",
      "notification definitions registry",
      "skew detection",
      "code-registry",
      "end-user inbox surface"
    ]

    for forbidden <- @admin_forbidden_strings do
      test "forbids #{forbidden} in demo-host admin copy", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "examples/chimeway_demo_host/README.md must not reintroduce stale admin claim: #{unquote(forbidden)}"
      end
    end
  end

  describe "admin integration guide doc contract (DOCS-12)" do
    setup do
      content = File.read!(@admin_integration_guide)
      %{content: content}
    end

    @admin_guide_required_strings [
      "Command Center",
      "Trace Lookup",
      "Trace Detail",
      "Feed Debug",
      "Definitions",
      "Health",
      "Recovery",
      "/admin/chimeway",
      "/admin/chimeway/traces",
      "/admin/chimeway/feed",
      "/admin/chimeway/definitions",
      "/admin/chimeway/health",
      "/admin/chimeway/recovery",
      "/admin/chimeway/deliveries/",
      "chimeway_admin_routes()",
      "Plug.Static",
      "ChimewayAdmin.Assets.css_path()",
      "/chimeway_admin/chimeway_admin.css",
      "config :chimeway_admin, auth_module: MyApp.AdminAuth",
      "ChimewayAdmin.Auth",
      "authorize/3",
      "{:error, :unauthorized}",
      "current_actor",
      "chimeway_admin_tenant_id",
      "path_prefix",
      ":list_recovery_candidates",
      ":recover_delivery",
      ":recover_event",
      "raw payloads",
      "render data",
      "provider bodies",
      "tokens",
      "secrets",
      "auth codes",
      "full recipient PII",
      "mix verify.admin"
    ]

    for required <- @admin_guide_required_strings do
      test "requires #{required} in admin integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "admin integration guide must reference #{unquote(required)}"
      end
    end

    @admin_guide_forbidden_strings [
      "trace lookup only",
      "code-registry",
      "code registry",
      "source-code skew",
      "source skew",
      "module inventory",
      "loaded modules",
      "provider raw body inspection",
      "generic CRUD",
      "template editing",
      "provider configuration UI",
      "arbitrary bulk recovery",
      "cohort analytics",
      "{:chimeway_admin, \"~> 1.0\"}"
    ]

    for forbidden <- @admin_guide_forbidden_strings do
      test "forbids #{forbidden} in admin integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "admin integration guide must not reintroduce stale or unsafe admin claim: #{unquote(forbidden)}"
      end
    end

    test "documents fail-closed production auth", %{content: content} do
      assert String.contains?(content, "Production setup must fail closed")
      assert String.contains?(content, "Production must not use permissive demo auth")
    end

    test "documents host-owned tenant and role policy", %{content: content} do
      assert String.contains?(content, "does not validate tenant membership or roles")
      assert String.contains?(content, "tenant membership, role policy, and per-resource access")
    end

    test "documents chimeway_admin preview/path install status (TRUTH-03 / D-05)", %{
      content: content
    } do
      assert String.contains?(content, "in-repo preview/path package"),
             "admin guide must state chimeway_admin is an in-repo preview/path package"

      assert String.contains?(content, "not published on Hex yet"),
             "admin guide must state chimeway_admin is not published on Hex yet"
    end

    test "uses chimeway_admin path dependency and preserves root Chimeway dep (D-05)", %{
      content: content
    } do
      assert String.contains?(content, ~s({:chimeway_admin, path: "../chimeway_admin"})),
             "admin guide must use the chimeway_admin path dependency for preview usage"

      assert String.contains?(content, ~s({:chimeway, "~> 1.0"})),
             "admin guide must preserve the root {:chimeway, \"~> 1.0\"} dependency"
    end

    test "forbids current-Hex chimeway_admin install claim (D-06)", %{content: content} do
      refute String.contains?(content, ~s({:chimeway_admin, "~> 1.0"})),
             "admin guide must not present chimeway_admin as a current Hex dependency"
    end

    test "chimeway_admin/mix.exs remains path-package evidence, not a Hex package (D-05)" do
      mix = File.read!("chimeway_admin/mix.exs")

      assert String.contains?(mix, "app: :chimeway_admin"),
             "chimeway_admin/mix.exs must declare app: :chimeway_admin"

      assert String.contains?(mix, ~s(version: "0.1.0")),
             "chimeway_admin/mix.exs must keep the preview version 0.1.0"

      assert String.contains?(mix, ~s({:chimeway, path: ".."})),
             "chimeway_admin/mix.exs must depend on chimeway via a path dependency"

      refute String.contains?(mix, "package:"),
             "chimeway_admin/mix.exs must not define Hex package metadata in Phase 78"

      refute String.contains?(mix, "docs:"),
             "chimeway_admin/mix.exs must not define HexDocs metadata in Phase 78"
    end
  end

  @mailglass_blueprint_recipe Path.expand(
                                "../../guides/recipes/mailglass-integration-blueprint.md",
                                __DIR__
                              )

  describe "mailglass blueprint recipe doc contract (ECOS-05)" do
    setup do
      content = File.read!(@mailglass_blueprint_recipe)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in mailglass blueprint recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "mailglass blueprint recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in mailglass blueprint recipe", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "mailglass blueprint recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Chimeway.Adapters.Mailglass
      Chimeway.Adapter.Mailglass
      Chimeway.trigger
      channel_adapters
      channel_adapter_configs
      render_key
      teampulse.invite_sent
      teampulse.invite_sent.email
      DemoHost.Notifiers.InviteSent
      DemoHost.Mailers.InviteEmail
      orchestrates
      templating
      idempotency_key
      tenant_id
    )

    for required <- @required do
      test "requires #{required} in mailglass blueprint recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "mailglass blueprint recipe must reference #{unquote(required)}"
      end
    end

    test "requires reciprocal link to mailglass integration guide", %{content: content} do
      assert String.contains?(content, "../introduction/mailglass-integration.md"),
             "mailglass blueprint recipe must link to introduction guide"
    end
  end

  @accrue_blueprint_recipe Path.expand(
                             "../../guides/recipes/accrue-dunning-blueprint.md",
                             __DIR__
                           )

  describe "accrue dunning blueprint recipe doc contract (ECOS-07)" do
    setup do
      content = File.read!(@accrue_blueprint_recipe)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in accrue dunning blueprint recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "accrue dunning blueprint recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in accrue dunning blueprint recipe",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "accrue dunning blueprint recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Accrue.Integrations.Chimeway
      invoice.payment_failed
      invoice.paid
      cancel_campaign
      Chimeway.Signal.track
      workflow/2
      config :accrue
      dunning
      idempotency_key
      tenant_id
      orchestrates
      DemoHost.Seeds.seed_accrue_dunning
      /admin/chimeway
    )

    for required <- @required do
      test "requires #{required} in accrue dunning blueprint recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "accrue dunning blueprint recipe must reference #{unquote(required)}"
      end
    end

    test "requires billing-state split language in accrue dunning blueprint recipe", %{
      content: content
    } do
      assert String.contains?(content, "billing")

      assert String.contains?(content, "state") or String.contains?(content, "Accrue"),
             "accrue dunning blueprint recipe must document billing-state responsibility split"
    end

    test "requires reciprocal link to accrue dunning integration guide", %{content: content} do
      assert String.contains?(content, "../introduction/accrue-dunning-integration.md"),
             "accrue dunning blueprint recipe must link to introduction guide"
    end

    test "forbids Phase 60 placeholder language in accrue dunning blueprint recipe", %{
      content: content
    } do
      refute Regex.match?(~r/ships in phase 60/i, content),
             "accrue dunning blueprint recipe must not reference Phase 60 placeholder shipping"

      refute Regex.match?(~r/placeholder/i, content),
             "accrue dunning blueprint recipe must not reference placeholder shipping language"
    end
  end

  @sigra_blueprint_recipe Path.expand("../../guides/recipes/sigra-auth-blueprint.md", __DIR__)

  describe "sigra auth blueprint recipe doc contract (ECOS-10)" do
    setup do
      content = File.read!(@sigra_blueprint_recipe)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in sigra auth blueprint recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "sigra auth blueprint recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids raw_token in sigra auth blueprint recipe", %{content: content} do
      refute String.contains?(content, "raw_token"),
             "sigra auth blueprint recipe must not expose raw token values"
    end

    test "forbids raw token (prose form) in sigra auth blueprint recipe", %{content: content} do
      refute String.contains?(content, "raw token"),
             "sigra auth blueprint recipe must not expose raw token values (prose form)"
    end

    test "forbids Chimeway.Workflow module (not Workflows) in sigra auth blueprint recipe",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "sigra auth blueprint recipe must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Sigra.Integrations.Chimeway
      sigra.auth.magic_link
      sigra.auth.confirmation_code
      Chimeway.trigger
      idempotency_key
      tenant_id
      orchestrates
      DemoHost.Seeds.seed_sigra
      /admin/chimeway
      sigra-auth-integration.md
    )

    for required <- @required do
      test "requires #{required} in sigra auth blueprint recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "sigra auth blueprint recipe must reference #{unquote(required)}"
      end
    end

    test "requires auth-state split language in sigra auth blueprint recipe", %{content: content} do
      assert String.contains?(content, "auth state") or String.contains?(content, "auth_state"),
             "sigra auth blueprint recipe must document auth-state responsibility split"
    end

    test "requires reciprocal link to sigra auth integration guide", %{content: content} do
      assert String.contains?(content, "sigra-auth-integration.md"),
             "sigra auth blueprint recipe must link to Phase 66 introduction guide"
    end
  end

  @mailglass_integration_guide Path.expand(
                                 "../../guides/introduction/mailglass-integration.md",
                                 __DIR__
                               )

  describe "mailglass integration guide doc contract (DOCS-06 / DOCS-07)" do
    setup do
      content = File.read!(@mailglass_integration_guide)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in mailglass integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "mailglass integration guide must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in mailglass integration guide", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "mailglass integration guide must not reference fictional Chimeway.Workflow"
    end

    test "requires Mailglass adapter for email channel (not Logger-only path)", %{
      content: content
    } do
      assert String.contains?(content, "Chimeway.Adapters.Mailglass"),
             "mailglass integration guide must document Chimeway.Adapters.Mailglass for email delivery"
    end

    test "couples clean-consumer repo guidance to the executable fixture topology", %{
      content: content
    } do
      topology = ArtifactConsumerFixture.mailglass_repo_topology()
      repo = inspect(topology.chimeway_repo)

      assert topology.ecto_repos == [topology.chimeway_repo]
      assert topology.chimeway_repo == topology.mailglass_repo
      assert topology.mailglass_repo == topology.active_repo
      assert topology.active_repo == topology.supervised_repo
      assert String.contains?(content, "config :artifact_consumer, ecto_repos: [#{repo}]")
      assert String.contains?(content, "config :chimeway, repo: #{repo}")
      assert String.contains?(content, "config :mailglass, repo: #{repo}")
      assert String.contains?(content, "included_applications: [:chimeway]")
      assert String.contains?(content, "without separately starting `Chimeway.Repo`")
      assert String.contains?(content, "Chimeway.Repo.put_dynamic_repo(#{repo})")
    end

    @mailglass_proof_required [
      "host-configured Ecto repo",
      "one consumer-owned `ArtifactConsumer.Repo`",
      "Fake recorded exactly one host-composed message",
      "successful `Chimeway.Adapters.Mailglass` attempt",
      "real provider acceptance",
      "sender/domain verification",
      "inbox placement/display",
      "production credentials",
      "provider callbacks",
      "live webhook feedback",
      "../recipes/mailglass-integration-blueprint.md"
    ]

    for required <- @mailglass_proof_required do
      test "requires Mailglass clean-consumer proof boundary: #{required}", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "mailglass integration guide must document #{unquote(required)} for the clean-consumer proof"
      end
    end

    @mailglass_proof_forbidden [
      "Fake recorded exactly one host-composed message and email delivered",
      "successful Chimeway.Adapters.Mailglass attempt means the email was delivered",
      "Hex consumers should run `mix verify.mailglass`",
      "run `mix verify.mailglass` after adding `{:chimeway"
    ]

    for forbidden <- @mailglass_proof_forbidden do
      test "forbids Mailglass proof overclaim: #{forbidden}", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "mailglass integration guide must not overclaim Fake proof or present maintainer commands to consumers"
      end
    end

    test "labels mix verify.mailglass as a repository-maintainer regression suite", %{
      content: content
    } do
      assert String.contains?(content, "repository-maintainer regression suite"),
             "mailglass integration guide must identify mix verify.mailglass as maintainer-only"
    end

    @mailglass_webhook_forbidden [
      ~s(process("mailglass"),
      "conn.params",
      "headers: headers",
      "inspect(reason)",
      "Map.new(conn.req_headers)"
    ]

    for forbidden <- @mailglass_webhook_forbidden do
      test "forbids #{forbidden} in mailglass integration guide webhook example", %{
        content: content
      } do
        refute String.contains?(content, unquote(forbidden)),
               "mailglass integration guide must not reference #{unquote(forbidden)} in webhook example"
      end
    end

    test "requires adapter module as first Webhooks.process/4 argument", %{content: content} do
      assert Regex.match?(
               ~r/Chimeway\.Webhooks\.process\(\s*(?:adapter_module|Chimeway\.Adapters\.Mailglass)/,
               content
             ),
             "mailglass integration guide must call Webhooks.process with adapter module, not string literal"
    end

    @required ~w(
      Chimeway.Adapters.Mailglass
      Chimeway.Adapter.Mailglass
      channel_adapters
      channel_adapter_configs
      render_key
      Chimeway.Webhooks.process
      conn.req_headers
      Mailglass.Mailable
      Chimeway.trigger
      tenant_id
      idempotency_key
      orchestrates
      templating
    )

    for required <- @required do
      test "requires #{required} in mailglass integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "mailglass integration guide must reference #{unquote(required)}"
      end
    end
  end

  @accrue_integration_guide Path.expand(
                              "../../guides/introduction/accrue-dunning-integration.md",
                              __DIR__
                            )

  describe "accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)" do
    setup do
      content = File.read!(@accrue_integration_guide)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in accrue dunning integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "accrue dunning integration guide must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in accrue dunning integration guide",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "accrue dunning integration guide must not reference fictional Chimeway.Workflow"
    end

    test "forbids payment_recovered in accrue dunning integration guide", %{content: content} do
      refute String.contains?(content, "payment_recovered"),
             "accrue dunning integration guide must use canonical invoice.paid Outcome Signal naming"
    end

    @required ~w(
      Accrue.Integrations.Chimeway
      invoice.payment_failed
      invoice.paid
      cancel_campaign
      Chimeway.Signal.track
      workflow/2
      config :accrue
      dunning
      idempotency_key
      tenant_id
      orchestrates
      mix verify.accrue
      DemoHost.Seeds.seed_accrue_dunning
      /admin/chimeway
      ACCRUE_PATH
    )

    for required <- @required do
      test "requires #{required} in accrue dunning integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "accrue dunning integration guide must reference #{unquote(required)}"
      end
    end

    test "requires billing-state split language in accrue dunning integration guide", %{
      content: content
    } do
      assert String.contains?(content, "billing")

      assert String.contains?(content, "state") or String.contains?(content, "Accrue"),
             "accrue dunning integration guide must document billing-state responsibility split"
    end

    test "requires dependencies section coverage in accrue dunning integration guide", %{
      content: content
    } do
      assert String.contains?(content, "chimeway") or String.contains?(content, "Chimeway"),
             "accrue dunning integration guide must document Chimeway dependency"

      assert String.contains?(content, "accrue") or String.contains?(content, "Accrue"),
             "accrue dunning integration guide must document Accrue dependency"
    end

    test "documents the package-executed clean-consumer proof contract", %{content: content} do
      assert String.contains?(
               content,
               "MIX_ENV=prod mix run scripts/prove-accrue-consumer.exs -- --artifact-archive <absolute-tarball> --sha256 <lowercase-64-hex>"
             )

      assert String.contains?(content, "trusted package or release channel")
      assert String.contains?(content, "immutable package archive and SHA-256")
      assert String.contains?(content, "package metadata")
      assert String.contains?(content, "runner verifies the archive")
      assert String.contains?(content, "unpacks into owned temporary storage")
      assert String.contains?(content, "isolated temporary host and database")
      assert String.contains?(content, "only `:chimeway` dependency")
      assert String.contains?(content, "runner and its support fixture are package members")
      assert String.contains?(content, "exactly one `CHIMEWAY_ACCRUE_PROOF` record")
      assert String.contains?(content, "exits nonzero without a proof record")
      assert String.contains?(content, "temporary host/database and archive-unpack storage")
      refute String.contains?(content, "--artifact-root")
      refute String.contains?(content, "already-unpacked Chimeway package")
      refute String.contains?(content, "verify.adoption_paths")
    end

    test "documents the public Accrue lifecycle without false completion semantics", %{content: content} do
      clean_consumer =
        content
        |> String.split("## Clean-consumer proof", parts: 2)
        |> List.last()
        |> String.split("## 6. Verification", parts: 2)
        |> List.first()

      lifecycle = [
        "invoice.payment_failed",
        "waiting / waiting_for_step_progression",
        "invoice.paid",
        "active / signal_received"
      ]

      indices =
        Enum.map(lifecycle, fn phrase ->
          case :binary.match(clean_consumer, phrase) do
            {index, _} -> index
            :nomatch -> flunk("accrue guide must document #{phrase}")
          end
        end)

      assert indices == Enum.sort(indices)

      assert String.contains?(content, "outcome signal ended the waiting escalation path")
      assert String.contains?(content, "does not mean the workflow completed")
    end

    test "keeps clean-consumer evidence to the fixed safe proof vocabulary", %{content: content} do
      assert String.contains?(content, "provenance=released_package accrue_version=1.3.0")
      assert String.contains?(content, "workflow_key=accrue.dunning workflow_version=1")
      assert String.contains?(content, "timeline_reasons=waiting_for_step_progression,signal_received")

      clean_consumer =
        content
        |> String.split("## Clean-consumer proof", parts: 2)
        |> List.last()
        |> String.split("## 6. Verification", parts: 2)
        |> List.first()

      for forbidden <- ["tenant_id=", "invoice_id=", "customer_id=", "recipient=", "payload=", "metadata=", "credential=", "Ecto.Query"] do
        refute String.contains?(clean_consumer, forbidden),
               "clean-consumer proof must not disclose #{forbidden}"
      end
    end

    test "conditions released-package proof on resolved Accrue source and module validation", %{
      content: content
    } do
      assert String.contains?(content, "released_package")
      assert String.contains?(content, "exact Accrue `1.3.0`")
      assert String.contains?(content, "`Accrue.Integrations.Chimeway`")
      assert String.contains?(content, "resolved Chimeway artifact version")
      assert String.contains?(content, "executable check, not optimistic prose")
      refute String.contains?(content, "Production adopters use `{:accrue, \"~> 1.3\"}` from Hex.")
    end

    test "limits the immutable Accrue SHA to compatibility evidence", %{content: content} do
      sha = "236fa2f1649e771f3b515603495436badeed3c7b"

      assert String.contains?(content, sha)
      assert String.contains?(content, "compatibility evidence only")
      assert String.contains?(content, "not released-package proof or installation guidance")

      sha_code_blocks =
        Regex.scan(~r/```[^`]*#{sha}[^`]*```/s, content)

      assert sha_code_blocks == [], "immutable compatibility SHA must not appear in a copyable code block"
      refute String.contains?(content, "git: #{sha}")
    end

    test "binds released-package and compatibility claims to the packaged CLI schemas", %{
      content: content
    } do
      release_section =
        content
        |> String.split("## 1. Dependencies", parts: 2)
        |> List.last()
        |> String.split("## 2. Database / migrations", parts: 2)
        |> List.first()

      compatibility_section =
        content
        |> String.split("### Provenance labels", parts: 2)
        |> List.last()
        |> String.split("## 6. Verification", parts: 2)
        |> List.first()

      sha = "236fa2f1649e771f3b515603495436badeed3c7b"

      for required <- [
            "released_package",
            "exact Accrue `1.3.0`",
            "resolved Hex metadata",
            "integration module origin",
            "exact Chimeway artifact version"
          ] do
        assert String.contains?(release_section, required),
               "released-package prose must require #{required}"
      end

      assert String.contains?(compatibility_section, sha)
      assert String.contains?(compatibility_section, "compatibility evidence only")
      assert String.contains?(compatibility_section, "not released-package proof")
      assert String.contains?(compatibility_section, "not installation guidance")

      for forbidden <- ["git: #{sha}", "{:accrue, git:", "mix deps.get #{sha}"] do
        refute String.contains?(content, forbidden),
               "compatibility SHA must not become dependency or installation guidance"
      end
    end

    test "keeps proof claims scoped to safe public evidence and maintainer mechanics", %{
      content: content
    } do
      clean_consumer =
        content
        |> String.split("## Clean-consumer proof", parts: 2)
        |> List.last()
        |> String.split("## 6. Verification", parts: 2)
        |> List.first()

      verification =
        content
        |> String.split("## 6. Verification", parts: 2)
        |> List.last()

      assert String.contains?(clean_consumer, "does not mean the workflow completed")
      assert String.contains?(clean_consumer, "does not mean the workflow entered a terminal state")
      refute String.contains?(clean_consumer, "unconditional `~> 1.3` proof")
      refute String.contains?(clean_consumer, "source/module presence without resolved metadata")

      for forbidden <- [
            "billing_id=",
            "recipient=",
            "tenant_id=",
            "payload=",
            "metadata=",
            "credential=",
            "raw_struct=",
            "Ecto.Query",
            "database inspection"
          ] do
        refute String.contains?(clean_consumer, forbidden),
               "clean-consumer proof must not disclose #{forbidden}"
      end

      for mechanic <- ["ACCRUE_PATH", "sibling checkout", "DemoHost", "CI checkout", "mix verify.accrue"] do
        assert String.contains?(verification, mechanic)
      end

      assert String.contains?(verification, "not independent packaged-consumer provenance")
      refute String.contains?(verification, "packaged proof")
    end

    test "labels maintainer checkout mechanics separately from proof provenance", %{content: content} do
      verification =
        content
        |> String.split("## 6. Verification", parts: 2)
        |> List.last()

      for mechanic <- ["ACCRUE_PATH", "sibling checkout", "CI checkout", "mix verify.accrue"] do
        assert String.contains?(verification, mechanic)
      end

      assert String.contains?(verification, "repository-maintainer regression mechanics")
      assert String.contains?(verification, "not independent packaged-consumer provenance")
    end

    test "sections appear in golden-path order from dependencies through verification", %{
      content: content
    } do
      headings = [
        "## 1. Dependencies",
        "## 2. Database / migrations",
        "## 3. Runtime config",
        "## 4. DunningNotifier reference",
        "## 5. Billing-event triggers",
        "## 6. Verification"
      ]

      indices =
        Enum.map(headings, fn heading ->
          case :binary.match(content, heading) do
            {index, _} -> index
            :nomatch -> flunk("accrue dunning integration guide must include #{heading}")
          end
        end)

      assert indices == Enum.sort(indices),
             "accrue dunning integration guide sections must appear in golden-path order"

      verify_index = Enum.at(indices, -1)
      verify_section = String.slice(content, verify_index, 800)

      assert String.contains?(verify_section, "mix verify.accrue"),
             "accrue dunning integration guide verification section must document mix verify.accrue"
    end
  end

  @inbox_integration_guide Path.expand("../../guides/introduction/inbox-integration.md", __DIR__)

  describe "inbox integration guide doc contract (DOCS-08 / DOCS-09)" do
    setup do
      content = File.read!(@inbox_integration_guide)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in inbox integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "inbox integration guide must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in inbox integration guide",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "inbox integration guide must not reference fictional Chimeway.Workflow"
    end

    test "forbids Chimeway.Inbox direct module calls in inbox integration guide",
         %{content: content} do
      refute String.contains?(content, "Chimeway.Inbox."),
             "inbox integration guide must use public Chimeway.* delegates only"
    end

    @required ~w(
      ChimewayInbox.Auth
      chimeway_inbox_routes
      config :chimeway_inbox
      auth_module
      Chimeway.unread_count
      Chimeway.list_for_recipient
      Chimeway.mark_read
      Chimeway.mark_seen
      BellDropdownLive
      mix verify.inbox
      DemoHost.Seeds.seed_inbox
      /inbox
    )

    for required <- @required do
      test "requires #{required} in inbox integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "inbox integration guide must reference #{unquote(required)}"
      end
    end

    test "requires golden-path section order in inbox integration guide", %{content: content} do
      headings = [
        "## 1. Dependencies",
        "## 2. Database / migrations",
        "## 3. Runtime config",
        "## 4. Auth behaviour",
        "## 5. Router mount",
        "## 6. Bell UI surface",
        "## 7. Headless API",
        "## 8. Verification"
      ]

      indices =
        for heading <- headings do
          case :binary.match(content, heading) do
            {index, _} -> index
            :nomatch -> flunk("inbox integration guide must include #{heading}")
          end
        end

      assert indices == Enum.sort(indices),
             "inbox integration guide sections must appear in golden-path order"
    end

    test "verification section documents mix verify.inbox in inbox integration guide",
         %{content: content} do
      verification_index =
        case :binary.match(content, "## 8. Verification") do
          {index, _} -> index
          :nomatch -> flunk("inbox integration guide must include verification section")
        end

      verification_tail =
        binary_part(content, verification_index, byte_size(content) - verification_index)

      assert String.contains?(verification_tail, "mix verify.inbox")
      assert String.contains?(verification_tail, "seed_inbox")
    end

    test "documents chimeway_inbox preview/path install status (TRUTH-03 / D-05)", %{
      content: content
    } do
      assert String.contains?(content, "in-repo preview/path package"),
             "inbox guide must state chimeway_inbox is an in-repo preview/path package"

      assert String.contains?(content, "not published on Hex yet"),
             "inbox guide must state chimeway_inbox is not published on Hex yet"
    end

    test "uses chimeway_inbox path dependency and preserves root Chimeway dep (D-05)", %{
      content: content
    } do
      assert String.contains?(content, ~s({:chimeway_inbox, path: "../chimeway_inbox"})),
             "inbox guide must keep the chimeway_inbox path dependency for preview usage"

      assert String.contains?(content, ~s({:chimeway, "~> 1.0"})),
             "inbox guide must preserve the root {:chimeway, \"~> 1.0\"} dependency"
    end

    test "forbids current-Hex chimeway_inbox install claim (D-06)", %{content: content} do
      refute String.contains?(content, ~s({:chimeway_inbox, "~> 1.0"})),
             "inbox guide must not present chimeway_inbox as a current Hex dependency"
    end

    test "chimeway_inbox/mix.exs remains path-package evidence, not a Hex package (D-05)" do
      mix = File.read!("chimeway_inbox/mix.exs")

      assert String.contains?(mix, "app: :chimeway_inbox"),
             "chimeway_inbox/mix.exs must declare app: :chimeway_inbox"

      assert String.contains?(mix, ~s(version: "0.1.0")),
             "chimeway_inbox/mix.exs must keep the preview version 0.1.0"

      assert String.contains?(mix, ~s({:chimeway, path: ".."})),
             "chimeway_inbox/mix.exs must depend on chimeway via a path dependency"

      refute String.contains?(mix, "package:"),
             "chimeway_inbox/mix.exs must not define Hex package metadata in Phase 78"

      refute String.contains?(mix, "docs:"),
             "chimeway_inbox/mix.exs must not define HexDocs metadata in Phase 78"
    end
  end

  @threadline_integration_guide Path.expand(
                                  "../../guides/introduction/threadline-integration.md",
                                  __DIR__
                                )

  describe "threadline integration guide doc contract (DOCS-10)" do
    setup do
      content = File.read!(@threadline_integration_guide)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in threadline integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "threadline integration guide must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in threadline integration guide",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "threadline integration guide must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      Chimeway.Telemetry.ThreadlineReporter
      attach/0
      config\ :chimeway
      correlation_id
      notification_suppressed
      DemoHost.Seeds.seed_threadline_notification
      /admin/chimeway
      mix\ verify.threadline
    )

    for required <- @required do
      test "requires #{required} in threadline integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "threadline integration guide must reference #{unquote(required)}"
      end
    end

    test "sections appear in golden-path order from dependencies through verification", %{
      content: content
    } do
      headings = [
        "## 1. Dependencies",
        "## 2. Attach reporter",
        "## 3. What gets recorded",
        "## 4. Verification"
      ]

      indices =
        for heading <- headings do
          case :binary.match(content, heading) do
            {index, _} -> index
            :nomatch -> flunk("threadline integration guide must include #{heading}")
          end
        end

      assert indices == Enum.sort(indices),
             "threadline integration guide sections must appear in golden-path order"
    end
  end

  @sigra_integration_guide Path.expand(
                             "../../guides/introduction/sigra-auth-integration.md",
                             __DIR__
                           )

  describe "sigra auth integration guide doc contract (DOCS-10)" do
    setup do
      content = File.read!(@sigra_integration_guide)
      %{content: content}
    end

    for forbidden <- @recipe_forbidden_strings do
      test "forbids #{forbidden} in sigra auth integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "sigra auth integration guide must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in sigra auth integration guide",
         %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "sigra auth integration guide must not reference fictional Chimeway.Workflow"
    end

    @sigra_forbidden ~w(:raw_token :magic_link_url)

    for forbidden <- @sigra_forbidden do
      test "forbids #{forbidden} in sigra auth integration guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "sigra auth integration guide must not reference #{unquote(forbidden)} in code examples"
      end
    end

    @sigra_invalid_patterns ["Chimeway.trigger(\"", "params:"]

    for forbidden <- @sigra_invalid_patterns do
      test "forbids invalid trigger shape #{forbidden} in sigra auth integration guide", %{
        content: content
      } do
        refute String.contains?(content, unquote(forbidden)),
               "sigra auth integration guide must not reference invalid shape #{unquote(forbidden)}"
      end
    end

    test "requires trigger example to pass a *Notifier module as first argument", %{
      content: content
    } do
      assert Regex.match?(
               ~r/Chimeway\.trigger\(\s*Sigra\.Integrations\.Chimeway\.\w*Notifier/,
               content
             ),
             "sigra auth integration guide must pass a Notifier module as first argument to Chimeway.trigger"
    end

    @required ~w(
      Sigra.Integrations.Chimeway
      sigra.auth.magic_link
      sigra.auth.confirmation_code
      Chimeway.trigger
      idempotency_key
      tenant_id
      DemoHost.Seeds.seed_sigra_auth
      /admin/chimeway
      mix\ verify.sigra
      SIGRA_PATH
      orchestrates
    )

    for required <- @required do
      test "requires #{required} in sigra auth integration guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "sigra auth integration guide must reference #{unquote(required)}"
      end
    end

    test "sections appear in golden-path order from dependencies through verification", %{
      content: content
    } do
      headings = [
        "## 1. Dependencies",
        "## 2. Integration seam",
        "## 3. Notifier reference",
        "## 4. Auth event triggers",
        "## 5. Verification"
      ]

      indices =
        for heading <- headings do
          case :binary.match(content, heading) do
            {index, _} -> index
            :nomatch -> flunk("sigra auth integration guide must include #{heading}")
          end
        end

      assert indices == Enum.sort(indices),
             "sigra auth integration guide sections must appear in golden-path order"
    end
  end

  @adoption_forbidden_strings ~w(
    stop_conditions
    Workflows.Workers
    Chimeway.Trigger.trigger
    resolve_recipients
  )

  @adoption_forbidden_phrases_golden_path ["mix chimeway.install"]
  @adoption_forbidden_phrases_installation ["mix chimeway.install"]
  @adoption_forbidden_phrases_readme ["mix chimeway.install"]

  @storage_prefix_required_strings [
    "prefix: \"chimeway\"",
    "prefix: false",
    "new isolated Chimeway schema",
    "existing public-schema legacy install",
    "unprefixed tables",
    "does not move data"
  ]

  @storage_prefix_forbidden_phrases [
    "--prefix",
    "automatic data move",
    "automatically move",
    "automatic public-to-chimeway",
    "Oban prefix",
    "oban prefix"
  ]

  @storage_prefix_upgrade_guide "guides/introduction/storage-prefix-upgrade.md"

  describe "storage prefix upgrade guide doc contract (UPG-02 / UPG-03 / DOCS-02)" do
    setup do
      content = File.read!(@storage_prefix_upgrade_guide)
      %{content: content}
    end

    @required_strings [
      "prefix: \"chimeway\"",
      "prefix: false",
      "public-schema legacy mode",
      "manual database operation",
      "verified database backup",
      "preflight checks",
      "transaction",
      "lock",
      "Verification Queries",
      "Rollback",
      "stop and restore",
      "mix chimeway.gen.migrations --prefix public",
      "does not move data",
      "does not create, move, or configure `oban_jobs`",
      "Oban.Migration.up(prefix: \"jobs\")",
      "Oban.Migration.down(prefix: \"jobs\")",
      "config :my_app, Oban"
    ]

    for required <- @required_strings do
      test "requires #{required} in storage prefix upgrade guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "storage prefix upgrade guide must reference #{unquote(required)}"
      end
    end

    @forbidden_strings [
      "@schema_prefix",
      "config :chimeway, prefix: \"public\"",
      "mix ecto.migrate --prefix chimeway",
      "search_path",
      "automatic public-to-chimeway",
      "automatically move"
    ]

    for forbidden <- @forbidden_strings do
      test "forbids #{forbidden} in storage prefix upgrade guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "storage prefix upgrade guide must not teach unsafe storage prefix form #{unquote(forbidden)}"
      end
    end

    test "forbids runtime prefix options on public Chimeway APIs", %{content: content} do
      refute Regex.match?(~r/Chimeway\.(?:trigger|mark_read|mark_seen)\([^)]*prefix:/s, content),
             "storage prefix guide must not teach per-call public API prefix options"
    end
  end

  @golden_path_guide "guides/introduction/golden-path.md"

  describe "golden path doc contract (DOCS-01 / GATE-01)" do
    setup do
      content = File.read!(@golden_path_guide)
      %{content: content}
    end

    for forbidden <- @adoption_forbidden_strings do
      test "forbids #{forbidden} in golden path guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "golden path guide must not reference #{unquote(forbidden)}"
      end
    end

    for phrase <- @adoption_forbidden_phrases_golden_path do
      test "forbids #{phrase} in golden path guide", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "golden path guide must not reference #{unquote(phrase)}"
      end
    end

    for phrase <- @storage_prefix_forbidden_phrases do
      test "forbids storage prefix drift phrase #{phrase} in golden path guide", %{
        content: content
      } do
        refute String.contains?(content, unquote(phrase)),
               "golden path guide must not reference #{unquote(phrase)}"
      end
    end

    test "forbids identity: (not recipient_identity:) in golden path guide", %{
      content: content
    } do
      refute Regex.match?(~r/(?<!recipient_)identity:/, content),
             "golden path guide must not reference identity: (recipient_identity: is permitted)"
    end

    test "forbids Chimeway.Workflow module (not Workflows) in golden path guide", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "golden path guide must not reference fictional Chimeway.Workflow"
    end

    # D-06: guard the canonicalized owner URLs so the golden-path fix cannot
    # silently regress (this guide is outside release_gate's package-facing file
    # list, so it was previously unguarded — RESEARCH Pitfall 4 / Open Q1).
    test "forbids the legacy jonlunsford owner URL in golden path guide", %{content: content} do
      refute String.contains?(content, "https://github.com/jonlunsford/chimeway"),
             "golden path guide must not reference the legacy jonlunsford owner GitHub URL"
    end

    @required ~w(
      mix chimeway.gen.migrations
      Chimeway.trigger
      idempotency_key
      tenant_id
      Chimeway.Traces.explain_delivery
      installation.md
    )

    for required <- @required do
      test "requires #{required} in golden path guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "golden path guide must reference #{unquote(required)}"
      end
    end

    for required <- @storage_prefix_required_strings do
      test "requires storage prefix phrase #{required} in golden path guide", %{
        content: content
      } do
        assert String.contains?(content, unquote(required)),
               "golden path guide must reference #{unquote(required)}"
      end
    end

    test "every Chimeway.trigger example includes idempotency_key and tenant_id", %{
      content: content
    } do
      triggers = Regex.scan(~r/Chimeway\.trigger\(/, content) |> length()
      idem = Regex.scan(~r/idempotency_key:/, content) |> length()
      tenant = Regex.scan(~r/tenant_id:/, content) |> length()

      assert triggers > 0

      assert triggers == idem,
             "expected idempotency_key on every trigger (got #{idem}/#{triggers})"

      assert triggers == tenant,
             "expected tenant_id on every trigger (got #{tenant}/#{triggers})"
    end
  end

  @installation_guide "guides/introduction/installation.md"

  describe "installation doc contract (GATE-01)" do
    setup do
      content = File.read!(@installation_guide)
      %{content: content}
    end

    for forbidden <- @adoption_forbidden_strings do
      test "forbids #{forbidden} in installation guide", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "installation guide must not reference #{unquote(forbidden)}"
      end
    end

    for phrase <- @adoption_forbidden_phrases_installation do
      test "forbids #{phrase} in installation guide", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "installation guide must not reference #{unquote(phrase)}"
      end
    end

    for phrase <- @storage_prefix_forbidden_phrases do
      test "forbids storage prefix drift phrase #{phrase} in installation guide", %{
        content: content
      } do
        refute String.contains?(content, unquote(phrase)),
               "installation guide must not reference #{unquote(phrase)}"
      end
    end

    test "forbids identity: in installation guide", %{content: content} do
      refute String.contains?(content, "identity:"),
             "installation guide must not reference identity:"
    end

    test "forbids Chimeway.Workflow module (not Workflows) in installation guide", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "installation guide must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      mix chimeway.gen.migrations
      Chimeway.Traces.explain_delivery
      golden-path
    )

    for required <- @required do
      test "requires #{required} in installation guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "installation guide must reference #{unquote(required)}"
      end
    end

    for required <- @storage_prefix_required_strings do
      test "requires storage prefix phrase #{required} in installation guide", %{
        content: content
      } do
        assert String.contains?(content, unquote(required)),
               "installation guide must reference #{unquote(required)}"
      end
    end
  end

  describe "README install doc contract (GATE-01)" do
    setup do
      content = File.read!("README.md")
      %{content: content}
    end

    for forbidden <- @adoption_forbidden_strings do
      test "forbids #{forbidden} in README", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "README must not reference #{unquote(forbidden)}"
      end
    end

    for phrase <- @adoption_forbidden_phrases_readme do
      test "forbids #{phrase} in README", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "README must not reference #{unquote(phrase)}"
      end
    end

    for phrase <- @storage_prefix_forbidden_phrases do
      test "forbids storage prefix drift phrase #{phrase} in README", %{content: content} do
        refute String.contains?(content, unquote(phrase)),
               "README must not reference #{unquote(phrase)}"
      end
    end

    test "forbids identity: in README", %{content: content} do
      refute String.contains?(content, "identity:"),
             "README must not reference identity:"
    end

    test "forbids Chimeway.Workflow module (not Workflows) in README", %{content: content} do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "README must not reference fictional Chimeway.Workflow"
    end

    @required ~w(
      mix chimeway.gen.migrations
      Chimeway.trigger
      idempotency_key
      tenant_id
      golden-path
      Chimeway.Traces.explain_delivery
      guides/introduction/mailglass-integration.md
      guides/introduction/accrue-dunning-integration.md
      guides/introduction/inbox-integration.md
    )

    for required <- @required do
      test "requires #{required} in README", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "README must reference #{unquote(required)}"
      end
    end

    for required <- @storage_prefix_required_strings do
      test "requires storage prefix phrase #{required} in README", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "README must reference #{unquote(required)}"
      end
    end

    # DOCS-14/15 decision-page markers (multi-word / heading phrases — explicit
    # string list, NOT ~w() which splits on whitespace). Byte-identical to the
    # packaged-README assertions in release_gate_contract_test.exs (marker-string
    # lockstep, D-07 <-> D-09).
    @readme_decision_markers [
      "local-first",
      "## When to use",
      "## Non-goals",
      "## Host-owned boundaries",
      "## Optional surfaces",
      "in-repo preview/path package",
      "not published on Hex yet"
    ]

    for marker <- @readme_decision_markers do
      test "requires decision-page marker #{marker} in README", %{content: content} do
        assert String.contains?(content, unquote(marker)),
               "README must reference decision-page marker #{unquote(marker)}"
      end
    end

    # DOCS-14/15 narrative-order gate (Success Criterion 1): the decision-markers above
    # assert each section is PRESENT; this asserts they appear in the coherent adoption
    # order value-prop -> When to use -> Non-goals -> Host-owned boundaries -> Optional
    # surfaces -> Installation -> Trigger to explainable trace. A reorder that breaks the
    # narrative passes the presence markers but fails here. Line-anchored (~r/^...$/m) so
    # only real headings match, not prose mentions.
    #
    # Note (Phase 85, INTEG-01): the README title is now rendered as a GitHub-native
    # brand lockup (<picture>/<img>), not a plain "# Chimeway" Markdown H1, so the
    # narrative-order gate starts at "## When to use". The lockup carries alt="Chimeway".
    @readme_section_order [
      "## When to use",
      "## Non-goals",
      "## Host-owned boundaries",
      "## Optional surfaces",
      "## Installation",
      "## Trigger to explainable trace"
    ]

    test "decision-page sections appear in narrative order", %{content: content} do
      offsets =
        Enum.map(@readme_section_order, fn heading ->
          case Regex.run(~r/^#{Regex.escape(heading)}$/m, content, return: :index) do
            [{start, _}] -> start
            _ -> flunk("README missing narrative section heading: #{heading}")
          end
        end)

      assert offsets == Enum.sort(offsets),
             "README decision-page sections must appear in narrative order: #{inspect(@readme_section_order)}"
    end

    # DOCS-16 per-trigger invariant (mirrored verbatim from the golden path block):
    # every Chimeway.trigger example must carry both required opts one-to-one.
    test "every Chimeway.trigger example includes idempotency_key and tenant_id", %{
      content: content
    } do
      triggers = Regex.scan(~r/Chimeway\.trigger\(/, content) |> length()
      idem = Regex.scan(~r/idempotency_key:/, content) |> length()
      tenant = Regex.scan(~r/tenant_id:/, content) |> length()

      assert triggers > 0

      assert triggers == idem,
             "expected idempotency_key on every trigger (got #{idem}/#{triggers})"

      assert triggers == tenant,
             "expected tenant_id on every trigger (got #{tenant}/#{triggers})"
    end

    # D-03: the Optional Surfaces copy must never claim a current-Hex install for
    # the sibling preview/path packages (mirrors the packaged-guide forbid at
    # release_gate_contract_test.exs:525-528).
    for sibling <- [~S({:chimeway_admin, "~> 1.0"}), ~S({:chimeway_inbox, "~> 1.0"})] do
      test "forbids current-Hex sibling install claim #{sibling} in README", %{content: content} do
        refute String.contains?(content, unquote(sibling)),
               "README must not claim a current-Hex install for a preview/path sibling package (#{unquote(sibling)})"
      end
    end
  end

  @oban_integration_recipe "guides/recipes/oban-integration.md"

  describe "oban integration doc contract (IN-01 / GATE-01)" do
    setup do
      content = File.read!(@oban_integration_recipe)
      %{content: content}
    end

    @forbidden_strings ~w(
      Workflows.Workers
      Chimeway.Trigger.trigger
      stop_conditions
    )

    for forbidden <- @forbidden_strings do
      test "forbids #{forbidden} in oban integration recipe", %{content: content} do
        refute String.contains?(content, unquote(forbidden)),
               "oban integration recipe must not reference #{unquote(forbidden)}"
      end
    end

    test "forbids Chimeway.Workflow module (not Workflows) in oban integration recipe", %{
      content: content
    } do
      refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
             "oban integration recipe must not reference fictional Chimeway.Workflow"
    end

    @required [
      "Chimeway.Dispatch.WorkflowProgressionWorker",
      "Chimeway.Dispatch.SignalRouterWorker",
      "chimeway_delivery",
      "chimeway_signals",
      "Oban.Migration.up(prefix: \"jobs\")",
      "Oban.Migration.down(prefix: \"jobs\")",
      "config :my_app, Oban",
      "prefix: \"jobs\"",
      "oban_jobs",
      "storage-prefix-upgrade.md"
    ]

    for required <- @required do
      test "requires #{required} in oban integration recipe", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "oban integration recipe must reference #{unquote(required)}"
      end
    end
  end

  describe "hexdocs extras doc contract" do
    setup do
      content = File.read!("mix.exs")
      %{content: content}
    end

    @integration_guides ~w(
      guides/introduction/storage-prefix-upgrade.md
      guides/introduction/mailglass-integration.md
      guides/introduction/accrue-dunning-integration.md
      guides/introduction/admin-console-integration.md
      guides/introduction/inbox-integration.md
      guides/introduction/threadline-integration.md
      guides/introduction/sigra-auth-integration.md
    )

    for guide <- @integration_guides do
      test "requires #{guide} in HexDocs extras", %{content: content} do
        assert String.contains?(content, unquote(guide)),
               "mix.exs HexDocs extras must include #{unquote(guide)}"
      end
    end

    test "lists storage prefix guide after golden path and before integration guides", %{
      content: content
    } do
      golden_path_index =
        case :binary.match(content, "guides/introduction/golden-path.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include golden path guide")
        end

      storage_index =
        case :binary.match(content, "guides/introduction/storage-prefix-upgrade.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include storage prefix upgrade guide")
        end

      mailglass_index =
        case :binary.match(content, "guides/introduction/mailglass-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include mailglass integration guide")
        end

      assert golden_path_index < storage_index,
             "HexDocs extras must list storage prefix guide after golden path"

      assert storage_index < mailglass_index,
             "HexDocs extras must list storage prefix guide before integration guides"
    end

    test "lists accrue integration guide after mailglass integration guide in extras", %{
      content: content
    } do
      mailglass_index =
        case :binary.match(content, "guides/introduction/mailglass-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include mailglass integration guide")
        end

      accrue_index =
        case :binary.match(content, "guides/introduction/accrue-dunning-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include accrue dunning integration guide")
        end

      assert mailglass_index < accrue_index,
             "HexDocs extras must list mailglass integration guide before accrue dunning integration guide"
    end

    test "lists admin integration guide after accrue dunning integration guide in extras", %{
      content: content
    } do
      accrue_index =
        case :binary.match(content, "guides/introduction/accrue-dunning-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include accrue dunning integration guide")
        end

      admin_index =
        case :binary.match(content, "guides/introduction/admin-console-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include admin integration guide")
        end

      assert accrue_index < admin_index,
             "HexDocs extras must list accrue dunning integration guide before admin integration guide"
    end

    test "lists inbox integration guide after admin integration guide in extras", %{
      content: content
    } do
      admin_index =
        case :binary.match(content, "guides/introduction/admin-console-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include admin integration guide")
        end

      inbox_index =
        case :binary.match(content, "guides/introduction/inbox-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include inbox integration guide")
        end

      assert admin_index < inbox_index,
             "HexDocs extras must list admin integration guide before inbox integration guide"
    end

    test "lists threadline integration guide after inbox integration guide in extras", %{
      content: content
    } do
      inbox_index =
        case :binary.match(content, "guides/introduction/inbox-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include inbox integration guide")
        end

      threadline_index =
        case :binary.match(content, "guides/introduction/threadline-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include threadline integration guide")
        end

      assert inbox_index < threadline_index,
             "HexDocs extras must list inbox integration guide before threadline integration guide"
    end

    test "lists sigra integration guide after threadline integration guide in extras", %{
      content: content
    } do
      threadline_index =
        case :binary.match(content, "guides/introduction/threadline-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include threadline integration guide")
        end

      sigra_index =
        case :binary.match(content, "guides/introduction/sigra-auth-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include sigra integration guide")
        end

      assert threadline_index < sigra_index,
             "HexDocs extras must list threadline integration guide before sigra integration guide"
    end
  end

  describe "consumer version alignment (DOCS-02 / GATE-01)" do
    @consumer_files ~w(
      README.md
      guides/introduction/installation.md
      guides/introduction/golden-path.md
    )

    test "mix.exs @version aligns with ~> MAJOR.MINOR in consumer docs" do
      mix_content = File.read!("mix.exs")
      [_, version] = Regex.run(~r/@version "([^"]+)"/, mix_content)
      [major, minor, _patch] = String.split(version, ".")
      expected = "{:chimeway, \"~> #{major}.#{minor}\"}"

      for path <- @consumer_files do
        content = File.read!(path)

        assert String.contains?(content, expected),
               "#{path} must include #{expected} aligned with mix.exs @version #{version}"
      end
    end

    test "forbids stale version drift in consumer docs" do
      mix_content = File.read!("mix.exs")
      [_, version] = Regex.run(~r/@version "([^"]+)"/, mix_content)
      [major, minor, _patch] = String.split(version, ".")

      stale_patterns = stale_drift_patterns(major, minor)

      for path <- @consumer_files do
        content = File.read!(path)

        for pattern <- stale_patterns do
          refute String.contains?(content, pattern),
                 "#{path} must not contain stale drift pattern #{inspect(pattern)}"
        end

        refute Regex.match?(~r/\{:chimeway,\s*"~>\s*\d+\.\d+\.\d+"/, content),
               "#{path} must use ~> MAJOR.MINOR, not a patch-level constraint"
      end
    end
  end

  defp stale_drift_patterns("1", "0"),
    do: ["{:chimeway, \"~> 0.1\"}", "0.1.0", ~s({:chimeway, "~> 0.)]

  defp stale_drift_patterns("0", _minor),
    do: ["{:chimeway, \"~> 1.0\"}", "1.0.0", ~s({:chimeway, "~> 1.)]

  defp stale_drift_patterns(major, minor) do
    prev_major = major |> String.to_integer() |> Kernel.-(1)

    if prev_major >= 0 do
      ["{:chimeway, \"~> #{prev_major}.#{minor}\"}", ~s({:chimeway, "~> #{prev_major}.)]
    else
      []
    end
  end
end
