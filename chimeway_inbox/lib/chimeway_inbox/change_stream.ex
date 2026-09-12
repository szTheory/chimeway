defmodule ChimewayInbox.ChangeStream do
  @moduledoc """
  Privacy-safe Phoenix PubSub routing for inbox reload hints.

  Topics are derived with a host secret and never contain tenant or recipient
  input. Messages are deliberately closed reload hints; durable inbox state is
  always authoritative.
  """

  alias Chimeway.SafeEvidence

  @domain "chimeway-inbox-stream"
  @prefix "chimeway:inbox:v1:"
  @reload_message {:chimeway_inbox, :reload, 1}
  @max_tenant_bytes 160

  @spec topic(term(), term()) :: {:ok, String.t()} | {:error, :invalid_stream}
  def topic(tenant_id, recipient_ref) do
    with {:ok, tenant_id} <- tenant_id(tenant_id),
         {:ok, recipient_ref} <- SafeEvidence.opaque_ref(:recipient, recipient_ref),
         {:ok, secret} <- topic_secret() do
      digest =
        :crypto.mac(
          :hmac,
          :sha256,
          secret,
          length_delimited([@domain, tenant_id, recipient_ref])
        )

      {:ok, @prefix <> Base.url_encode64(digest, padding: false)}
    else
      _ -> {:error, :invalid_stream}
    end
  end

  @spec subscribe(term(), term()) :: :ok | {:error, :invalid_stream}
  def subscribe(tenant_id, recipient_ref) do
    with {:ok, topic} <- topic(tenant_id, recipient_ref),
         {:ok, server} <- pubsub_server() do
      safe_pubsub(fn -> Phoenix.PubSub.subscribe(server, topic) end)
    end
  end

  @doc false
  @spec broadcast_topic(term()) :: :ok | {:error, :invalid_stream}
  def broadcast_topic(@prefix <> _digest = topic) do
    with {:ok, server} <- pubsub_server() do
      safe_pubsub(fn -> Phoenix.PubSub.broadcast(server, topic, @reload_message) end)
    end
  end

  def broadcast_topic(_topic), do: {:error, :invalid_stream}

  defp tenant_id(value) when is_binary(value) and byte_size(value) in 1..@max_tenant_bytes do
    case String.trim(value) do
      "" -> {:error, :invalid_stream}
      normalized -> {:ok, normalized}
    end
  end

  defp tenant_id(_value), do: {:error, :invalid_stream}

  defp topic_secret do
    case Application.get_env(:chimeway_inbox, :topic_secret) do
      secret when is_binary(secret) and byte_size(secret) >= 32 -> {:ok, secret}
      _ -> {:error, :invalid_stream}
    end
  end

  defp pubsub_server do
    case Application.get_env(:chimeway_inbox, :pubsub_server) do
      server when is_atom(server) -> {:ok, server}
      _ -> {:error, :invalid_stream}
    end
  end

  defp length_delimited(parts) do
    Enum.map(parts, fn part -> [<<byte_size(part)::unsigned-big-32>>, part] end)
  end

  defp safe_pubsub(fun) do
    case fun.() do
      :ok -> :ok
      _ -> {:error, :invalid_stream}
    end
  catch
    _, _ -> {:error, :invalid_stream}
  end
end
