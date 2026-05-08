# Installation

This guide will walk you through installing Chimeway and configuring it for your Elixir application.

## 1. Add Dependency

Add `chimeway` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0.0"}
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

Now that Chimeway is installed and running, you're ready to start building notifications. Head over to the [Getting Started](getting-started.md) guide to create your first notification!