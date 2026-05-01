defmodule Chimeway.Rendering.Channel do
  @moduledoc """
  Behaviour contract for channel-specific render validation.

  Every channel render validator — built-in or host-defined — must implement
  this behaviour. Declaring `use Chimeway.Rendering.Channel` injects
  `@behaviour Chimeway.Rendering.Channel` so the Elixir compiler issues warnings
  for typo'd or missing `validate/1` implementations.

  ## Usage

      defmodule MyApp.Channels.Slack do
        use Chimeway.Rendering.Channel

        @impl Chimeway.Rendering.Channel
        def validate(attrs) when is_map(attrs) do
          # Ecto.Changeset validation producing a stringified map
          {:ok, attrs}
        end

        def validate(_other) do
          {:error, :invalid}
        end
      end

  ## Contract

  `validate/1` receives the raw render attrs map from the notifier's `rendering/2`
  callback and must return `{:ok, stringified_map}` on success or
  `{:error, %Ecto.Changeset{}}` on validation failure.

  The returned map MUST have string keys (produced by `Atom.to_string/1`) so it
  survives JSONB round-trips and Oban serialization without key-type drift.
  """

  @callback validate(attrs :: map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Chimeway.Rendering.Channel
    end
  end
end
