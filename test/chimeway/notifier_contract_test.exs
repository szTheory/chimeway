defmodule Chimeway.NotifierContractTest do
  use ExUnit.Case, async: true

  alias Chimeway.Notifier

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

  test "returns tagged error for missing notification_key callback" do
    assert {:error, :missing_notification_key_callback} =
             Notifier.validate_module!(MissingNotificationKey)
  end

  test "returns tagged error for missing version callback" do
    assert {:error, :missing_version_callback} =
             Notifier.validate_module!(MissingVersion)
  end
end
