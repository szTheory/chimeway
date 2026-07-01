# chimeway_migration: add_attempt_history_columns
defmodule InstallerHost.Repo.Migrations.AddAttemptHistoryColumns do
  @moduledoc """
  Phase 14 REL-02 (D-07): adds attempt_number and error_class columns to
  chimeway_delivery_attempts.

  Columns are nullable at the DB level. The changeset enforces
  validate_required(:attempt_number) for new rows (promoted in Plan 14-04 Task 3
  after the record_attempt/2 Multi step injects the value). Existing rows are
  backfilled with ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at);
  error_class stays NULL on historical rows because it cannot be derived from
  existing data (per CONTEXT.md D-07).
  """

  use Ecto.Migration

  @chimeway_prefix "chimeway"

  def up do
    alter chimeway_table(:chimeway_delivery_attempts) do
      add(:attempt_number, :integer, null: true)
      add(:error_class, :string, null: true)
    end

    execute(
      """
      UPDATE #{chimeway_relation(:chimeway_delivery_attempts)} AS a
      SET attempt_number = sub.rn
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY delivery_id ORDER BY inserted_at, id) AS rn
        FROM #{chimeway_relation(:chimeway_delivery_attempts)}
      ) AS sub
      WHERE a.id = sub.id;
      """,
      "UPDATE #{chimeway_relation(:chimeway_delivery_attempts)} SET attempt_number = NULL;"
    )

    create(chimeway_index(:chimeway_delivery_attempts, [:error_class]))
  end

  def down do
    drop(chimeway_index(:chimeway_delivery_attempts, [:error_class]))

    alter chimeway_table(:chimeway_delivery_attempts) do
      remove(:error_class)
      remove(:attempt_number)
    end
  end

  defp chimeway_prefix_opts(opts \\ []) do
    if @chimeway_prefix do
      Keyword.put_new(opts, :prefix, @chimeway_prefix)
    else
      opts
    end
  end

  defp chimeway_table(name, opts \\ []) do
    table(name, chimeway_prefix_opts(opts))
  end

  defp chimeway_index(table_name, columns, opts \\ []) do
    index(table_name, columns, chimeway_prefix_opts(opts))
  end

  defp chimeway_relation(:chimeway_delivery_attempts) do
    if @chimeway_prefix do
      ~s("#{@chimeway_prefix}"."chimeway_delivery_attempts")
    else
      "chimeway_delivery_attempts"
    end
  end
end
