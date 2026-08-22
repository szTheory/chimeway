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

  @tag :apns_input_smoke
  test "opaque references use one closed grammar at construction, reload, and payload boundaries" do
    accepted = ["open-ref", "open_opaque_ref", "cw_open_opaque_001", "open-" <> String.duplicate("a", 251)]

    for open_ref <- accepted do
      assert {:ok, %RequestIntent{open_ref: ^open_ref}} = intent(open_ref: open_ref)

      assert {:ok, %RequestIntent{open_ref: ^open_ref}} =
               RequestIntent.from_storage(storage(open_ref: open_ref))

      assert {:ok, _payload} = Payload.build(%{"title" => "Hello", "body" => "World"}, open_ref)
    end

    rejected = [
      nil,
      "",
      "user_123",
      "person@example.com",
      "https://example.test/open",
      "//example.test/open",
      "open ref",
      "open\0ref",
      "open\rref",
      "open\nref",
      "open" <> <<127>>,
      "open-é",
      ~c"open-ref",
      %{}
    ]

    for open_ref <- rejected do
      assert {:error, :invalid_apns_request_intent} = intent(open_ref: open_ref)
      assert {:error, :invalid_apns_request_intent} = RequestIntent.from_storage(storage(open_ref: open_ref))
      assert {:error, :invalid_payload} = Payload.build(%{"title" => "Hello", "body" => "World"}, open_ref)
    end

    over_bound = "open-" <> String.duplicate("a", 252)
    assert {:error, :invalid_apns_request_intent} = intent(open_ref: over_bound)
    assert {:error, :invalid_apns_request_intent} = RequestIntent.from_storage(storage(open_ref: over_bound))
    assert {:error, :invalid_payload} = Payload.build(%{"title" => "Hello", "body" => "World"}, over_bound)
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

  @tag :apns_input_smoke
  test "explicit collapse IDs are header-safe before intent construction" do
    for collapse_id <- ["a", String.duplicate("a", 64), "collapse_id-001"] do
      assert {:ok, %RequestIntent{collapse_id: ^collapse_id}} = intent(collapse_id: collapse_id)

      assert {:ok, %RequestIntent{collapse_id: ^collapse_id}} =
               RequestIntent.from_storage(storage(collapse_id: collapse_id))
    end

    for collapse_id <- [
          "",
          String.duplicate("a", 65),
          "has space",
          "contains.dot",
          "collapse\0id",
          "collapse\rid",
          "collapse\nid",
          "collapse" <> <<1>>,
          "collapse" <> <<127>>,
          "é",
          ~c"collapse-id",
          %{}
        ] do
      assert {:error, :invalid_apns_request_intent} = intent(collapse_id: collapse_id)

      assert {:error, :invalid_apns_request_intent} =
               RequestIntent.from_storage(storage(collapse_id: collapse_id))
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
        key in [:environment, :topic, :apns_id, :expires_at, :open_ref, :collapse_id]
      end)

    RequestIntent.new(Map.merge(attrs, Map.new(attr_overrides)), opts)
  end

  defp storage(overrides) do
    %{
      "environment" => "sandbox",
      "topic" => "com.example.app",
      "apns_id" => @id,
      "expires_at" => DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.to_iso8601(),
      "open_ref" => "open-ref",
      "collapse_id" => nil
    }
    |> then(fn storage ->
      Enum.reduce(overrides, storage, fn {key, value}, acc ->
        Map.put(acc, Atom.to_string(key), value)
      end)
    end)
  end

  defp encoded_overhead do
    Jason.encode!(%{
      "aps" => %{"alert" => %{"title" => "", "body" => ""}},
      "chimeway_open_ref" => "open-1"
    })
    |> byte_size()
  end
end
