defmodule DemoHostWeb.MailglassDeliveryProofTest do
  @moduledoc """
  DEMO-06 proof: TeamPulse invite email delivers through `Chimeway.Adapters.Mailglass`
  with operator trace inspectability at `/admin/chimeway`.

  Tagged `:mailglass` only — journey suite keeps default Logger adapter (D-10).
  """
  use DemoHostWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Chimeway.{Delivery, DeliveryAttempt, Repo}

  @moduletag :mailglass

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mailglass.TestRepo)
    Ecto.Adapters.SQL.Sandbox.mode(Mailglass.TestRepo, {:shared, self()})

    Mailglass.Adapters.Fake.checkout()
    Mailglass.Adapters.Fake.set_shared(self())
    Mailglass.Tenancy.put_current(DemoHost.Seeds.tenant_id())

    previous_channel_adapters = Application.get_env(:chimeway, :channel_adapters)
    previous_channel_configs = Application.get_env(:chimeway, :channel_adapter_configs)

    Application.put_env(:chimeway, :channel_adapters, %{
      "email" => Chimeway.Adapters.Mailglass
    })

    Application.put_env(:chimeway, :channel_adapter_configs, %{
      "email" => [
        mailables: %{
          "teampulse.invite_sent.email" => {DemoHost.Mailers.InviteEmail, :invite_email}
        }
      ]
    })

    on_exit(fn ->
      if previous_channel_adapters do
        Application.put_env(:chimeway, :channel_adapters, previous_channel_adapters)
      else
        Application.delete_env(:chimeway, :channel_adapters)
      end

      if previous_channel_configs do
        Application.put_env(:chimeway, :channel_adapter_configs, previous_channel_configs)
      else
        Application.delete_env(:chimeway, :channel_adapter_configs)
      end
    end)

    :ok
  end

  test "DEMO-06 invite email delivers via Mailglass adapter" do
    count_before = length(Mailglass.Adapters.Fake.deliveries())

    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

    email_delivery =
      delivery_ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "email" and &1.render_key == "teampulse.invite_sent.email"))

    refute is_nil(email_delivery)

    attempts =
      Repo.all(from(a in DeliveryAttempt, where: a.delivery_id == ^email_delivery.id))

    mailglass_attempt =
      Enum.find(attempts, fn attempt ->
        attempt.outcome == :succeeded and
          is_binary(attempt.adapter_module) and
          String.contains?(attempt.adapter_module, "Chimeway.Adapters.Mailglass")
      end)

    assert mailglass_attempt

    assert length(Mailglass.Adapters.Fake.deliveries()) > count_before
  end

  test "DEMO-06 admin trace shows invite Mailglass delivery", %{conn: conn} do
    assert {:ok, %{trace: %{delivery_ids: delivery_ids}}} = DemoHost.Seeds.seed_invite()

    email_delivery =
      delivery_ids
      |> Enum.map(&Repo.get!(Delivery, &1))
      |> Enum.find(&(&1.channel == "email"))

    refute is_nil(email_delivery)

    conn = get(conn, "/admin/chimeway")
    assert html_response(conn, 200) =~ "Trace search"

    {:ok, view, _html} = live(conn)

    html =
      view
      |> form("#trace-search-form", %{
        "mode" => "recipient",
        "query" => DemoHost.Seeds.alex_identity(),
        "notification_key" => ""
      })
      |> render_submit()

    assert html =~ DemoHost.Seeds.alex_identity()

    {:ok, detail_view, detail_html} =
      live(conn, "/admin/chimeway/deliveries/#{email_delivery.id}")

    assert detail_html =~ "Trace detail"

    detail = render(detail_view)
    assert detail =~ "teampulse.invite_sent"
    assert detail =~ "Chimeway.Adapters.Mailglass" or detail =~ "Mailglass"

    refute detail =~ DemoHost.Seeds.alex_email()
    refute detail =~ "<p>Join your team on TeamPulse.</p>"
  end
end
