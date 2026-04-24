defmodule Chimeway.Adapter do
  @moduledoc """
  Behaviour contract for outbound delivery adapters.

  ## Content responsibility

  Adapters receive a pre-planned `%Chimeway.Delivery{}` struct with all rendered
  content already present. Adapters MUST NOT call back into notifier modules to
  render content — all content must arrive pre-populated on the delivery struct
  before `deliver/2` is called.

  ## Configuration

  Adapter config (API keys, base URLs, from addresses, etc.) must be read at
  call time via `Application.get_env/3`. Never read config in module attributes
  or at compile time — this supports test overrides via `Application.put_env`
  and runtime environment switching.

  ## Return contract

  - `{:ok, meta}` — the provider accepted the delivery. `meta` is a compact
    map written to `chimeway_delivery_attempts.provider_response`. Adapters MUST
    redact sensitive fields (password, token, secret, api_key, auth) from `meta`
    before returning.

  - `{:error, reason_class, detail}` — delivery failed. `reason_class` MUST be
    one of `:temporary | :permanent | :bounced`:
    - `:temporary` — transient failure; the dispatcher may retry.
    - `:permanent` — non-retriable rejection by the provider.
    - `:bounced` — the address or identity is unreachable (e.g. hard bounce).
    `detail` is a compact map with no PII and no full provider response bodies.

  ## Outcome classification

  Outcome classification (`:succeeded`, `:failed`, `:rejected`, `:bounced`) is
  the dispatcher's responsibility, not the adapter's. Adapters return raw results;
  `Chimeway.Dispatch.Sync` maps them to Chimeway's delivery state machine.
  """

  # Add `use Chimeway.Adapter.ContractTest` to your adapter test module.
  # See test/support/chimeway/adapter/contract_test.ex for the shared contract test suite.

  @doc """
  Deliver a single delivery to its outbound channel.

  `delivery` is a pre-planned `%Chimeway.Delivery{}` struct with all content
  populated. `config` is a keyword list of adapter-specific options read from
  `Application.get_env/3` at call time.
  """
  @callback deliver(delivery :: Chimeway.Delivery.t(), config :: keyword()) ::
              {:ok, map()} | {:error, atom(), map()}
end
