defmodule DemoHostWeb.WebhooksControllerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  use Oban.Testing, repo: Chimeway.Repo

  alias Chimeway.Repo
  alias Chimeway.Webhooks.{Ingress, ProcessFeedbackWorker}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chimeway.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Chimeway.Repo, {:shared, self()})
    Application.put_env(:demo_host, :chimeway_adapter_config, [])
    :ok
  end

  describe "POST /webhooks/chimeway/echo (Phase 33 host-mount E2E proof)" do
    test "valid signature + parseable body returns 200, commits ingress row, and enqueues Oban job" do
      # Use a provider-side message ID (plain string, no FK constraint).
      # The EchoAdapter maps "id" -> provider_message_id.
      provider_msg_id = "msg-" <> Ecto.UUID.generate()
      body = Jason.encode!(%{"id" => provider_msg_id, "status" => "ok"})
      conn =
        conn(:post, "/webhooks/chimeway/echo", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "valid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      assert conn.status == 200

      # T-33-ATOMIC verified end-to-end: ingress row durably committed
      assert [%Ingress{} = ingress] = Repo.all(Ingress)
      assert ingress.adapter_module == to_string(DemoHost.Adapters.EchoAdapter)
      assert ingress.provider_message_id == provider_msg_id
      assert ingress.normalized_status == "delivered"

      # Oban job enqueued atomically with ingress row
      assert_enqueued worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id}
    end

    test "bad signature returns 401 and commits NO ingress row (D-09 / T-33-AUTH-LEAK)" do
      body = Jason.encode!(%{"id" => "msg-" <> Ecto.UUID.generate(), "status" => "ok"})
      conn =
        conn(:post, "/webhooks/chimeway/echo", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "invalid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      assert conn.status == 401
      assert Repo.aggregate(Ingress, :count) == 0
      refute_enqueued worker: ProcessFeedbackWorker
    end

    test "unresolvable body returns non-2xx and commits NO ingress row" do
      # Send valid JSON that Chimeway cannot process: an empty object has no
      # "id" or "msg_id" key that EchoAdapter.resolve_delivery/1 recognizes,
      # and no "status" key that normalize_feedback/1 recognizes. Chimeway
      # returns {:error, :unresolvable_delivery}, the controller maps to 500.
      # This covers D-03: any non-ok, non-unauthorized error -> non-2xx.
      #
      # NOTE: Plug.Parsers.ParseError (truly malformed JSON bytes) is handled
      # differently in Phoenix test mode: Phoenix's RenderErrors renders a 400
      # response AND then re-raises the exception (by design — the server HTTP
      # adapter catches the re-raise in production; Plug.Test propagates it).
      # Using a semantically-unprocessable but syntactically-valid JSON body
      # avoids that test-mode wrinkle and exercises the same D-03 contract.
      conn =
        conn(:post, "/webhooks/chimeway/echo", Jason.encode!(%{}))
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "valid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # Not 2xx (Chimeway returned {:error, :unresolvable_delivery} -> 500).
      refute conn.status in 200..299
      refute conn.status == 401
      assert Repo.aggregate(Ingress, :count) == 0
    end

    test "raw body iolist is correctly flattened — Pitfall 4 / T-33-RAWBODY regression test" do
      # Simulate a chunked body by passing a binary that exercises iodata accumulation
      # in CacheBodyReader. With the canonical update_in pattern the body is stored
      # as `[chunk | acc]` and the controller MUST flatten via IO.iodata_to_binary/1
      # before passing to verify_webhook/3.
      provider_msg_id = "msg-" <> Ecto.UUID.generate()
      body = Jason.encode!(%{"id" => provider_msg_id, "status" => "ok"})
      conn =
        conn(:post, "/webhooks/chimeway/echo", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("signature", "valid")
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # The controller's `IO.iodata_to_binary(raw_body)` MUST have produced the
      # exact bytes `body` so the EchoAdapter's `verify_webhook/3` returned `:ok`.
      # Status 200 here means the iolist-flattening worked end-to-end.
      assert conn.status == 200
      assert [%Ingress{}] = Repo.all(Ingress)
    end

    test "verify-before-parse ordering — HMAC over raw bytes survives JSON byte-for-byte" do
      # Phase 33 D-13 / T-33-RAWBODY first-class DX assertion:
      # Signature verification MUST run on the EXACT raw bytes BEFORE any JSON
      # parsing or re-encoding. This test uses an adapter (RawBodyHmacAdapter,
      # added in Task 2) that computes HMAC-SHA256 over the raw body bytes.
      #
      # The body intentionally contains non-canonical whitespace (double-spaces
      # inside the JSON object) — bytes like `{"id":  "msg-...", ...}`. Any
      # host code that calls Jason.decode + Jason.encode before verify_webhook
      # would produce normalized JSON without the double-spaces, and the HMAC
      # over those re-encoded bytes would NOT match the signature header.
      #
      # If this test passes (status 200), the controller called verify_webhook
      # BEFORE Jason.decode — verified end-to-end. If a future refactor reorders
      # the controller pipeline to parse-then-verify, this test fails with 401
      # because the re-encoded bytes don't HMAC-match.
      provider_msg_id = "msg-rawbody-" <> Ecto.UUID.generate()

      # Hand-crafted body bytes with intentional double-spaces that will NOT
      # survive Jason.encode after Jason.decode. The body still parses to valid
      # JSON, but its byte representation is byte-distinguishable from any
      # re-encoded form.
      body =
        ~s|{"id":  "| <> provider_msg_id <> ~s|",  "status": "ok"}|

      # Compute HMAC-SHA256 over the EXACT raw bytes using the same shared
      # secret RawBodyHmacAdapter expects.
      secret = "test-secret-rawbody"
      signature =
        :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

      conn =
        conn(:post, "/webhooks/chimeway/rawbody", body)
        |> put_req_header("content-type", "application/json")
        |> put_req_header("x-signature", signature)
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # Status 200 PROVES verify_webhook ran on the unparsed raw bytes BEFORE
      # Jason.decode. If verify-before-parse ordering were broken (parse then
      # re-encode then verify), the bytes would have changed and HMAC compare
      # would fail with 401.
      assert conn.status == 200

      # Sanity check: ingress row exists with the provider_message_id we sent.
      assert [%Ingress{provider_message_id: ^provider_msg_id}] = Repo.all(Ingress)

      # Documentation note for executor / future readers:
      # If a developer swaps the controller pipeline to parse-then-verify
      # (i.e., calls Jason.decode on the body before verify_webhook), the
      # body bytes the adapter sees will be the re-encoded form WITHOUT the
      # double-spaces. The HMAC over those bytes will NOT match `signature`
      # above, and verify_webhook returns {:error, :unauthorized} -> 401.
      # That is the failure mode this test detects.
    end
  end
end
