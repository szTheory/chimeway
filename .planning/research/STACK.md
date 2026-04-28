# Project Research: Stack

**Project:** Chimeway  
**Milestone:** v1.2 Delivery Orchestration  
**Researched:** 2026-04-28  
**Confidence:** HIGH

## Focus

What stack additions or existing integrations are needed to support scheduled delivery windows, digests, richer rendering, and recovery workflows without breaking Chimeway's local-first architecture?

## Findings

### Keep Oban as the scheduling backbone

- Oban supports future `scheduled_at` jobs and transitions scheduled and retryable jobs back to `:available` through job staging.
- Named uniqueness state groups can include incomplete states, which is useful when deferred or digest jobs must not duplicate while waiting or retrying.
- This aligns with Chimeway's existing async seam and avoids introducing a second scheduler abstraction.

### Use Phoenix.Swoosh for rendered outbound content

- Phoenix.Swoosh supports rendering template bodies into `html_body` and `text_body` from explicit templates and layouts.
- Template rendering can stay optional and channel-specific; Chimeway should define rendering contracts and versioned template identity rather than inventing a provider-specific mailer DSL.

### Keep template identity inside Chimeway, rendering execution in host-app seams

- The durable data model should persist template identity and version metadata.
- Rendering itself should stay composable so host applications can supply views, layouts, and channel-specific assigns.

## Recommended Stack Direction

- **Scheduling**: Oban `scheduled_at`, uniqueness constraints across incomplete states, and existing worker lifecycle semantics.
- **Persistence**: New Ecto/Postgres tables for delivery windows, digest batches or accumulators, and reconciliation metadata where required.
- **Rendering**: Phoenix.Swoosh-compatible rendering seam for email-like channels; neutral rendering contracts for in-app and custom channels.
- **Analytics**: Ecto query surfaces over existing lifecycle tables plus new digest/deferral facts.

## What Not To Add

- A second queueing/scheduling system beside Oban
- A bespoke HTML email DSL that competes with Phoenix or Swoosh rendering
- Hosted analytics infrastructure detached from the host application's data

## Sources

- Oban Job state transitions and uniqueness groups: https://hexdocs.pm/oban/Oban.Job.html
- Phoenix.Swoosh rendering and layouts: https://hexdocs.pm/phoenix_swoosh/Phoenix.Swoosh.html

---
*Research completed: 2026-04-28*
