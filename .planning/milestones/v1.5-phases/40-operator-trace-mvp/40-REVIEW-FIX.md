---
phase: 40-operator-trace-mvp
status: all_fixed
iteration: 1
fix_scope: critical_warning
findings_in_scope: 7
fixed: 7
skipped: 0
fixed_at: 2026-05-29
---

# Phase 40 Code Review Fix Report

**Fix scope:** critical + warning (default)  
**Iteration:** 1  
**Status:** all_fixed

## Summary

Applied fixes for all 1 critical and 6 warning findings from `40-REVIEW.md`. Info-level items (IN-01 through IN-04) were out of scope for this pass.

## Fixes Applied

### CR-01: Hardcoded absolute paths break scoped host mounts — FIXED

- Added `ChimewayAdmin.Routes` with configurable `path_prefix`
- Updated `TraceSearchLive` navigation (`open_delivery`) and `TraceDetailLive` back links
- Configured demo host: `config :chimeway_admin, path_prefix: "/admin/chimeway"`
- Added `chimeway_admin/test/chimeway_admin/routes_test.exs`

### WR-01: Correlation search unbounded — FIXED

- Added optional `limit:` to `Chimeway.Traces.find_traces_by_correlation_id/2`
- `TraceSearchLive` passes `limit: 50` for correlation mode (matches recipient search)
- Added limit test in `test/chimeway/traces_test.exs`

### WR-02: `redact_recipient/1` passthrough leaks identities — FIXED

- Default opaque masking for unrecognized identity shapes
- Explicit `webhook:` prefix handling
- Phone-number pattern masking
- Extended `redaction_test.exs`

### WR-03: `ALLOW_DEMO_ADMIN` production escape hatch — FIXED

- Removed `ALLOW_DEMO_ADMIN` env bypass from `DemoHost.AdminAuth`
- Production now always denies; logs warning directing hosts to implement real auth

### WR-04: `LiveAuth` catch-all for unexpected returns — FIXED

- Catch-all clause logs and treats unexpected `authorize/3` returns as unauthorized
- Documented allowed return values in `LiveAuth` moduledoc
- Added `UnexpectedAuth` test support module and test case

### WR-05: Authorization only at mount — FIXED

- Added `LiveAuth.ensure_authorized/2` for event handlers
- `TraceSearchLive` re-checks auth on `search` and `open_delivery` events
- Session stashed in `:chimeway_admin_session` assign at mount

### WR-06: `error_class` rendered without sanitization — FIXED

- Added `Redaction.safe_error_class/1` for summary display
- Masks paths, emails, and explicit secret/password patterns
- `TraceDetailLive.format_last_attempt/1` uses safe helper

## Additional Improvements (related info findings)

- `unauthorized_redirect` config supported in `LiveAuth` (addresses IN-02 partially)
- `ChimewayAdmin.Auth` moduledoc notes tenancy scoping (addresses IN-04 partially)

## Verification

```bash
cd chimeway_admin && mix test   # 11 tests, 0 failures
cd .. && mix test test/chimeway/traces_test.exs  # limit test passes
```

## Out of Scope (info)

| ID | Reason |
|----|--------|
| IN-01 | Broader LiveView integration tests — follow-up |
| IN-02 | `unauthorized_redirect` config added; demo host login redirect not wired |
| IN-03 | Oban dep acceptable for MVP |
| IN-04 | Tenancy documented; per-delivery context deferred |

## Commits

Fixes applied in working tree (not yet committed). Suggested atomic commits:

1. `fix(40): add path_prefix routes for scoped admin mounts`
2. `fix(40): bound correlation trace search and harden redaction`
3. `fix(40): harden LiveAuth and remove demo prod bypass`
