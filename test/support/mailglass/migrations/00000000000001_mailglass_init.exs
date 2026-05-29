defmodule Mailglass.TestRepo.Migrations.MailglassInit do
  use Ecto.Migration

  def up, do: Mailglass.Migration.up()

  def down, do: Mailglass.Migration.down()
end
