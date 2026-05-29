defmodule Mailglass.TestRepo.Migrations.MailglassV04 do
  use Ecto.Migration

  def up, do: Mailglass.Migration.up()

  def down, do: Mailglass.Migration.down(version: 3)
end
