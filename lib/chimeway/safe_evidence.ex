defmodule Chimeway.SafeEvidence do
  @moduledoc """
  Closed, validated evidence constructors for durable delivery diagnostics.
  """

  alias Chimeway.Privacy

  @max_ref_bytes 160
  @max_code_bytes 80
  @max_adapter_bytes 120
  @max_telemetry_bytes 160
  @max_retry_after_ms 86_400_000
  @error_classes ~w(temporary permanent bounced unknown_classification)
  @telemetry_keys %{
    "notification_key" => :notification_key,
    "event_id" => :event_id,
    "recipient_id" => :recipient_id,
    "channel" => :channel,
    "delivery_id" => :delivery_id,
    "attempt_id" => :attempt_id,
    "outcome" => :outcome,
    "suppression_reason" => :suppression_reason,
    "planning_reason" => :planning_reason,
    "correlation_id" => :correlation_id,
    "attempt_number" => :attempt_number,
    "error_class" => :error_class,
    "adapter_module" => :adapter_module
  }
  @outcomes [:succeeded, :failed, :bounced, :rejected]

  @spec opaque_ref(atom() | String.t(), term()) :: {:ok, String.t()} | {:error, :unsafe_evidence}
  def opaque_ref(domain, value)
      when domain in [
             :provider,
             :provider_message_id,
             :recipient,
             :correlation,
             "provider",
             "provider_message_id",
             "recipient",
             "correlation"
           ] and
             is_binary(value) do
    if byte_size(value) in 4..@max_ref_bytes and
         String.match?(value, ~r/^cw_[a-z0-9][a-z0-9_-]*$/) do
      {:ok, value}
    else
      {:error, :unsafe_evidence}
    end
  end

  def opaque_ref(_domain, _value), do: {:error, :unsafe_evidence}

  @doc "Builds the intentionally small durable event payload vocabulary."
  @spec event_payload(term()) :: map()
  def event_payload(value), do: closed_facts(value, ["category", "reason", "scheduled_at"])

  @doc "Builds the metadata retained beside a notification identity."
  @spec notification_metadata(term()) :: map()
  def notification_metadata(value), do: closed_facts(value, ["category", "reason"])

  @doc "Retains channel render identity only, never rendered content or assigns."
  @spec render_channels(term()) :: map()
  def render_channels(channels) when is_map(channels) do
    channels
    |> Privacy.redact()
    |> Enum.reduce(%{}, fn {channel, info}, acc ->
      with channel when is_binary(channel) <- to_string(channel),
           info when is_map(info) <- info,
           render_key when is_binary(render_key) and byte_size(render_key) in 1..160 <-
             fetch_known(info, "render_key", :render_key),
           render_version when is_integer(render_version) and render_version > 0 <-
             fetch_known(info, "render_version", :render_version) do
        Map.put(acc, channel, %{"render_key" => render_key, "render_version" => render_version})
      else
        _ -> acc
      end
    end)
  end

  def render_channels(_channels), do: %{}

  @spec planning_context(term()) :: map()
  def planning_context(value),
    do: closed_facts(value, ["source", "digest_key", "time_zone", "rule_id", "reason"])

  @spec delivery_metadata(term()) :: map()
  def delivery_metadata(value),
    do:
      closed_facts(value, [
        "delayed_fallback_source",
        "notification_key",
        "event_id",
        "correlation_id",
        "reason"
      ])

  @spec render_data(term()) :: map()
  def render_data(value), do: closed_facts(value, ["render_key", "render_version"])

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
  def telemetry_meta(metadata) when is_map(metadata) do
    metadata
    |> Privacy.redact()
    |> Enum.reduce(%{}, fn {key, value}, safe ->
      case Map.get(@telemetry_keys, key |> to_string() |> String.downcase()) do
        nil ->
          safe

        field ->
          if valid_telemetry_value?(field, value), do: Map.put(safe, field, value), else: safe
      end
    end)
  end

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

  defp closed_facts(value, allowed) when is_map(value) or is_list(value) do
    value
    |> Privacy.redact()
    |> Enum.reduce(%{}, fn {key, fact}, acc ->
      key = to_string(key)

      if key in allowed and safe_scalar?(fact) do
        Map.put(acc, key, fact)
      else
        acc
      end
    end)
  end

  defp closed_facts(_value, _allowed), do: %{}

  defp safe_scalar?(value) when is_binary(value), do: byte_size(value) <= 160
  defp safe_scalar?(value) when is_integer(value) or is_boolean(value), do: true
  defp safe_scalar?(_value), do: false

  defp valid_telemetry_value?(field, value)
       when field in [
              :notification_key,
              :event_id,
              :recipient_id,
              :delivery_id,
              :attempt_id,
              :suppression_reason,
              :planning_reason,
              :correlation_id,
              :adapter_module
            ] do
    safe_telemetry_string?(value)
  end

  defp valid_telemetry_value?(:channel, value) when is_atom(value), do: true
  defp valid_telemetry_value?(:channel, value), do: safe_telemetry_string?(value)
  defp valid_telemetry_value?(:outcome, value), do: value in @outcomes
  defp valid_telemetry_value?(:error_class, value), do: value in @error_classes
  defp valid_telemetry_value?(:attempt_number, value), do: is_integer(value) and value > 0

  defp safe_telemetry_string?(value) when is_binary(value) do
    byte_size(value) in 1..@max_telemetry_bytes and
      String.match?(value, ~r/^[A-Za-z0-9._:-]+$/) and
      not String.match?(
        value,
        ~r/(token|secret|authorization|credential|password|recipient|email|body|content|url|link)/i
      )
  end

  defp safe_telemetry_string?(_value), do: false
end
