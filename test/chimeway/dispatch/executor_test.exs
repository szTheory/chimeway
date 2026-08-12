defmodule Chimeway.Test.ExecutorProviderMessageIdAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: {:ok, %{provider_message_id: "msg-abc-123"}}
end

defmodule Chimeway.Test.ExecutorSafeEvidenceAdapter do
  @moduledoc false
  @behaviour Chimeway.Adapter

  @impl Chimeway.Adapter
  def deliver(_delivery, _config), do: Application.fetch_env!(:chimeway, :executor_safe_evidence_result)
end

defmodule Chimeway.Dispatch.ExecutorTest do
  @moduledoc """
  Plan 55-01 Task 1: persist provider_message_id from adapter success meta (D-05).
  """
  use Chimeway.DataCase, async: false

  alias Chimeway.DeliveryAttempt
  alias Chimeway.Dispatch.Executor
  alias Chimeway.Repo
  alias Chimeway.Test.DispatchHelpers

  setup do
    previous_adapter = Application.get_env(:chimeway, :adapter, Chimeway.Adapters.Logger)
    previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)
    previous_safe_evidence_result = Application.get_env(:chimeway, :executor_safe_evidence_result)

    Application.put_env(:chimeway, :adapter, Chimeway.Test.ExecutorProviderMessageIdAdapter)
    Application.delete_env(:chimeway, :channel_adapters)

    on_exit(fn ->
      Application.put_env(:chimeway, :adapter, previous_adapter)

      if is_nil(previous_channel_adapters) do
        Application.delete_env(:chimeway, :channel_adapters)
      else
        Application.put_env(:chimeway, :channel_adapters, previous_channel_adapters)
      end

      if is_nil(previous_safe_evidence_result) do
        Application.delete_env(:chimeway, :executor_safe_evidence_result)
      else
        Application.put_env(:chimeway, :executor_safe_evidence_result, previous_safe_evidence_result)
      end
    end)

    :ok
  end

  test "run_delivery persists provider_message_id from adapter success meta" do
    %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)

    assert {:ok, %{attempt: attempt}} = Executor.run_delivery(delivery)

    reloaded = Repo.get!(DeliveryAttempt, attempt.id)
    assert reloaded.provider_message_id == "msg-abc-123"
  end

  test "adapter details never reach persisted attempts or caller-visible results" do
    Application.put_env(:chimeway, :adapter, Chimeway.Test.ExecutorSafeEvidenceAdapter)

    for result <- [
          {:ok,
           %{
             provider_message_id: "raw-provider-message-sentinel",
             provider_body: "provider-body-sentinel"
           }},
          {:error, :temporary, %{reason: "raw-temporary-sentinel", provider_body: "provider-body-sentinel"}},
          {:error, :permanent, %{reason: "raw-permanent-sentinel", provider_body: "provider-body-sentinel"}},
          {:error, :bounced, %{reason: "raw-bounced-sentinel", provider_body: "provider-body-sentinel"}},
          {:error, :unknown_provider_term, %{reason: "raw-unknown-sentinel"}}
        ] do
      %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)
      Application.put_env(:chimeway, :executor_safe_evidence_result, result)

      assert {:ok, %{attempt: attempt}} =
               Executor.run_delivery(delivery)

      persisted = Repo.get!(DeliveryAttempt, attempt.id)
      refute_sentinels(persisted)
      refute_sentinels(attempt)
    end
  end

  test "malformed adapter details and unexpected returns become bounded evidence" do
    Application.put_env(:chimeway, :adapter, Chimeway.Test.ExecutorSafeEvidenceAdapter)

    for result <- [
          {:ok, "raw-success-detail-sentinel"},
          {:error, :temporary, "raw-error-detail-sentinel"},
          {:unexpected, "raw-unexpected-return-sentinel"}
        ] do
      %{delivery: delivery} = DispatchHelpers.create_pending_delivery(channel: :email)
      Application.put_env(:chimeway, :executor_safe_evidence_result, result)

      assert {:ok, %{attempt: attempt}} =
               Executor.run_delivery(delivery)

      persisted = Repo.get!(DeliveryAttempt, attempt.id)
      assert persisted.provider_response == %{}
      assert persisted.provider_message_id == nil
      refute_sentinels(persisted)
    end
  end

  defp refute_sentinels(term) do
    encoded = :erlang.term_to_binary(term)

    Enum.each(
      [
        "raw-provider-message-sentinel",
        "provider-body-sentinel",
        "raw-temporary-sentinel",
        "raw-permanent-sentinel",
        "raw-bounced-sentinel",
        "raw-unknown-sentinel",
        "raw-success-detail-sentinel",
        "raw-error-detail-sentinel",
        "raw-unexpected-return-sentinel"
      ],
      fn sentinel ->
        refute :binary.match(encoded, sentinel) != :nomatch, "leaked #{sentinel}"
      end
    )
  end
end
