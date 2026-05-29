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
                Mailglass.TenancyError
              ]}

    @user_email_prefix ~r/^user:(.+)$/

    @impl Chimeway.Adapter
    def deliver(%Chimeway.Delivery{} = delivery, config) do
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

    defp validate_tenant_id(%{tenant_id: tenant_id})
         when is_binary(tenant_id) and tenant_id != "",
         do: :ok

    defp validate_tenant_id(_),
      do: {:error, :permanent, %{reason: :missing_tenant_id}}

    defp resolve_recipient(delivery) do
      render_data = delivery.render_data || %{}

      email =
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
          {:error, :permanent,
           %{reason: :unknown_render_key, render_key: delivery.render_key}}
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

    @sensitive_keys [:password, :token, :secret, :api_key, :auth, "password", "token", "secret", "api_key", "auth"]

    defp redact_meta(meta) when is_map(meta) do
      meta
      |> Map.drop(@sensitive_keys)
      |> Map.new(fn
        {key, value} when is_map(value) -> {key, Map.drop(value, @sensitive_keys)}
        pair -> pair
      end)
    end
  end
end
