---
phase: 107-operator-timeline-guidance-gate-parity
reviewed: 2026-09-13T02:33:24Z
reviewed_at: 2026-09-13T02:33:24Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/chimeway/traces.ex
  - lib/chimeway/safe_evidence.ex
  - test/chimeway/traces_test.exs
  - test/chimeway/safe_evidence_test.exs
  - chimeway_admin/lib/chimeway_admin/components/timeline_event.ex
  - chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs
  - examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs
  - guides/introduction/inbox-integration.md
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
  - mix.exs
  - MAINTAINING.md
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
critical: 2
blockers: 2
warnings: 1
info: 0
suggestions: 0
status: issues_found
---

# Phase 107: Code Review Report

**Reviewed:** 2026-09-13T02:33:24Z
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

The timeline projection, closed evidence vocabulary, admin rendering, and ordered gate composition are internally consistent, and `mix verify.inbox --warnings-as-errors` completed with 156 tests across its five layers and no failures. The review nevertheless found two release-blocking correctness/safety gaps and one contract-coverage weakness. The green gate does not exercise either blocker.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01 — BLOCKER: A forged `load_more` event records “seen” while the panel is closed

**Files:** `guides/introduction/inbox-integration.md:138-158`; `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:112-142`

**Cross-file evidence:** `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex:91-105`

**Issue:** Phase 107 defines inbox seen as proof that a row was revealed on a visible page and documents `load_more` as marking newly visible rows. The server handler, however, never checks `socket.assigns.panel_open`: any authorized connected client can send the `load_more` LiveView event while the panel is closed, after which the handler fetches the next page and immediately calls `mark_items_seen/3`. Those rows were never rendered, yet durable `seen_at` values and `chimeway.notification.seen` signals can be recorded and can progress workflows. The new demo proof follows only the normal DOM path, so the claimed explainability invariant remains untested and false at the event boundary.

**Fix:** Require an open panel before loading or marking the next page, and add a direct-event regression test that sends `load_more` while closed and asserts that no second-page row receives `seen_at` and no seen signal is emitted. For example:

```elixir
def handle_event("load_more", _params, %{assigns: %{panel_open: true}} = socket) do
  # existing authorized fetch-and-mark path
end

def handle_event("load_more", _params, socket), do: {:noreply, socket}
```

### CR-02 — BLOCKER: The recursive cleanup guard recognizes a name prefix, not test ownership

**File:** `test/chimeway/release_gate_contract_test.exs:89-119,3001-3028,3042-3055`

**Issue:** `remove_owned_temp_dir!/1` will recursively delete any existing immediate child of the system temp directory whose basename begins with one of four public prefixes. It does not prove that `owned_temp_directory!/1` created that directory in the current run. The refusal test labels a directory “unowned” only by giving it a nonmatching prefix, so it misses the dangerous case: an unrelated or stale `/tmp/chimeway_release_gate_*` directory is accepted and deleted. In addition, names use `System.unique_integer/1`, which is unique only inside one BEAM VM; concurrent repository/worktree test runs can choose the same basename. `build_unpacked_package!/0` does not reserve its path with the constructor before handing it to Hex, increasing the collision window. This is a bounded but real recursive data-loss and cross-run interference risk in the release gate the phase claims to make ownership-safe.

**Fix:** Allocate one random, atomically-created scratch root per fixture (for example with `Briefly`/`mkdtemp` semantics or a cryptographically random suffix and exclusive `File.mkdir/1` retry), place build output beneath it, and bind cleanup to evidence created by that allocator rather than a prefix alone. Add a refusal test for an independently created immediate temp child whose name has an allowed prefix, plus a concurrency/collision test. Keep the final `lstat` non-symlink check at the deletion boundary.

## Warnings

### WR-01 — WARNING: The notification-content documentation contract misses common unsafe Elixir forms

**File:** `test/chimeway/doc_contract_test.exs:1245-1253,1339-1344`

**Issue:** The new privacy contract is an exact-substring denylist. It rejects string-key examples such as `"body" => notification.body` but permits equivalent, common atom-key code such as `metadata: %{subject: notification.subject, body: notification.body}`. None of the seven forbidden strings matches that example, so the contract can stay green while future copy-paste guidance publishes raw notification content. This weakens the executable evidence used to close T-107-05.

**Fix:** Cover both atom-key and string-key forms with whitespace-tolerant regexes, or extract Elixir code fences and inspect their AST for metadata/render/content values derived from notification/session/params. At minimum, add negative mutations for `subject: notification.*`, `body: notification.*`, and nested `metadata` maps and prove each mutation fails the tagged contract.

## Verification Performed

- `mix verify.inbox --warnings-as-errors` — passed: 74 root, 24 inbox-package, 9 admin, 44 tagged contract, and 5 demo-host tests; 0 failures.
- `git diff --check dce95b90^..HEAD` — implementation files are clean; only pre-existing planning-artifact trailing whitespace was reported.
- Reviewed the phase diff from `dce95b90^`, all 12 scoped files, and the `BellDropdownLive` authorization/visibility call chain supporting CR-01.

---

_Reviewed: 2026-09-13T02:33:24Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
