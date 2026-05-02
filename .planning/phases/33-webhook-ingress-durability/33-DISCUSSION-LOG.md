# Phase 33: webhook-ingress-durability - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `33-CONTEXT.md`.

**Date:** 2026-05-01
**Phase:** 33-webhook-ingress-durability
**Mode:** assumptions + delegated research
**Areas analyzed:** durable async handoff, stale callback handling, host ingress proof

## Assumptions Presented

### Durable async handoff
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `process/4` should only acknowledge success after durable queueing, not after an optimistic helper return. | Likely | `lib/chimeway/webhooks.ex`, `lib/chimeway/webhooks/process_feedback_worker.ex`, `lib/chimeway/signal.ex`, `.planning/v1.4-MILESTONE-AUDIT.md` |

### Unknown delivery resolution
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Unknown or stale callback correlation should stop raising and converge on a safe non-retrying path. | Likely | `lib/chimeway/webhooks/process_feedback_worker.ex`, `test/chimeway/webhooks/process_feedback_worker_test.exs`, `lib/chimeway/dispatch/workflow_progression_worker.ex`, `.planning/v1.4-MILESTONE-AUDIT.md` |

### Runtime ingress proof
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The repo should prove a host-mounted HTTP ingress path without adding Phoenix/Plug coupling to core. | Likely | `mix.exs`, `prompts/chimeway-host-app-integration-seam.md`, `.planning/ROADMAP.md`, `.planning/v1.4-MILESTONE-AUDIT.md` |

### Scope boundary
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 33 should close durability/safety/proof gaps only, leaving vocabulary unification and full E2E proof to Phase 34. | Confident | `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/v1.4-MILESTONE-AUDIT.md` |

## Research Applied

### Durable async handoff
- **Recommendation:** add a dedicated ingress row and atomically enqueue the feedback
  worker in the same `Ecto.Multi`; acknowledge HTTP success only after commit.
- **Alternatives rejected:** optimistic enqueue helper; sync processing before ack.
- **Why:** strongest match for Chimeway's explainability and durable-spine goals.

### Safe stale callback handling
- **Recommendation:** use `:ok`/noop for stale or unknown callback correlation, but record
  the ignored reason durably on the ingress surface.
- **Alternatives rejected:** raising `get_delivery!`; retrying `{:error, :not_found}`;
  silent noop with no audit trail.
- **Why:** protects queue health while preserving explainability.

### Runtime ingress proof
- **Recommendation:** keep `Chimeway.Webhooks.process/4` as the only core boundary and add
  an executable Phoenix fixture/example app with real route/body-reader/controller wiring.
- **Alternatives rejected:** docs-only proof; Chimeway-owned Plug/controller helper in
  core; pseudo request-map shim.
- **Why:** best combination of optional integration, least surprise DX, and real proof.

## External Sources Consulted

### Elixir / Ecto / Plug / Oban
- Plug `Plug.Parsers` docs — `:body_reader` is the official raw-body seam for signature
  verification: <https://hexdocs.pm/plug/Plug.Parsers.html>
- Oban docs — atomic `Oban.insert` with `Ecto.Multi`, job insertion return contract:
  <https://hexdocs.pm/oban/Oban.html>
- Oban error handling docs — `{:error, reason}` and unhandled exceptions retry:
  <https://hexdocs.pm/oban/error_handling.html>
- Ecto transaction and lookup posture:
  <https://hexdocs.pm/ecto/Ecto.Multi.html>
  <https://hexdocs.pm/ecto/Ecto.Repo.html>

### Comparable webhook ecosystems
- Stripe webhook docs — raw body is required, handle asynchronously, return success quickly:
  <https://docs.stripe.com/webhooks?locale=en-GB>
- Stripe signature docs:
  <https://docs.stripe.com/webhooks/signature?lang=node&locale=en-GB>
- GitHub webhook best practices / troubleshooting:
  <https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks>
  <https://docs.github.com/en/webhooks/testing-and-troubleshooting-webhooks/troubleshooting-webhooks>
- Shopify webhook best practices:
  <https://shopify.dev/docs/apps/build/webhooks/best-practices>
- Twilio Conversations webhooks / events:
  <https://www.twilio.com/docs/conversations/conversations-webhooks>
  <https://www.twilio.com/docs/events>

### Adjacent library design references
- Symfony Webhook component — centralized parser/consumer architecture:
  <https://symfony.com/doc/current/webhook.html>
- LatticeStripe webhook docs — pure verification core plus Plug/Phoenix integration
  pattern:
  <https://hexdocs.pm/lattice_stripe/LatticeStripe.Webhook.html>
  <https://hexdocs.pm/lattice_stripe/LatticeStripe.Webhook.CacheBodyReader.html>
- DoubleEntryLedger.Oban — adjacent embedded-library transaction seam:
  <https://hexdocs.pm/double_entry_ledger/DoubleEntryLedger.Oban.html>

## Corrections Made

None. Research strengthened the original assumptions and collapsed the remaining branch
choices into one cohesive recommendation set.

## Final Recommendation Shape

1. Add a durable ingress row for trusted callbacks.
2. Insert ingress row and feedback job atomically in one transaction.
3. Treat unresolved callback correlation as `:ok` + durable ignored reason.
4. Keep core framework-agnostic.
5. Prove ingress in a real Phoenix fixture/example app using a raw-body body reader.
6. Leave vocabulary unification and full E2E proof to Phase 34.

