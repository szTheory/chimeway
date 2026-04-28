defmodule Mix.Tasks.Preview.Rendering do
  @moduledoc """
  Previews notification rendering through the production library pipeline.

  The canonical preview path is the `Chimeway.preview_rendering/3` API function.
  This task is a data-only wrapper for CLI convenience.

  For advanced executable Elixir preview experimentation, use `mix run -e` or `iex -S mix`
  rather than passing executable inputs to this task.

  Usage:

      mix preview.rendering --notifier MyApp.Notifiers.CommentCreated \\
        --params-json '{"id": 1}' \\
        --recipient-json '{"id": "recipient-1"}' \\
        --channel email
  """

  use Mix.Task

  @shortdoc "Preview one channel rendering without dispatching provider traffic"

  @switches [
    notifier: :string,
    channel: :string,
    params_json: :string,
    params_file: :string,
    param: :keep,
    recipient_json: :string,
    recipient_file: :string,
    recipient_field: :keep,
    help: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {[help: true], _, _} ->
        Mix.shell().info(usage())

      {opts, _, []} ->
        with :ok <- validate_required_switches(opts),
             {:ok, notifier} <- parse_notifier(Keyword.fetch!(opts, :notifier)),
             {:ok, params} <- build_map_input(opts, :params_file, :params_json, :param),
             {:ok, recipient} <- build_map_input(opts, :recipient_file, :recipient_json, :recipient_field),
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
    has_notifier = Keyword.has_key?(opts, :notifier)
    has_channel = Keyword.has_key?(opts, :channel)
    has_params = Keyword.has_key?(opts, :params_json) or Keyword.has_key?(opts, :params_file) or Keyword.has_key?(opts, :param)
    has_recipient = Keyword.has_key?(opts, :recipient_json) or Keyword.has_key?(opts, :recipient_file) or Keyword.has_key?(opts, :recipient_field)

    if has_notifier and has_channel and has_params and has_recipient do
      :ok
    else
      {:error, :missing_required_options}
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

  defp build_map_input(opts, file_key, json_key, kv_key) do
    with {:ok, from_file} <- parse_file_json(Keyword.get(opts, file_key)),
         {:ok, from_json} <- parse_inline_json(Keyword.get(opts, json_key)),
         {:ok, from_kv} <- parse_kv_pairs(Keyword.get_values(opts, kv_key)) do
      merged =
        from_file
        |> Map.merge(from_json)
        |> Map.merge(from_kv)

      {:ok, merged}
    end
  end

  defp parse_file_json(nil), do: {:ok, %{}}

  defp parse_file_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, term} when is_map(term) -> {:ok, term}
          {:ok, _other} -> {:error, {:invalid_json_map, :file, path}}
          {:error, _reason} -> {:error, {:invalid_json, :file, path}}
        end

      {:error, reason} ->
        {:error, {:file_read_error, path, reason}}
    end
  end

  defp parse_inline_json(nil), do: {:ok, %{}}

  defp parse_inline_json(content) do
    case Jason.decode(content) do
      {:ok, term} when is_map(term) -> {:ok, term}
      {:ok, _other} -> {:error, {:invalid_json_map, :inline}}
      {:error, _reason} -> {:error, {:invalid_json, :inline}}
    end
  end

  defp parse_kv_pairs([]), do: {:ok, %{}}

  defp parse_kv_pairs(pairs) do
    Enum.reduce_while(pairs, {:ok, %{}}, fn pair, {:ok, acc} ->
      case String.split(pair, "=", parts: 2) do
        [key, value] -> {:cont, {:ok, Map.put(acc, key, value)}}
        _ -> {:halt, {:error, {:invalid_kv_pair, pair}}}
      end
    end)
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

  defp format_error(:missing_required_options) do
    "Missing required options.\n\nYou must provide --notifier, --channel, and at least one source for params and recipient.\n\n#{usage()}"
  end

  defp format_error({:invalid_json_map, source}) do
    "Preview rendering failed: JSON from #{source} must be a map/object"
  end

  defp format_error({:invalid_json_map, source, path}) do
    "Preview rendering failed: JSON from #{source} (#{path}) must be a map/object"
  end

  defp format_error({:invalid_json, source, path}) do
    "Preview rendering failed: Invalid JSON syntax in #{source} (#{path})"
  end

  defp format_error({:invalid_json, source}) do
    "Preview rendering failed: Invalid JSON syntax in #{source}"
  end

  defp format_error(reason), do: "Preview rendering failed: #{inspect(reason)}"

  defp usage do
    """
    Usage: mix preview.rendering --notifier MODULE --channel CHANNEL [DATA FLAGS]

    Required options:
      --notifier          notifier module name, for example MyApp.Notifiers.CommentCreated
      --channel           channel name to preview, for example email or in_app

    Data flags (at least one for params, one for recipient):
      --params-json       Inline JSON string for params
      --params-file       Path to JSON file for params
      --param             Key=value pair (can be repeated)

      --recipient-json    Inline JSON string for recipient
      --recipient-file    Path to JSON file for recipient
      --recipient-field   Key=value pair (can be repeated)
    """
    |> String.trim_trailing()
  end
end
