defmodule ChimewayAdmin.LiveAuthTest do
  use ExUnit.Case, async: false

  alias ChimewayAdmin.LiveAuth
  alias ChimewayAdmin.TestSupport.DenyAuth

  setup do
    previous = Application.get_env(:chimeway_admin, :auth_module)
    Application.put_env(:chimeway_admin, :auth_module, DenyAuth)
    on_exit(fn -> Application.put_env(:chimeway_admin, :auth_module, previous) end)
    :ok
  end

  test "halts and redirects when authorize returns unauthorized" do
    Application.put_env(:chimeway_admin, :unauthorized_redirect, "/login")

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.TraceSearchLive,
        private: %{}
      }

    assert {:halt, redirected} =
             LiveAuth.on_mount(:search_traces, %{}, %{"current_actor" => "ops:1"}, socket)

    assert {:redirect, redirect} = redirected.redirected
    assert redirect.to == "/login"
  end

  test "treats unexpected authorize return as unauthorized" do
    Application.put_env(:chimeway_admin, :auth_module, ChimewayAdmin.TestSupport.UnexpectedAuth)

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.TraceSearchLive,
        private: %{}
      }

    assert {:halt, _} =
             LiveAuth.on_mount(:search_traces, %{}, %{"current_actor" => "ops:1"}, socket)
  end

  test "passes route params into authorization context" do
    Application.put_env(:chimeway_admin, :capture_pid, self())

    defmodule ParamCaptureAuth do
      @behaviour ChimewayAdmin.Auth

      @impl true
      def authorize(_actor, action, context) do
        :chimeway_admin
        |> Application.fetch_env!(:capture_pid)
        |> send({:authorized, action, context})

        :ok
      end
    end

    Application.put_env(:chimeway_admin, :auth_module, ParamCaptureAuth)

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.TraceDetailLive,
        private: %{}
      }

    assert {:cont, _} =
             LiveAuth.on_mount(
               :view_trace,
               %{"delivery_id" => "del-1"},
               %{"current_actor" => "ops:1"},
               socket
             )

    assert_receive {:authorized, :view_trace, %{params: %{"delivery_id" => "del-1"}}}
  end

  test "passes actor, action, tenant, params, session, and live view into authorization context" do
    Application.put_env(:chimeway_admin, :capture_pid, self())

    defmodule RichContextCaptureAuth do
      @behaviour ChimewayAdmin.Auth

      @impl true
      def authorize(actor, action, context) do
        :chimeway_admin
        |> Application.fetch_env!(:capture_pid)
        |> send({:authorized, actor, action, context})

        :ok
      end
    end

    Application.put_env(:chimeway_admin, :auth_module, RichContextCaptureAuth)

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}},
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.RecoveryLive,
        private: %{}
      }

    assert {:cont, mounted} =
             LiveAuth.on_mount(
               :list_recovery_candidates,
               %{"tenant_id" => "ignored-from-params"},
               %{
                 "current_actor" => "ops:1",
                 "chimeway_admin_tenant_id" => " tenant-a ",
                 "raw_secret" => "only-for-host-auth"
               },
               socket
             )

    assert mounted.assigns.chimeway_admin_context.tenant_id == "tenant-a"
    assert mounted.assigns.chimeway_admin_session["current_actor"] == "ops:1"

    assert_receive {:authorized, "ops:1", :list_recovery_candidates,
                    %{
                      actor: "ops:1",
                      action: :list_recovery_candidates,
                      tenant_id: "tenant-a",
                      params: %{"tenant_id" => "ignored-from-params"},
                      session: %{"raw_secret" => "only-for-host-auth"},
                      live_view: ChimewayAdmin.Live.RecoveryLive
                    }}
  end

  test "ensure_authorized merges safe resource facts into authorization context" do
    Application.put_env(:chimeway_admin, :capture_pid, self())

    defmodule ResourceContextCaptureAuth do
      @behaviour ChimewayAdmin.Auth

      @impl true
      def authorize(actor, action, context) do
        :chimeway_admin
        |> Application.fetch_env!(:capture_pid)
        |> send({:authorized, actor, action, context})

        :ok
      end
    end

    Application.put_env(:chimeway_admin, :auth_module, ResourceContextCaptureAuth)

    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{
          __changed__: %{},
          chimeway_admin_context: %{
            actor: "ops:2",
            tenant_id: "tenant-b",
            params: %{},
            session: %{"current_actor" => "ops:2"},
            live_view: ChimewayAdmin.Live.RecoveryLive
          },
          chimeway_admin_session: %{"current_actor" => "ops:2"}
        },
        endpoint: ChimewayAdmin.TestSupport.Endpoint,
        router: ChimewayAdmin.Router,
        view: ChimewayAdmin.Live.RecoveryLive,
        private: %{}
      }

    assert {:ok, _socket} =
             LiveAuth.ensure_authorized(socket, :recover_delivery, %{
               resource_id: 123,
               recovery_type: :delivery,
               candidate: %{delivery_id: 123, tenant_id: "tenant-b"}
             })

    assert_receive {:authorized, "ops:2", :recover_delivery,
                    %{
                      action: :recover_delivery,
                      tenant_id: "tenant-b",
                      resource_id: 123,
                      recovery_type: :delivery,
                      candidate: %{delivery_id: 123, tenant_id: "tenant-b"}
                    }}
  end

  test "recovery opts include allowlisted evidence and omit raw params or session" do
    context =
      ChimewayAdmin.Context.from(
        %{"tenant_id" => "tenant-a", "token" => "secret"},
        %{"current_actor" => %{id: "ops-1"}, "session_secret" => "secret"},
        %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}, private: %{}}
      )

    opts = ChimewayAdmin.Context.recovery_opts(context, " retry now ", " CONFIRM ")

    assert opts[:source] == "chimeway_admin"
    assert opts[:reason] == "retry now"
    assert opts[:actor_ref] == "ops-1"
    assert opts[:confirmation_marker] == "CONFIRM"
    refute Keyword.has_key?(opts, :params)
    refute Keyword.has_key?(opts, :session)
  end
end
