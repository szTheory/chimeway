# Installation

This guide will walk you through installing Chimeway and configuring it for your Elixir application.

## 1. Add Dependency

Add `chimeway` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.1"}
  ]
end
```

Then, run `mix deps.get` in your terminal to fetch the new dependency:

```bash
mix deps.get
```

## 2. Generate and Run Migrations

Chimeway relies on a durable storage spine to ensure notifications are reliable and explainable. To set up the necessary database tables, you must generate and run the Chimeway migrations.

Generate the migrations:

```bash
mix chimeway.gen.migrations
```

This will copy the required migration files into your `priv/repo/migrations` directory.

Then, run Ecto migrations to apply them to your database:

```bash
mix ecto.migrate
```

## 3. Configuration

You need to configure Chimeway to use your application's Ecto Repo. Add the following to your `config/config.exs` (or `config/dev.exs` / `config/prod.exs` as appropriate):

```elixir
config :chimeway,
  repo: MyApp.Repo
```

Replace `MyApp.Repo` with the actual name of your application's Repo module.

Choose the runtime storage prefix explicitly. New installs should use the new isolated Chimeway schema:

```elixir
config :chimeway, prefix: "chimeway"
```

Use `prefix: false` only for an existing public-schema legacy install whose
Chimeway tables already live in public:

```elixir
config :chimeway, prefix: false
```

That legacy mode keeps using the existing unprefixed tables and does not move data.

For upgrade and troubleshooting notes, see the [Storage Prefix Upgrade guide](storage-prefix-upgrade.md).

At runtime, Chimeway queries through `Chimeway.Repo`. Configure it to use the same database where your host migrations created the `chimeway_*` tables — see [Golden Path §3](golden-path.md#3-configure-chimeway) for the full shared-database setup.

## 4. Add to Supervision Tree

Finally, add the Chimeway Supervisor to your application's supervision tree to ensure the background processing and inbox mechanics are started.

Open your application module (usually `lib/my_app/application.ex`) and add the Chimeway application to the children list:

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    # ... other children
    Chimeway.Application
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Next Steps

Follow the [Golden Path](golden-path.md) guide to define a notifier, trigger your first notification, and verify explainability with `Chimeway.Traces.explain_delivery/1`.

For inbox and channel depth, continue to [Getting Started](getting-started.md).
