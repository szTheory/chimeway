defmodule Mix.Tasks.Preview.Rendering do
  @moduledoc """
  Previews notification rendering through the production library pipeline.

  Usage:

      mix preview.rendering --notifier MyApp.Notifiers.CommentCreated --params "%{id: 1}" \
        --recipient "%{recipient_identity: \"user:1\"}" --channel email

  `--params` and `--recipient` accept either Elixir literals or a path to an `.exs` file
  that evaluates to a map.
  """

  use Mix.Task

  @shortdoc "Preview one channel rendering without dispatching provider traffic"

  @switches [notifier: :string, params: :string, recipient: :string, channel: :string, help: :boolean]
  @required_switches [:notifier, :params, :recipient, :channel]

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {[help: true], _, _} ->
        Mix.shell().info(usage())

      {opts, _, []} ->
        with :ok <- validate_required_switches(opts),
             {:ok, notifier} <- parse_notifier(Keyword.fetch!(opts, :notifier)),
             {:ok, params} <- parse_map_option(Keyword.fetch!(opts, :params), :params),
             {:ok, recipient} <- parse_map_option(Keyword.fetch!(opts, :recipient), :recipient),
             {:ok, preview} <-
               Chimeway.preview_rendering(
                 notifier,
                 params,
                 recipient: recipient,
                 channel: Keyword.fetch!(opts, :channel)
               ) do
          Mix.shell().info(format_preview(preview))
        else
          {:error, reason} ->
            Mix.shell().error(format_error(reason))
            exit({:shutdown, 1})
        end

      {_opts, _args, invalid} ->
        Mix.shell().error("Unknown options: #{Enum.join(invalid, ", ")}\n\n#{usage()}")
        exit({:shutdown, 1})
    end
  end

  defp validate_required_switches(opts) do
    missing =
      @required_switches
      |> Enum.reject(&Keyword.has_key?(opts, &1))

    case missing do
      [] -> :ok
      keys -> {:error, {:missing_required_options, keys}}
    end
  end

  defp parse_notifier(value) when is_binary(value) do
    module_name =
      if String.starts_with?(value, "Elixir.") do
        value
      else
        "Elixir." <> value
      end

    try do
      module = String.to_existing_atom(module_name)

      case Code.ensure_loaded(module) do
        {:module, ^module} -> {:ok, module}
        _ -> {:error, {:invalid_notifier, value}}
      end
    rescue
      ArgumentError -> {:error, {:invalid_notifier, value}}
    end
  end

  defp parse_map_option(value, label) when is_binary(value) do
    with {:ok, term} <- eval_input(value, label),
         true <- is_map(term) do
      {:ok, term}
    else
      false -> {:error, {:invalid_map_option, label, value}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp eval_input(value, label) do
    try do
      evaluated =
        if String.ends_with?(value, ".exs") do
          {term, _binding} = Code.eval_file(value)
          term
        else
          {term, _binding} = Code.eval_string(value)
          term
        end

      {:ok, evaluated}
    rescue
      error -> {:error, {:invalid_option_value, label, Exception.message(error)}}
    end
  end

  defp format_preview(preview) do
    """
    Preview rendering
    render_key: #{preview.render_key}
    render_version: #{preview.render_version}
    channel: #{preview.channel}
    render_data: #{inspect(preview.render_data, pretty: true)}
    """
    |> String.trim_trailing()
  end

  defp format_error({:missing_required_options, keys}) do
    missing =
      keys
      |> Enum.map_join(", ", &"--#{&1}")

    "Missing required options: #{missing}\n\n#{usage()}"
  end

  defp format_error(reason), do: "Preview rendering failed: #{inspect(reason)}"

  defp usage do
    """
    Usage: mix preview.rendering --notifier MODULE --params EXPR_OR_FILE --recipient EXPR_OR_FILE --channel CHANNEL

    Required options:
      --notifier   notifier module name, for example MyApp.Notifiers.CommentCreated
      --params     Elixir literal or .exs file that evaluates to a params map
      --recipient  Elixir literal or .exs file that evaluates to a recipient map
      --channel    channel name to preview, for example email or in_app
    """
    |> String.trim_trailing()
  end
end
