{:ok, _} = Application.ensure_all_started(:chimeway)

case DemoHost.Seeds.run() do
  {:ok, _} ->
    IO.puts("TeamPulse demo data seeded.")
    IO.puts("Admin: #{DemoHost.Seeds.admin_url()}")
    IO.puts("Search recipient: #{DemoHost.Seeds.alex_identity()}")

  {:error, reason} ->
    IO.puts(:stderr, "Seed failed: #{inspect(reason)}")
    System.halt(1)
end
