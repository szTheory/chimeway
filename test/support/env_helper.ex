defmodule Chimeway.TestSupport.EnvHelper do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc """
  Set app env for the duration of the current test, restoring the prior
  value on exit (or deleting the key entirely if it was absent before the
  call).

  Safe to use from `async: true` test modules for keys that are not
  concurrently mutated by other async modules — `on_exit` bounds the
  mutation per-test-in-time, not across concurrently-running modules.
  """
  def put_env_isolated(app, key, value) do
    original = Application.fetch_env(app, key)
    Application.put_env(app, key, value)

    on_exit(fn ->
      case original do
        {:ok, v} -> Application.put_env(app, key, v)
        :error -> Application.delete_env(app, key)
      end
    end)

    :ok
  end
end
