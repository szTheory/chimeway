defmodule Chimeway.WebhooksTest do
  use Chimeway.DataCase, async: true
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.Webhooks

  defmodule MockAdapter do
    @behaviour Chimeway.Adapter

    def deliver(_delivery, _config), do: {:ok, %{}}

    def verify_webhook(_body, [{"signature", "valid"}], _config), do: :ok
    def verify_webhook(_, _, _config), do: {:error, :unauthorized}

    def resolve_delivery(%{"id" => "del_123"}), do: {:ok, %{delivery_id: "del_123"}}
    def resolve_delivery(%{"msg_id" => "msg_123"}), do: {:ok, %{provider_message_id: "msg_123"}}
    def resolve_delivery(_), do: :error

    def normalize_feedback(%{"status" => "bounce"}), do: {:ok, %{status: :bounced}}
    def normalize_feedback(%{"status" => "ok"}), do: {:ok, %{status: :delivered}}
    def normalize_feedback(%{"status" => "fail"}), do: {:ok, %{status: :failed}}
    def normalize_feedback(_), do: :error
  end

  describe "process/4" do
    test "returns {:error, :unauthorized} if verification fails" do
      assert {:error, :unauthorized} = Webhooks.process(MockAdapter, "invalid_body", [{"signature", "invalid"}], [])
    end

    test "returns :error if delivery cannot be resolved" do
      body = Jason.encode!(%{"status" => "ok"})
      assert :error = Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])
    end

    test "returns :error if feedback cannot be normalized" do
      body = Jason.encode!(%{"id" => "del_123", "status" => "unknown"})
      assert :error = Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])
    end

    test "enqueues worker and returns {:ok, :enqueued} on success with delivery_id" do
      # Note: Testing Oban insertion usually involves assert_enqueued, but Webhooks
      # uses ProcessFeedbackWorker.enqueue. We will verify the enqueue via Oban.
      body = Jason.encode!(%{"id" => "del_123", "status" => "bounce"})
      
      assert {:ok, :enqueued} = Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      assert_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker, args: %{
        "delivery_id" => "del_123",
        "status" => "bounced",
        "provider_response" => %{"id" => "del_123", "status" => "bounce"},
        "adapter_module" => to_string(MockAdapter)
      }
    end

    test "enqueues worker and returns {:ok, :enqueued} on success with provider_message_id" do
      body = Jason.encode!(%{"msg_id" => "msg_123", "status" => "ok"})
      
      assert {:ok, :enqueued} = Webhooks.process(MockAdapter, body, [{"signature", "valid"}], [])

      assert_enqueued worker: Chimeway.Webhooks.ProcessFeedbackWorker, args: %{
        "provider_message_id" => "msg_123",
        "status" => "delivered",
        "provider_response" => %{"msg_id" => "msg_123", "status" => "ok"},
        "adapter_module" => to_string(MockAdapter)
      }
    end
  end
end