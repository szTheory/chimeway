# Custom Adapter Recipe

This guide walks you through implementing a custom outbound channel adapter using the `Chimeway.Adapter` behaviour. It covers required callbacks, secure runtime configuration, returning delivery outcomes, and writing contract tests to enforce redaction.

## Implementing the Behaviour

A custom adapter in Chimeway is any module that implements the `Chimeway.Adapter` behaviour. The primary responsibility of an adapter is to take a pre-planned `%Chimeway.Delivery{}` struct and dispatch it to an external provider (like an SMS gateway, email service, or push notification API).

Here is a basic structure for a custom adapter:

```elixir
defmodule MyApp.MyCustomAdapter do
  @behaviour Chimeway.Adapter

  @impl true
  def deliver(%Chimeway.Delivery{} = delivery, config) do
    # Implementation goes here
  end
end
```

## Secure Runtime Configuration

**CRITICAL:** Adapter configuration (such as API keys, base URLs, or secrets) MUST be loaded at runtime. 

Do not use compile-time module attributes (e.g., `@api_key Application.compile_env(...)`). Instead, you must read configuration at call time, typically via `Application.get_env/3` or through the `config` keyword list passed to your `deliver/2` function. 

Loading configuration at runtime ensures multi-environment safety and allows you to seamlessly switch environments or override configurations during tests without needing to recompile your application.

```elixir
defmodule MyApp.MyCustomAdapter do
  @behaviour Chimeway.Adapter

  @impl true
  def deliver(%Chimeway.Delivery{} = delivery, config) do
    # Good: Reading config at runtime
    api_key = Keyword.get(config, :api_key) || Application.get_env(:my_app, :custom_adapter_api_key)
    
    # ... external API call ...
  end
end
```

## Return Shapes and Outcomes

The `deliver/2` function must return one of the following specific shapes to allow Chimeway's dispatcher to properly handle the outcome:

### Success
- `{:ok, meta}`: Indicates the provider accepted the delivery. 
  - `meta` is a map containing relevant provider response details (like an external message ID). It will be persisted to `chimeway_delivery_attempts.provider_response`. 
  - **Security Note:** You MUST redact sensitive fields (like passwords, tokens, secrets, API keys, or auth headers) from `meta` before returning it.

### Error
- `{:error, class, detail}`: Indicates the delivery failed.
  - `class` MUST be one of `:temporary`, `:permanent`, or `:bounced`:
    - `:temporary` - A transient failure (e.g., 500 Server Error). The dispatcher may retry.
    - `:permanent` - A non-retriable rejection (e.g., 400 Bad Request).
    - `:bounced` - The address or identity is unreachable.
  - `detail` is a map containing error specifics. Like `meta`, it must not contain any sensitive data, PII, or full provider response bodies.

## Enforcing Safety with Contract Tests

To guarantee that your custom adapter correctly implements the behaviour and adheres to security requirements (specifically, redaction of credentials in metadata), Chimeway provides a shared contract test suite.

You should use the `Chimeway.Adapter.ContractTest` macro in your test suite to automatically run these checks against your adapter. This enforces runtime safety and prevents accidental credential leaks.

```elixir
defmodule MyApp.MyCustomAdapterTest do
  use ExUnit.Case, async: true
  
  # This macro injects shared contract tests for your adapter
  use Chimeway.Adapter.ContractTest, adapter: MyApp.MyCustomAdapter

  # ... your custom tests ...
end
```

Using this macro is the recommended way to ensure your adapter meets Chimeway's production-grade standards.
