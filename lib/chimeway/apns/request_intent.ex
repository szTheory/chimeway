defmodule Chimeway.APNS.RequestIntent do
  @moduledoc "Safe, durable routing intent for an APNs target."

  @enforce_keys [:environment, :topic, :apns_id, :expires_at, :open_ref]
  defstruct [:environment, :topic, :apns_id, :expires_at, :open_ref, :collapse_id]

  @type t :: %__MODULE__{
          environment: :sandbox | :production,
          topic: String.t(),
          apns_id: String.t(),
          expires_at: DateTime.t(),
          open_ref: String.t(),
          collapse_id: String.t() | nil
        }

  @uuid ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

  @spec new(map(), keyword()) :: {:ok, t()} | {:error, :invalid_apns_request_intent}
  def new(attrs, opts) when is_map(attrs) and is_list(opts) do
    environment = Map.get(attrs, :environment) || Map.get(attrs, "environment")
    topic = Map.get(attrs, :topic) || Map.get(attrs, "topic")
    apns_id = Map.get(attrs, :apns_id) || Map.get(attrs, "apns_id")
    expires_at = Map.get(attrs, :expires_at) || Map.get(attrs, "expires_at")
    open_ref = Map.get(attrs, :open_ref) || Map.get(attrs, "open_ref")
    collapse_id = Map.get(attrs, :collapse_id) || Map.get(attrs, "collapse_id")

    with true <- environment in [:sandbox, :production],
         true <- bounded?(topic, 1, 255),
         true <- is_binary(apns_id) and Regex.match?(@uuid, apns_id),
         %DateTime{} = expires_at <- normalize_datetime(expires_at),
         true <- bounded?(open_ref, 1, 256),
         true <- safe_opaque?(topic) and safe_opaque?(open_ref),
         {:ok, collapse_id} <- collapse_id(collapse_id, opts, environment, topic),
         true <- is_nil(collapse_id) or (bounded?(collapse_id, 1, 64) and safe_opaque?(collapse_id)) do
      {:ok,
       %__MODULE__{
         environment: environment,
         topic: topic,
         apns_id: String.downcase(apns_id),
         expires_at: DateTime.truncate(expires_at, :second),
         open_ref: open_ref,
         collapse_id: collapse_id
       }}
    else
      _ -> {:error, :invalid_apns_request_intent}
    end
  end

  def new(_, _), do: {:error, :invalid_apns_request_intent}

  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}, %DateTime{} = now),
    do: DateTime.compare(expires_at, now) != :gt

  @spec to_storage(t()) :: map()
  def to_storage(%__MODULE__{} = intent) do
    %{
      "environment" => Atom.to_string(intent.environment),
      "topic" => intent.topic,
      "apns_id" => intent.apns_id,
      "expires_at" => DateTime.to_iso8601(intent.expires_at),
      "open_ref" => intent.open_ref,
      "collapse_id" => intent.collapse_id
    }
  end

  @spec from_storage(map() | nil) :: {:ok, t()} | {:error, :invalid_apns_request_intent}
  def from_storage(nil), do: {:error, :invalid_apns_request_intent}
  def from_storage(storage) when is_map(storage) do
    with {:ok, environment} <- environment(Map.get(storage, "environment")),
         {:ok, expires_at} <- parse_datetime(Map.get(storage, "expires_at")) do
      new(Map.put(storage, "environment", environment) |> Map.put("expires_at", expires_at), [])
    else
      _ -> {:error, :invalid_apns_request_intent}
    end
  end
  def from_storage(_), do: {:error, :invalid_apns_request_intent}

  defp collapse_id(nil, opts, environment, topic) do
    case Keyword.get(opts, :replaceable, false) do
      true ->
        with occurrence when is_binary(occurrence) <- Keyword.get(opts, :occurrence_ref),
             binding when is_binary(binding) <- Keyword.get(opts, :binding_revision_ref),
             true <- bounded?(occurrence, 1, 256) and bounded?(binding, 4, 128),
             true <- safe_opaque?(occurrence) and safe_opaque?(binding) do
          {:ok,
           :crypto.hash(:sha256, Enum.join([occurrence, binding, Atom.to_string(environment), topic], "\u0000"))
           |> Base.url_encode64(padding: false)}
        else
          _ -> {:error, :invalid_apns_request_intent}
        end

      false -> {:ok, nil}
    end
  end
  defp collapse_id(value, _opts, _environment, _topic) when is_binary(value), do: {:ok, value}
  defp collapse_id(_, _opts, _environment, _topic), do: {:error, :invalid_apns_request_intent}

  defp environment("sandbox"), do: {:ok, :sandbox}
  defp environment("production"), do: {:ok, :production}
  defp environment(_), do: :error
  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, parsed, _offset} -> {:ok, parsed}
      _ -> :error
    end
  end
  defp parse_datetime(_), do: :error
  defp normalize_datetime(%DateTime{} = value), do: value
  defp normalize_datetime(_), do: nil
  defp bounded?(value, min, max), do: is_binary(value) and byte_size(value) in min..max
  defp safe_opaque?(value), do: is_binary(value) and not String.contains?(String.downcase(value), ["token", "credential", "password", "secret"])
end
