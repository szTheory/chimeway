defmodule ChimewayAdmin.RedactionTest do
  use ExUnit.Case, async: true

  alias ChimewayAdmin.Redaction

  test "redact_recipient masks user: prefix identities" do
    assert Redaction.redact_recipient("user:abc123") == "user:***123"
    refute String.contains?(Redaction.redact_recipient("user:abc123"), "abc")
  end

  test "redact_recipient masks email local parts" do
    result = Redaction.redact_recipient("alice@example.com")
    assert result == "a***@example.com"
    refute String.contains?(result, "alice")
  end

  test "safe_timeline_detail drops sensitive keys" do
    detail = %{
      "reason" => "channel_disabled",
      "password" => "secret",
      "api_key" => "x",
      "outcome" => "failed"
    }

    assert Redaction.safe_timeline_detail(detail) == %{
             "reason" => "channel_disabled",
             "outcome" => "failed"
           }
  end
end
