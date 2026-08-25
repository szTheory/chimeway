defmodule AlphaTwin.Runner do
  @moduledoc false

  def run!(attrs) when is_map(attrs) do
    # This boundary accepts only opaque references and safe lifecycle facts. The host
    # retains raw token and one-time-intent authority; no host secret is returned.
    AlphaTwin.ProofSummary.render!(attrs)
  end
end
