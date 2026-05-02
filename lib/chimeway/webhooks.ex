defmodule Chimeway.Webhooks do
  @moduledoc """
  Pure function boundary for synchronously ingesting and verifying inbound webhooks.

  Success returns ONLY when the ingress row and the ProcessFeedbackWorker job
  have both committed in a single transaction. Returning `{:ok, ingress}` is
  the host's acknowledgment cue — the host MAY return 2xx to the provider
  (Phase 33 D-03). Any error tuple means the host MUST return non-2xx so the
  provider retries.

  Unauthorized signature failures and unparseable bodies do NOT create a
  durable ingress row (Phase 33 D-09). Only verified, parsed, normalized
  callbacks enter the durable inbound lifecycle.
  """

  alias Chimeway.Repo
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}
  alias Ecto.Multi

  @spec process(module(), binary(), list(), keyword()) ::
          {:ok, Ingress.t()}
          | {:error, :unauthorized}
          | {:error, :unparseable_body}
          | {:error, :unresolvable_delivery}
          | {:error, :unnormalizable_feedback}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def process(adapter_module, raw_body, headers, config) do
    with :ok <- adapter_module.verify_webhook(raw_body, headers, config),
         {:ok, parsed} <- decode_body(raw_body),
         {:ok, delivery_info} <- resolve_delivery(adapter_module, parsed),
         {:ok, feedback_info} <- normalize_feedback(adapter_module, parsed),
         {:ok, provider_event_id} <- extract_provider_event_id(adapter_module, parsed) do
      attrs = %{
        adapter_module: to_string(adapter_module),
        delivery_id: delivery_info[:delivery_id],
        provider_message_id: delivery_info[:provider_message_id],
        provider_event_id: provider_event_id,
        normalized_status: to_string(feedback_info.status),
        ingress_state: :queued
      }

      Multi.new()
      |> Multi.insert(:ingress, Ingress.changeset(%Ingress{}, attrs),
           on_conflict: :nothing,
           conflict_target: {:unsafe_fragment, ~s|("adapter_module", "provider_event_id") WHERE "provider_event_id" IS NOT NULL|},
           returning: true
         )
      |> Oban.insert(:job, fn %{ingress: ingress} ->
        ProcessFeedbackWorker.new(%{"ingress_id" => ingress.id})
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{ingress: ingress}} -> {:ok, ingress}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  defp decode_body(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :unparseable_body}
    end
  end

  defp resolve_delivery(adapter_module, parsed) do
    case adapter_module.resolve_delivery(parsed) do
      {:ok, info} -> {:ok, info}
      _ -> {:error, :unresolvable_delivery}
    end
  end

  defp normalize_feedback(adapter_module, parsed) do
    case adapter_module.normalize_feedback(parsed) do
      {:ok, info} -> {:ok, info}
      _ -> {:error, :unnormalizable_feedback}
    end
  end

  # Optional adapter callback (A4) — adapters that don't expose stable provider
  # event ids return :none / are not function_exported and the row stores nil
  # (no dedup for that adapter — the partial unique index ignores NULLs).
  defp extract_provider_event_id(adapter_module, parsed) do
    if function_exported?(adapter_module, :resolve_provider_event_id, 1) do
      case adapter_module.resolve_provider_event_id(parsed) do
        {:ok, id} when is_binary(id) -> {:ok, id}
        :none -> {:ok, nil}
        _ -> {:ok, nil}
      end
    else
      {:ok, nil}
    end
  end
end
