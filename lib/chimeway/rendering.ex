defmodule Chimeway.Rendering do
  @moduledoc """
  Normalizes notifier rendering declarations into one durable contract.
  """

  alias Chimeway.Rendering.Channels.{Email, InApp}

  @type channel_rendering :: %{
          render_key: String.t(),
          render_version: pos_integer()
        }

  @type rendering_declaration :: %{
          assigns: map(),
          channels: %{String.t() => channel_rendering()},
          source: :notifier | :build_fallback
        }

  @type rendered_delivery :: %{
          channel: String.t(),
          render_key: String.t(),
          render_version: pos_integer(),
          render_data: map()
        }

  @spec resolve_declaration(module(), map(), map()) ::
          {:ok, rendering_declaration()} | {:error, term()}
  def resolve_declaration(notifier, trigger_params, recipient) when is_atom(notifier) do
    if function_exported?(notifier, :rendering, 2) do
      notifier
      |> apply(:rendering, [trigger_params, recipient])
      |> handle_result(:notifier)
    else
      resolve_build_fallback(notifier, trigger_params, recipient)
    end
  end

  @spec normalize_declaration(map()) :: {:ok, rendering_declaration()} | {:error, term()}
  def normalize_declaration(%{} = declaration) do
    with {:ok, assigns} <-
           normalize_assigns(Map.get(declaration, :assigns, Map.get(declaration, "assigns"))),
         {:ok, channels} <-
           normalize_channels(Map.get(declaration, :channels, Map.get(declaration, "channels"))),
         {:ok, source} <- normalize_source(Map.get(declaration, :source, :notifier)) do
      {:ok, %{assigns: assigns, channels: channels, source: source}}
    else
      {:error, reason} -> {:error, {:rendering_resolution_failed, reason}}
    end
  end

  def normalize_declaration(other),
    do: {:error, {:rendering_resolution_failed, {:invalid_rendering_declaration, other}}}

  @spec render_delivery(atom() | binary(), String.t(), pos_integer(), map()) ::
          {:ok, rendered_delivery()} | {:error, term()}
  def render_delivery(channel, render_key, render_version, attrs) do
    with {:ok, normalized_channel} <- normalize_channel(channel),
         {:ok, normalized_render_key} <- normalize_render_key(normalized_channel, render_key),
         {:ok, normalized_render_version} <-
           normalize_render_version(normalized_channel, render_version),
         {:ok, validated_render_data} <-
           normalized_channel
           |> channel_module()
           |> validate_channel_payload(normalized_channel, attrs) do
      {:ok,
       %{
         channel: normalized_channel,
         render_key: normalized_render_key,
         render_version: normalized_render_version,
         render_data: validated_render_data
       }}
    else
      {:error, {:invalid_channel_payload, _channel, _changeset} = reason} ->
        {:error, {:rendering_failed, normalize_channel_error(channel), reason}}

      {:error, {:unsupported_render_channel, unsupported_channel}} ->
        {:error,
         {:rendering_failed, unsupported_channel,
          {:unsupported_render_channel, unsupported_channel}}}

      {:error, reason} ->
        {:error, {:rendering_failed, normalize_channel_error(channel), reason}}
    end
  end

  defp resolve_build_fallback(notifier, trigger_params, recipient) do
    with {:ok, assigns} <- notifier.build(trigger_params, recipient),
         {:ok, channels} <- resolve_notifier_channels(notifier, trigger_params, recipient) do
      normalize_declaration(%{
        assigns: assigns,
        channels: fallback_channel_declarations(notifier, channels),
        source: :build_fallback
      })
    else
      {:error, reason} -> {:error, {:rendering_resolution_failed, reason}}
    end
  end

  defp handle_result({:ok, declaration}, source) do
    declaration
    |> Map.put(:source, source)
    |> normalize_declaration()
  end

  defp handle_result({:error, reason}, _source),
    do: {:error, {:rendering_resolution_failed, reason}}

  defp handle_result(unexpected, _source),
    do: {:error, {:rendering_resolution_failed, {:unexpected_result, unexpected}}}

  defp normalize_assigns(assigns) when is_map(assigns), do: {:ok, assigns}
  defp normalize_assigns(other), do: {:error, {:invalid_render_assigns, other}}

  defp normalize_channels(channels) when is_map(channels) and map_size(channels) > 0 do
    Enum.reduce_while(channels, {:ok, %{}}, fn {channel, declaration}, {:ok, acc} ->
      with {:ok, normalized_channel} <- normalize_channel(channel),
           {:ok, normalized_declaration} <-
             normalize_channel_declaration(normalized_channel, declaration) do
        {:cont, {:ok, Map.put(acc, normalized_channel, normalized_declaration)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_channels(channels) when is_map(channels),
    do: {:error, {:invalid_rendering_channels, channels}}

  defp normalize_channels(other), do: {:error, {:invalid_rendering_channels, other}}

  defp normalize_source(source) when source in [:notifier, :build_fallback], do: {:ok, source}
  defp normalize_source(source), do: {:error, {:invalid_rendering_source, source}}

  defp normalize_channel(channel) when is_atom(channel), do: {:ok, Atom.to_string(channel)}

  defp normalize_channel(channel) when is_binary(channel) do
    normalized = String.trim(channel)

    if normalized == "" do
      {:error, {:invalid_rendering_channel, channel}}
    else
      {:ok, normalized}
    end
  end

  defp normalize_channel(channel), do: {:error, {:invalid_rendering_channel, channel}}

  defp normalize_channel_declaration(channel, %{} = declaration) do
    render_key = Map.get(declaration, :render_key, Map.get(declaration, "render_key"))
    render_version = Map.get(declaration, :render_version, Map.get(declaration, "render_version"))

    with {:ok, normalized_render_key} <- normalize_render_key(channel, render_key),
         {:ok, normalized_render_version} <- normalize_render_version(channel, render_version) do
      {:ok,
       %{
         render_key: normalized_render_key,
         render_version: normalized_render_version
       }}
    end
  end

  defp normalize_channel_declaration(channel, declaration),
    do: {:error, {:invalid_channel_rendering, channel, declaration}}

  defp normalize_render_key(channel, render_key) when is_binary(render_key) do
    normalized = String.trim(render_key)

    if normalized == "" do
      {:error, {:blank_render_key, channel}}
    else
      {:ok, normalized}
    end
  end

  defp normalize_render_key(channel, render_key),
    do: {:error, {:invalid_render_key, channel, render_key}}

  defp normalize_render_version(_channel, render_version)
       when is_integer(render_version) and render_version > 0,
       do: {:ok, render_version}

  defp normalize_render_version(channel, render_version),
    do: {:error, {:invalid_render_version, channel, render_version}}

  defp resolve_notifier_channels(notifier, trigger_params, recipient) do
    if function_exported?(notifier, :channels, 2) do
      case notifier.channels(trigger_params, recipient) do
        {:ok, channels} -> normalize_channel_list(channels)
        {:error, reason} -> {:error, {:channels_resolution_failed, reason}}
        unexpected -> {:error, {:channels_resolution_failed, {:unexpected_result, unexpected}}}
      end
    else
      {:ok, ["in_app"]}
    end
  end

  defp normalize_channel_list(channels) when is_list(channels) do
    channels
    |> Enum.reduce_while({:ok, MapSet.new()}, fn channel, {:ok, acc} ->
      case normalize_channel(channel) do
        {:ok, normalized_channel} -> {:cont, {:ok, MapSet.put(acc, normalized_channel)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, channel_set} ->
        if MapSet.size(channel_set) > 0 do
          {:ok, channel_set |> MapSet.to_list() |> Enum.sort()}
        else
          {:error, {:invalid_rendering_channels, []}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_channel_list(other), do: {:error, {:invalid_channels, other}}

  defp fallback_channel_declarations(notifier, channels) do
    Enum.into(channels, %{}, fn channel ->
      {channel,
       %{
         render_key: "#{notifier.notification_key()}.#{channel}",
         render_version: notifier.version()
       }}
    end)
  end

  defp channel_module("in_app"), do: {:ok, InApp}
  defp channel_module("email"), do: {:ok, Email}
  defp channel_module(channel), do: {:error, {:unsupported_render_channel, channel}}

  defp validate_channel_payload({:ok, module}, channel, attrs) do
    case module.validate(attrs) do
      {:ok, validated_attrs} ->
        {:ok, validated_attrs}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:invalid_channel_payload, channel, changeset}}
    end
  end

  defp validate_channel_payload({:error, reason}, _channel, _attrs), do: {:error, reason}

  defp normalize_channel_error(channel) when is_atom(channel), do: Atom.to_string(channel)
  defp normalize_channel_error(channel) when is_binary(channel), do: String.trim(channel)
  defp normalize_channel_error(channel), do: inspect(channel)
end
