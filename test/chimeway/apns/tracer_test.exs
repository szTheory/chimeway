defmodule Chimeway.APNS.TracerTest do
  use Chimeway.DataCase, async: false

  alias Chimeway.APNS.RequestIntent

  test "request intents retain only durable APNs routing facts" do
    expires_at = DateTime.add(DateTime.utc_now(), 60, :second) |> DateTime.truncate(:second)

    assert {:ok, intent} =
             RequestIntent.new(
               %{
                 environment: :sandbox,
                 topic: "com.example.chimeway",
                 apns_id: "8d9c95fe-a6fd-4e82-b451-cbd59f02d948",
                 expires_at: expires_at,
                 open_ref: "open_opaque_ref"
               },
               binding_revision_ref: "cw_apns_tracer_001"
             )

    assert intent.environment == :sandbox
    assert intent.collapse_id == nil
    assert %{environment: "sandbox", topic: "com.example.chimeway"} =
             RequestIntent.to_storage(intent)
  end
end
