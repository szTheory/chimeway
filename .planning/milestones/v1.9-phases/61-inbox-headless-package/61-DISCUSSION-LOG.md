# Phase 61: Inbox Headless + Package - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 61-inbox-headless-package
**Mode:** assumptions
**Areas analyzed:** Headless API polish, Package bootstrap, UI contract & testing

## Assumptions Presented

### Headless API polish (Wave 61-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `Chimeway.unread_count/1` with `exclude_archived` default true | Likely | INBX-01; absent from `lib/chimeway.ex`; UI-SPEC badge |
| Paginated `list_for_recipient/2` with cursor, DTO return when opts present; struct list when not | Likely | `lib/chimeway/inbox.ex` returns all structs; UI-SPEC §Pagination |
| DTO maps with UI-SPEC keys; title/body from metadata | Confident | `lib/chimeway/trigger.ex`; UI-SPEC §Serializable item map |

### Package bootstrap (Wave 61-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Sibling `chimeway_inbox/` cloned from `chimeway_admin/` | Confident | STATE.md; `chimeway_admin/mix.exs` |
| `ChimewayInbox.Auth` with `current_recipient/2` (not action-based authorize) | Likely | UI-SPEC line 33; `ChimewayAdmin.Auth` contrast |
| Router macro mounts BellDropdownLive under host scope | Likely | INBX-02; UI-SPEC; demo host router pattern |

### UI contract & testing (Wave 61-02/03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Approved 61-UI-SPEC.md locked; no PubSub | Confident | UI-SPEC status approved 2026-05-30 |
| Package LiveViewTests only; demo host deferred to Phase 62 | Confident | ROADMAP wave split; chimeway_admin test support |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

Not performed — codebase provided sufficient evidence.
