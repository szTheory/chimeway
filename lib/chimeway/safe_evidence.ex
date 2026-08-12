defmodule Chimeway.SafeEvidence do
  @moduledoc """
  Closed, validated evidence constructors for durable delivery diagnostics.
  """

  alias Chimeway.Privacy

  @max_ref_bytes 160
  @max_code_bytes 80
  @max_adapter_bytes 120
  @max_retry_after_ms 86_400_000
  @error_classes ~w(temporary permanent bounced unknown_classification)

  @spec opaque_ref(atom() | String.t(), term()) :: {:ok, String.t()} | {:error, :unsafe_evidence}
  def opaque_ref(domain, value)
      when domain in [:provider, :provider_message_id, "provider", "provider_message_id"] and
             is_binary(value) do
    if byte_size(value) in 4..@max_ref_bytes and
         String.match?(value, ~r/^cw_[a-z0-9][a-z0-9_-]*$/) do
      {:ok, value}
    else
      {:error, :unsafe_evidence}
    end
  end

  def opaque_ref(_domain, _value), do: {:error, :unsafe_evidence}

  @spec provider_facts(term()) :: {:ok, map()} | {:error, :unsafe_evidence}
  def provider_facts(value) when is_map(value) or is_list(value) do
    facts = Privacy.redact(value)

    with {:ok, code} <- optional_provider_code(facts),
         {:ok, retry_after_ms} <- optional_retry_after_ms(facts),
         {:ok, accepted_at} <- optional_accepted_at(facts) do
      {:ok,
       %{}
       |> maybe_put("provider_code", code)
       |> maybe_put("retry_after_ms", retry_after_ms)
       |> maybe_put("accepted_at", accepted_at)}
    end
  end

  def provider_facts(_value), do: {:error, :unsafe_evidence}

  @spec attempt_attrs(map()) :: {:ok, map()} | {:error, :unsafe_evidence, atom()}
  def attempt_attrs(attrs) when is_map(attrs) do
    provider_response =
      Map.get(attrs, :provider_response, Map.get(attrs, "provider_response", %{}))

    provider_message_id =
      Map.get(attrs, :provider_message_id, Map.get(attrs, "provider_message_id"))

    with {:ok, facts} <- provider_facts(provider_response),
         {:ok, provider_ref} <- optional_provider_ref(provider_message_id),
         {:ok, outcome} <- valid_outcome(Map.get(attrs, :outcome, Map.get(attrs, "outcome"))),
         {:ok, error_class} <-
           valid_error_class(Map.get(attrs, :error_class, Map.get(attrs, "error_class"))),
         {:ok, adapter_module} <-
           valid_adapter(Map.get(attrs, :adapter_module, Map.get(attrs, "adapter_module"))) do
      {:ok,
       %{
         outcome: outcome,
         error_class: error_class,
         adapter_module: adapter_module,
         provider_message_id: provider_ref,
         provider_response: facts
       }}
    else
      {:error, :unsafe_evidence} -> {:error, :unsafe_evidence, :provider_facts}
      {:error, reason} -> {:error, :unsafe_evidence, reason}
    end
  end

  def attempt_attrs(_attrs), do: {:error, :unsafe_evidence, :attempt_attrs}

  @spec telemetry_meta(map()) :: map()
  def telemetry_meta(metadata) when is_map(metadata), do: Privacy.redact(metadata)
  def telemetry_meta(_metadata), do: %{}

  @spec trace_attempt(map()) :: map()
  def trace_attempt(attempt) do
    %{
      outcome: Map.get(attempt, :outcome),
      inserted_at: Map.get(attempt, :inserted_at),
      attempt_number: Map.get(attempt, :attempt_number),
      error_class: Map.get(attempt, :error_class),
      provider_message_id: safe_opaque_ref(Map.get(attempt, :provider_message_id)),
      provider_facts: safe_facts(Map.get(attempt, :provider_response))
    }
  end

  @spec timeline_detail(map()) :: map()
  def timeline_detail(attempt) do
    trace_attempt(attempt)
    |> Map.drop([:inserted_at])
  end

  @spec admin_fact(atom(), term()) :: map()
  def admin_fact(name, value) when is_atom(name), do: %{name: name, value: Privacy.redact(value)}

  @spec proof(map()) :: map()
  def proof(value) when is_map(value), do: Privacy.redact(value)

  defp optional_provider_code(facts) do
    case fetch(facts, "provider_code") do
      :missing -> {:ok, nil}
      value when is_binary(value) and byte_size(value) in 1..@max_code_bytes -> {:ok, value}
      _ -> {:error, :unsafe_evidence}
    end
  end

  defp optional_retry_after_ms(facts) do
    case fetch(facts, "retry_after_ms") do
      :missing -> {:ok, nil}
      value when is_integer(value) and value >= 0 and value <= @max_retry_after_ms -> {:ok, value}
      _ -> {:error, :unsafe_evidence}
    end
  end

  defp optional_accepted_at(facts) do
    case fetch(facts, "accepted_at") do
      :missing ->
        {:ok, nil}

      %DateTime{} = value ->
        {:ok, DateTime.to_iso8601(value)}

      value when is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, _datetime, 0} -> {:ok, value}
          _ -> {:error, :unsafe_evidence}
        end

      _ ->
        {:error, :unsafe_evidence}
    end
  end

  defp optional_provider_ref(nil), do: {:ok, nil}
  defp optional_provider_ref(value), do: opaque_ref(:provider_message_id, value)

  defp valid_outcome(value) when value in [:succeeded, :failed, :bounced, :rejected],
    do: {:ok, value}

  defp valid_outcome(value) when value in ~w(succeeded failed bounced rejected), do: {:ok, value}
  defp valid_outcome(_value), do: {:error, :outcome}

  defp valid_error_class(nil), do: {:ok, nil}
  defp valid_error_class(value) when value in @error_classes, do: {:ok, value}
  defp valid_error_class(_value), do: {:error, :error_class}

  defp valid_adapter(nil), do: {:ok, nil}

  defp valid_adapter(value) when is_binary(value) and byte_size(value) in 1..@max_adapter_bytes,
    do: {:ok, value}

  defp valid_adapter(_value), do: {:error, :adapter_module}

  defp fetch(value, "provider_code"), do: fetch_known(value, "provider_code", :provider_code)
  defp fetch(value, "retry_after_ms"), do: fetch_known(value, "retry_after_ms", :retry_after_ms)
  defp fetch(value, "accepted_at"), do: fetch_known(value, "accepted_at", :accepted_at)

  defp fetch_known(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key, Map.get(map, atom_key, :missing))
  end

  defp fetch_known(list, _string_key, atom_key) when is_list(list),
    do: Keyword.get(list, atom_key, :missing)

  defp safe_facts(value) do
    case provider_facts(value || %{}) do
      {:ok, facts} -> facts
      {:error, :unsafe_evidence} -> %{}
    end
  end

  defp safe_opaque_ref(value) do
    case optional_provider_ref(value) do
      {:ok, ref} -> ref
      {:error, :unsafe_evidence} -> nil
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
