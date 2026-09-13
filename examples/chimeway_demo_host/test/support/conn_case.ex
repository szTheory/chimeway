defmodule DemoHostWeb.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  import ExUnit.Assertions

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import DemoHostWeb.ConnCase, only: [assert_trace_recipient_redacted: 4]

      @endpoint DemoHostWeb.Endpoint
    end
  end

  setup tags do
    {:ok, _} = Application.ensure_all_started(:chimeway)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def assert_trace_recipient_redacted(html, delivery_id, tenant_id, durable_recipient_ref) do
    assert {:ok, explanation} =
             Chimeway.Traces.explain_delivery(delivery_id, tenant_id: tenant_id)

    assert is_binary(explanation.recipient_id)
    assert explanation.recipient_id != durable_recipient_ref

    assert html =~ ChimewayAdmin.Redaction.redact_recipient(explanation.recipient_id)
    refute html =~ explanation.recipient_id
    refute html =~ durable_recipient_ref

    explanation
  end
end
