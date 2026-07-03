if Code.ensure_loaded?(Sigra) do
  defmodule Chimeway.Integrations.SigraAuthHarnessTest do
    @moduledoc false

    use Sigra.DataCase, async: false

    @moduletag :sigra

    alias Chimeway.TestSupport.Sigra.User
    alias Sigra.TestRepo, as: Repo

    describe "sigra auth harness (ECOS-09 wave 1)" do
      test "Sigra module loaded exports request_magic_link/3" do
        assert Code.ensure_loaded?(Sigra)
        assert Code.ensure_loaded?(Sigra.Auth)
        assert function_exported?(Sigra.Auth, :request_magic_link, 3)
      end

      test "Sigra integration module loaded exports dispatch_magic_link_after_request/3" do
        assert Code.ensure_loaded?(Sigra.Integrations.Chimeway)

        assert function_exported?(
                 Sigra.Integrations.Chimeway,
                 :dispatch_magic_link_after_request,
                 3
               )
      end

      test "TestRepo reachable after insert_user!/0" do
        insert_user!()

        assert Repo.aggregate(User, :count) == 1
      end

      test "schema config round-trip sets harness user modules" do
        assert Application.get_env(:sigra, :user_schema) == Chimeway.TestSupport.Sigra.User

        assert Application.get_env(:sigra, :user_token_schema) ==
                 Chimeway.TestSupport.Sigra.UserToken
      end
    end
  end
end
