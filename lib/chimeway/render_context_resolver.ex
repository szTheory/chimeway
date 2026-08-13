defmodule Chimeway.RenderContextResolver do
  @moduledoc """
  Host-owned reconstruction boundary for deferred notification rendering.

  Chimeway stores only a notification's stable key/version and opaque recipient
  reference. When a delivery is planned after the original trigger process has
  gone away, the configured resolver maps those safe identifiers to current host
  context and the notifier that owns rendering.
  """

  @type context :: %{
          required(:notifier) => module(),
          required(:params) => map(),
          required(:recipient) => map()
        }

  @callback resolve(String.t(), pos_integer(), String.t()) :: {:ok, context()} | {:error, atom()}

  @spec resolve(String.t(), pos_integer(), String.t()) :: {:ok, context()} | {:error, atom()}
  def resolve(notification_key, notification_version, recipient_ref)
      when is_binary(notification_key) and is_integer(notification_version) and
             notification_version > 0 and
             is_binary(recipient_ref) do
    with {:ok, resolver} <- fetch_resolver(notification_key, notification_version),
         {:ok, context} <- resolver.resolve(notification_key, notification_version, recipient_ref),
         :ok <- validate_context(context, notification_key, notification_version, recipient_ref) do
      {:ok, context}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_render_context}
    end
  end

  def resolve(_, _, _), do: {:error, :invalid_render_context}

  def validate_registry! do
    Application.get_env(:chimeway, :render_context_resolvers, %{})
    |> Enum.each(fn
      {{key, version}, module}
      when is_binary(key) and is_integer(version) and version > 0 and is_atom(module) ->
        unless Code.ensure_loaded?(module) and function_exported?(module, :resolve, 3) do
          raise ArgumentError,
                "[chimeway] :render_context_resolvers[#{inspect({key, version})}] must export resolve/3"
        end

      {entry, _module} ->
        raise ArgumentError,
              "[chimeway] :render_context_resolvers has invalid key #{inspect(entry)}; expected {notification_key, positive_version}"
    end)
  end

  defp fetch_resolver(key, version) do
    case Application.get_env(:chimeway, :render_context_resolvers, %{}) do
      %{^key => _} -> {:error, :invalid_render_context_registry}
      registry -> Map.fetch(registry, {key, version}) |> missing_resolver()
    end
  end

  defp missing_resolver({:ok, resolver}), do: {:ok, resolver}
  defp missing_resolver(:error), do: {:error, :render_context_unavailable}

  defp validate_context(
         %{notifier: notifier, params: params, recipient: recipient},
         key,
         version,
         recipient_ref
       )
       when is_atom(notifier) and is_map(params) and is_map(recipient) do
    with true <- function_exported?(notifier, :notification_key, 0),
         true <- function_exported?(notifier, :version, 0),
         ^key <- notifier.notification_key(),
         ^version <- notifier.version(),
         ^recipient_ref <- Map.get(recipient, :recipient_ref, Map.get(recipient, "recipient_ref")) do
      :ok
    else
      _ -> {:error, :invalid_render_context}
    end
  end

  defp validate_context(_, _, _, _), do: {:error, :invalid_render_context}
end
