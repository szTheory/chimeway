defmodule Chimeway.Rendering.Preview do
  @moduledoc """
  Pure preview surface over the production rendering pipeline.
  """

  alias Chimeway.{Notifier, Rendering}

  @enforce_keys [:channel, :render_key, :render_version, :render_data]
  defstruct [:channel, :render_key, :render_version, :render_data]

  @type t :: %__MODULE__{
          channel: String.t(),
          render_key: String.t(),
          render_version: pos_integer(),
          render_data: map()
        }

  @spec preview(module(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def preview(notifier, params, opts \\ [])

  def preview(notifier, params, opts) when is_atom(notifier) and is_map(params) and is_list(opts) do
    with {:ok, recipient} <- fetch_required_option(opts, :recipient),
         {:ok, channel} <- fetch_required_channel(opts),
         {:ok, rendering} <- Notifier.resolve_rendering(notifier, params, recipient),
         {:ok, channel_rendering} <- fetch_channel_rendering(rendering, channel),
         {:ok, rendered_delivery} <-
           Rendering.render_delivery(
             channel,
             channel_rendering.render_key,
             channel_rendering.render_version,
             rendering.assigns
           ) do
      {:ok, struct!(__MODULE__, rendered_delivery)}
    end
  end

  def preview(notifier, _params, _opts), do: {:error, {:invalid_preview_notifier, notifier}}

  defp fetch_required_option(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_preview_option, key}}
    end
  end

  defp fetch_required_channel(opts) do
    with {:ok, channel} <- fetch_required_option(opts, :channel),
         {:ok, normalized_channel} <- normalize_channel(channel) do
      {:ok, normalized_channel}
    end
  end

  defp normalize_channel(channel) when is_atom(channel), do: {:ok, Atom.to_string(channel)}

  defp normalize_channel(channel) when is_binary(channel) do
    normalized_channel = String.trim(channel)

    if normalized_channel == "" do
      {:error, {:invalid_preview_channel, channel}}
    else
      {:ok, normalized_channel}
    end
  end

  defp normalize_channel(channel), do: {:error, {:invalid_preview_channel, channel}}

  defp fetch_channel_rendering(%{channels: channels}, channel) when is_map(channels) do
    case Map.fetch(channels, channel) do
      {:ok, channel_rendering} -> {:ok, channel_rendering}
      :error -> {:error, {:missing_render_identity, channel}}
    end
  end
end
