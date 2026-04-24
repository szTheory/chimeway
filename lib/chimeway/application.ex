defmodule Chimeway.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
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
end
