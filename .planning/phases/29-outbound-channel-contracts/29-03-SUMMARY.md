---
phase: 29-outbound-channel-contracts
plan: "03"
subsystem: rendering
tags: [elixir, ecto, ecto-changeset, channel-validators, sms, push, chat]

# Dependency graph
requires:
  - phase: 29-outbound-channel-contracts
    provides: "Chimeway.Rendering.Channel behaviour module from Plan 01 (use macro injects @behaviour)"
provides:
  - "Chimeway.Rendering.Channels.Sms validator (text_body required, vendor fields stripped)"
  - "Chimeway.Rendering.Channels.Push validator (title + body required, optional opaque data map)"
  - "Chimeway.Rendering.Channels.Chat validator (text required, optional opaque rich_payload map)"
  - "All five built-in channel modules now declare use Chimeway.Rendering.Channel"
affects:
  - "Plan 29-04 (channel registry resolution): depends on Sms/Push/Chat modules existing"
  - "Future phases adding channel adapters for SMS/Push/Chat providers"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-channel render-contract validator pattern: Ecto.Changeset over `{%{}, @types}` with required + optional fields, opaque :map fields for vendor payloads, stringified-key map result"
    - "@behaviour enforcement via use macro: `use Chimeway.Rendering.Channel` + `@impl Chimeway.Rendering.Channel` annotation surfaces typos at compile time"
    - "Vendor field stripping by Ecto.Changeset cast/3: keys not in @types are silently dropped, eliminating accidental vendor leakage into render_data"

key-files:
  created:
    - "lib/chimeway/rendering/channels/sms.ex"
    - "lib/chimeway/rendering/channels/push.ex"
    - "lib/chimeway/rendering/channels/chat.ex"
    - "test/chimeway/rendering/channels/sms_push_chat_validators_test.exs"
  modified:
    - "lib/chimeway/rendering/channels/email.ex"
    - "lib/chimeway/rendering/channels/in_app.ex"

key-decisions:
  - "Sms render contract scope is text_body only; sender ID, Messaging Service SID, and recipient phone number are adapter-config territory"
  - "Push render contract is title + body + opaque data :map; APNs/FCM platform plumbing belongs in adapter, not render_data"
  - "Chat render contract uses Slack-native field name `text` (not `text_body`) and exposes rich_payload as opaque :map for vendor blocks/embeds"
  - "All five built-in channel validators (Email, InApp, Sms, Push, Chat) declare @behaviour via use macro so missing or typo'd validate/1 surfaces at compile time"

patterns-established:
  - "Per-channel render-contract validator pattern: copy email.ex skeleton verbatim, substitute @types/@required_fields/@moduledoc, declare use + @impl"
  - "Opaque :map field pattern: validate type only (not shape) for app-specific custom payloads where the library cannot know vendor semantics"
  - "Vendor field rejection via cast/3 surface area: no explicit deny-list needed; @types is the allow-list"

requirements-completed:
  - CHAN-01
  - CHAN-02

# Metrics
duration: 3m21s
completed: 2026-05-01
---

# Phase 29 Plan 03: Channel Modules Summary

**Three new channel render-contract validators (Sms, Push, Chat) built from the Email skeleton plus @behaviour declarations on Email and InApp — five built-in channel modules now compile-time-checked.**

## Performance

- **Duration:** 3m21s
- **Started:** 2026-05-01T01:34:54Z
- **Completed:** 2026-05-01T01:38:15Z
- **Tasks:** 2
- **Files created:** 4 (sms.ex, push.ex, chat.ex, sms_push_chat_validators_test.exs)
- **Files modified:** 2 (email.ex, in_app.ex)

## Accomplishments

- Created `Chimeway.Rendering.Channels.Sms` validator with `text_body :string` required field; vendor fields (from, to, phone_number, media_url) silently stripped by Ecto cast/3 (T-29-07 mitigation).
- Created `Chimeway.Rendering.Channels.Push` validator with `title :string` and `body :string` required, plus optional `data :map` for opaque app-specific payloads; APNs/FCM platform plumbing (apns_topic, priority, device_token) stripped (D-08 accept).
- Created `Chimeway.Rendering.Channels.Chat` validator with `text :string` required (Slack-native field name) and optional `rich_payload :map` for vendor block kits (D-09 accept).
- Refactored `Chimeway.Rendering.Channels.Email` and `Chimeway.Rendering.Channels.InApp` to declare `@behaviour Chimeway.Rendering.Channel` via the `use` macro plus `@impl` annotation on `validate/1` (T-29-10 mitigation, D-11).
- Added a focused test file (`sms_push_chat_validators_test.exs`) with 17 tests covering required-field errors, vendor field stripping, optional opaque maps, non-map fallback, and behaviour-declaration assertions.

## Task Commits

Each task was committed atomically. Task 1 used the TDD RED → GREEN cycle.

1. **Task 1 (RED): Failing tests for Sms, Push, Chat validators** — `550055f` (test)
2. **Task 1 (GREEN): Implement Sms, Push, Chat validators** — `e125425` (feat)
3. **Task 2: Declare @behaviour on Email and InApp** — `5731c0f` (refactor)

_Note: Task 1 was tdd="true" so it produced two commits (RED + GREEN). REFACTOR was unnecessary since the GREEN implementation already mirrored the email.ex template verbatim. Plan-metadata commit (with this SUMMARY.md) is owned by the orchestrator after the wave completes._

## Files Created/Modified

