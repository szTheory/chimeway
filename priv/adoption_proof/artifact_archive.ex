defmodule Chimeway.AdoptionProof.ArtifactArchive do
  @moduledoc false

  @runner "scripts/prove-accrue-consumer.exs"
  @fixture "priv/adoption_proof/artifact_consumer_fixture.ex"

  @spec with_validated_archive(Path.t(), String.t(), (Path.t() -> term())) ::
          {:ok, term()} | {:error, String.t()}
  def with_validated_archive(archive, expected_digest, callback)
      when is_binary(archive) and is_binary(expected_digest) and is_function(callback, 1) do
    scratch =
      Path.join(
        System.tmp_dir!(),
        "chimeway_adoption_archive_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(scratch)

    try do
      actual_digest = :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)

      if not secure_equal?(actual_digest, expected_digest),
        do: throw({:provenance, "archive digest mismatch"})

      entries = :erl_tar.extract(String.to_charlist(archive), [:memory])
      metadata = fetch_entry!(entries, ~c"metadata.config")
      contents = fetch_entry!(entries, ~c"contents.tar.gz")
      config = parse_metadata!(metadata)
      validate_metadata!(config)
      extract_contents!(contents, scratch)
      root = artifact_root!(scratch)
      validate_root!(root, scratch, config)
      {:ok, callback.(root)}
    rescue
      _ -> {:error, "archive validation failed"}
    catch
      {:provenance, message} -> {:error, message}
    after
      File.rm_rf!(scratch)
    end
  end

  @spec secure_equal?(String.t(), String.t()) :: boolean()
  def secure_equal?(left, right) when byte_size(left) == byte_size(right),
    do: :crypto.hash(:sha256, left) == :crypto.hash(:sha256, right)

  def secure_equal?(_, _), do: false

  defp fetch_entry!({:ok, entries}, name) do
    case Enum.find(entries, fn {entry, _} -> entry == name end) do
      {^name, body} -> body
      _ -> throw({:provenance, "archive is missing required package data"})
    end
  end

  defp fetch_entry!(_, _), do: throw({:provenance, "archive extraction failed"})

  defp parse_metadata!(metadata) do
    path =
      Path.join(
        System.tmp_dir!(),
        "chimeway_adoption_metadata_#{System.unique_integer([:positive])}"
      )

    File.write!(path, metadata)

    try do
      case :file.consult(String.to_charlist(path)) do
        {:ok, terms} when is_list(terms) -> Map.new(terms)
        _ -> throw({:provenance, "package metadata is malformed"})
      end
    after
      File.rm(path)
    end
  end

  defp validate_metadata!(config) do
    files = Map.get(config, "files") || Map.get(config, <<"files">>)
    name = Map.get(config, "name") || Map.get(config, <<"name">>)
    version = Map.get(config, "version") || Map.get(config, <<"version">>)

    unless name == "chimeway" and is_binary(version) and is_list(files) and @runner in files and
             @fixture in files do
      throw({:provenance, "package metadata does not match required proof files"})
    end
  end

  defp extract_contents!(contents, scratch) do
    case :erl_tar.table({:binary, contents}, [:compressed]) do
      {:ok, entries} ->
        Enum.each(entries, fn entry ->
          name = if is_list(entry), do: entry, else: elem(entry, 0)
          path = List.to_string(name)

          if Path.type(path) == :absolute or path == ".." or String.contains?(path, "../"),
            do: throw({:provenance, "archive contains unsafe paths"})
        end)

      _ ->
        throw({:provenance, "package contents are malformed"})
    end

    case :erl_tar.extract({:binary, contents}, [:compressed, cwd: String.to_charlist(scratch)]) do
      :ok -> :ok
      _ -> throw({:provenance, "package contents could not be unpacked"})
    end
  end

  defp artifact_root!(scratch) do
    candidates =
      [scratch | Path.wildcard(Path.join(scratch, "*"))]
      |> Enum.filter(&File.regular?(Path.join(&1, "mix.exs")))

    case candidates do
      [root] -> Path.expand(root)
      _ -> throw({:provenance, "archive must contain exactly one package root"})
    end
  end

  defp validate_root!(root, scratch, config) do
    unless Path.expand(root) == Path.expand(scratch) or
             String.starts_with?(Path.expand(root), Path.expand(scratch) <> "/"),
           do: throw({:provenance, "package root escaped fixture storage"})

    source = File.read!(Path.join(root, "mix.exs"))
    version = Map.get(config, "version") || Map.get(config, <<"version">>)

    unless Regex.match?(~r/@version\s+"#{Regex.escape(version)}"/, source) and
             File.regular?(Path.join(root, @runner)) and File.regular?(Path.join(root, @fixture)),
           do: throw({:provenance, "unpacked package does not match metadata"})
  end
end
