defmodule Chimeway.Trigger do
  @moduledoc """
  Orchestrates notifier triggering with deterministic recipient normalization.
  """

  alias Chimeway.Notifier

  @spec trigger(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def trigger(notifier, params, opts \\ []) do
    with {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
         :ok <- validate_idempotency_key(idempotency_key),
         :ok <- Notifier.validate_module!(notifier),
         {:ok, recipients} <- notifier.recipients(params) do
      {:ok,
       %{
         notification_key: notifier.notification_key(),
         notification_version: notifier.version(),
         idempotency_key: idempotency_key,
         recipients: normalize_recipients(recipients)
       }}
    else
      :error -> {:error, :missing_idempotency_key}
      {:error, _reason} = error -> error
    end
  end

  @spec normalize_recipients([map()]) :: [map()]
  def normalize_recipients(recipients) when is_list(recipients) do
    recipients
    |> Enum.reduce(%{}, fn recipient, acc ->
      case recipient_identity(recipient) do
        identity when is_binary(identity) and byte_size(identity) > 0 ->
          Map.put_new(acc, identity, recipient)

        _identity ->
          acc
      end
    end)
    |> Enum.sort_by(fn {identity, _recipient} -> identity end)
    |> Enum.map(fn {_identity, recipient} -> recipient end)
  end

  defp validate_idempotency_key(idempotency_key) when is_binary(idempotency_key) do
    if String.trim(idempotency_key) == "" do
      {:error, :blank_idempotency_key}
    else
      :ok
    end
  end

  defp validate_idempotency_key(_idempotency_key), do: {:error, :invalid_idempotency_key}

  defp recipient_identity(%{recipient_identity: identity}), do: identity
  defp recipient_identity(%{"recipient_identity" => identity}), do: identity
  defp recipient_identity(_recipient), do: nil
end
