defmodule Chimeway.DocContractTest do
  use ExUnit.Case, async: true

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

  @mailglass_blueprint_recipe Path.expand("../../guides/recipes/mailglass-integration-blueprint.md", __DIR__)

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

  @accrue_blueprint_recipe Path.expand("../../guides/recipes/accrue-dunning-blueprint.md", __DIR__)

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

  @mailglass_integration_guide Path.expand("../../guides/introduction/mailglass-integration.md", __DIR__)

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

    test "requires Mailglass adapter for email channel (not Logger-only path)", %{content: content} do
      assert String.contains?(content, "Chimeway.Adapters.Mailglass"),
             "mailglass integration guide must document Chimeway.Adapters.Mailglass for email delivery"
    end

    @mailglass_webhook_forbidden [
      ~s(process("mailglass"),
      "conn.params",
      "headers: headers",
      "inspect(reason)",
      "Map.new(conn.req_headers)"
    ]

    for forbidden <- @mailglass_webhook_forbidden do
      test "forbids #{forbidden} in mailglass integration guide webhook example", %{content: content} do
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

  @accrue_integration_guide Path.expand("../../guides/introduction/accrue-dunning-integration.md", __DIR__)

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

      verification_tail = binary_part(content, verification_index, byte_size(content) - verification_index)
      assert String.contains?(verification_tail, "mix verify.inbox")
      assert String.contains?(verification_tail, "seed_inbox")
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

    @required ~w(
      Chimeway.Dispatch.WorkflowProgressionWorker
      Chimeway.Dispatch.SignalRouterWorker
      chimeway_delivery
      chimeway_signals
    )

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
      guides/introduction/mailglass-integration.md
      guides/introduction/accrue-dunning-integration.md
      guides/introduction/inbox-integration.md
    )

    for guide <- @integration_guides do
      test "requires #{guide} in HexDocs extras", %{content: content} do
        assert String.contains?(content, unquote(guide)),
               "mix.exs HexDocs extras must include #{unquote(guide)}"
      end
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

    test "lists inbox integration guide after accrue dunning integration guide in extras", %{
      content: content
    } do
      accrue_index =
        case :binary.match(content, "guides/introduction/accrue-dunning-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include accrue dunning integration guide")
        end

      inbox_index =
        case :binary.match(content, "guides/introduction/inbox-integration.md") do
          {index, _} -> index
          :nomatch -> flunk("mix.exs extras must include inbox integration guide")
        end

      assert accrue_index < inbox_index,
             "HexDocs extras must list accrue dunning integration guide before inbox integration guide"
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
