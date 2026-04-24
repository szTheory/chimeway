defmodule Chimeway.Trigger do
  @moduledoc """
  Orchestrates notifier triggering with deterministic recipient normalization.
  """

  alias Chimeway.Events.Event
  alias Chimeway.Notifier
  alias Chimeway.Repo

  @sensitive_keys ~w(password token secret)

  @spec trigger(module(), map(), keyword()) :: {:ok, map()} | {:duplicate, struct()} | {:error, term()}
  def trigger(notifier, params, opts \\ []) do
    with {:ok, idempotency_key} <- Keyword.fetch(opts, :idempotency_key),
         :ok <- validate_idempotency_key(idempotency_key),
         :ok <- Notifier.validate_module!(notifier),
         {:ok, recipients} <- notifier.recipients(params) do
      normalized_recipients = normalize_recipients(recipients)

      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :event,
        Event.changeset(%Event{}, %{
          notification_key: notifier.notification_key(),
          notification_version: notifier.version(),
          idempotency_key: idempotency_key,
          payload: sanitize_payload(params)
        })
      )
      |> Ecto.Multi.run(:notifications, fn repo, %{event: event} ->
        insert_notifications(repo, notifier, params, event, normalized_recipients)
      end)
      |> Repo.transaction()
      |> normalize_trigger_result(idempotency_key, normalized_recipients)
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

  defp insert_notifications(repo, notifier, params, event, recipients) do
    with {:ok, notifications_attrs} <- notifications_attrs(notifier, params, event, recipients) do
      try do
        {count, _rows} = repo.insert_all("chimeway_notifications", notifications_attrs)
        {:ok, count}
      rescue
        error -> {:error, error}
      end
    end
  end

  defp notifications_attrs(notifier, params, event, recipients) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    recipients
    |> Enum.reduce_while({:ok, []}, fn recipient, {:ok, acc} ->
      with {:ok, metadata} <- notifier.build(params, recipient) do
        row = %{
          id: Ecto.UUID.generate() |> Ecto.UUID.dump!(),
          event_id: Ecto.UUID.dump!(event.id),
          recipient_identity: recipient_identity(recipient),
          recipient_type: recipient_type(recipient),
          metadata: sanitize_metadata(metadata),
          inserted_at: timestamp,
          updated_at: timestamp
        }

        {:cont, {:ok, [row | acc]}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_trigger_result(
         {:ok, %{event: event, notifications: notifications_inserted}},
         _idempotency_key,
         recipients
       ) do
    {:ok,
     %{
       event: event,
       notification_key: event.notification_key,
       notification_version: event.notification_version,
       idempotency_key: event.idempotency_key,
       recipients: recipients,
       notifications_inserted: notifications_inserted
     }}
  end

  defp normalize_trigger_result(
         {:error, :event, %Ecto.Changeset{} = changeset, _changes},
         idempotency_key,
         _recipients
       ) do
    if idempotency_conflict?(changeset) do
      case Repo.get_by(Event, idempotency_key: idempotency_key) do
        nil -> {:error, :duplicate_event_not_found}
        existing_event -> {:duplicate, existing_event}
      end
    else
      {:error, {:event_insert_failed, changeset}}
    end
  end

  defp normalize_trigger_result({:error, :notifications, reason, _changes}, _idempotency_key, _recipients) do
    {:error, {:notifications_insert_failed, reason}}
  end

  defp idempotency_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:idempotency_key, {_message, opts}} ->
        opts[:constraint] == :unique and
          opts[:constraint_name] in [
            :chimeway_events_idempotency_key_index,
            "chimeway_events_idempotency_key_index"
          ]

      _ ->
        false
    end)
  end

  defp sanitize_payload(payload), do: sanitize_map(payload)

  defp sanitize_metadata(metadata), do: sanitize_map(metadata)

  defp sanitize_map(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      if sensitive_key?(key) do
        acc
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp sanitize_map(_not_map), do: %{}

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))
  defp sensitive_key?(key) when is_binary(key), do: String.downcase(key) in @sensitive_keys
  defp sensitive_key?(_key), do: false

  defp recipient_identity(%{recipient_identity: identity}), do: identity
  defp recipient_identity(%{"recipient_identity" => identity}), do: identity
  defp recipient_identity(_recipient), do: nil

  defp recipient_type(%{recipient_type: recipient_type}), do: normalize_recipient_type(recipient_type)
  defp recipient_type(%{"recipient_type" => recipient_type}), do: normalize_recipient_type(recipient_type)
  defp recipient_type(%{channel: recipient_type}), do: normalize_recipient_type(recipient_type)
  defp recipient_type(%{"channel" => recipient_type}), do: normalize_recipient_type(recipient_type)
  defp recipient_type(_recipient), do: nil

  defp normalize_recipient_type(type) when is_binary(type), do: type
  defp normalize_recipient_type(type) when is_atom(type), do: Atom.to_string(type)
  defp normalize_recipient_type(_type), do: nil
end
