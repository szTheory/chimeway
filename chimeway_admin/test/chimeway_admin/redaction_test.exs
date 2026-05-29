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

  test "redact_recipient masks opaque identities by default" do
    result = Redaction.redact_recipient("+15551234567")
    assert result =~ "***"
    refute result == "+15551234567"
  end

  test "redact_recipient masks webhook identities" do
    assert Redaction.redact_recipient("webhook:https://example.com/hook") =~ "webhook:***"
  end

  test "safe_error_class masks sensitive error classes" do
    assert Redaction.safe_error_class("smtp_auth_failed") == "smtp_auth_failed"
    assert Redaction.safe_error_class("/var/app/secrets/smtp") =~ "***"
    assert Redaction.safe_error_class("user@host.com/path") =~ "***"
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

  test "safe_timeline_detail allows adapter_module while dropping sensitive keys" do
    detail = %{
      "adapter_module" => "Elixir.Chimeway.Adapters.Mailglass",
      "password" => "secret"
    }

    assert Redaction.safe_timeline_detail(detail) == %{
             "adapter_module" => "Elixir.Chimeway.Adapters.Mailglass"
           }
  end
end
