if Code.ensure_loaded?(Mailglass) do
  defmodule Chimeway.Adapters.Mailglass do
    @moduledoc """
    Mailglass-backed email adapter for Chimeway outbound delivery.

    Product-facing name: `Chimeway.Adapter.Mailglass` (see ECOS-01). Implementation
    module: `Chimeway.Adapters.Mailglass` (D-07).

    Mailglass requires Elixir ~> 1.18 when enabled. Chimeway core compiles on 1.17+;
    run mailglass adapter tests on Elixir 1.18+ (see Phase 54 research).

    Outbound `deliver/2` is implemented in plan 54-02. Webhook callbacks are Phase 55.
    """

    @behaviour Chimeway.Adapter

    @compile {:no_warn_undefined,
              [
                Mailglass.Outbound,
                Mailglass.Message,
                Mailglass.Tenancy,
                Mailglass.Error
              ]}

    @impl Chimeway.Adapter
    def deliver(_delivery, _config), do: not_implemented()

    defp not_implemented do
      {:error, :permanent, %{reason: :not_implemented}}
    end
  end
end
