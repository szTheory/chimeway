# Phase 64 Verification

## ECOS-09 End-to-End Proof

This document provides the definitive evidence that ECOS-09 is satisfied. The `mix verify.sigra` command successfully proves the ECOS-09 requirement under clean-CI conditions against the repinned partner module (SHA `62ceb46a`), replacing the previous vacuous pass that was masked by the local gitignored `deps/sigra`.

### Verification Lanes & Test Counts

The `verify.sigra` alias executes multiple steps to ensure comprehensive coverage:
1. **Root lane:** Executes `cmd env MIX_ENV=test mix test --only sigra --warnings-as-errors`, yielding `>= 5` tests. This exercises both the integration harness and the ECOS-09 lifecycle test.
2. **Demo-host lane:** Executes inside `examples/chimeway_demo_host` using `CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra`, yielding `>= 2` tests. This proves the DEMO-10 requirement via `sigra_auth_proof_test.exs`, confirming operator-trace proof.

### Redacted Trace Assertions

The lifecycle tests in `test/chimeway/integrations/sigra_auth_lifecycle_test.exs` prove that both magic-link and confirmation dispatch create durable deliveries with correctly redacted traces. The test suite explicitly asserts:
- `refute_sensitive_in_trace!(trace, [raw_token, url])` / `[code, url]`
- `refute_sensitive_in_telemetry!([raw_token, url])` / `[code, url]`

These assertions guarantee that sensitive data is never persisted in traces or leaked to telemetry.

### Binding Clean-CI Evidence

The authoritative proof for ECOS-09 E2E behavior relies on the CI job `verify_sigra`. The GitHub Actions CI pipeline pulls the correct integration code via a sibling checkout pinned to `szTheory/sigra@62ceb46a`, ensuring that the tests run against the true, remote-verified partner integration rather than a local copy. This fulfills the ECOS-09 clean-CI requirement.
