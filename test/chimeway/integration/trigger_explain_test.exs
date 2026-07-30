defmodule Chimeway.TriggerExplainTest do
  use Chimeway.DataCase, async: true

  import Ecto.Query

  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Signals.Signal
  alias Chimeway.Trigger
  alias Chimeway.Workflows
  alias Chimeway.Workflows.WorkflowRun

  defmodule ExplainWorkflowNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "trigger.explain.workflow"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params) do
      {:ok, [%{recipient_identity: "user:explain", recipient_type: "user"}]}
    end

    @impl true
    def build(_params, _recipient) do
      {:ok,
       %{
         "subject" => "workflow",
         "html_body" => "workflow",
         "text_body" => "workflow"
       }}
    end

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "trigger.explain.workflow",
         workflow_version: 1,
         steps: [
           %{
             step_key: "email-first",
             step_order: 1,
             channel: :email,
             config: %{"template" => "first"}
           }
         ]
       }}
    end
  end

  test "trigger-created workflow runs explain within the supplied tenant boundary" do
    assert {:ok, result} =
             Trigger.trigger(ExplainWorkflowNotifier, %{},
               idempotency_key: "trigger-explain-1",
               tenant_id: "acme"
             )

    notification =
      Repo.one!(
        from(n in Notification,
          where: n.event_id == ^result.event.id
        )
      )

    run =
      Repo.one!(
        from(wr in WorkflowRun,
          where: wr.notification_id == ^notification.id
        )
      )

    assert run.tenant_id == "acme"
    assert {:ok, explanation} = Workflows.explain("acme", run.id)
    assert explanation.id == run.id
    assert explanation.tenant_id == "acme"
    assert {:error, :not_found} = Workflows.explain("other_tenant", run.id)
  end

  test "route_signal/1 resumes a trigger-created run only within its tenant" do
    assert {:ok, result} =
             Trigger.trigger(ExplainWorkflowNotifier, %{},
               idempotency_key: "trigger-explain-3",
               tenant_id: "acme"
             )

    notification =
      Repo.one!(
        from(n in Notification,
          where: n.event_id == ^result.event.id
        )
      )

    run =
      Repo.one!(
        from(wr in WorkflowRun,
          where: wr.notification_id == ^notification.id
        )
      )

    assert {:ok, waiting_run} =
             Workflows.update_run(Repo, run, %{
               state: :waiting,
               pending_signals: ["email_opened"],
               status_reason: "waiting_for_signal"
             })

    signal =
      Repo.insert!(
        Signal.changeset(%Signal{}, %{
          tenant_id: "acme",
          actor_id: "user:explain",
          event_name: "email_opened",
          payload: %{}
        })
      )

    assert {:ok, results} = Workflows.route_signal(signal)
    assert Map.has_key?(results, {:run_updated, waiting_run.id})

    resumed_run = Repo.get!(WorkflowRun, waiting_run.id)
    assert resumed_run.tenant_id == "acme"
    assert resumed_run.state == :active
    assert resumed_run.pending_signals == []
    assert resumed_run.status_reason == "signal_received"
    assert {:error, :not_found} = Workflows.explain("other_tenant", resumed_run.id)
  end

  test "trigger/3 returns missing_tenant_id when tenant_id is omitted" do
    assert {:error, :missing_tenant_id} =
             Trigger.trigger(ExplainWorkflowNotifier, %{}, idempotency_key: "trigger-explain-2")
  end
end
