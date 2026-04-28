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
end
