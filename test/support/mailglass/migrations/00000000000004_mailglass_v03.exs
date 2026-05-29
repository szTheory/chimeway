defmodule Mailglass.TestRepo.Migrations.MailglassV03 do
  use Ecto.Migration

  # Phase 12 V03 wrapper. Calls into `Mailglass.Migration.up/0`, which
  # dispatches from the repo's recorded version to the current core
  # migration version.
  def up, do: Mailglass.Migration.up()

  # Roll back only to V02. Earlier wrappers own their own down paths.
  def down, do: Mailglass.Migration.down(version: 2)
end
