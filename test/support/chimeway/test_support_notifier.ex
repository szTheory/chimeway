defmodule Chimeway.Test.SupportNotifier do
  @behaviour Chimeway.Notifier

  def notification_key, do: "test_support_notifier"
  def version, do: 1

  def recipients(%{user_id: user_id}),
    do: {:ok, [%{recipient_identity: "user:#{user_id}", recipient_type: "user"}]}

  def build(_params, _recipient), do: {:ok, %{}}
end
