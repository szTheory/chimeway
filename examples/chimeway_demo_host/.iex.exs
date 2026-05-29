# Start Chimeway (Repo + Oban) for IEx trace walkthroughs.
# DemoHost.Application supervises Phoenix only; Chimeway is started on demand.
{:ok, _} = Application.ensure_all_started(:chimeway)
