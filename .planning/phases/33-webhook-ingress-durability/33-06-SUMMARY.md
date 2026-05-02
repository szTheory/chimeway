---
phase: 33-webhook-ingress-durability
plan: "06"
subsystem: webhook-ingress
tags: [elixir, plug, webhook, body_reader, chunked, hmac, regression, gap-closure]

gap_closed: BL-01
threats_mitigated: [T-33-RAWBODY, T-33-CHUNK-DROP]

# Dependency graph
requires:
  - phase: 33-04
    provides: examples/chimeway_demo_host CacheBodyReader pattern + Plug.Parsers wiring + RawBodyHmacAdapter fixture
  - phase: 33-05
    provides: 33-VERIFICATION.md gap report identifying BL-01 as the open phase blocker
provides:
  - "DemoHost.Plugs.CacheBodyReader.read_body/2 that handles all three Plug.Conn.read_body/2 return shapes (:ok, :more, :error) and accumulates ALL chunks into conn.assigns[:raw_body]"
  - "BL-01 regression describe block in webhooks_controller_test.exs covering both the :more unit path (via custom Plug.Conn.Adapter) and the :ok-path E2E (via Endpoint + HMAC)"
  - "Closure of the canonical-pattern defect: the moduledoc adopters are told to copy (D-12) is now safe for production-shaped chunked traffic"