- `lib/chimeway/rendering/channels/sms.ex` — SMS render contract validator (text_body required, vendor field stripping via cast/3, opaque non-map fallback)
- `lib/chimeway/rendering/channels/push.ex` — Push render contract validator (title + body required, optional opaque data :map for app payloads)
- `lib/chimeway/rendering/channels/chat.ex` — Chat render contract validator (text required, optional opaque rich_payload :map for vendor block kits)
- `lib/chimeway/rendering/channels/email.ex` — Added `use Chimeway.Rendering.Channel` and `@impl` annotation; no functional change
- `lib/chimeway/rendering/channels/in_app.ex` — Added `use Chimeway.Rendering.Channel` and `@impl` annotation on outer `validate/1` only (private `validate_primary_action/1` left unchanged)
- `test/chimeway/rendering/channels/sms_push_chat_validators_test.exs` — 17 tests covering all three new validators (RED → GREEN driven)

## Decisions Made

None beyond the plan's specified design decisions (D-01 through D-11, D-25). The plan front-loaded all field shapes, moduledoc paragraphs, and structural choices verbatim — execution applied them directly. No deviations needed.

## Deviations from Plan

None — plan executed exactly as written.

The plan's `<interfaces>` block provided the verbatim email.ex skeleton; per-module substitutions (module name, @types, @required_fields, @moduledoc paragraph, use + @impl) were applied as specified. Both tasks satisfied all acceptance-criteria checks on the first run.

## Issues Encountered

None during implementation.

One environmental setup step was needed before tests could run: `mix deps.get` had to fetch dependencies (the worktree had no `deps/` directory yet). This is normal worktree-setup overhead, not a plan deviation. Once deps were fetched, RED ran cleanly with 17 expected failures and GREEN passed all 17 tests on the first try.

## Verification Results

- `mix compile --warnings-as-errors` — exits 0 across all five channel modules
- `mix test test/chimeway/rendering/channel_contract_test.exs` — 3 tests, 0 failures (existing email/in_app coverage unaffected)
- `mix test test/chimeway/rendering/channels/sms_push_chat_validators_test.exs` — 17 tests, 0 failures
- `mix test test/chimeway/rendering/channel_behaviour_test.exs` — 7 tests, 0 failures (Plan 01 behaviour contract still passes)
- Combined rendering tests — 27 tests, 0 failures
- `grep -rn "use Chimeway.Rendering.Channel" lib/chimeway/rendering/channels/` — 5 matches (Email, InApp, Sms, Push, Chat)

## TDD Gate Compliance

Task 1 (`tdd="true"`) followed the RED → GREEN sequence:

1. RED commit `550055f` (test): tests added with all 17 assertions failing on `UndefinedFunctionError` (modules did not yet exist) — clean RED.
2. GREEN commit `e125425` (feat): implementations added; all 17 tests pass.
3. REFACTOR step was evaluated and skipped — the implementation files already matched the email.ex template verbatim, so no cleanup was warranted. (REFACTOR is optional per the TDD reference; no commit is created when no changes are made.)

The gate sequence is intact in `git log` and verifiable via the commit message prefixes (`test(...)` → `feat(...)`).

## Threat Surface Scan

No new security-relevant surface introduced beyond what the plan's `<threat_model>` already documents (T-29-07 through T-29-10). All four threats are addressed:

- **T-29-07 (mitigate):** SMS vendor fields stripped by cast/3 — verified by `Sms.validate/1` test "strips vendor fields like from/to/phone_number".
- **T-29-08 (accept):** Push `data :map` is type-validated only by design — confirmed in the moduledoc and in the "accepts optional data map" test.
- **T-29-09 (accept):** Chat `rich_payload :map` is opaque host-app territory — confirmed in the moduledoc and in the "accepts optional rich_payload" test.
- **T-29-10 (mitigate):** `@behaviour` enforcement via `use` macro and `@impl` annotation — confirmed by the `module_info(:attributes)` assertions for all three new modules and the Email/InApp refactor (Task 2).

No threat flags raised — no new endpoints, auth paths, file access, or schema changes.

## Known Stubs

None. The three new validators are fully wired with required-field enforcement and opaque-map type checking; there are no placeholder values, mock data, or "TODO" markers in any committed file. Email and InApp refactors are pure annotation additions with zero functional change.

## Next Phase Readiness

- Plan 29-04 (channel registry resolution, wave 3) can proceed: it depends on Sms/Push/Chat modules existing, which they now do.
- All five built-in channel validators are uniformly contract-checked at compile time, so future channel additions follow a discoverable, consistent pattern (just `use Chimeway.Rendering.Channel` + `@impl`).
- No blockers introduced.

## Self-Check: PASSED

**Files claimed created:**
- `lib/chimeway/rendering/channels/sms.ex` — FOUND
- `lib/chimeway/rendering/channels/push.ex` — FOUND
- `lib/chimeway/rendering/channels/chat.ex` — FOUND
- `test/chimeway/rendering/channels/sms_push_chat_validators_test.exs` — FOUND

**Files claimed modified:**
- `lib/chimeway/rendering/channels/email.ex` — modified at HEAD (use + @impl added)
- `lib/chimeway/rendering/channels/in_app.ex` — modified at HEAD (use + @impl added)

**Commits claimed:**
- `550055f` (test RED) — FOUND in git log
- `e125425` (feat GREEN) — FOUND in git log
- `5731c0f` (refactor) — FOUND in git log

All claims verified.

---

*Phase: 29-outbound-channel-contracts*
*Plan: 03*
*Completed: 2026-05-01*
