if Code.ensure_loaded?(Mailglass) do
  defmodule Chimeway.Adapters.Mailglass do
    @moduledoc """
    Mailglass-backed email adapter for Chimeway outbound delivery.

    Product-facing name: `Chimeway.Adapter.Mailglass` (see ECOS-01). Implementation
    module: `Chimeway.Adapters.Mailglass` (D-07).

    Mailglass requires Elixir ~> 1.18 when enabled. Chimeway core compiles on 1.17+;
    run mailglass adapter tests on Elixir 1.18+ (see Phase 54 research).

    Webhook callbacks are Phase 55.
    """

    @behaviour Chimeway.Adapter

    @compile {:no_warn_undefined,
              [
                Mailglass.Outbound,
                Mailglass.Message,
                Mailglass.Tenancy,
                Mailglass.Error,
                Mailglass.SuppressedError,
                Mailglass.RateLimitError,
                Mailglass.SendError,
                Mailglass.TemplateError,
                Mailglass.ConfigError,
                Mailglass.TenancyError,
                Mailglass.SignatureError,
                Mailglass.Events.Event,
                Mailglass.Webhook.Providers.Postmark,
                Mailglass.Webhook.Providers.SendGrid,
                Mailglass.Webhook.Providers.Mailgun,
                Mailglass.Webhook.Providers.SES,
                Mailglass.Webhook.Providers.Resend
              ]}

    @delivery_relevant_types ~w(delivered sent bounced failed rejected)a

    @user_email_prefix ~r/^user:(.+)$/

    if Mix.env() == :test do
      @doc false
      def classify_error_for_test(err), do: classify_mailglass_error(err)
    end

    @impl Chimeway.Adapter
    def deliver(%Chimeway.Delivery{} = delivery, config) do
      config = merge_simulate_error_config(config)

      cond do
        Keyword.get(config, :simulate_error) in [true, :temporary] ->
          {:error, :temporary, %{reason: :simulated}}

        Keyword.get(config, :simulate_error) in [:bounced, :suppressed] ->
          classify_mailglass_error(Mailglass.SuppressedError.new(:address))

        true ->
          do_deliver(delivery, config)
      end
    end

    defp do_deliver(delivery, config) do
      with :ok <- validate_tenant_id(delivery),
           {:ok, recipient} <- resolve_recipient(delivery),
           {:ok, msg} <- build_message(delivery, recipient, config) do
        outbound_opts = Keyword.get(config, :outbound_opts, [])

        delivery.tenant_id
        |> Mailglass.Tenancy.with_tenant(fn ->
          Mailglass.Outbound.deliver(msg, outbound_opts)
        end)
        |> case do
          {:ok, mg_delivery} ->
            meta =
              %{
                adapter: "mailglass",
                mailglass_delivery_id: mg_delivery.id,
                provider_message_id: mg_delivery.provider_message_id,
                status: mg_delivery.status
              }
              |> redact_meta()

            {:ok, meta}

          {:error, err} ->
            classify_mailglass_error(err)
        end
      end
    end

    defp merge_simulate_error_config(config) do
      case Application.get_env(:chimeway, :simulate_mailglass_error) do
        nil ->
          config

        simulate when is_atom(simulate) or simulate == true ->
          Keyword.put_new(config, :simulate_error, simulate)
      end
    end

    defp validate_tenant_id(%{tenant_id: tenant_id})
         when is_binary(tenant_id) and tenant_id != "",
         do: :ok

    defp validate_tenant_id(_),
      do: {:error, :permanent, %{reason: :missing_tenant_id}}

    defp resolve_recipient(delivery) do
      render_data = delivery.render_data || %{}

      email =
        delivery.recipient_address ||
          render_data["to"] ||
          render_data["email"] ||
          parse_user_email(delivery.actor_id)

      if is_binary(email) and email != "" do
        {:ok, email}
      else
        {:error, :permanent, %{reason: :missing_recipient}}
      end
    end

    defp parse_user_email(actor_id) when is_binary(actor_id) do
      case Regex.run(@user_email_prefix, actor_id) do
        [_, email] when email != "" -> email
        _ -> nil
      end
    end

    defp parse_user_email(_), do: nil

    defp build_message(delivery, recipient, config) do
      mailables = resolve_mailables(config)

      case Map.fetch(mailables, delivery.render_key) do
        {:ok, {module, function}} ->
          assigns = Map.merge(%{"to" => recipient}, delivery.render_data || %{})
          msg = build_mailable_message(module, function, assigns)
          {:ok, ensure_tenant_and_recipient(msg, delivery.tenant_id, recipient)}

        :error ->
          {:error, :permanent, %{reason: :unknown_render_key, render_key: delivery.render_key}}
      end
    end

    defp resolve_mailables(config) do
      Keyword.get(config, :mailables) ||
        case Application.get_env(:chimeway, :channel_adapter_configs, %{}) do
          configs when is_map(configs) -> get_in(configs, ["email", :mailables])
          _ -> nil
        end ||
        %{}
    end

    defp build_mailable_message(module, function, assigns) do
      if function_exported?(module, function, 1) do
        apply(module, function, [assigns])
      else
        module.new(assigns)
        |> Mailglass.Message.put_function(function)
      end
    end

    defp ensure_tenant_and_recipient(%Mailglass.Message{} = msg, tenant_id, recipient) do
      msg = %{msg | tenant_id: tenant_id}

      if blank_to?(msg.swoosh_email) do
        Mailglass.Message.update_swoosh(msg, &Swoosh.Email.to(&1, recipient))
      else
        msg
      end
    end

    defp blank_to?(nil), do: true

    defp blank_to?(%Swoosh.Email{to: to}) when to in [nil, []], do: true
    defp blank_to?(%Swoosh.Email{}), do: false

    defp classify_mailglass_error(%Mailglass.SuppressedError{} = err) do
      {:error, :bounced, error_detail(err)}
    end

    defp classify_mailglass_error(%Mailglass.RateLimitError{} = err) do
      {:error, :temporary, error_detail(err)}
    end

    defp classify_mailglass_error(%Mailglass.SendError{} = err) do
      class = if Mailglass.Error.retryable?(err), do: :temporary, else: :permanent
      {:error, class, error_detail(err)}
    end

    defp classify_mailglass_error(%Mailglass.TemplateError{} = err) do
      {:error, :permanent, error_detail(err)}
    end

    defp classify_mailglass_error(%Mailglass.ConfigError{} = err) do
      {:error, :permanent, error_detail(err)}
    end

    defp classify_mailglass_error(%Mailglass.TenancyError{} = err) do
      {:error, :permanent, error_detail(err)}
    end

    defp classify_mailglass_error(%{__struct__: _} = err) do
      if Mailglass.Error.is_error?(err) do
        {:error, :permanent, error_detail(err)}
      else
        {:error, :permanent, %{reason: :unknown_mailglass_error}}
      end
    end

    defp classify_mailglass_error(_),
      do: {:error, :permanent, %{reason: :unknown_mailglass_error}}

    defp error_detail(err) do
      %{
        type: Mailglass.Error.kind(err),
        module: err.__struct__ |> Atom.to_string()
      }
    end

    @sensitive_keys [
      :password,
      :token,
      :secret,
      :api_key,
      :auth,
      "password",
      "token",
      "secret",
      "api_key",
      "auth"
    ]

    defp redact_meta(meta) when is_map(meta) do
      meta
      |> Map.drop(@sensitive_keys)
      |> Map.new(fn
        {key, value} when is_map(value) -> {key, Map.drop(value, @sensitive_keys)}
        pair -> pair
      end)
    end

    @impl Chimeway.Adapter
    def parse_webhook_body(raw_body, headers, config)
        when is_binary(raw_body) and is_list(headers) do
      provider = webhook_provider_module(config)

      case provider.normalize(raw_body, headers) do
        events when is_list(events) ->
          case Enum.find(events, &delivery_relevant?/1) do
            %Mailglass.Events.Event{} = event ->
              {:ok, %{"_mailglass_event" => event}}

            _ ->
              {:error, :unparseable_body}
          end

        _ ->
          {:error, :unparseable_body}
      end
    end

    @impl Chimeway.Adapter
    def verify_webhook(raw_body, headers, config) when is_binary(raw_body) and is_list(headers) do
      provider = webhook_provider_module(config)
      provider_config = webhook_provider_config(config)

      try do
        provider.verify!(raw_body, headers, provider_config)
        :ok
      rescue
        _e in [Mailglass.SignatureError, Mailglass.ConfigError] ->
          {:error, :unauthorized}
      end
    end

    @impl Chimeway.Adapter
    def resolve_delivery(%{"_mailglass_event" => %Mailglass.Events.Event{metadata: metadata}})
        when is_map(metadata) do
      case message_id_from_metadata(metadata) do
        id when is_binary(id) ->
          case Chimeway.SafeEvidence.provider_message_reference(id) do
            {:ok, reference} -> {:ok, %{provider_message_id: reference}}
            {:error, :unsafe_evidence} -> :error
          end

        _ ->
          :error
      end
    end

    def resolve_delivery(_), do: :error

    @impl Chimeway.Adapter
    def normalize_feedback(%{"_mailglass_event" => %Mailglass.Events.Event{type: type}}) do
      case type do
        t when t in [:delivered, :sent] -> {:ok, %{status: :delivered}}
        :bounced -> {:ok, %{status: :bounced}}
        t when t in [:failed, :rejected] -> {:ok, %{status: :failed}}
        _ -> :error
      end
    end

    def normalize_feedback(_), do: :error

    @impl Chimeway.Adapter
    def resolve_provider_event_id(%{
          "_mailglass_event" => %Mailglass.Events.Event{metadata: metadata}
        })
        when is_map(metadata) do
      case metadata["provider_event_id"] do
        id when is_binary(id) and id != "" -> {:ok, id}
        _ -> :none
      end
    end

    def resolve_provider_event_id(_), do: :none

    defp message_id_from_metadata(metadata) do
      metadata["message_id"] || metadata["provider_message_id"]
    end

    defp delivery_relevant?(%Mailglass.Events.Event{type: type})
         when type in @delivery_relevant_types,
         do: true

    defp delivery_relevant?(_), do: false

    defp webhook_provider_module(config) do
      config
      |> Keyword.get(:webhook_provider, :postmark)
      |> webhook_provider_atom()
      |> provider_module()
    end

    defp webhook_provider_atom(provider) when is_atom(provider), do: provider

    defp webhook_provider_atom(provider) when is_binary(provider) do
      case String.to_existing_atom(provider) do
        atom -> atom
      end
    rescue
      ArgumentError -> :postmark
    end

    defp webhook_provider_atom(_), do: :postmark

    defp provider_module(:postmark), do: Mailglass.Webhook.Providers.Postmark
    defp provider_module(:sendgrid), do: Mailglass.Webhook.Providers.SendGrid
    defp provider_module(:mailgun), do: Mailglass.Webhook.Providers.Mailgun
    defp provider_module(:ses), do: Mailglass.Webhook.Providers.SES
    defp provider_module(:resend), do: Mailglass.Webhook.Providers.Resend
    defp provider_module(_), do: Mailglass.Webhook.Providers.Postmark

    defp webhook_provider_config(config) do
      provider = Keyword.get(config, :webhook_provider, :postmark) |> webhook_provider_atom()

      case Keyword.get(config, :webhook_provider_config) do
        provider_config when is_map(provider_config) ->
          provider_config

        _ ->
          case Application.get_env(:mailglass, :webhook_providers, %{}) do
            providers when is_map(providers) ->
              Map.get(providers, provider) ||
                Map.get(providers, Atom.to_string(provider)) ||
                default_webhook_provider_config(provider)

            _ ->
              default_webhook_provider_config(provider)
          end
      end
    end

    defp default_webhook_provider_config(:postmark) do
      env = Application.get_env(:mailglass, :postmark, [])

      %{
        basic_auth: env[:basic_auth],
        ip_allowlist: env[:ip_allowlist] || []
      }
    end

    defp default_webhook_provider_config(:sendgrid) do
      env = Application.get_env(:mailglass, :sendgrid, [])

      %{
        public_key: env[:public_key],
        timestamp_tolerance_seconds: env[:timestamp_tolerance_seconds] || 300
      }
    end

    defp default_webhook_provider_config(:mailgun) do
      env = Application.get_env(:mailglass, :mailgun, [])

      %{
        signing_key: env[:signing_key],
        timestamp_tolerance_seconds: env[:timestamp_tolerance_seconds] || 28_800,
        future_skew_seconds: env[:future_skew_seconds] || 300,
        replay_cache_ttl_seconds: env[:replay_cache_ttl_seconds] || 28_800
      }
    end

    defp default_webhook_provider_config(:ses) do
      env = Application.get_env(:mailglass, :ses, [])

      %{cert_cache_ttl_seconds: env[:cert_cache_ttl_seconds] || 86_400}
    end

    defp default_webhook_provider_config(:resend) do
      env = Application.get_env(:mailglass, :resend, [])

      %{
        secret: env[:secret],
        timestamp_tolerance_seconds: env[:timestamp_tolerance_seconds] || 300
      }
    end

    defp default_webhook_provider_config(_), do: %{}
  end
end
