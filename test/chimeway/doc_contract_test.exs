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
    )

    @forbidden_phrases [
      "type: :wait"
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
    )

    for required <- @required do
      test "requires #{required} in journey guide", %{content: content} do
        assert String.contains?(content, unquote(required)),
               "guides/flows/multi-step-journeys.md must reference #{unquote(required)}"
      end
    end

    test "includes Deferred or READ milestone callout", %{content: content} do
      assert String.match?(content, ~r/Deferred|READ-0/),
             "journey guide must defer aspirational read-to-cancel behavior"
    end
  end

  @password_reset_recipe "guides/recipes/password-reset-support-trace.md"
  @feedback_recipe "guides/recipes/feedback-escalation-workflow.md"

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
