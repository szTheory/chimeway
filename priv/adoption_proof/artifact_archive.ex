defmodule Chimeway.AdoptionProof.ArtifactArchive do
  @moduledoc false

  @runner "scripts/prove-accrue-consumer.exs"
  @fixture "priv/adoption_proof/artifact_consumer_fixture.ex"
  @tar_block_size 512
  @max_outer_archive_bytes 32 * 1024 * 1024
  @max_compressed_contents_bytes 16 * 1024 * 1024
  @max_decompressed_contents_bytes 64 * 1024 * 1024
  @max_metadata_bytes 1 * 1024 * 1024
  @max_members 4_096
  @max_regular_member_bytes 8 * 1024 * 1024

  @spec with_validated_archive(Path.t(), String.t(), (Path.t() -> term())) ::
          {:ok, term()} | {:error, String.t()}
  def with_validated_archive(archive, expected_digest, callback)
      when is_binary(archive) and is_binary(expected_digest) and is_function(callback, 1) do
    with_validated_archive(archive, expected_digest, callback, [])
  end

  @doc false
  @spec with_validated_archive(Path.t(), String.t(), (Path.t() -> term()), keyword()) ::
          {:ok, term()} | {:error, String.t()}
  def with_validated_archive(archive, expected_digest, callback, opts)
      when is_binary(archive) and is_binary(expected_digest) and is_function(callback, 1) and
             is_list(opts) do
    scratch =
      Path.join(
        System.tmp_dir!(),
        "chimeway_adoption_archive_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(scratch)

    try do
      archive_binary = read_bounded_archive!(archive, opts)
      actual_digest = :crypto.hash(:sha256, archive_binary) |> Base.encode16(case: :lower)

      if not secure_equal?(actual_digest, expected_digest),
        do: throw({:provenance, "archive digest mismatch"})

      entries = :erl_tar.extract({:binary, archive_binary}, [:memory])
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

  defp read_bounded_archive!(archive, opts) do
    archive_opened = Keyword.get(opts, :archive_opened, fn -> :ok end)

    unless is_function(archive_opened, 0),
      do: throw({:provenance, "archive validation failed"})

    archive
    |> File.open!([:read, :binary])
    |> then(fn device ->
      try do
        archive_opened.()

        case IO.binread(device, @max_outer_archive_bytes + 1) do
          :eof ->
            throw({:provenance, "archive extraction failed"})

          binary when byte_size(binary) > @max_outer_archive_bytes ->
            throw({:provenance, "archive validation failed"})

          binary when is_binary(binary) ->
            binary
        end
      after
        File.close(device)
      end
    end)
  end

  defp fetch_entry!({:ok, entries}, name) do
    case Enum.find(entries, fn {entry, _} -> entry == name end) do
      {^name, body} -> body
      _ -> throw({:provenance, "archive is missing required package data"})
    end
  end

  defp fetch_entry!(_, _), do: throw({:provenance, "archive extraction failed"})

  defp parse_metadata!(metadata) do
    if byte_size(metadata) > @max_metadata_bytes, do: metadata_error!()

    metadata
    |> parse_metadata_whitespace!()
    |> parse_metadata_forms!(%{})
  end

  defp parse_metadata_forms!(<<>>, config), do: config

  defp parse_metadata_forms!(metadata, config) do
    {key, value, rest} = parse_metadata_pair!(metadata)

    rest =
      rest
      |> parse_metadata_whitespace!()
      |> parse_metadata_dot!()
      |> parse_metadata_whitespace!()

    config = put_selected_metadata!(config, key, value)
    parse_metadata_forms!(rest, config)
  end

  defp parse_metadata_pair!(metadata) do
    metadata = parse_metadata_open!(metadata, "{") |> parse_metadata_whitespace!()
    {key, metadata} = parse_metadata_binary!(metadata)

    metadata =
      parse_metadata_comma!(parse_metadata_whitespace!(metadata)) |> parse_metadata_whitespace!()

    {value, metadata} = parse_metadata_value!(metadata)
    metadata = parse_metadata_close!(parse_metadata_whitespace!(metadata), "}")
    {key, value, metadata}
  end

  defp parse_metadata_value!(metadata) do
    case metadata do
      <<"<<\"", _::binary>> ->
        {value, rest} = parse_metadata_binary!(metadata)
        {{:binary, value}, rest}

      <<"[", _::binary>> ->
        parse_metadata_binary_list!(metadata)

      _ ->
        metadata_error!()
    end
  end

  defp parse_metadata_binary_list!(<<"[", metadata::binary>>) do
    metadata = parse_metadata_whitespace!(metadata)
    parse_metadata_binary_list_items!(metadata, [])
  end

  defp parse_metadata_binary_list_items!(<<"]", rest::binary>>, items),
    do: {{:list, Enum.reverse(items)}, rest}

  defp parse_metadata_binary_list_items!(metadata, items) do
    {item, metadata} = parse_metadata_binary!(metadata)
    metadata = parse_metadata_whitespace!(metadata)

    case metadata do
      <<",", rest::binary>> ->
        parse_metadata_binary_list_items!(parse_metadata_whitespace!(rest), [item | items])

      <<"]", rest::binary>> ->
        {{:list, Enum.reverse([item | items])}, rest}

      _ ->
        metadata_error!()
    end
  end

  defp parse_metadata_binary!(<<"<<\"", metadata::binary>>) do
    {value, rest} = parse_metadata_binary_bytes!(metadata, [])
    unless String.valid?(value), do: metadata_error!()
    {value, rest}
  end

  defp parse_metadata_binary!(_metadata), do: metadata_error!()

  defp parse_metadata_binary_bytes!(<<"\">>", rest::binary>>, bytes),
    do: {bytes |> Enum.reverse() |> IO.iodata_to_binary(), rest}

  defp parse_metadata_binary_bytes!(<<byte, rest::binary>>, bytes)
       when byte >= 32 and byte <= 126 and byte not in [?\\, ?"],
       do: parse_metadata_binary_bytes!(rest, [<<byte>> | bytes])

  defp parse_metadata_binary_bytes!(_metadata, _bytes), do: metadata_error!()

  defp put_selected_metadata!(config, key, value)
       when key in [<<"name">>, <<"version">>, <<"files">>] do
    if Map.has_key?(config, key), do: metadata_error!()
    Map.put(config, key, selected_metadata_value!(key, value))
  end

  defp put_selected_metadata!(config, _key, _value), do: config

  defp selected_metadata_value!(key, {:binary, value}) when key in [<<"name">>, <<"version">>],
    do: value

  defp selected_metadata_value!(<<"files">>, {:list, files}), do: files
  defp selected_metadata_value!(_key, _value), do: metadata_error!()

  defp parse_metadata_whitespace!(<<byte, rest::binary>>) when byte in [9, 10, 13, 32],
    do: parse_metadata_whitespace!(rest)

  defp parse_metadata_whitespace!(metadata), do: metadata

  defp parse_metadata_open!(<<expected, rest::binary>>, <<expected>>), do: rest
  defp parse_metadata_open!(_metadata, _expected), do: metadata_error!()

  defp parse_metadata_close!(<<expected, rest::binary>>, <<expected>>), do: rest
  defp parse_metadata_close!(_metadata, _expected), do: metadata_error!()

  defp parse_metadata_comma!(<<",", rest::binary>>), do: rest
  defp parse_metadata_comma!(_metadata), do: metadata_error!()

  defp parse_metadata_dot!(<<".", rest::binary>>), do: rest
  defp parse_metadata_dot!(_metadata), do: metadata_error!()

  defp metadata_error!, do: throw({:provenance, "package metadata is malformed"})

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
    decompressed_contents = decompress_contents!(contents)
    members = scan_members!(decompressed_contents)
    bodies = extract_regular_bodies!(decompressed_contents)
    materialize_members!(members, bodies, scratch)
    validate_materialized_tree!(scratch)
  end

  # The header scan deliberately happens before `:erl_tar` sees a filesystem path.
  # `:memory` returns bodies for ordinary files; no archive-controlled link or special
  # member is ever allowed to create an object on disk.
  defp decompress_contents!(contents) do
    if byte_size(contents) > @max_compressed_contents_bytes,
      do: throw({:provenance, "package contents are malformed"})

    inflate_contents!(contents)
  end

  defp inflate_contents!(contents) do
    zlib = :zlib.open()

    try do
      :ok = :zlib.inflateInit(zlib, 31, :error)

      contents
      |> binary_chunks()
      |> Enum.reduce({[], 0}, fn chunk, {chunks, total} ->
        inflate_chunk!(zlib, chunk, chunks, total)
      end)
      |> drain_inflater!(zlib)
      |> elem(0)
      |> Enum.reverse()
      |> IO.iodata_to_binary()
    rescue
      _ -> throw({:provenance, "package contents are malformed"})
    after
      :zlib.inflateEnd(zlib)
      :zlib.close(zlib)
    end
  end

  defp binary_chunks(binary), do: binary_chunks(binary, [])

  defp binary_chunks(<<>>, chunks), do: Enum.reverse(chunks)

  defp binary_chunks(binary, chunks) do
    chunk_size = min(byte_size(binary), 64 * 1024)
    <<chunk::binary-size(chunk_size), rest::binary>> = binary
    binary_chunks(rest, [chunk | chunks])
  end

  defp inflate_chunk!(zlib, chunk, chunks, total) do
    case :zlib.safeInflate(zlib, chunk) do
      {status, output} when status in [:continue, :finished] ->
        append_inflated_chunk!(zlib, status, output, chunks, total)

      {:need_dictionary, _adler, _output} ->
        throw({:provenance, "package contents are malformed"})
    end
  end

  defp drain_inflater!({chunks, total}, zlib) do
    case :zlib.safeInflate(zlib, []) do
      {:continue, output} ->
        {chunks, total} = append_inflated_chunk!(zlib, :continue, output, chunks, total)
        drain_inflater!({chunks, total}, zlib)

      {:finished, output} ->
        append_inflated_chunk!(zlib, :finished, output, chunks, total)

      {:need_dictionary, _adler, _output} ->
        throw({:provenance, "package contents are malformed"})
    end
  end

  defp append_inflated_chunk!(zlib, :finished, output, chunks, total) do
    {chunks, total} = append_output!(output, chunks, total)

    case :zlib.safeInflate(zlib, []) do
      {:finished, []} -> {chunks, total}
      _ -> throw({:provenance, "package contents are malformed"})
    end
  end

  defp append_inflated_chunk!(_zlib, :continue, output, chunks, total),
    do: append_output!(output, chunks, total)

  defp append_output!(output, chunks, total) do
    output = IO.iodata_to_binary(output)
    next_total = total + byte_size(output)

    if next_total > @max_decompressed_contents_bytes,
      do: throw({:provenance, "package contents are malformed"})

    {[output | chunks], next_total}
  end

  defp scan_members!(contents), do: scan_members!(contents, [], %{})

  defp scan_members!(<<0::size(8192), rest::binary>>, members, _paths) when rest == <<>>,
    do: Enum.reverse(members)

  defp scan_members!(<<0::size(8192), _rest::binary>>, _members, _paths),
    do: throw({:provenance, "package contents are malformed"})

  defp scan_members!(contents, _members, _paths) when byte_size(contents) < @tar_block_size,
    do: throw({:provenance, "package contents are malformed"})

  defp scan_members!(<<header::binary-size(@tar_block_size), rest::binary>>, members, paths) do
    validate_header_checksum!(header)
    name = header_name!(header)
    type = :binary.at(header, 156)
    size = header_size!(header)
    path = normalized_member_path!(name, type)
    validate_member_type!(type)
    validate_member_size!(type, size)
    validate_member_count!(members)
    validate_unique_path!(paths, path)

    padding = padding_for!(size)

    if byte_size(rest) < size + padding do
      throw({:provenance, "package contents are malformed"})
    end

    <<_body::binary-size(size), _padding::binary-size(padding), remaining::binary>> = rest
    member = %{path: path, type: type, size: size}
    scan_members!(remaining, [member | members], Map.put(paths, path, type))
  end

  defp validate_member_size!(?5, 0), do: :ok

  defp validate_member_size!(type, size)
       when type in [0, ?0] and size <= @max_regular_member_bytes,
       do: :ok

  defp validate_member_size!(_, _), do: throw({:provenance, "package contents are malformed"})

  defp validate_member_count!(members) when length(members) < @max_members, do: :ok

  defp validate_member_count!(_members),
    do: throw({:provenance, "package contents are malformed"})

  defp validate_header_checksum!(header) do
    expected = header |> binary_part(148, 8) |> tar_octal!()

    actual =
      header
      |> binary_part(0, 148)
      |> then(&:binary.bin_to_list/1)
      |> Enum.sum()
      |> Kernel.+(8 * 32)
      |> Kernel.+(header |> binary_part(156, 356) |> :binary.bin_to_list() |> Enum.sum())

    if actual != expected, do: throw({:provenance, "package contents are malformed"})
  end

  defp header_name!(header) do
    name = tar_string!(binary_part(header, 0, 100))
    prefix = tar_string!(binary_part(header, 345, 155))

    case {prefix, name} do
      {"", ""} -> throw({:provenance, "package contents are malformed"})
      {"", name} -> name
      {prefix, ""} -> prefix
      {prefix, name} -> prefix <> "/" <> name
    end
  end

  defp header_size!(header), do: header |> binary_part(124, 12) |> tar_octal!()

  defp tar_string!(field) do
    case :binary.split(field, <<0>>) do
      [value, trailing] ->
        if trailing == :binary.copy(<<0>>, byte_size(trailing)),
          do: value,
          else: throw({:provenance, "package contents are malformed"})

      [value] ->
        value

      _ ->
        throw({:provenance, "package contents are malformed"})
    end
  end

  defp tar_octal!(field) do
    {value, trailing} = field |> :binary.bin_to_list() |> Enum.split_while(&(&1 != 0))
    value = value |> to_string() |> String.trim()

    cond do
      Enum.any?(trailing, &(&1 not in [0, 32])) ->
        throw({:provenance, "package contents are malformed"})

      value == "" ->
        0

      not Regex.match?(~r/\A[0-7]+\z/, value) ->
        throw({:provenance, "package contents are malformed"})

      true ->
        String.to_integer(value, 8)
    end
  rescue
    ArgumentError -> throw({:provenance, "package contents are malformed"})
  end

  defp normalized_member_path!(name, type) do
    path = if type == ?5, do: String.trim_trailing(name, "/"), else: name

    if Path.type(path) == :absolute or path == "" or
         Enum.any?(String.split(path, "/", trim: false), &(&1 in ["", ".", ".."])) do
      throw({:provenance, "archive contains unsafe paths"})
    end

    path
  end

  defp validate_member_type!(type) when type in [0, ?0, ?5], do: :ok
  defp validate_member_type!(_), do: throw({:provenance, "archive contains unsupported members"})

  defp validate_unique_path!(paths, path) do
    conflict? =
      Map.has_key?(paths, path) or
        Enum.any?(paths, fn {existing, existing_type} ->
          existing_type != ?5 and
            (String.starts_with?(existing, path <> "/") or
               String.starts_with?(path, existing <> "/"))
        end)

    if conflict?,
      do: throw({:provenance, "archive contains conflicting paths"})
  end

  defp padding_for!(size) when is_integer(size) and size >= 0,
    do: rem(@tar_block_size - rem(size, @tar_block_size), @tar_block_size)

  defp extract_regular_bodies!(contents) do
    case :erl_tar.extract({:binary, contents}, [:memory]) do
      {:ok, entries} ->
        Map.new(entries, fn {name, body} -> {List.to_string(name), body} end)

      _ ->
        throw({:provenance, "package contents could not be unpacked"})
    end
  end

  defp materialize_members!(members, bodies, scratch) do
    Enum.each(members, fn %{path: path, type: type, size: size} ->
      destination = destination!(scratch, path)

      case type do
        ?5 ->
          File.mkdir_p!(destination)

        _ ->
          body = Map.fetch!(bodies, path)

          if byte_size(body) != size,
            do: throw({:provenance, "package contents could not be unpacked"})

          File.mkdir_p!(Path.dirname(destination))
          File.write!(destination, body, [:binary])
      end
    end)
  end

  defp destination!(scratch, path) do
    destination = Path.expand(Path.join(scratch, path))
    expanded_scratch = Path.expand(scratch)

    unless destination == expanded_scratch or
             String.starts_with?(destination, expanded_scratch <> "/"),
           do: throw({:provenance, "archive contains unsafe paths"})

    destination
  end

  defp validate_materialized_tree!(scratch) do
    scratch
    |> Path.join("**")
    |> Path.wildcard(match_dot: true)
    |> Enum.each(fn path ->
      case File.lstat(path) do
        {:ok, %File.Stat{type: type}} when type in [:regular, :directory] -> :ok
        _ -> throw({:provenance, "package contents could not be unpacked"})
      end
    end)
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
