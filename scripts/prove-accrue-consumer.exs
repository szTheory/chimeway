#!/usr/bin/env elixir

fixture = Path.expand("../test/support/artifact_consumer_fixture.ex", __DIR__)
Code.require_file(fixture)

case System.argv() do
  ["--artifact-root", root] when Path.type(root) == :absolute ->
    if File.dir?(root) do
      try do
        proof = Chimeway.Test.ArtifactConsumerFixture.prove_accrue!(root)
        IO.puts(proof.output)
      rescue
        error ->
          IO.warn("Accrue artifact proof failed: #{Exception.message(error)}")
          System.halt(1)
      end
    else
      IO.warn("--artifact-root must name an unpacked artifact directory")
      System.halt(2)
    end

  _ ->
    IO.warn(
      "usage: MIX_ENV=test mix run scripts/prove-accrue-consumer.exs -- --artifact-root /absolute/path/to/unpacked/chimeway"
    )

    System.halt(2)
end
