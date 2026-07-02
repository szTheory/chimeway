# Storage Prefix Upgrade and Troubleshooting

Chimeway-owned tables can run in an isolated `chimeway` schema. New installs should use that isolated Chimeway schema from the start:

```elixir
config :chimeway, prefix: "chimeway"
```

Existing public-schema legacy installs can stay where they are by setting:

```elixir
config :chimeway, prefix: false
```

That public-schema legacy mode keeps using existing public/unprefixed Chimeway tables and does not move data, copy data, rewrite data, or backfill data. Moving an existing install from public tables into the isolated Chimeway schema is a manual database operation for operators who choose that cutover.

## Prefix Matrix

| Surface | Setting | Meaning |
|---------|---------|---------|
| New migration generation | `mix chimeway.gen.migrations` | Generates migrations for Chimeway-owned tables in the isolated `chimeway` schema. |
| Legacy migration generation | `mix chimeway.gen.migrations --prefix public` | Generator-only compatibility sugar for legacy unprefixed migration output. |
| Runtime isolated schema mode | `config :chimeway, prefix: "chimeway"` | Routes Chimeway-owned `chimeway_*` tables through the isolated `chimeway` schema. |
| Runtime public-schema legacy mode | `config :chimeway, prefix: false` | Keeps using existing public/unprefixed Chimeway tables. It does not move data. |
| Oban-owned job tables | `Oban.Migration.up(prefix: "jobs")` and `config :my_app, Oban, prefix: "jobs"` | Routes Oban-owned tables separately from Chimeway storage. |

## Before You Move Public Tables

Treat public-to-`chimeway` movement as a production database change. Chimeway does not ship an automatic production move task in this release.

Do this first:

1. Take a verified database backup.
2. Schedule a maintenance window and stop application writes that can call `Chimeway.trigger/3`, inbox APIs, workflow progression, webhook processing, or recovery APIs.
3. Confirm the `chimeway` schema name is not being used for other host-owned objects.
4. Confirm the target schema does not already contain Chimeway tables with production data.
5. Run the full procedure in staging against a recent backup.

Useful preflight checks:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE 'chimeway\_%' ESCAPE '\'
ORDER BY table_schema, table_name;

SELECT to_regclass('public.chimeway_events') AS public_events,
       to_regclass('chimeway.chimeway_events') AS chimeway_events;

SELECT count(*) AS public_events FROM public.chimeway_events;
```

If both public and `chimeway` versions of the same Chimeway table exist, stop and inspect before continuing. Do not merge by hand without a reviewed migration plan.

## Manual Public-to-Chimeway Move

The safest shape is one transaction while application writes are stopped. The exact table list must match the Chimeway migrations your application has installed.

```sql
BEGIN;

CREATE SCHEMA IF NOT EXISTS chimeway;

LOCK TABLE
  public.chimeway_events,
  public.chimeway_notifications,
  public.chimeway_deliveries,
  public.chimeway_delivery_attempts
IN ACCESS EXCLUSIVE MODE;

ALTER TABLE public.chimeway_events SET SCHEMA chimeway;
ALTER TABLE public.chimeway_notifications SET SCHEMA chimeway;
ALTER TABLE public.chimeway_deliveries SET SCHEMA chimeway;
ALTER TABLE public.chimeway_delivery_attempts SET SCHEMA chimeway;

COMMIT;
```

Most real installs have additional Chimeway-owned tables for preferences, policies, workflows, digests, signals, and webhooks. Move every `public.chimeway_*` table that belongs to Chimeway in the same maintenance window. Keep host-owned tables in public unless your host app has its own separate migration plan.

After the database move, update runtime config:

```elixir
config :chimeway, prefix: "chimeway"
```

Then restart the application and run the verification checks.

## Verification Queries

Run schema-qualified checks. Do not rely on session search path.

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_name LIKE 'chimeway\_%' ESCAPE '\'
ORDER BY table_schema, table_name;

SELECT count(*) AS chimeway_events FROM chimeway.chimeway_events;
SELECT count(*) AS public_events FROM public.chimeway_events;
```

If `public.chimeway_events` no longer exists after `ALTER TABLE ... SET SCHEMA`, that is expected. If you chose a copy-based plan instead of `SET SCHEMA`, public counts should remain unchanged until your rollback window closes and you intentionally remove old public tables.

Application-level verification:

```bash
MIX_ENV=test mix test test/chimeway/repo_prefix_test.exs test/chimeway/runtime_prefix_integration_test.exs --warnings-as-errors
```

For an installed app, trigger a low-risk notification and inspect it with `Chimeway.Traces.explain_delivery/1`.

## Rollback

Keep the pre-move backup until the runtime proof has passed and operators have accepted the cutover.

If verification fails before application traffic resumes, roll back the transaction if it is still open. If it has committed and you used `ALTER TABLE ... SET SCHEMA`, stop the application again and move the same Chimeway tables back:

```sql
BEGIN;

LOCK TABLE
  chimeway.chimeway_events,
  chimeway.chimeway_notifications,
  chimeway.chimeway_deliveries,
  chimeway.chimeway_delivery_attempts
IN ACCESS EXCLUSIVE MODE;

ALTER TABLE chimeway.chimeway_delivery_attempts SET SCHEMA public;
ALTER TABLE chimeway.chimeway_deliveries SET SCHEMA public;
ALTER TABLE chimeway.chimeway_notifications SET SCHEMA public;
ALTER TABLE chimeway.chimeway_events SET SCHEMA public;

COMMIT;
```

Then restore runtime config to public-schema legacy mode:

```elixir
config :chimeway, prefix: false
```

If any step fails, stop and restore from the verified backup instead of attempting partial manual repair. The database is the source of delivery history; do not continue application traffic on a partially moved lifecycle spine.

## Oban Job Tables Are Separate

Chimeway's storage prefix routes Chimeway-owned `chimeway_*` tables only. It does not create, move, or configure `oban_jobs`.

If you run Oban in a separate schema, configure Oban with Oban-owned migration and runtime settings:

```elixir
def change do
  Oban.Migration.up(prefix: "jobs")
end
```

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  prefix: "jobs"
```

Use `Oban.Migration.down(prefix: "jobs")` for Oban rollback migrations. See [Integrating Oban for Reliable Async Dispatch](../recipes/oban-integration.md) for queue and worker configuration.
