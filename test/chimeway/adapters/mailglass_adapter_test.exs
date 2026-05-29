if Code.ensure_loaded?(Mailglass) and Code.ensure_loaded?(Chimeway.Adapters.Mailglass) do
  defmodule Chimeway.Adapters.MailglassAdapterTest do
    @moduledoc """
    Contract and classification tests for `Chimeway.Adapters.Mailglass`.

    ## Error classification (D-15)

    | Mailglass error | Chimeway class |
    |-----------------|----------------|
    | `%Mailglass.SuppressedError{}` | `:bounced` |
    | `%Mailglass.RateLimitError{}` | `:temporary` |
    | `%Mailglass.SendError{}` (retryable) | `:temporary` |
    | `%Mailglass.SendError{}` (non-retryable) | `:permanent` |
    | `%Mailglass.TemplateError{}` | `:permanent` |
    | `%Mailglass.ConfigError{}` | `:permanent` |
    | `%Mailglass.TenancyError{}` | `:permanent` |
    | `simulate_error: true` config | `:temporary` |
    """

    use Mailglass.DataCase, async: false
    use Chimeway.Adapter.ContractTest

    @webhook_contract true
    @moduletag :mailglass

    alias Chimeway.Adapters.Mailglass, as: MailglassAdapter
    alias Chimeway.Repo
    alias Chimeway.TestSupport.MailglassFixtures
    alias Chimeway.Webhooks
    alias Chimeway.Webhooks.Ingress

    def adapter_module, do: MailglassAdapter
    def sample_delivery, do: MailglassFixtures.sample_delivery()
    def simulate_error?, do: true
    def webhook_contract?, do: true

    def webhook_fixtures do
      message_id = "postmark-msg-123"
      delivered_at = "2026-05-29T12:00:00Z"

      payload =
        MailglassFixtures.postmark_delivery_payload(
          message_id: message_id,
          delivered_at: delivered_at
        )

      %{
        valid_body: MailglassFixtures.encode_postmark_payload(payload),
        valid_headers: MailglassFixtures.postmark_delivery_headers(),
        config: MailglassFixtures.postmark_webhook_config_keyword(),
        provider_message_id: message_id,
        provider_event_id: "Delivery:#{message_id}:#{delivered_at}"
      }
    end

    setup do
      Mailglass.Adapters.Fake.checkout()
      Mailglass.Adapters.Fake.set_shared(self())

      previous_configs = Application.get_env(:chimeway, :channel_adapter_configs)

      Application.put_env(:chimeway, :channel_adapter_configs, %{
        "email" => [mailables: MailglassFixtures.mailables()]
      })

      on_exit(fn ->
        if previous_configs do
          Application.put_env(:chimeway, :channel_adapter_configs, previous_configs)
        else
          Application.delete_env(:chimeway, :channel_adapter_configs)
        end
      end)

      :ok
    end

    describe "Mailglass integration" do
      test "happy path uses Mailglass.Fake" do
        count_before = length(Mailglass.Adapters.Fake.deliveries())

        assert {:ok, meta} =
                 MailglassAdapter.deliver(
                   MailglassFixtures.sample_delivery(),
                   mailables: MailglassFixtures.mailables(),
                   outbound_opts: []
                 )

        assert length(Mailglass.Adapters.Fake.deliveries()) == count_before + 1
        assert meta[:adapter] == "mailglass"
      end
    end

    describe "error classification (D-14, D-15)" do
      test "classifies simulate_error config as :temporary" do
        delivery = MailglassFixtures.sample_delivery()

        assert {:error, :temporary, detail} =
                 MailglassAdapter.deliver(delivery,
                   mailables: MailglassFixtures.mailables(),
                   simulate_error: true
                 )

        assert is_map(detail)
        refute Map.has_key?(detail, :token)
        refute Map.has_key?(detail, :api_key)
      end

      test "classifies Mailglass.SuppressedError as :bounced" do
        delivery = MailglassFixtures.sample_delivery()

        assert {:error, :bounced, detail} =
                 MailglassAdapter.deliver(delivery,
                   mailables: MailglassFixtures.mailables(),
                   simulate_error: :bounced
                 )

        assert detail[:type] == :address
        assert detail[:module] == "Elixir.Mailglass.SuppressedError"
        refute Map.has_key?(detail, :token)
      end

      test "classifies Mailglass.TemplateError as :permanent" do
        err = Mailglass.TemplateError.new(:missing_assign, context: %{assign: :name})

        assert {:error, :permanent, detail} = MailglassAdapter.classify_error_for_test(err)
        assert is_map(detail)
        refute Map.has_key?(detail, :token)
        refute Map.has_key?(detail, :api_key)
      end
    end

    describe "webhook callbacks" do
      @tag :webhook
      test "verify_webhook accepts valid Postmark Basic auth" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        assert :ok = MailglassAdapter.verify_webhook(body, headers, config)
      end

      @tag :webhook
      test "verify_webhook rejects invalid Basic auth" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = [{"authorization", "Basic #{Base.encode64("wrong:creds")}"}]

        assert {:error, :unauthorized} = MailglassAdapter.verify_webhook(body, headers, config)
      end

      @tag :webhook
      test "parse_webhook_body returns _mailglass_event for Delivery payload" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        assert {:ok, %{"_mailglass_event" => event}} =
                 MailglassAdapter.parse_webhook_body(body, headers, config)

        assert event.type == :delivered
        assert event.metadata["message_id"] == "postmark-msg-123"
      end

      @tag :webhook
      test "parse_webhook_body rejects engagement-only payloads" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_open_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        assert {:error, :unparseable_body} =
                 MailglassAdapter.parse_webhook_body(body, headers, config)
      end

      @tag :webhook
      test "resolve_delivery extracts provider_message_id from Delivery event" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        {:ok, parsed} = MailglassAdapter.parse_webhook_body(body, headers, config)

        assert {:ok, %{provider_message_id: "postmark-msg-123"}} =
                 MailglassAdapter.resolve_delivery(parsed)
      end

      @tag :webhook
      test "normalize_feedback maps Delivery to :delivered" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        {:ok, parsed} = MailglassAdapter.parse_webhook_body(body, headers, config)

        assert {:ok, %{status: :delivered}} = MailglassAdapter.normalize_feedback(parsed)
      end

      @tag :webhook
      test "normalize_feedback maps Bounce to :bounced" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_bounce_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        {:ok, parsed} = MailglassAdapter.parse_webhook_body(body, headers, config)

        assert {:ok, %{status: :bounced}} = MailglassAdapter.normalize_feedback(parsed)
      end

      @tag :webhook
      test "normalize_feedback returns :error for Open engagement events" do
        event = %Mailglass.Events.Event{
          type: :opened,
          metadata: %{"message_id" => "postmark-msg-open"}
        }

        parsed = %{"_mailglass_event" => event}

        assert :error = MailglassAdapter.normalize_feedback(parsed)
      end

      @tag :webhook
      test "resolve_provider_event_id returns id from event metadata" do
        config = MailglassFixtures.postmark_webhook_config_keyword()
        body = MailglassFixtures.encode_postmark_payload(MailglassFixtures.postmark_delivery_payload())
        headers = MailglassFixtures.postmark_delivery_headers()

        {:ok, parsed} = MailglassAdapter.parse_webhook_body(body, headers, config)

        assert {:ok, id} = MailglassAdapter.resolve_provider_event_id(parsed)
        assert is_binary(id) and id != ""
        assert String.starts_with?(id, "Delivery:")
      end
    end

    describe "webhook dedup (T-55-06)" do
      setup do
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
        Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
        :ok
      end

      @tag :webhook
      test "duplicate provider_event_id collapses to one ingress row" do
        fixtures = webhook_fixtures()

        assert {:ok, %Ingress{} = first} =
                 Webhooks.process(
                   MailglassAdapter,
                   fixtures.valid_body,
                   fixtures.valid_headers,
                   fixtures.config
                 )

        assert first.provider_event_id == fixtures.provider_event_id

        assert {:ok, %Ingress{} = _second} =
                 Webhooks.process(
                   MailglassAdapter,
                   fixtures.valid_body,
                   fixtures.valid_headers,
                   fixtures.config
                 )

        assert Repo.aggregate(Ingress, :count) == 1
      end
    end
  end
end
