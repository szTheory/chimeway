---
status: verifying
trigger: "Diagnose and fix the cross-phase regression: `mix cmd --cd chimeway_inbox mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs:83 --warnings-as-errors` fails during `mount_bell(conn)`, while Phoenix's missing `ChimewayInbox.ErrorView` masks the original exception."
created: 2026-08-13T15:20:00-04:00
updated: 2026-08-13T15:38:00-04:00
---

## Current Focus
<!-- OVERWRITE on each update - reflects NOW -->

reasoning_checkpoint:
  hypothesis: "BellDropdownLive assigns `{:error, :unsafe_evidence}` to `unread_count` because Phase 98 makes `Chimeway.unread_count/2` reject raw `user:42`; `bell_aria_label/1` then interpolates that tuple and crashes. The stale inbox auth/fixtures supply the raw value, and a missing test ErrorView masks the crash."
  confirming_evidence:
    - "With test-only `debug_errors: true`, the exact test exposes `Protocol.UndefinedError` for `{:error, :unsafe_evidence}` at BellDropdownLive.bell_aria_label/1."
    - "Chimeway.Inbox.unread_count/2 delegates recipient validation to SafeEvidence.opaque_ref/2, which rejects `user:42`; BellDropdownLive rescues only exceptions and assigns its direct return value."
    - "Phase 98 plan 02 explicitly requires opaque `cw_` recipient references, while AllowAuth and all BellDropdownLive test fixtures still use raw `user:42`/`user:99`."
  falsification_test: "After making `unread_count` accept only a nonnegative integer and converting fixture identities to valid opaque refs, the focused test must mount with an integer count and no 500; an unchanged tuple or a new error would disprove the mechanism."
  fix_rationale: "Guarding the unread-count result prevents any fail-closed Inbox error tuple from becoming a render crash; bringing test auth and inserted notification identities onto the opaque-reference contract exercises the intended successful tenant-scoped path. Test Endpoint debug errors exposes future failures without adding a production 500 template."
  blind_spots: "The failing test has not yet been rerun after the change, and the full chimeway_inbox suite may contain unrelated stale raw-reference fixtures."
  candidate_causes:
    - "code: BellDropdownLive assumes unread_count always returns an integer despite its error-returning Inbox boundary."
    - "data: the inbox package's auth/fixture test identities predate the Phase 98 opaque-reference contract."
    - "config: the test Endpoint lacks debug_errors and therefore masks LiveView exceptions with an absent ErrorView."
  and_gate: "yes — the observed 500 requires both a rejected raw recipient from stale test data and the LiveView's unchecked tuple interpolation; the missing ErrorView independently masks the causal stack trace."

hypothesis: Confirmed — stale raw test identities caused a fail-closed Inbox tuple; the bell rendered that tuple as a count.
test: Run the exact original test and full `chimeway_inbox` suite after the minimal UI guard, opaque fixture migration, and test-only diagnostic configuration.
expecting: The target passes, no unsafe value appears in UI output, and the package suite remains green.
next_action: Inspect the final diff, run the exact original command once more, then commit only owned source/test/config files.

## Symptoms
<!-- Written during gathering, then IMMUTABLE -->

expected: The Bell dropdown LiveView mounts successfully for a tenant-scoped recipient.
actual: `mount_bell(conn)` fails and Phoenix then raises because `ChimewayInbox.ErrorView` has no renderable template/module, masking the initial exception.
errors: Phoenix unable to render its 500 response because `ChimewayInbox.ErrorView` is absent; original exception unknown.
reproduction: `mix cmd --cd chimeway_inbox mix test test/chimeway_inbox/live/bell_dropdown_live_test.exs:83 --warnings-as-errors`
started: After Phase 98 privacy-safe Trigger projection and render-context resolver work.

## Eliminated
<!-- APPEND only - prevents re-investigating -->

## Evidence
<!-- APPEND only - facts discovered -->

- timestamp: 2026-08-13T15:20:00-04:00
  checked: Existing debug sessions and Phase 97/98 planning artifacts.
  found: The active wave-7 session documents Phase 98 opaque recipient-reference and privacy-projection contract changes; this inbox failure is not recorded there.
  implication: Treat changed recipient and rendering contracts as candidates, while independently validating view configuration.

- timestamp: 2026-08-13T15:24:00-04:00
  checked: Phase 98 plans 02, 08, and 10 summaries plus the full focused test.
  found: Phase 98 made Inbox predicates require host-supplied opaque `cw_` recipient references, while the exact targeted test is the changed-tenant case that mounts before modifying tenant state.
  implication: The normal default auth fixture's `user:42` recipient may now violate the core Inbox boundary during mount.

- timestamp: 2026-08-13T15:26:00-04:00
  checked: Exact line-83 command and complete BellDropdownLive implementation.
  found: The command deterministically fails at `mount_bell/1` with only the missing `ChimewayInbox.ErrorView` 500-render error. BellDropdownLive rescues list/count errors, so that error cannot originate in `load_inbox/3`.
  implication: The underlying exception is earlier than the LiveView's Inbox fetch path, likely in the shared authentication/on-mount lifecycle.

- timestamp: 2026-08-13T15:31:00-04:00
  checked: Test Endpoint diagnostics, LiveAuth, core Inbox, SafeEvidence, and focused test rerun.
  found: With `debug_errors: true` in test configuration, the original exception is `Protocol.UndefinedError` at `bell_aria_label/1`: the assigned count is `{:error, :unsafe_evidence}`. Phase 98 rejects raw `user:42`; the LiveView only rescues exceptions, not error tuples.
  implication: The confirmed failure is a stale opaque-reference fixture plus unchecked fail-closed result, not missing error rendering.

- timestamp: 2026-08-13T15:38:00-04:00
  checked: Focused BellDropdownLive suite and complete chimeway_inbox suite after targeted corrections.
  found: BellDropdownLive has 11 passing tests, including an unsafe raw-recipient regression that stays mountable, renders no error tuple, and reports the normal load-failed state; full chimeway_inbox has 12 passing tests.
  implication: The correction preserves both opaque-reference fail-closed behavior and a safe operator-visible fallback.

## Resolution
<!-- OVERWRITE as understanding evolves -->

root_cause: "Phase 98's opaque-recipient validation makes raw `user:42` return `{:error, :unsafe_evidence}`. The inbox test auth/fixtures remained raw, and BellDropdownLive treated the result of unread_count as an integer then interpolated the tuple in its aria label. The missing test ErrorView obscured this actual exception."
fix: "Use opaque `cw_` identities in inbox auth/test fixtures; accept only nonnegative integer unread counts in BellDropdownLive and default failure results to zero; enable Phoenix test debug errors; add a regression test for safe raw-recipient UI failure."
verification: "Focused BellDropdownLive suite: 11 tests, 0 failures. Complete chimeway_inbox suite: 12 tests, 0 failures. Formatting check passed."
files_changed: ["chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex", "chimeway_inbox/test/support/allow_auth.ex", "chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs", "chimeway_inbox/config/test.exs"]
