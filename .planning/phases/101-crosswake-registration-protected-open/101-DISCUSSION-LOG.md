# Phase 101: CrossWake Registration & Protected Open - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-08-22
**Phase:** 101-crosswake-registration-protected-open
**Mode:** assumptions
**Areas analyzed:** Registration Lifecycle Authority, Manifest-Consistent Notification Policy, Offline One-Time Protected Open

## Assumptions Presented

### Registration Lifecycle Authority

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The host registry is the sole authority for an APNs binding: authenticated scoped observations refresh or supersede atomically, and revocation/invalidation disables only the exact revision. | Likely | `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/contracts.ex`; `.planning/phases/97-tenant-identity-compatible-upgrade/97-CONTEXT.md`; `.planning/phases/100-optional-apns-adapter/100-CONTEXT.md` |
| Raw APNs tokens remain transient; durable and observable contracts carry only opaque refs and closed safe facts. | Confident | `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/redaction.ex`; `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/telemetry.ex`; `.planning/phases/98-privacy-safe-delivery-evidence/98-CONTEXT.md` |

### Manifest-Consistent Notification Policy

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Normalize `notification_open` into one closed default-deny manifest representation; legacy `true` permits only the canonical default tap action. | Confident | `../crosswake/lib/crosswake/policy/schema.ex`; `../crosswake/lib/crosswake/manifest/builder.ex`; `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex` |
| A consumed intent still passes the current compiled manifest and RouteGate; notification denials halt and never navigate through fallback. | Confident | `../crosswake/lib/crosswake/compatibility/route_gate.ex`; `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/resolver.ex`; `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/ActivationCoordinator.swift` |

### Offline One-Time Protected Open

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Offline taps enter a bounded opaque queue; reconnect atomically consumes one intent with current tenant, binding, expiry, and session checks before current manifest and RouteGate authorization. | Likely | `.planning/REQUIREMENTS.md`; `.planning/ROADMAP.md`; `../crosswake/packages/crosswake_chimeway/lib/crosswake/companions/chimeway/intent_consumer.ex`; `.planning/research/ARCHITECTURE.md` |
| Phase 101 adds only required iOS registration/open seams and excludes digital-twin, physical-device, generic sync, Android/FCM, and general action-framework work. | Confident | `../crosswake/packages/crosswake-shell-core-ios/Sources/CrosswakeShellCore/CrosswakeShellConfig.swift`; `.planning/ROADMAP.md`; `../crosswake/.planning/phases/162-physical-iphone-adoption-proof/162-CONTEXT.md` |

## Corrections Made

No corrections — all assumptions confirmed.

