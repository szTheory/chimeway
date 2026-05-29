defmodule Mailglass.TestRepo.Migrations.MailglassWebhookEvents do
  use Ecto.Migration

  # Phase 4 Wave 0 evolution wrapper. Calls into `Mailglass.Migration.up/0`
  # which dispatches based on `@current_version` — bumps the DB from V01
  # (shipped in Phase 2) to V02 (Phase 4 Wave 0).
  #
  # `down/0` rolls back ONLY to V01 (not to 0) by passing `version: 1`.
  # The previous migration wrapper (`00000000000001_mailglass_init.exs`)
  # owns V01 lifecycle — letting both wrappers claim V01 in their down
  # paths causes V01 to be rolled back twice on `mix ecto.rollback --all`,
  # or (equivalently) the interleaved plain-Ecto migration 2 to re-apply
  # against a fully-dropped schema.
  def up, do: Mailglass.Migration.up()

  def down, do: Mailglass.Migration.down(version: 1)
end
