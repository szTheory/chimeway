defmodule DemoHostWeb.WebhooksControllerTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  use Oban.Testing, repo: Chimeway.Repo, prefix: "public"

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
      assert_enqueued(worker: ProcessFeedbackWorker, args: %{"ingress_id" => ingress.id})
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
      refute_enqueued(worker: ProcessFeedbackWorker)
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

  describe "BL-01 regression: CacheBodyReader chunked-body accumulation" do
    # ---------------------------------------------------------------------------
    # Why a custom adapter: Plug.Test.conn/3 uses Plug.Adapters.Test.Conn whose
    # read_req_body/2 always returns {:ok, full_body, state} — it NEVER returns
    # {:more, ...} regardless of :read_length opts. To exercise the :more branch
    # we construct a bare %Plug.Conn{} with a custom adapter that pops chunks.
    #
    # ChunkedTestAdapter simulates Cowboy delivering a body in two TCP reads:
    #   first call  -> {:more, chunk1, new_state}
    #   second call -> {:ok,  chunk2, new_state}
    # ---------------------------------------------------------------------------

    defmodule ChunkedTestAdapter do
      @moduledoc false
      @behaviour Plug.Conn.Adapter

      # Called by Plug.Conn.read_body/2.
      # State is %{chunks: remaining_chunks}.
      @impl true
      def read_req_body(%{chunks: [only]} = state, _opts) do
        {:ok, only, %{state | chunks: []}}
      end

      def read_req_body(%{chunks: [head | tail]} = state, _opts) do
        {:more, head, %{state | chunks: tail}}
      end

      def read_req_body(%{chunks: []}, _opts) do
        {:ok, "", %{chunks: []}}
      end

      # Required Plug.Conn.Adapter callbacks — not used by this test.
      @impl true
      def send_resp(state, _status, _headers, _body), do: {:ok, nil, state}
      @impl true
      def send_file(state, _status, _headers, _path, _offset, _length), do: {:ok, nil, state}
      @impl true
      def send_chunked(state, _status, _headers), do: {:ok, nil, state}
      @impl true
      def chunk(state, _body), do: {:ok, state}
      @impl true
      def inform(state, _status, _headers), do: {:ok, state}
      @impl true
      def upgrade(_state, _protocol, _opts), do: {:error, :not_supported}
      @impl true
      def push(state, _path, _headers), do: {:ok, state}
      @impl true
      def get_peer_data(_state), do: %{address: {127, 0, 0, 1}, port: 0, ssl_cert: nil}
      @impl true
      def get_http_protocol(_state), do: :"HTTP/1.1"
    end

    test "CacheBodyReader accumulates ALL chunks — :more path writes to assigns (BL-01 unit)" do
      alias DemoHost.Plugs.CacheBodyReader

      # Two 50-byte chunks — total body is 100 bytes.
      chunk1 = String.duplicate("A", 50)
      chunk2 = String.duplicate("B", 50)
      full_body = chunk1 <> chunk2

      # Construct a bare conn with the chunked adapter.
      # assigns[:raw_body] starts as nil (the accumulator's nil-guard handles this).
      conn = %Plug.Conn{
        adapter: {ChunkedTestAdapter, %{chunks: [chunk1, chunk2]}},
        assigns: %{}
      }

      # First call: adapter returns {:more, chunk1, ...}
      # CacheBodyReader MUST write chunk1 to assigns[:raw_body].
      {:more, ^chunk1, conn_after_first} = CacheBodyReader.read_body(conn, [])

      assert conn_after_first.assigns[:raw_body] == [chunk1],
             "Expected [chunk1] after first read; got #{inspect(conn_after_first.assigns[:raw_body])}"

      # Second call: adapter returns {:ok, chunk2, ...}
      # CacheBodyReader MUST write chunk2 to assigns[:raw_body] (prepended).
      {:ok, ^chunk2, conn_after_second} = CacheBodyReader.read_body(conn_after_first, [])

      assert conn_after_second.assigns[:raw_body] == [chunk2, chunk1],
             "Expected [chunk2, chunk1] after second read; got #{inspect(conn_after_second.assigns[:raw_body])}"

      # Flatten: Enum.reverse |> IO.iodata_to_binary must recover the full body.
      recovered =
        conn_after_second.assigns[:raw_body]
        |> Enum.reverse()
        |> IO.iodata_to_binary()

      assert recovered == full_body,
             "Flattened body #{inspect(recovered)} does not equal original #{inspect(full_body)}"
    end

    test "chunked-body delivery — HMAC over full body still verifies (E2E, status 200, ingress row == 1)" do
      # This test proves that after the BL-01 fix, the full-body HMAC still
      # passes through the endpoint pipeline even for bodies that would chunk
      # in production. Because Plug.Test always delivers in a single :ok read,
      # this E2E proves the :ok-path post-fix; the unit test above proves :more.
      #
      # Together they close the gap: the :more path now writes chunks, and the
      # final :ok path has always written. Signature over the full body verifies.
      provider_msg_id = "msg-chunked-" <> Ecto.UUID.generate()

      # Body with intentional non-canonical whitespace (same strategy as the
      # existing verify-before-parse test) so any parse-then-re-encode would
      # produce different bytes and break the HMAC.
      body =
        ~s|{"id":  "| <> provider_msg_id <> ~s|",  "status": "ok"}|

      secret = "test-secret-rawbody"

      signature =
        :crypto.mac(:hmac, :sha256, secret, body)
        |> Base.encode16(case: :lower)

      conn =
        Plug.Test.conn(:post, "/webhooks/chimeway/rawbody", body)
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("x-signature", signature)
        |> DemoHostWeb.Endpoint.call(DemoHostWeb.Endpoint.init([]))

      # Status 200 proves the HMAC over the full raw bytes matched the
      # signature the adapter computed — i.e., CacheBodyReader preserved
      # the complete body (no truncation).
      assert conn.status == 200,
             "Expected 200 but got #{conn.status}; likely HMAC mismatch from truncated body"

      # Ingress row exists — the full pipeline ran to completion.
      assert [%Chimeway.Webhooks.Ingress{provider_message_id: ^provider_msg_id}] =
               Chimeway.Repo.all(Chimeway.Webhooks.Ingress),
             "Expected exactly 1 ingress row with provider_message_id=#{provider_msg_id}"
    end
  end
end
