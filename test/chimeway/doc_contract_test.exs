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
end
