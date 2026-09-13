defmodule DemoHostWeb.AdminTraceLiveTest do
  @moduledoc """
  Host-mount admin integration — part of the JOUR-01..08 journey suite.

  Covers JOUR-04 (admin search finds seeded invite), JOUR-07 (Sam password-reset
  suppression), and JOUR-08 (Morgan payment-escalation trace). Tagged `:journey`
  for `mix verify.journeys`.
  """
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Chimeway.{Delivery, Repo, Traces}

  @runtime_prefix "chimeway"
  @identifier_regex ~r/\A[a-z][a-z0-9_]*\z/

  setup_all :prepare_prefixed_runtime_storage
  setup :reset_chimeway_storage

  @tag :journey
  @tag :admin_truth
  test "admin command center exposes shipped operator paths", %{conn: conn} do
    conn = get(conn, "/admin/chimeway")
    assert html_response(conn, 200) =~ "Command Center"

    {:ok, view, html} = live(conn)

    assert html =~ "Open Trace Lookup"
    assert html =~ "Trace Lookup"
    assert html =~ "Feed Debug"
    assert html =~ "Definitions"
    assert html =~ "Health"
    assert html =~ "Recovery"

    rendered = render(view)
    assert rendered =~ "Command Center"
    assert rendered =~ "Open Trace Lookup"
  end

  @tag :journey
  @tag :jour_04
  test "JOUR-04 admin search finds seeded invite delivery", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.alex_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.alex_identity())

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace Detail"
    assert render(detail_view) =~ "teampulse.invite_sent"
    assert render(detail_view) =~ "teampulse-seed-invite-corr"
  end

  @tag :demo_01
  test "DEMO-01 public seed trigger writes trace rows only under isolated schema" do
    assert {:ok, %{trace: %{delivery_ids: [delivery_id | _] = delivery_ids}}} =
             DemoHost.Seeds.seed_invite()

    assert {:ok, explanation} =
             Traces.explain_delivery(delivery_id, tenant_id: DemoHost.Seeds.tenant_id())

    assert explanation.delivery_id == delivery_id
    assert explanation.notification_key == "teampulse.invite_sent"
    assert explanation.correlation_id == "teampulse-seed-invite-corr"

    assert_prefixed_only("chimeway_events", 1)
    assert_prefixed_only("chimeway_notifications", 1)
    assert_prefixed_only("chimeway_deliveries", length(delivery_ids))
    assert_prefixed_only("chimeway_delivery_attempts", length(delivery_ids))
  end

  @tag :journey
  @tag :jour_07
  test "JOUR-07 admin shows Sam password-reset suppression", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_password_reset()

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.sam_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.sam_identity())

    delivery_id =
      Enum.find(delivery_ids, &String.contains?(html, &1)) ||
        flunk("expected search results to include a seeded delivery id")

    {:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
    assert detail_html =~ "Trace Detail"

    detail = render(detail_view)
    assert detail =~ "suppressed"
    assert detail =~ "channel_disabled"
    assert detail =~ "teampulse.password_reset"
  end

  @tag :journey
  @tag :jour_08
  test "JOUR-08 admin shows Morgan payment-escalation trace", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.escalation_waiting!()

    in_app_delivery =
      delivery_ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "in_app"))

    refute is_nil(in_app_delivery)

    conn = get(conn, "/admin/chimeway/traces")
    assert html_response(conn, 200) =~ "Trace Lookup"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.morgan_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert_redacted_recipient(html, DemoHost.Seeds.morgan_identity())

    {:ok, detail_view, detail_html} =
      live(conn, "/admin/chimeway/deliveries/#{in_app_delivery.id}")

    assert detail_html =~ "Trace Detail"

    detail = render(detail_view)
    assert detail =~ "teampulse.payment_reminder"
    assert detail =~ "teampulse-seed-payment-corr"
    assert detail =~ "workflow waiting" or detail =~ "Workflow waiting"
  end

  defp assert_redacted_recipient(html, recipient_id) do
    assert html =~ ChimewayAdmin.Redaction.redact_recipient(recipient_id)
    refute html =~ recipient_id
  end

  defp prepare_prefixed_runtime_storage(_context) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      if generated_prefixed_schema_ready?() do
        :ok
      else
        drop_generated_prefixed_schema!()
        clone_public_chimeway_schema!()
      end
    end)

    :ok
  end

  defp reset_chimeway_storage(_context) do
    truncate_chimeway_rows!(@runtime_prefix)
    truncate_chimeway_rows!("public")

    :ok
  end

  defp assert_prefixed_only(table_name, expected_count) when is_integer(expected_count) do
    assert table_count(@runtime_prefix, table_name) == expected_count
    assert table_count("public", table_name) == 0
  end

  defp generated_prefixed_schema_ready? do
    schema_exists?(@runtime_prefix) and
      Enum.all?(
        [
          "chimeway_events",
          "chimeway_notifications",
          "chimeway_deliveries",
          "chimeway_delivery_attempts"
        ],
        &regclass?(@runtime_prefix, &1)
      )
  end

  defp clone_public_chimeway_schema! do
    Ecto.Adapters.SQL.query!(Repo, ~s(CREATE SCHEMA "#{@runtime_prefix}"), [])

    case chimeway_tables("public") do
      [] ->
        raise "public Chimeway tables are missing; run the base test migrations first"

      tables ->
        Enum.each(tables, fn table_name ->
          Ecto.Adapters.SQL.query!(
            Repo,
            """
            CREATE TABLE #{qualified_name(@runtime_prefix, table_name)}
            (LIKE #{qualified_name("public", table_name)} INCLUDING ALL)
            """,
            []
          )
        end)
    end
  end

  defp truncate_chimeway_rows!(schema) do
    tables = chimeway_tables(schema)

    if tables != [] do
      qualified_tables =
        tables
        |> Enum.map(&qualified_name(schema, &1))
        |> Enum.join(", ")

      Ecto.Adapters.SQL.query!(
        Repo,
        "TRUNCATE TABLE #{qualified_tables} RESTART IDENTITY CASCADE",
        []
      )
    end
  end

  defp chimeway_tables(schema) do
    schema = normalize_identifier!(schema)

    Repo
    |> Ecto.Adapters.SQL.query!(
      """
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = $1
        AND table_name LIKE 'chimeway_%'
      ORDER BY table_name
      """,
      [schema]
    )
    |> then(fn %{rows: rows} -> Enum.map(rows, fn [table_name] -> table_name end) end)
  end

  defp table_count(schema, table_name) do
    schema = normalize_identifier!(schema)
    table_name = normalize_identifier!(table_name)

    if regclass?(schema, table_name) do
      sql = "SELECT count(*) FROM #{qualified_name(schema, table_name)}"

      Repo
      |> Ecto.Adapters.SQL.query!(sql, [])
      |> then(fn %{rows: [[count]]} -> count end)
    else
      0
    end
  end

  defp schema_exists?(schema) do
    schema = normalize_identifier!(schema)

    result =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = $1)",
        [schema]
      )

    result.rows == [[true]]
  end

  defp regclass?(schema, name) do
    case Ecto.Adapters.SQL.query!(Repo, "SELECT to_regclass($1)", ["#{schema}.#{name}"]).rows do
      [[nil]] -> false
      [[_value]] -> true
    end
  end

  defp drop_generated_prefixed_schema! do
    Ecto.Adapters.SQL.query!(Repo, ~s(DROP SCHEMA IF EXISTS "#{@runtime_prefix}" CASCADE), [])
  end

  defp qualified_name(schema, table_name) do
    ~s("#{normalize_identifier!(schema)}"."#{normalize_identifier!(table_name)}")
  end

  defp normalize_identifier!(identifier) when is_atom(identifier) do
    identifier
    |> Atom.to_string()
    |> normalize_identifier!()
  end

  defp normalize_identifier!(identifier) when is_binary(identifier) do
    if Regex.match?(@identifier_regex, identifier) do
      identifier
    else
      raise ArgumentError, "unsafe SQL identifier: #{inspect(identifier)}"
    end
  end
end
