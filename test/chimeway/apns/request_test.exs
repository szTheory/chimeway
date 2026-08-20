defmodule Chimeway.APNS.RequestTest do
  use ExUnit.Case, async: true

  alias Chimeway.APNS.{Payload, RequestIntent}

  @id "8d9c95fe-a6fd-4e82-b451-cbd59f02d948"

  test "request intent validates closed fields without atomizing string aliases" do
    for attrs <- [
          %{},
          %{
            environment: "sandbox",
            topic: "com.example.app",
            apns_id: @id,
            expires_at: DateTime.utc_now(),
            open_ref: "open"
          },
          %{
            environment: :sandbox,
            topic: "",
            apns_id: @id,
            expires_at: DateTime.utc_now(),
            open_ref: "open"
          },
          %{
            environment: :sandbox,
            topic: "com.example.app",
            apns_id: "not-a-uuid",
            expires_at: DateTime.utc_now(),
            open_ref: "open"
          },
          %{
            environment: :sandbox,
            topic: "com.example.app",
            apns_id: @id,
            expires_at: DateTime.utc_now(),
            open_ref: "raw-token-sentinel"
          }
        ] do
      assert {:error, :invalid_apns_request_intent} = RequestIntent.new(attrs, [])
    end
  end

  test "expiry is absolute at equality and eligible one microsecond later" do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    assert {:ok, expired} = intent(expires_at: now)
    assert RequestIntent.expired?(expired, now)

    assert {:ok, eligible} = intent(expires_at: DateTime.add(now, 1, :microsecond))
    refute RequestIntent.expired?(eligible, now)
  end

  test "collapse identity is absent unless opted in and exact-scoped when present" do
    assert {:ok, distinct} = intent()
    assert distinct.collapse_id == nil

    assert {:ok, first} = intent(replaceable: true)
    assert {:ok, same} = intent(replaceable: true)
    assert first.collapse_id == same.collapse_id
    assert byte_size(first.collapse_id) <= 64

    for changed <- [
          [occurrence_ref: "occurrence-2"],
          [binding_revision_ref: "cw_binding_revision_002"],
          [environment: :production],
          [topic: "com.example.other"]
        ] do
      assert {:ok, other} = intent(Keyword.merge([replaceable: true], changed))
      refute other.collapse_id == first.collapse_id
    end
  end

  test "payload is closed to APS alert and opaque open reference at the byte boundary" do
    assert {:ok, payload} =
             Payload.build(
               %{"title" => "Hello", "body" => "World", "data" => %{"ignored" => "value"}},
               "open-1"
             )

    assert payload.json == %{
             "aps" => %{"alert" => %{"title" => "Hello", "body" => "World"}},
             "chimeway_open_ref" => "open-1"
           }

    refute inspect(payload) =~ "ignored"

    body_4095 = String.duplicate("a", 4095 - encoded_overhead())
    body_4096 = String.duplicate("a", 4096 - encoded_overhead())
    body_4097 = String.duplicate("a", 4097 - encoded_overhead())

    for body <- [body_4095, body_4096] do
      assert {:ok, result} = Payload.build(%{"title" => "", "body" => body}, "open-1")
      assert result.bytes <= 4096
    end

    assert {:error, :payload_too_large} =
             Payload.build(%{"title" => "", "body" => body_4097}, "open-1")

    assert {:error, :invalid_payload} =
             Payload.build(%{"title" => "Hello", "body" => "World"}, "raw-token-sentinel")
  end

  defp intent(overrides \\ []) do
    attrs = %{
      environment: :sandbox,
      topic: "com.example.app",
      apns_id: @id,
      expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
      open_ref: "open-ref"
    }

    {attr_overrides, opts} =
      [occurrence_ref: "occurrence-1", binding_revision_ref: "cw_binding_revision_001"]
      |> Keyword.merge(overrides)
      |> Enum.split_with(fn {key, _} ->
        key in [:environment, :topic, :apns_id, :expires_at, :open_ref]
      end)

    RequestIntent.new(Map.merge(attrs, Map.new(attr_overrides)), opts)
  end

  defp encoded_overhead do
    Jason.encode!(%{
      "aps" => %{"alert" => %{"title" => "", "body" => ""}},
      "chimeway_open_ref" => "open-1"
    })
    |> byte_size()
  end
end
