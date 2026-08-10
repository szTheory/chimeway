defmodule Chimeway.Test.ArtifactConsumerFixtureSource do
  @fixture Path.expand("../../priv/adoption_proof/artifact_consumer_fixture.ex", __DIR__)
  @external_resource @fixture

  def fixture, do: @fixture
end

Code.require_file(Chimeway.Test.ArtifactConsumerFixtureSource.fixture())
