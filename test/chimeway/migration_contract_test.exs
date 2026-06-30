defmodule Chimeway.MigrationContractTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Repo

  test "public migration assertions are explicitly labeled" do
    labeled_tests =
      __MODULE__.__info__(:functions)
      |> Keyword.keys()
      |> Enum.map(&Atom.to_string/1)
      |> Enum.filter(&String.starts_with?(&1, "test "))
      |> Enum.reject(&String.contains?(&1, "public migration assertions are explicitly labeled"))
      |> Enum.filter(fn name ->
        String.contains?(name, "legacy") or
          String.contains?(name, "public-schema compatibility")
      end)

    assert length(labeled_tests) >= 2,
           "current public-schema checks must be named as legacy compatibility proof"
  end

  test "events and notifications tables exist with required named indexes" do
    assert regclass("chimeway_events")
    assert regclass("chimeway_notifications")

    assert regclass("chimeway_events_idempotency_key_index")

    assert regclass("chimeway_notifications_event_recipient_index")
    assert regclass("chimeway_notifications_inbox_read_inserted_index")
  end

  test "phase 27 state spine tables and columns exist" do
    assert regclass("chimeway_signals")

    assert workflow_runs_column("tenant_id") == {false, "character varying"}
    assert workflow_runs_column("pending_signals") == {true, "ARRAY"}
    assert workflow_runs_column("suspended_until") == {true, "timestamp without time zone"}
    assert workflow_runs_column("terminal_reason") == {true, "character varying"}
  end

  defp regclass(name) do
    sql = "SELECT to_regclass($1)"

    case Ecto.Adapters.SQL.query!(Repo, sql, ["public." <> name]).rows do
      [[nil]] -> nil
      [[value]] -> value
    end
  end

  defp workflow_runs_column(column_name) do
    sql = """
    SELECT is_nullable = 'YES', data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'chimeway_workflow_runs'
      AND column_name = $1
    """

    case Ecto.Adapters.SQL.query!(Repo, sql, [column_name]).rows do
      [[is_nullable, data_type]] -> {is_nullable, data_type}
      _ -> nil
    end
  end
end
