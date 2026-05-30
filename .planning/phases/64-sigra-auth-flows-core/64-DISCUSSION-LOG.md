# Phase 64: Sigra Auth Flows Core - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 64-sigra-auth-flows-core
**Mode:** assumptions
**Areas analyzed:** Cross-Repo Integration Seam, Magic Link Dispatch Wiring, MFA Token Dispatch Target, Trace Redaction at Integration Boundary, Phase 64 Scope & CI Harness

## Assumptions Presented

### Cross-Repo Integration Seam
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship `Sigra.Integrations.Chimeway` in Sigra (conditional compile); Chimeway adds optional dep + test harness + `@moduletag :sigra` tests | Confident | `../accrue/accrue/lib/accrue/integrations/chimeway.ex`, Phase 58 CONTEXT, zero Sigra code in Chimeway today |

### Magic Link Dispatch Wiring
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Wire `Sigra.Auth.request_magic_link/3` success → `Chimeway.trigger/3` via integration module | Likely | `../sigra/lib/sigra/auth.ex` ~616–677; `../sigra/priv/templates/sigra.install/core/session_controller.ex` ~37–48 (no email send) |

### MFA Token Dispatch Target
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| “MFA token dispatch” = new/wired auth notification event; Sigra MFA today is TOTP in-app with no outbound token API | Unclear | `../sigra/lib/sigra/mfa.ex`; ECOS-09 requires second flow; SEED-003 cites MFA Token SMS |

**Locked in CONTEXT.md (user confirmed proceed):** Use **email confirmation code dispatch** as second proof flow until Sigra grows dedicated MFA email OTP.

### Trace Redaction at Integration Boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Identifier-only trigger params; reconstruct URL/code at render time; extend `@sensitive_keys` | Likely | `lib/chimeway/trigger.ex` sanitize_payload; `lib/chimeway/traces.ex` get_trace exposes payload; `../sigra/lib/sigra/delivery.ex` job args |

### Phase 64 Scope & CI Harness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Core + harness + `@moduletag :sigra` + exclude wiring; defer blueprint/demo/verify to Phases 65–66 | Confident | Phase 63 D-13, ROADMAP phase split, `mix.exs` ci.test excludes |

## Corrections Made

No corrections — all assumptions confirmed via "Yes, proceed".

## External Research

Topics flagged during analysis (not blocking CONTEXT capture):

- **Sigra MFA OTP product surface:** No library API for outbound MFA tokens today; confirmation code chosen as pragmatic second flow.
- **Delivery ownership split:** Whether Chimeway adapter vs `Sigra.Delivery` sends actual email — left to Claude's discretion in CONTEXT.md.
- **Coordinated Sigra release:** Phase 64 likely requires Sigra release with optional `:chimeway` dep; version pin TBD at planning.
