defmodule Chimeway.Rendering.Channels.SmsPushChatValidatorsTest do
  @moduledoc """
  Asserts the per-channel render-contract validators for SMS, Push, and Chat
  added in plan 29-03. Each module must:

    * declare `use Chimeway.Rendering.Channel` (so `@behaviour` is injected)
    * implement `validate/1` returning `{:ok, stringified_map}` on success and
      `{:error, %Ecto.Changeset{}}` on failure
    * cast away vendor/transport fields not in `@types`
  """

  use ExUnit.Case, async: true

  alias Chimeway.Rendering.Channels.Chat
  alias Chimeway.Rendering.Channels.Push
  alias Chimeway.Rendering.Channels.Sms

  describe "Sms.validate/1" do
    test "accepts a valid text_body and returns stringified map" do
      assert {:ok, %{"text_body" => "Hello"}} = Sms.validate(%{"text_body" => "Hello"})
    end

    test "rejects empty attrs with text_body required error" do
      assert {:error, %Ecto.Changeset{} = changeset} = Sms.validate(%{})
      assert %{text_body: ["can't be blank"]} = errors_on(changeset)
    end

    test "strips vendor fields like from/to/phone_number" do
      assert {:ok, validated} =
               Sms.validate(%{
                 "text_body" => "Hi",
                 "from" => "+15551234567",
                 "to" => "+15557654321",
                 "phone_number" => "+15555555555"
               })

      assert validated == %{"text_body" => "Hi"}
      refute Map.has_key?(validated, "from")
      refute Map.has_key?(validated, "to")
      refute Map.has_key?(validated, "phone_number")
    end

    test "rejects non-map input" do
      assert {:error, %Ecto.Changeset{}} = Sms.validate(:not_a_map)
    end

    test "declares the Chimeway.Rendering.Channel behaviour" do
      assert {:behaviour, [Chimeway.Rendering.Channel]} in Sms.module_info(:attributes)
    end
  end

  describe "Push.validate/1" do
    test "accepts title + body" do
      assert {:ok, %{"title" => "Alert", "body" => "New msg"}} =
               Push.validate(%{"title" => "Alert", "body" => "New msg"})
    end

    test "rejects missing body" do
      assert {:error, %Ecto.Changeset{} = changeset} = Push.validate(%{"title" => "Alert"})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects missing title" do
      assert {:error, %Ecto.Changeset{} = changeset} = Push.validate(%{"body" => "Hi"})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts optional data map for app-specific custom payloads" do
      assert {:ok, validated} =
               Push.validate(%{
                 "title" => "Alert",
                 "body" => "New msg",
                 "data" => %{"deep_link" => "/inbox"}
               })

      assert validated["title"] == "Alert"
      assert validated["body"] == "New msg"
      assert validated["data"] == %{"deep_link" => "/inbox"}
    end

    test "strips platform plumbing like apns_topic and device_token" do
      assert {:ok, validated} =
               Push.validate(%{
                 "title" => "Alert",
                 "body" => "Hi",
                 "apns_topic" => "com.example.app",
                 "priority" => 10,
                 "device_token" => "abc123"
               })

      assert validated == %{"title" => "Alert", "body" => "Hi"}
      refute Map.has_key?(validated, "apns_topic")
      refute Map.has_key?(validated, "priority")
      refute Map.has_key?(validated, "device_token")
    end

    test "rejects non-map input" do
      assert {:error, %Ecto.Changeset{}} = Push.validate("string")
    end

    test "declares the Chimeway.Rendering.Channel behaviour" do
      assert {:behaviour, [Chimeway.Rendering.Channel]} in Push.module_info(:attributes)
    end
  end

  describe "Chat.validate/1" do
    test "accepts text" do
      assert {:ok, %{"text" => "Hi"}} = Chat.validate(%{"text" => "Hi"})
    end

    test "rejects empty attrs with text required error" do
      assert {:error, %Ecto.Changeset{} = changeset} = Chat.validate(%{})
      assert %{text: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts optional rich_payload as opaque map" do
      payload = %{"blocks" => [%{"type" => "section", "text" => "hello"}]}

      assert {:ok, validated} =
               Chat.validate(%{"text" => "Hi", "rich_payload" => payload})

      assert validated["text"] == "Hi"
      assert validated["rich_payload"] == payload
    end

    test "rejects non-map input" do
      assert {:error, %Ecto.Changeset{}} = Chat.validate(123)
    end

    test "declares the Chimeway.Rendering.Channel behaviour" do
      assert {:behaviour, [Chimeway.Rendering.Channel]} in Chat.module_info(:attributes)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
