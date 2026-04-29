defmodule Chimeway.NotifierContractTest do
  use ExUnit.Case, async: true

  alias Chimeway.{Notifier, Rendering}

  defmodule ValidNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  end

  defmodule DigestNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "comment.digest"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def orchestration(_params, _recipient), do: {:ok, [email: :digest]}
  end

  defmodule RenderingNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 2

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{legacy_recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:in_app, :email]}

    @impl true
    def rendering(params, recipient) do
      {:ok,
       %{
         assigns: %{"comment_id" => params.comment_id, "recipient" => recipient.recipient_identity},
         channels: %{
           in_app: %{render_key: "comment.created.in_app", render_version: 3},
           email: %{render_key: "comment.created.email", render_version: 4}
         }
       }}
    end
  end

  defmodule LegacyBuildNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "legacy.build"

    @impl true
    def version, do: 7

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(params, recipient), do: {:ok, %{post_id: params.post_id, recipient: recipient.recipient_identity}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}
  end

  defmodule InvalidRenderingNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "invalid.rendering"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def channels(_params, _recipient), do: {:ok, [:email]}

    @impl true
    def rendering(_params, _recipient),
      do: {:ok, %{assigns: %{}, channels: %{" " => %{render_key: " ", render_version: 0}}}}
  end

  defmodule WorkflowNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "comment.escalation"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "comment.escalation",
         workflow_version: 3,
         steps: [
           %{step_key: "email", step_order: 2, channel: :email, config: %{"delay_minutes" => 30}},
           %{step_key: "in_app", step_order: 1, channel: "in_app", config: %{}}
         ]
       }}
    end
  end

  defmodule InvalidWorkflowNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "workflow.invalid"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "",
         workflow_version: 0,
         steps: [
           %{step_key: "dup", step_order: 1, channel: :email, config: %{}},
           %{step_key: "dup", step_order: 1, channel: "", config: %{}}
         ]
       }}
    end
  end

  defmodule InvalidWorkflowShapeNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "workflow.invalid_shape"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def workflow(_params, _recipient), do: {:ok, %{workflow_key: "shape.only"}}
  end

  defmodule ProgressWorkflowNotifier do
    @behaviour Notifier

    @impl true
    def notification_key, do: "comment.progress"

    @impl true
    def version, do: 1

    @impl true
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}

    @impl true
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}

    @impl true
    def workflow(_params, _recipient) do
      {:ok,
       %{
         workflow_key: "comment.progress",
         workflow_version: 1,
         steps: [
           %{
             step_key: "in_app",
             step_order: 1,
             channel: "in_app",
             config: %{
               "progress" => [
                 %{
                   "kind" => "wait_until",
                   "anchor" => "prior_delivery_terminal_at",
                   "delay_seconds" => 1800,
                   "to_step" => "email"
                 },
                 %{
                   "kind" => "on_outcome",
                   "outcome" => "bounced",
                   "to_step" => "sms"
                 }
               ]
             }
           },
           %{step_key: "email", step_order: 2, channel: "email", config: %{}},
           %{step_key: "sms", step_order: 3, channel: "sms", config: %{}}
         ]
       }}
    end
  end

  defmodule MissingNotificationKey do
    def version, do: 1
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  end

  defmodule MissingVersion do
    def notification_key, do: "comment.created"
    def recipients(_params), do: {:ok, [%{recipient_identity: "user-1"}]}
    def build(_params, recipient), do: {:ok, %{recipient: recipient}}
  end

  test "accepts a valid notifier module" do
    assert :ok = Notifier.validate_module!(ValidNotifier)
  end

  test "keeps existing notifiers valid when orchestration callback is absent" do
    assert {:ok, %{default: :immediate, channels: %{}}} =
             Notifier.resolve_orchestration(ValidNotifier, %{}, %{})
  end

  test "normalizes optional orchestration declarations for digest participation" do
    assert {:ok, %{default: :immediate, channels: %{"email" => :digest_held}}} =
             Notifier.resolve_orchestration(DigestNotifier, %{}, %{})
  end

  test "returns tagged error for missing notification_key callback" do
    assert {:error, :missing_notification_key_callback} =
             Notifier.validate_module!(MissingNotificationKey)
  end

  test "returns tagged error for missing version callback" do
    assert {:error, :missing_version_callback} =
             Notifier.validate_module!(MissingVersion)
  end

  test "normalizes explicit rendering declarations with assigns and per-channel identity" do
    assert {:ok,
            %{
              assigns: %{"comment_id" => 42, "recipient" => "user-1"},
              channels: %{
                "email" => %{render_key: "comment.created.email", render_version: 4},
                "in_app" => %{render_key: "comment.created.in_app", render_version: 3}
              },
              source: :notifier
            }} =
             Rendering.resolve_declaration(RenderingNotifier, %{comment_id: 42}, %{
               recipient_identity: "user-1"
             })
  end

  test "falls back to build/2 for notifiers without rendering/2" do
    assert {:ok,
            %{
              assigns: %{post_id: 99, recipient: "user-1"},
              channels: %{
                "email" => %{render_key: "legacy.build.email", render_version: 7}
              },
              source: :build_fallback
            }} =
             Rendering.resolve_declaration(LegacyBuildNotifier, %{post_id: 99}, %{
               recipient_identity: "user-1"
             })
  end

  test "returns tagged normalization errors for blank render keys, invalid channels, and non-positive versions" do
    assert {:error, {:rendering_resolution_failed, {:invalid_rendering_channel, " "}}} =
             Rendering.resolve_declaration(InvalidRenderingNotifier, %{}, %{
               recipient_identity: "user-1"
             })

    assert {:error, {:rendering_resolution_failed, {:blank_render_key, "email"}}} =
             Rendering.normalize_declaration(%{
               assigns: %{},
               channels: %{email: %{render_key: " ", render_version: 1}}
             })

    assert {:error, {:rendering_resolution_failed, {:invalid_render_version, "email", 0}}} =
             Rendering.normalize_declaration(%{
               assigns: %{},
               channels: %{email: %{render_key: "comment.created.email", render_version: 0}}
             })
  end

  test "normalizes workflow declarations into durable identity and ordered steps" do
    assert {:ok,
            %{
              workflow_key: "comment.escalation",
              workflow_version: 3,
              source: :notifier,
              steps: [
                %{
                  step_key: "in_app",
                  step_order: 1,
                  channel: "in_app",
                  config: %{}
                },
                %{
                  step_key: "email",
                  step_order: 2,
                  channel: "email",
                  config: %{"delay_minutes" => 30}
                }
              ]
            }} = Notifier.resolve_workflow(WorkflowNotifier, %{}, %{recipient_identity: "user-1"})
  end

  test "rejects invalid workflow declarations with tagged errors" do
    assert {:error, {:workflow_resolution_failed, {:blank_workflow_key, ""}}} =
             Notifier.resolve_workflow(InvalidWorkflowNotifier, %{}, %{recipient_identity: "user-1"})

    assert {:error, {:workflow_resolution_failed, {:invalid_workflow_version, 0}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.escalation",
               workflow_version: 0,
               steps: [%{step_key: "email", step_order: 1, channel: "email", config: %{}}]
             })

    assert {:error, {:workflow_resolution_failed, {:duplicate_workflow_step_key, "email"}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.escalation",
               workflow_version: 1,
               steps: [
                 %{step_key: "email", step_order: 1, channel: "email", config: %{}},
                 %{step_key: "email", step_order: 2, channel: "in_app", config: %{}}
               ]
             })

    assert {:error, {:workflow_resolution_failed, {:duplicate_workflow_step_order, 1}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.escalation",
               workflow_version: 1,
               steps: [
                 %{step_key: "email", step_order: 1, channel: "email", config: %{}},
                 %{step_key: "in_app", step_order: 1, channel: "in_app", config: %{}}
               ]
             })

    assert {:error, {:workflow_resolution_failed, {:invalid_workflow_channel, ""}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.escalation",
               workflow_version: 1,
               steps: [%{step_key: "email", step_order: 1, channel: "", config: %{}}]
             })

    assert {:error, {:workflow_resolution_failed, {:invalid_workflow_step_order, 3}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.escalation",
               workflow_version: 1,
               steps: [%{step_key: "email", step_order: 3, channel: "email", config: %{}}]
             })

    assert {:error, {:workflow_resolution_failed, {:invalid_workflow_declaration, %{workflow_key: "shape.only"}}}} =
             Notifier.resolve_workflow(InvalidWorkflowShapeNotifier, %{}, %{recipient_identity: "user-1"})
  end

  test "normalizes step progress rules with string-keyed wait_until and on_outcome shapes" do
    assert {:ok, workflow} =
             Notifier.resolve_workflow(ProgressWorkflowNotifier, %{}, %{
               recipient_identity: "user-1"
             })

    [in_app_step, _email_step, _sms_step] = workflow.steps
    assert in_app_step.step_key == "in_app"

    progress = Map.fetch!(in_app_step.config, "progress")

    assert [
             %{
               "kind" => "wait_until",
               "anchor" => "prior_delivery_terminal_at",
               "delay_seconds" => 1800,
               "to_step" => "email"
             },
             %{
               "kind" => "on_outcome",
               "outcome" => "bounced",
               "to_step" => "sms"
             }
           ] = progress

    serialized = Notifier.serialize_workflow(workflow)

    [serialized_in_app, _serialized_email, _serialized_sms] = serialized["steps"]

    assert [
             %{
               "kind" => "wait_until",
               "anchor" => "prior_delivery_terminal_at",
               "delay_seconds" => 1800,
               "to_step" => "email"
             },
             %{
               "kind" => "on_outcome",
               "outcome" => "bounced",
               "to_step" => "sms"
             }
           ] = serialized_in_app["config"]["progress"]
  end

  test "rejects invalid step progress rule shapes with tagged errors" do
    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:invalid_anchor, "comment_created_at"}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{
                         "kind" => "wait_until",
                         "anchor" => "comment_created_at",
                         "delay_seconds" => 60,
                         "to_step" => "email"
                       }
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })

    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:invalid_outcome, "delayed"}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{"kind" => "on_outcome", "outcome" => "delayed", "to_step" => "email"}
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })

    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:blank_to_step, ""}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{"kind" => "on_outcome", "outcome" => "delivered", "to_step" => ""}
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })

    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:mixed_rule_shape, _}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{
                         "kind" => "wait_until",
                         "anchor" => "prior_delivery_terminal_at",
                         "delay_seconds" => 60,
                         "to_step" => "email",
                         "outcome" => "delivered"
                       }
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })

    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:unknown_rule_kind, "after_minutes"}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{"kind" => "after_minutes", "to_step" => "email"}
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })

    assert {:error,
            {:workflow_resolution_failed,
             {:invalid_workflow_progress_rule, {:invalid_delay_seconds, 0}}}} =
             Notifier.normalize_workflow_declaration(%{
               workflow_key: "comment.progress",
               workflow_version: 1,
               steps: [
                 %{
                   step_key: "in_app",
                   step_order: 1,
                   channel: "in_app",
                   config: %{
                     "progress" => [
                       %{
                         "kind" => "wait_until",
                         "anchor" => "prior_delivery_terminal_at",
                         "delay_seconds" => 0,
                         "to_step" => "email"
                       }
                     ]
                   }
                 },
                 %{step_key: "email", step_order: 2, channel: "email", config: %{}}
               ]
             })
  end

  test "serializes workflow declarations into durable string-keyed data and rebuilds overrides without callback re-entry" do
    assert {:ok, workflow} =
             Notifier.resolve_workflow(WorkflowNotifier, %{}, %{recipient_identity: "user-1"})

    assert %{
             "workflow_key" => "comment.escalation",
             "workflow_version" => 3,
             "source" => "notifier",
             "steps" => [
               %{
                 "step_key" => "in_app",
                 "step_order" => 1,
                 "channel" => "in_app",
                 "config" => %{}
               },
               %{
                 "step_key" => "email",
                 "step_order" => 2,
                 "channel" => "email",
                 "config" => %{"delay_minutes" => 30}
               }
             ]
           } = serialized = Notifier.serialize_workflow(workflow)

    assert {:ok, ^workflow} = Notifier.resolve_workflow(nil, %{}, %{}, serialized)
  end
end
