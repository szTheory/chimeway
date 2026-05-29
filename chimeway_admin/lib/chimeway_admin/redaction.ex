defmodule ChimewayAdmin.Redaction do
  @moduledoc """
  View-layer redaction for operator trace surfaces (D-13, D-14).
  """

  @allowed_detail_keys ~w(
    reason outcome event_name step_key adapter status notification_key channel
    workflow_step_key workflow_outcome from_step to_step rule_identity
  )

  @sensitive_key ~r/(password|token|secret|api_key|auth)/i

  @doc """
  Masks recipient identity for list/detail display.
  """
  @spec redact_recipient(String.t()) :: String.t()
  def redact_recipient("user:" <> id) do
    suffix =
      if String.length(id) > 3,
        do: String.slice(id, -3..-1//1),
        else: id

    "user:***" <> suffix
  end

  def redact_recipient(value) when is_binary(value) do
    case String.split(value, "@", parts: 2) do
      [local, domain] when byte_size(local) > 0 ->
        first = String.first(local)
        "#{first}***@#{domain}"

      _ ->
        value
    end
  end

  @doc """
  Returns a whitelisted, non-sensitive subset of timeline `:detail` maps.
  """
  @spec safe_timeline_detail(map()) :: map()
  def safe_timeline_detail(detail) when is_map(detail) do
    detail
    |> Enum.filter(fn {key, _value} ->
      key_str = key |> to_string() |> String.downcase()
      key_str in @allowed_detail_keys and not Regex.match?(@sensitive_key, key_str)
    end)
    |> Map.new()
  end

  def safe_timeline_detail(_), do: %{}
end
