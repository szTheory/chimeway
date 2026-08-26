defmodule AlphaTwin.IntegrationNotifier do
  @moduledoc false
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "alpha_twin.persisted_trace"

  @impl true
  def version, do: 1

  @impl true
  def recipients(_params),
    do: {:ok, [%{recipient_identity: "cw_recipient_alpha_001", recipient_type: "user"}]}

  @impl true
  def build(_params, _recipient), do: {:ok, %{}}

  @impl true
  def channels(_params, _recipient), do: {:ok, [:push]}

  @impl true
  def rendering(_params, _recipient) do
    {:ok,
     %{
       assigns: %{title: "Alpha twin", body: "Hermetic lifecycle proof"},
       channels: %{push: %{render_key: "alpha_twin.push", render_version: 1}}
     }}
  end
end

defmodule AlphaTwin.IntegrationTargetResolver do
  @moduledoc false
  @behaviour Chimeway.TargetResolver

  alias Chimeway.TargetResolver.BindingRevision

  @impl true
  def resolve_targets(tenant_id, _opts) do
    bindings =
      case Application.fetch_env(:chimeway, :alpha_twin_target_bindings) do
        {:ok, configured} ->
          configured

        :error ->
          [
            {Application.fetch_env!(:chimeway, :alpha_twin_binding_ref),
             Application.fetch_env!(:chimeway, :alpha_twin_request_intent)}
          ]
      end

    bindings
    |> Enum.reduce_while({:ok, []}, fn {binding_ref, intent}, {:ok, bindings} ->
      case BindingRevision.new_with_request_intent(tenant_id, binding_ref, intent) do
        {:ok, binding} -> {:cont, {:ok, [binding | bindings]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, bindings} -> {:ok, Enum.reverse(bindings)}
      error -> error
    end
  end
end

defmodule AlphaTwin.IntentConsumer do
  @moduledoc false
  @behaviour Crosswake.Companions.Chimeway.IntentConsumer

  alias Crosswake.Companions.Chimeway.Contracts.{NotificationOpenEvidence, OpenResolution}

  @resolved_at "2026-08-25T12:00:00Z"
  @route_id "alpha_protected"
  @action_ref "tap"

  @impl true
  def consume_intent(%NotificationOpenEvidence{} = evidence) do
    registry = Application.fetch_env!(:chimeway, :alpha_twin_registry)
    binding_ref = Application.fetch_env!(:chimeway, :alpha_twin_binding_ref)

    if evidence.binding_ref == binding_ref do
      resolution(registry, evidence.open_ref)
    else
      {:ok,
       %OpenResolution{
         open_ref: evidence.open_ref,
         state: :binding_mismatch,
         resolved_at: @resolved_at
       }}
    end
  end

  defp resolution(registry, open_ref) do
    case AlphaTwin.Registry.consume_intent(registry, open_ref) do
      {:ok, %{classification: :accepted}} ->
        {:ok,
         %OpenResolution{
           open_ref: open_ref,
           state: :valid,
           route_id: @route_id,
           action_ref: @action_ref,
           resolved_at: @resolved_at
         }}

      {:error, :replayed} ->
        {:ok, %OpenResolution{open_ref: open_ref, state: :replayed, resolved_at: @resolved_at}}

      {:error, _reason} ->
        {:ok,
         %OpenResolution{open_ref: open_ref, state: :policy_denied, resolved_at: @resolved_at}}
    end
  end
end

defmodule AlphaTwin.CrashOnceDispatcher do
  @moduledoc false
  @behaviour Chimeway.Dispatch

  @impl true
  def dispatch(_notifications, _opts), do: exit(:alpha_twin_post_commit_crash)

  @impl true
  def dispatch_delivery(_delivery, _opts), do: exit(:alpha_twin_post_commit_crash)
end

defmodule AlphaTwin.PlanOnlyDispatcher do
  @moduledoc false
  @behaviour Chimeway.Dispatch

  @impl true
  def dispatch(notifications, opts) when is_list(notifications) do
    notifications
    |> Enum.reduce_while({:ok, []}, fn notification, {:ok, deliveries} ->
      case Chimeway.DeliveryPlanning.plan_notification(notification, opts) do
        {:ok, planned} -> {:cont, {:ok, deliveries ++ planned}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @impl true
  def dispatch_delivery(delivery, _opts), do: {:ok, delivery}
end

defmodule AlphaTwin.ProtectedOpen do
  @moduledoc false

  alias Crosswake.Companions.Chimeway.Contracts
  alias Crosswake.Companions.Sigra.Contracts, as: SigraContracts
  alias Crosswake.Manifest.Types.{Compatibility, Host, NavigationTopology, Root, RouteEntry}
  alias Crosswake.Manifest.Types.SupportMatrix

  @fixed_now "2026-08-25T12:00:00Z"

  def manifest do
    %Root{
      manifest_schema_version: "2.0.0",
      crosswake_version: "0.1.0",
      generated_at: @fixed_now,
      host: %Host{
        phoenix_version: "1.7.0",
        live_view_version: "0.20.0",
        origin: "https://alpha-twin.example.test",
        manifest_sources: [:bundled]
      },
      compatibility: %Compatibility{
        manifest_schema_version: "2.0.0",
        bridge_protocol_version: "1.0.0",
        native_runtime_version: "1.0.0",
        supported_manifest_sources: [:bundled],
        remote_updates: []
      },
      support_matrix: %SupportMatrix{
        phoenix: [],
        live_view: [],
        ios: [],
        android: [],
        shells: [],
        capability_families: [],
        package_surfaces: [],
        release_boundaries: [],
        change_classes: []
      },
      capability_registry: %{},
      pack_registry: %{},
      commerce_corridors: %{},
      navigation_topology: %NavigationTopology{
        topology_schema_version: "1.0.0",
        manifest_schema_version: "2.0.0",
        status: :unknown_blocking,
        entries: []
      },
      routes: %{
        "alpha_protected" => %RouteEntry{
          id: "alpha_protected",
          path: "/alpha/protected",
          runtime: :live_view,
          entry: :external,
          notification_open: %{actions: ["tap"]},
          auth_min_level: :mfa,
          requires_recent_auth: 300,
          auth_posture: :strict_recent
        }
      }
    }
  end

  def evidence(open_ref, binding_ref) do
    Contracts.new_notification_open_evidence!(%{
      route_id: "untrusted_client_route",
      open_ref: open_ref,
      binding_ref: binding_ref,
      provider: :apns,
      action_ref: "untrusted_client_action",
      action_kind: :tap,
      evaluated_at: @fixed_now,
      auth_context: auth_context(),
      metadata: %{}
    })
  end

  defp auth_context do
    {:ok, lane} =
      SigraContracts.new_session_authority_lane(%{
        session_ref: "session_ref_alpha",
        subject_ref: "actor_alpha",
        org_id: "org_alpha",
        state: :active,
        assurance_level: :mfa,
        authn_methods: [:password, :totp],
        authenticated_at: "2026-08-25T11:59:00Z",
        last_seen_at: @fixed_now,
        idle_expires_at: "2026-08-25T12:30:00Z",
        absolute_expires_at: "2026-08-26T12:00:00Z",
        renew_after: "2026-08-25T12:20:00Z",
        remembered: false,
        cached: false,
        session_version: 7,
        revoked_at: nil,
        as_of: @fixed_now
      })

    {:ok, context} =
      SigraContracts.new_auth_context(%{
        actor_id: "actor_alpha",
        org_id: "org_alpha",
        mfa_level: :mfa,
        auth_age: 60,
        session_authority_lane: lane,
        as_of: @fixed_now
      })

    context
  end
end