affects: [phase-34, v1.4-milestone-audit, host-mount-reference-docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Custom Plug.Conn.Adapter test pattern: define a minimal @behaviour Plug.Conn.Adapter module inside the test file to force {:more, ...} returns from Plug.Conn.read_body/2 (Plug.Test.conn never produces :more regardless of :read_length opts)"
    - "Body-reader exhaustive-case pattern: case Plug.Conn.read_body(conn, opts) over all three return shapes; both :ok and :more branches MUST update conn.assigns[:raw_body] to preserve chunked bodies"
    - "Iolist accumulator nil-guard: update_in(conn.assigns[:raw_body], &[body | &1 || []]) handles the first chunk (assign absent) and subsequent chunks uniformly"

key-files:
  created:
    - .planning/phases/33-webhook-ingress-durability/33-06-SUMMARY.md
  modified:
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex
    - examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs

key-decisions:
  - "Replace `with {:ok, ...}` single-clause with explicit `case` over all three Plug.Conn.read_body/2 return shapes — prefer exhaustiveness over brevity at a teaching-example boundary that adopters are explicitly told to copy"
  - "Define ChunkedTestAdapter inside the test module rather than in a shared support file — the adapter is purpose-built for BL-01 regression and adding it to test/support would imply broader reuse"
  - "Keep the HMAC-over-full-body E2E test using Plug.Test.conn (single :ok read) rather than booting a real Cowboy adapter — together with the unit test that directly exercises :more, the pair covers both code paths without adding a transport-layer test dependency"

patterns-established:
  - "Gap-closure plan pattern: a focused plan (3 tasks, 2 file changes) addresses one verifier-flagged blocker with paired implementation + regression test + integration verification"
  - "Threat-mitigation regression pattern: every threat with disposition `mitigate` in the threat register MUST have a regression test that fails loudly if the mitigation is removed (T-33-CHUNK-DROP now has the unit test that asserts conn.assigns[:raw_body] == [chunk1] after the first :more read)"

requirements-completed: [FEED-01, FEED-02]

# Metrics
duration: 8min
completed: 2026-05-02
---

# Phase 33 Plan 06: CacheBodyReader Chunked-Body Fix (BL-01 Gap Closure) Summary

**The canonical CacheBodyReader pattern adopters are told to copy now handles `{:more, ...}` correctly — chunked webhook bodies above Cowboy's default 1 MB :read_length are no longer silently truncated, HMAC verification holds for production-shaped traffic, and a paired unit + E2E regression test will fail loudly if the bug is reintroduced.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-02T14:54:00Z (approx)
- **Completed:** 2026-05-02T15:02:31Z
- **Tasks:** 3 of 3 complete
- **Files modified:** 2 (1 lib, 1 test)
- **New tests:** 2 (BL-01 unit + chunked E2E)
- **Total tests in example app suite:** 5 → 7 (no regressions)

## Accomplishments

- **BL-01 closed.** `DemoHost.Plugs.CacheBodyReader.read_body/2` now uses an exhaustive `case` over `Plug.Conn.read_body/2`'s three return shapes. Both `:ok` and `:more` branches write the chunk to `conn.assigns[:raw_body]` via the same `update_in` accumulator; the `:error` branch passes through unchanged. The old `with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts)` single-clause shape (which silently dropped chunks 1..N-1) is gone.
- **Regression coverage added.** A new describe block (`BL-01 regression: CacheBodyReader chunked-body accumulation`) holds two tests. The unit test forces `{:more, ...}` returns via a custom `ChunkedTestAdapter` (`@behaviour Plug.Conn.Adapter`) defined inline in the test module, calls `CacheBodyReader.read_body/2` twice, and asserts the accumulator contains both chunks in reverse arrival order. The E2E test posts an HMAC-signed body with intentional non-canonical whitespace through the Endpoint and asserts status 200 + exactly one ingress row.
- **Moduledoc updated.** The `CacheBodyReader` moduledoc now documents chunked-delivery behavior under a `## Chunked delivery (production Cowboy)` heading, so adopters who follow D-12 ("copy that pattern in your own host app") get correct behavior on bodies larger than 1 MB without having to read the source.
- **D-10 boundary preserved.** No files under `lib/chimeway/` were touched. The full chimeway core suite (548 tests) and the example app suite (7 tests) both pass.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite CacheBodyReader.read_body/2 to handle :ok, :more, and :error** — `bdaa3db` (fix)
2. **Task 2: Add chunked-body regression test that forces the :more path via a custom adapter conn** — `e8c42a3` (test)
3. **Task 3: Run the full verify chain and confirm all 7 tests pass** — no-op commit (verification only; no source changes)

**Plan metadata:** to be recorded by final docs commit.

## Files Created/Modified

- `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` — Rewrote `read_body/2` with `case` over `:ok`/`:more`/`:error` return shapes; both `:ok` and `:more` branches now call `update_in(conn.assigns[:raw_body], &[body | &1 || []])`. Updated moduledoc to document chunked delivery.
- `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` — Appended `BL-01 regression: CacheBodyReader chunked-body accumulation` describe block with `ChunkedTestAdapter` (minimal `Plug.Conn.Adapter` impl) and two tests; the 5 existing tests are untouched.
- `.planning/phases/33-webhook-ingress-durability/33-06-SUMMARY.md` — This file (created).

## Decisions Made

- **Use `case` not `with`.** The original single-clause `with` was the source of BL-01. At a teaching-example boundary that adopters are explicitly told to copy, exhaustiveness over brevity is mandatory.
- **Custom adapter inside the test module.** `Plug.Test.conn/3` cannot produce `{:more, ...}` regardless of `:read_length` because `Plug.Adapters.Test.Conn.read_req_body/2` always returns `:ok`. Rather than booting a real Cowboy adapter, the test defines a minimal `ChunkedTestAdapter` that pops chunks from a list. This keeps the regression test fast (~ms) and self-contained.
- **Pair unit + E2E rather than two unit tests.** The unit test directly proves `:more` writes the chunk; the E2E test proves the full HMAC pipeline still works end-to-end via the Endpoint. The two tests together cover the boundary that BL-01 broke (chunks dropped) and the boundary that always worked (single `:ok` read), which gives future maintainers immediate signal on which half regressed if either fails.

## Deviations from Plan

**1. [Out-of-scope cleanup] Prefixed unused `state` parameter on `ChunkedTestAdapter.upgrade/3`**
- **Found during:** Task 2 verification (running `mix test` produced an unused-variable warning).
- **Issue:** The plan's verbatim adapter stub used `def upgrade(state, _protocol, _opts), do: {:error, :not_supported}` with `state` unused, producing a compile warning.
- **Fix:** Renamed `state` to `_state` to silence the warning. Behavior unchanged.
- **Files modified:** `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs` (one character change inside the same Task 2 commit).
- **Verification:** `mix test` now produces no warnings; 7 tests, 0 failures.
- **Committed in:** `e8c42a3` (folded into Task 2 commit since it was the same code path).

This is a Rule 1 (auto-fix) cosmetic adjustment — no plan-content deviation. The plan stub was a verbatim paste from the BL-01 reference fix; the warning is incidental to the chosen adapter shape.

## Verification Evidence (Task 3)

| Check | Result |
|-------|--------|
| `grep -c "with {:ok, body, conn} <- Plug.Conn.read_body" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | `0` (old shape gone) |
| `grep -c "{:more, body, conn} ->" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | `1` (:more branch exists) |
| `grep -c "{:error, _} = err" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | `1` (:error passthrough exists) |
| `grep -c "update_in(conn.assigns\[:raw_body\]" examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex` | `2` (one per :ok/:more) |
| `MIX_ENV=test mix test` (chimeway core) | 548 tests, 0 failures |
| `mix verify.example` | exit 0; 7 tests, 0 failures |
| `git diff --name-only HEAD~2 HEAD lib/chimeway/` | empty (D-10 boundary preserved) |

## Threat Mitigation Updates

- **T-33-RAWBODY** (Tampering / Spoofing on `CacheBodyReader.read_body/2`): the test suite no longer leaves the `:more` path unexercised. The unit regression test in the new describe block forces `{:more, ...}` via `ChunkedTestAdapter` and asserts every chunk accumulates before flattening — the mitigation is now actively monitored, not just structurally claimed.
- **T-33-CHUNK-DROP** (Spoofing / Repudiation on `CacheBodyReader.read_body/2`, previously unmitigated): the `:more` branch now writes to `conn.assigns[:raw_body]` before returning to `Plug.Parsers`. The unit test asserts `conn.assigns[:raw_body] == [chunk1]` after the first (`:more`) read and `[chunk2, chunk1]` after the second (`:ok`) read, directly proving no chunk is dropped.

## Notes for Adopters (D-12 fulfillment)

The `CacheBodyReader` moduledoc now correctly documents chunked-delivery behavior:

```
## Chunked delivery (production Cowboy)

`Plug.Conn.read_body/2` returns `{:more, chunk, conn}` when the provider
body exceeds Cowboy's `:read_length` (default 1 MB). `Plug.Parsers` calls
`read_body/2` in a loop until it receives `:ok`. This implementation caches
EVERY chunk — both `:ok` and `:more` branches prepend to the accumulator —
so the full body is available in `conn.assigns[:raw_body]` regardless of
how many TCP reads the provider request required.
```

Adopters who copy the canonical pattern verbatim now get correct chunked-body behavior. The D-12 reference is safe.

## Self-Check: PASSED

- FOUND: `examples/chimeway_demo_host/lib/demo_host_web/plugs/cache_body_reader.ex`
- FOUND: `examples/chimeway_demo_host/test/demo_host_web/controllers/webhooks_controller_test.exs`
- FOUND: `.planning/phases/33-webhook-ingress-durability/33-06-SUMMARY.md`
- FOUND: commit `bdaa3db` (Task 1)
- FOUND: commit `e8c42a3` (Task 2)

All claimed artifacts and commits exist on disk and in git history.
