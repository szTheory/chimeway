defmodule Chimeway.MigrationContractTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.Repo

  test "events and notifications tables exist with required named indexes" do
    assert regclass("chimeway_events")
    assert regclass("chimeway_notifications")

    assert regclass("chimeway_events_idempotency_key_index")

    assert regclass("chimeway_notifications_event_recipient_index")
    assert regclass("chimeway_notifications_inbox_read_inserted_index")
  end

  defp regclass(name) do
    sql = "SELECT to_regclass($1)"

    case Ecto.Adapters.SQL.query!(Repo, sql, ["public." <> name]).rows do
      [[nil]] -> nil
      [[value]] -> value
    end
  end
end
