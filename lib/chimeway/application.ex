defmodule Chimeway.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    validate_channel_render_modules!()

    children =
      [
        Chimeway.Repo
      ] ++ oban_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chimeway.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp oban_child do
    if Code.ensure_loaded?(Oban) do
      case Application.get_env(:chimeway, Oban) do
        nil -> []
        config -> [{Oban, config}]
      end
    else
      []
    end
  end

  defp validate_channel_render_modules! do
    registry = Application.get_env(:chimeway, :channel_render_modules, %{})

    Enum.each(registry, fn {channel, module} ->
      cond do
        not is_atom(module) ->
          raise ArgumentError,
                "[chimeway] :channel_render_modules[#{inspect(channel)}] must be a module atom, " <>
                  "got: #{inspect(module)}"

        not Code.ensure_loaded?(module) ->
          raise ArgumentError,
                "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                  "could not be loaded"

        not function_exported?(module, :validate, 1) ->
          raise ArgumentError,
                "[chimeway] :channel_render_modules[#{inspect(channel)}] module #{inspect(module)} " <>
                  "does not export validate/1"

        true ->
          :ok
      end
    end)
  end
end
