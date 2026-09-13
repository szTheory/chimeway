defmodule Mix.Tasks.Chimeway.ReconcileTenants do
  @moduledoc """
  Reports and explicitly assigns tenant ownership for legacy event trees.

      mix chimeway.reconcile_tenants --report
      mix chimeway.reconcile_tenants --event-id UUID --tenant-id TENANT

  Output is exactly one JSON object. This task never accepts tenant storage-prefix
  options and never infers ownership from lifecycle data.
  """

  use Mix.Task

  alias Chimeway.Reconciliation

  @shortdoc "Report or explicitly assign legacy tenant ownership"
  @switches [report: :boolean, event_id: :string, tenant_id: :string]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.start")

    argv
    |> parse_mode!()
    |> run_mode!()
    |> Jason.encode!()
    |> Mix.shell().info()
  end

  defp parse_mode!(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, [], []} -> normalize_mode!(opts)
      {_opts, rest, invalid} -> raise_usage!(format_parse_error(rest, invalid))
    end
  end

  defp normalize_mode!(opts) do
    report_values = Keyword.get_values(opts, :report)
    event_ids = Keyword.get_values(opts, :event_id)
    tenant_ids = Keyword.get_values(opts, :tenant_id)

    case {report_values, event_ids, tenant_ids} do
      {[true], [], []} -> :report
      {[], [event_id], [tenant_id]} -> {:assign, event_id, tenant_id}
      _ -> raise_usage!("pass exactly --report or --event-id UUID --tenant-id TENANT")
    end
  end

  defp run_mode!(:report), do: Reconciliation.report()

  defp run_mode!({:assign, event_id, tenant_id}) do
    case Reconciliation.assign_event_tree(event_id, tenant_id) do
      {:ok, result} -> result
      {:error, reason} -> Mix.raise("Tenant reconciliation failed: #{reason}")
    end
  end

  defp format_parse_error(rest, invalid) do
    details =
      [
        if(rest == [], do: nil, else: "unexpected positional arguments #{inspect(rest)}"),
        if(invalid == [], do: nil, else: "unsupported options #{inspect(invalid)}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("; ")

    "Tenant reconciliation #{details}"
  end

  defp raise_usage!(reason) do
    Mix.raise("""
    Tenant reconciliation failed: #{reason}

    Usage:
      mix chimeway.reconcile_tenants --report
      mix chimeway.reconcile_tenants --event-id UUID --tenant-id TENANT
    """)
  end
end
