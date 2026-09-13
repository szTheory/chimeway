# Phase 107: Operator Timeline, Guidance & Gate Parity - Research

**Researched:** 2026-09-12
**Domain:** Durable lifecycle projection, Phoenix LiveView operator presentation, adopter guidance, and CI gate composition
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Safe Timeline Projection
- Add conditional `:notification_seen` and `:notification_read` entries to every `Chimeway.Traces.explain_delivery/2` timeline, deriving timestamps directly from the parent notification's persisted `seen_at` and `read_at` fields so sibling delivery explanations agree.
- Give both events closed empty detail maps and pass them through the existing `Chimeway.SafeEvidence` event/detail allowlists. Never project recipient identity, signal payload, caller metadata, tenant, notification content, or publisher data.
- Preserve genuinely chronological presentation: sort first by authoritative timestamp and use the closed event rank only as a deterministic tie-breaker. When timestamps are equal, seen sorts before read.
- Keep read and seen independent: do not synthesize seen from read, signals, PubSub hints, delivery state, protected activation, or provider feedback.

### Admin Timeline Presentation
- Reuse `ChimewayAdmin.Components.TimelineEvent`; add explicit accessible labels “Notification seen” and “Notification read” plus stable per-event structural hooks.
- Preserve the existing timestamp element, detail list, status badge, suppression-reason handling, and both core and admin redaction layers.
- Prove presentation through focused component/redaction contracts and the mounted demo-host Trace Detail path after real seen/read transitions.
- Do not redesign the inbox or broaden admin/browser coverage beyond the timeline facts required by this phase.

### Adopter Guidance and Ownership
- Update `guides/introduction/inbox-integration.md` as the single canonical host guide. Show the working `:inbox_change_publisher`, `:pubsub_server`, high-entropy `:topic_secret`, and an auth module implementing both `current_recipient/2` and `current_tenant/2`.
- State ownership explicitly: Chimeway owns durable notification state and best-effort post-commit publishing; `chimeway_inbox` owns opaque topics, closed reload messages, subscription, and authoritative reload; the host owns authentication, tenant membership, recipient mapping, PubSub supervision, secret custody, and production authorization.
- Replace stale raw-email and deferred-seen examples with stable opaque `cw_*` recipient references and current semantics: arrival is durable creation, panel reveal marks only visible rows first-seen, read is explicit, archive is independent, and reconnect/reload does not imply engagement.
- Include a concise semantics table separating durable inbox arrival/seen/read/archive from provider handoff, visible presentation, CrossWake protected activation, and engagement; none implies another unless the host records that separate fact.

### Verification and Gate Parity
- Strengthen the existing `mix verify.inbox` composition instead of adding a CI lane. It must require focused core lifecycle/timeline/privacy/Phoenix-optional evidence, the full inbox package suite, focused admin timeline evidence, the canonical guide contract, and the demo `:inbox` journey covering arrival → mounted seen → explicit read with once-only workflow progression.
- Keep `pr-gate` and `ci-gate` dependent on the single `verify_inbox` job; extend release-gate contracts to lock the alias contents and both aggregate edges.
- Keep nightly-only admin/browser work outside `ci-gate`; do not change the established fast/release topology.
- Update `MAINTAINING.md` and doc/release contracts so pre-ship instructions name all required evidence classes and assert that both aggregate gates consume the same lane.

### the agent's Discretion
- Exact helper names, focused test-file placement, CSS hook naming, and guide prose are at the agent's discretion when consistent with existing conventions and the decisions above.

### Deferred Ideas (OUT OF SCOPE)
- Android/FCM, retention/pruning, analytics/engagement inference, generic offline sync, package promotion, additional provider integrations, broad inbox redesign, and CI topology refactors remain outside Phase 107.
- Repository-wide release hygiene and the 1.2.0 release train will run as a separate bounded stabilization batch after the milestone closes.
</user_constraints>

## Summary

Phase 107 is an integration-and-proof phase, not a storage or protocol phase. The authoritative facts already exist on the parent notification as `seen_at` and `read_at`; `explain_delivery/2` already preloads that notification for every delivery and sends the completed timeline through `SafeEvidence.trace/1`. The implementation should therefore add two conditional projection entries to the existing builder, admit exactly those atoms through the closed event vocabulary, and keep their details exactly `%{}`. [VERIFIED: lib/chimeway/notifications/notification.ex:17-32; lib/chimeway/traces.ex:189-255; lib/chimeway/safe_evidence.ex:303-366]

The critical code-level trap is the current sort key: `timeline_sort_key/1` returns `{timeline_rank(event), at}`. That makes event rank primary and timestamp secondary, contradicting the locked timestamp-first rule. The phase must reverse the priority using a real datetime comparison representation and add a fixture whose timestamps cross event ranks, plus an equal-timestamp assertion that seen precedes read. Elixir's official documentation warns that ordinary comparisons of `DateTime` structs are structural and directs callers to `DateTime.compare/2`, `before?/2`, or `after?/2`; using `DateTime.to_unix(at, :microsecond)` as the first tuple element is a simple deterministic key for the persisted UTC datetimes here. [VERIFIED: lib/chimeway/traces.ex:405-545; lib/chimeway/traces.ex:603-632] [CITED: https://hexdocs.pm/elixir/DateTime.html]

The release topology already has the correct single lane: `verify_inbox` runs on pull requests, `pr-gate` needs it, and `ci-gate` needs the same job. The missing work is to broaden the root `verify.inbox` alias from its current package-plus-demo composition, strengthen documentation/release contracts so that broadening cannot regress, and update maintainer copy. Do not add another CI job and do not move the nightly `verify_admin` browser lane into `ci-gate`. [VERIFIED: mix.exs:160-164; .github/workflows/ci.yml:450-469; .github/workflows/ci.yml:846-910; .github/workflows/ci.yml:1540-1568]

**Primary recommendation:** Implement this as two ordered plans: first close the core/admin/demo vertical slice with timestamp-first privacy-safe projection; then close canonical guidance and broaden the existing inbox alias/contracts, hardening release-test temp cleanup before running the full release gate.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Seen/read durable facts | Database / Storage | API / Backend | The notification row owns the authoritative timestamps; this phase reads them and adds no storage. [VERIFIED: lib/chimeway/notifications/notification.ex:17-32] |
| Delivery explanation projection | API / Backend | Database / Storage | `Chimeway.Traces.explain_delivery/2` owns tenant-scoped loading, timeline construction, and final safe projection. [VERIFIED: lib/chimeway/traces.ex:189-255] |
| Operator timeline labels/hooks | Frontend Server (SSR) | API / Backend | `TimelineEvent` renders server-side HEEx from the already-safe explanation, then applies admin redaction to details. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/timeline_event.ex:14-50; chimeway_admin/lib/chimeway_admin/redaction.ex:82-96] |
| Inbox arrival/seen/read interaction | Frontend Server (SSR) | API / Backend | The mounted optional package reauthorizes the host-selected tenant/recipient and calls durable core APIs; it must remain a consumer, not the timeline authority. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/live_auth.ex:14-80; examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs:20-107] |
| Opaque real-time reload | Frontend Server (SSR) | Browser / Client | `chimeway_inbox` derives the opaque topic and sends a closed reload tuple; the LiveView reloads durable state. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/change_stream.ex:12-80] |
| Adopter ownership guidance | CDN / Static | — | The canonical guide is static documentation and must describe, not reimplement, the host/core/package boundaries. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:29-33] |
| Verification composition | API / Backend | External CI service | The root Mix alias is the local owner; the existing `verify_inbox` CI job executes it and both aggregate jobs fold the same result. [VERIFIED: mix.exs:160-164; .github/workflows/ci.yml:450-469; .github/workflows/ci.yml:846-910; .github/workflows/ci.yml:1540-1568] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INT-02 | An operator can distinguish notification-seen and notification-read facts on each correlated delivery timeline using stable event names, timestamps, and allowlisted detail without recipient identity or caller metadata. | Parent-notification projection, timestamp-first rank tie-breaking, dual redaction, sibling-delivery and privacy-negative tests. [VERIFIED: .planning/REQUIREMENTS.md:19-23] |
| DOCS-03 | Host guidance explains publisher configuration, topic ownership, tenant and recipient isolation, arrival/seen/read/archive semantics, reconnect behavior, and the distinction between inbox state, protected open, provider handoff, and engagement. | Canonical-guide gap inventory, working demo config/auth source, semantics table contract, stale-example removals. [VERIFIED: .planning/REQUIREMENTS.md:25-28] |
| GATE-03 | Named inbox and aggregate verification entrypoints prove the packaged LiveView, demo-host arrival-to-seen-to-read journey, workflow progression, operator timeline, documentation contract, and Phoenix-optional core boundary. | Exact alias composition, focused test map, unchanged CI job topology, aggregate-edge mutation contracts, pre-ship copy. [VERIFIED: .planning/REQUIREMENTS.md:25-28] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep durable identity on stable `notification_key` plus version, never module names. [VERIFIED: AGENTS.md:17-23]
- Preserve the durable lifecycle spine `event -> notification -> delivery -> attempt`. [VERIFIED: AGENTS.md:17-23]
- Treat idempotency and suppression reasons as first-class behavior. [VERIFIED: AGENTS.md:17-23]
- Keep adapters replaceable with explicit behaviours and contract tests. [VERIFIED: AGENTS.md:17-23]
- Preserve host ownership of authentication, tenancy, URL generation, and correlation IDs. [VERIFIED: AGENTS.md:17-23]
- Maintain named `mix verify.*` and `mix ci.*` entrypoints and keep local/CI parity. [VERIFIED: AGENTS.md:25-32]
- Do not leak sensitive payload fields in telemetry or operator surfaces. [VERIFIED: AGENTS.md:25-32]
- Route objectively machine-testable acceptance to executable evidence; do not create conversational UAT or `checkpoint:human-verify` for this phase. If live CI is used as a backstop, inspect run/job/step results programmatically against the implementation SHA. [VERIFIED: AGENTS.md:25-32]

## Standard Stack

No dependency installation or upgrade belongs in this phase. Keep every lockfile unchanged and use the already-selected stack. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:7-10]

### Core

| Library / Runtime | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| Elixir / OTP | `1.19.5-otp-27` / `27.3.4.15` | Core projection, Mix aliases, ExUnit | Exact repository toolchain. [VERIFIED: .tool-versions:1-10] |
| Ecto | root lock `3.13.6` | Load persisted notification timestamps and build scoped fixtures | Existing core persistence layer; no migration needed. [VERIFIED: mix.lock:20; lib/chimeway/notifications/notification.ex:17-32] |
| PostgreSQL | CI service `15` | Durable lifecycle and integration-test authority | Existing `verify_inbox` service and project minimum. [VERIFIED: .github/workflows/ci.yml:846-866; AGENTS.md:9-15] |
| ExUnit | Elixir built-in | Core, docs, release, and journey contracts | Existing test framework in all relevant projects. [VERIFIED: test/chimeway/traces_test.exs:1-4; chimeway_admin/test/chimeway_admin/redaction_test.exs:1-4] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix | admin/demo lock `1.8.7` | Host-mounted admin and inbox routes | Only in optional packages/demo host, never core. [VERIFIED: chimeway_admin/mix.lock:21; examples/chimeway_demo_host/mix.lock:46] |
| Phoenix LiveView | admin lock `1.1.30`; demo/inbox lock `1.1.31` | Function-component and mounted-route proof | `render_component/3` for focused timeline markup; `live/2` for the real Trace Detail path. [VERIFIED: chimeway_admin/mix.lock:23; examples/chimeway_demo_host/mix.lock:48; chimeway_inbox/mix.lock:23] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| Phoenix PubSub | existing optional-package dependency | Closed reload hint transport | Preserve existing stream behavior; the timeline must not consume PubSub as truth. [VERIFIED: chimeway_inbox/mix.exs:22-34; chimeway_inbox/lib/chimeway_inbox/change_stream.ex:36-54] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Parent notification timestamps | Infer from signal/workflow/PubSub rows | Rejected by locked semantics: those are separate or lossy facts and would make sibling explanations disagree. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21] |
| Existing `TimelineEvent` | New admin component or browser redesign | Rejected by phase boundary; focused labels/hooks belong in the current component. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:23-27] |
| Existing `verify_inbox` job | New CI lane | Rejected by locked topology; the current lane already feeds both aggregates. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:35-39] |

**Installation:** None. Do not run `mix deps.update`, edit dependency constraints, or regenerate lockfiles.

## Package Legitimacy Audit

Not applicable. Phase 107 installs no external packages and reuses only dependencies already declared and locked in the repository. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:7-10]

## Architecture Patterns

### System Architecture Diagram

```text
Host action / mounted bell
        |
        +--> durable Chimeway notification creation ----------------------+
        |                                                                 |
        +--> first visible reveal --> mark_seen --------------------------+--> notification row
        |                                                                 |    seen_at / read_at
        +--> explicit user action --> mark_read --------------------------+         |
                                                                                   v
delivery id + host tenant --> Traces.explain_delivery/2 --> build_timeline
                                                          |   if seen_at? add seen
                                                          |   if read_at? add read
                                                          v
                                            timestamp-first sort + rank tie-break
                                                          |
                                                          v
                                              SafeEvidence.trace/1
                                                          |
                              +---------------------------+--------------------+
                              |                                                |
                              v                                                v
                    API explanation                            TraceDetailLive (host mount)
                                                                     |
                                                                     v
                                             TimelineEvent --> admin Redaction --> HTML

Guide + focused contracts + package suite + demo journey
                              |
                              v
                       mix verify.inbox
                              |
                              v
                 CI verify_inbox job (single owner)
                       /                 \
                      v                   v
                  pr-gate              ci-gate
```

### Recommended Project Structure

```text
lib/chimeway/traces.ex                                  # add entries and correct global ordering
lib/chimeway/safe_evidence.ex                           # admit exactly two new event atoms
test/chimeway/traces_test.exs                           # independence, siblings, chronology, privacy
test/chimeway/safe_evidence_test.exs                    # closed allowlist and empty-detail contract
chimeway_admin/lib/chimeway_admin/components/
└── timeline_event.ex                                   # explicit labels and stable data hook
chimeway_admin/test/chimeway_admin/components/
└── timeline_event_test.exs                             # Wave 0: focused render contract
examples/chimeway_demo_host/test/demo_host_web/
└── inbox_bell_proof_test.exs                           # arrival -> mounted seen -> read -> Trace Detail
guides/introduction/inbox-integration.md                # single canonical ownership/semantics guide
test/chimeway/doc_contract_test.exs                     # positive + stale/unsafe negative guide contract
mix.exs                                                 # broaden existing verify.inbox only
MAINTAINING.md                                          # enumerate its complete evidence surface
test/chimeway/release_gate_contract_test.exs            # alias and both aggregate-edge locks; safe cleanup
```

### Pattern 1: Project From the Parent Durable Row

`explain_delivery/2` already pattern-matches the preloaded parent notification before calling `build_timeline/6`; use `notification.seen_at` and `notification.read_at` there. Do not query signals or derive lifecycle facts from the delivery. This naturally gives every sibling delivery the same two timestamps. [VERIFIED: lib/chimeway/traces.ex:189-227]

Recommended helper shape:

```elixir
# Values are locked verbatim as `:notification_seen` and `:notification_read`.
# Source: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21
defp notification_lifecycle_entries(notification) do
  [
    notification_lifecycle_entry(notification.seen_at, :notification_seen),
    notification_lifecycle_entry(notification.read_at, :notification_read)
  ]
  |> Enum.concat()
end

defp notification_lifecycle_entry(nil, _event), do: []

defp notification_lifecycle_entry(%DateTime{} = at, event) do
  [%{at: at, event: event, detail: SafeEvidence.timeline_detail(%{})}]
end
```

### Pattern 2: Timestamp First, Closed Rank Second

Keep a closed rank clause for every admitted event, append the new events without renumbering old ties, and make the time coordinate primary. The exact locked values are `:notification_seen` and `:notification_read`, with seen ordered first on equal timestamps. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21]

```elixir
# Source: https://hexdocs.pm/elixir/DateTime.html
defp timeline_sort_key(%{event: event, at: at}) do
  {DateTime.to_unix(at, :microsecond), timeline_rank(event)}
end
```

Add closed rank clauses for the two event atoms so the seen rank is lower than the read rank; preserve every existing relative tie relationship. Test behavior, not the numeric constants.

### Pattern 3: Two Redaction Layers, Empty New Detail

Admission and projection happen in core `SafeEvidence`; admin applies its own `Privacy.redact/1` plus detail-key allowlist. Add only the two new atoms to `@timeline_events`. Do not add any new detail field to `@timeline_fields` or `ChimewayAdmin.Redaction.@allowed_detail_keys`; assert the emitted detail is exactly `%{}` before and after UI rendering. [VERIFIED: lib/chimeway/safe_evidence.ex:32-78; lib/chimeway/safe_evidence.ex:355-366; lib/chimeway/safe_evidence.ex:482-501; chimeway_admin/lib/chimeway_admin/redaction.ex:6-11; chimeway_admin/lib/chimeway_admin/redaction.ex:82-96]

### Pattern 4: Focused Component Contract Plus Real Host Mount

Use `render_component(&TimelineEvent.timeline/1, timeline: ...)` to verify the visible labels, `<time datetime=...>`, empty detail list, and a stable hook such as `data-cw-timeline-event="notification_seen"`. Then use the demo host's real `/admin/chimeway/deliveries/:delivery_id` route after actual bell-open and mark-read transitions to prove package integration and both redaction layers. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] [VERIFIED: chimeway_admin/lib/chimeway_admin/components/timeline_event.ex:14-37; chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex:40-98; examples/chimeway_demo_host/lib/demo_host_web/router.ex:23-35]

### Pattern 5: One Verification Owner, Many Evidence Classes

Expand `mix verify.inbox` into ordered commands for: focused root lifecycle/timeline/privacy/Phoenix-optional tests; full `chimeway_inbox`; focused `chimeway_admin` timeline/redaction; tagged guide and gate contracts; and the demo `:inbox` journey. The CI job already runs `mix verify.inbox`, so the larger alias automatically flows into both aggregates without a new job. [VERIFIED: mix.exs:160-164; .github/workflows/ci.yml:846-910; .github/workflows/ci.yml:450-469; .github/workflows/ci.yml:1540-1568]

### Anti-Patterns to Avoid

- **Rank-first sorting:** `{timeline_rank(event), at}` groups by event kind and only sorts within a kind; replace it and add a cross-rank timestamp fixture. [VERIFIED: lib/chimeway/traces.ex:610-632]
- **Treating read as proof of seen:** `mark_read` and `mark_seen` write independent columns; timeline projection must mirror that independence. [VERIFIED: lib/chimeway/inbox.ex:42-67; lib/chimeway/inbox.ex:162-199]
- **Bypassing SafeEvidence because detail is empty:** an event absent from `@timeline_events` is silently dropped by `trace_timeline_entry/1`. [VERIFIED: lib/chimeway/safe_evidence.ex:32-37; lib/chimeway/safe_evidence.ex:355-366]
- **Generic label-only coverage:** current generic humanization happens to produce similar prose but provides no explicit locked label contract or event-specific structural hook. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/timeline_event.ex:20-46]
- **Adding broad browser work to the inbox lane:** nightly-only `verify_admin` includes Playwright; Phase 107 needs only a focused component test and the existing demo LiveView route. [VERIFIED: mix.exs:178-185; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:35-39]
- **Creating another guide or CI job:** both are explicitly outside the selected ownership model. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:29-39]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Seen/read storage | New timeline table, event log, or engagement record | `Notification.seen_at` / `read_at` | Facts are already durable and idempotent. [VERIFIED: lib/chimeway/notifications/notification.ex:17-32; lib/chimeway/inbox.ex:42-79] |
| Timeline privacy | Ad hoc `Map.drop` at the component | `SafeEvidence.trace/1` and `ChimewayAdmin.Redaction.safe_timeline_detail/1` | Existing closed admission plus defense-in-depth rendering. [VERIFIED: lib/chimeway/safe_evidence.ex:303-366; chimeway_admin/lib/chimeway_admin/redaction.ex:82-96] |
| Realtime lifecycle truth | Rich PubSub delta or browser state machine | Existing closed reload tuple plus durable re-query | PubSub is deliberately lossy/routing-only. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/change_stream.ex:1-14; chimeway_inbox/lib/chimeway_inbox/change_stream.ex:36-54] |
| Component harness | New test app or Playwright path | `Phoenix.LiveViewTest.render_component/3` and existing demo route | Covers markup and mounted integration with existing infrastructure. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html] |
| Gate aggregation | New script or new CI lane | Existing `verify.inbox` alias, `verify_inbox` job, and `aggregate-gate.sh` | Topology already has the exact two required edges. [VERIFIED: .github/workflows/ci.yml:450-469; .github/workflows/ci.yml:846-910; .github/workflows/ci.yml:1540-1568] |
| Temp cleanup | Direct recursive deletion of derived paths | One ownership-validating cleanup helper | A malformed path must never make `System.tmp_dir!()` itself a recursive-delete target. [VERIFIED: test/chimeway/release_gate_contract_test.exs:1836-1844; test/chimeway/release_gate_contract_test.exs:2817-2857; test/chimeway/release_gate_contract_test.exs:2869-2879; test/chimeway/release_gate_contract_test.exs:2954-2959] |

**Key insight:** The phase is safest when every layer remains a projection or composition of an already-owned fact. New storage, transport, auth, or aggregate topology would create a second authority and undermine the milestone's local-first explainability boundary.

## Common Pitfalls

### Pitfall 1: A New Event Is Built but Disappears

**What goes wrong:** `build_timeline/6` produces an entry, but the returned explanation omits it.
**Why it happens:** `SafeEvidence.trace_timeline_entry/1` keeps only atoms in `@timeline_events`. [VERIFIED: lib/chimeway/safe_evidence.ex:32-37; lib/chimeway/safe_evidence.ex:355-366]
**How to avoid:** Add both exact atoms to the closed list and directly test `SafeEvidence.trace/1` with positive and unknown-event negative cases.
**Warning signs:** Builder-level assertions pass while `Traces.explain_delivery/2` lacks the lifecycle entries.

### Pitfall 2: “Chronological” Tests Pass Vacuously

**What goes wrong:** Normal inserts happen in lifecycle order, so an event-rank-first implementation passes an ascending-time check.
**Why it happens:** The current test uses naturally ordered fixture timestamps, while the implementation sorts by rank first. [VERIFIED: test/chimeway/traces_test.exs:462-486; lib/chimeway/traces.ex:610-632]
**How to avoid:** Set authoritative timestamps so two different ranks are deliberately out of rank order; separately set seen/read to the same microsecond and assert seen first.
**Warning signs:** The test never asserts a timestamp inversion relative to event rank.

### Pitfall 3: Sibling Deliveries Disagree

**What goes wrong:** Two deliveries belonging to one notification show different seen/read facts.
**Why it happens:** Projection is derived from delivery state, attempt state, or a per-delivery signal query.
**How to avoid:** Create one notification with at least two deliveries, transition the notification once, explain both delivery IDs, and assert byte-identical seen/read entries. [VERIFIED: lib/chimeway/traces.ex:194-227; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21]
**Warning signs:** The new helper accepts only a delivery or attempt rather than the parent notification.

### Pitfall 4: Read Silently Synthesizes Seen

**What goes wrong:** A read-only notification produces both facts, or a seen-only notification produces read.
**Why it happens:** UI intuition (“read implies seen”) replaces persisted truth.
**How to avoid:** Four explicit fixtures: neither, seen only, read only, both. Assert only the non-nil persisted columns appear. [VERIFIED: lib/chimeway/inbox.ex:42-67; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21]
**Warning signs:** Conditional code checks `read_at || seen_at` or references signal/PubSub state.

### Pitfall 5: Empty Detail Becomes a Future Leakage Channel

**What goes wrong:** Recipient, tenant, caller metadata, content, signal payload, or publisher detail is added “for convenience.”
**Why it happens:** The existing timeline has richer details for attempts and workflow transitions.
**How to avoid:** Assert each new entry has `Map.keys(entry) == [:at, :detail, :event]`, `entry.detail == %{}`, and hostile sentinels do not occur in the serialized explanation or rendered component. [VERIFIED: test/chimeway/traces_test.exs:383-440; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21]
**Warning signs:** Any new `@timeline_fields` or admin allowed-detail key accompanies this phase.

### Pitfall 6: The Guide Repeats Pre-Phase Semantics

**What goes wrong:** Adopters copy raw email recipients, implement only `current_recipient/2`, believe seen is deferred/headless-only, or treat reconnect as engagement.
**Why it happens:** The current guide still contains raw-email examples and explicitly says `mark_seen` is not wired. [VERIFIED: guides/introduction/inbox-integration.md:61-84; guides/introduction/inbox-integration.md:114-145]
**How to avoid:** Make working demo configuration/auth the source pattern, use stable `cw_*` examples throughout, and add negative doc assertions for the stale phrases and raw identity forms. [VERIFIED: examples/chimeway_demo_host/config/config.exs:14-23; examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex:11-26]
**Warning signs:** The guide omits `current_tenant/2`, `topic_secret`, or “authoritative reload.”

### Pitfall 7: Gate Parity Is Nominal but Not Composed

**What goes wrong:** CI still says `verify_inbox`, but the alias proves only package and demo tests.
**Why it happens:** The existing alias has exactly two commands. [VERIFIED: mix.exs:160-164]
**How to avoid:** Contract the exact evidence classes/commands in the alias, the CI job's single alias invocation, and both aggregate `needs`/environment/aggregate tokens. Use mutation-negative cases, not marker-only presence.
**Warning signs:** A new test is green locally but absent from `mix verify.inbox`.

### Pitfall 8: Release-Test Cleanup Can Target the System Temp Root

**What goes wrong:** A derived archive path is cleaned with `File.rm_rf(Path.dirname(archive))`; if a test helper ever returns a direct child of the system temp directory, its dirname is `System.tmp_dir!()` and recursive cleanup is catastrophic. The current file has many indirect dirname cleanup calls and one unguarded pre-clean of a generated output path. [VERIFIED: test/chimeway/release_gate_contract_test.exs:1836-1844; test/chimeway/release_gate_contract_test.exs:2817-2857; test/chimeway/release_gate_contract_test.exs:2869-2879; test/chimeway/release_gate_contract_test.exs:2954-2959]
**Why it happens:** Ownership is inferred from naming convention rather than validated at the deletion boundary.
**How to avoid:** Before any Phase 107 full release-contract run, route recursive cleanup through a helper that expands the path, rejects equality with `System.tmp_dir!()`, requires its immediate parent to equal the expanded temp root, and requires a closed Chimeway-owned basename prefix. Add a refusal test for the temp root and arbitrary paths. Remove the unnecessary `File.rm_rf!(output)` before building a fresh unique path or guard it through the same helper.
**Warning signs:** New or retained direct `File.rm_rf*` calls receive `Path.dirname(...)`, `System.tmp_dir!()`, or caller-controlled paths.

## Code Examples

Verified implementation patterns and planner-ready test shapes:

### Focused Function Component Contract

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
html =
  render_component(&ChimewayAdmin.Components.TimelineEvent.timeline/1,
    timeline: [
      %{at: timestamp, event: :notification_seen, detail: %{}},
      %{at: timestamp, event: :notification_read, detail: %{}}
    ]
  )

assert html =~ "Notification seen"
assert html =~ "Notification read"
assert html =~ ~s(data-cw-timeline-event="notification_seen")
assert html =~ ~s(data-cw-timeline-event="notification_read")
```

The event values and visible labels above are verbatim locked decisions. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-24; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:70-75]

### Safe Temp Ownership Guard

```elixir
defp remove_owned_temp_dir!(directory) do
  temp_root = Path.expand(System.tmp_dir!())
  directory = Path.expand(directory)
  basename = Path.basename(directory)

  owned_prefix? =
    Enum.any?(
      [
        "chimeway_release_gate_",
        "chimeway_release_archive_",
        "chimeway_adoption_security_",
        "chimeway_adoption_run_"
      ],
      &String.starts_with?(basename, &1)
    )

  if directory != temp_root and Path.dirname(directory) == temp_root and owned_prefix? do
    File.rm_rf!(directory)
  else
    raise ArgumentError, "refusing recursive cleanup outside an owned temp directory"
  end
end
```

The listed prefixes are taken verbatim from existing temp constructors; keep the list closed and co-located with the helper. [VERIFIED: test/chimeway/release_gate_contract_test.exs:2817-2857; test/chimeway/release_gate_contract_test.exs:2954-2959; test/chimeway/release_gate_contract_test.exs:3294-3306]

## State of the Art

| Old Approach | Current Approach for Phase 107 | When Changed | Impact |
|--------------|--------------------------------|--------------|--------|
| Rank-first timeline key | Timestamp-first, closed-rank tie-break | Phase 107 | Explanations become genuinely chronological across all event kinds. [VERIFIED: lib/chimeway/traces.ex:610-632; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:17-21] |
| Generic event humanization only | Explicit two-label clauses plus stable per-event hook | Phase 107 | Accessible copy and CSS/test selectors become contractual. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/timeline_event.ex:20-46; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:23-27] |
| Guide says seen is deferred and uses email-shaped identities | Visible-row seen semantics, both auth callbacks, opaque `cw_*`, and full ownership table | Phases 105–107 | Copy-paste guidance matches shipped behavior. [VERIFIED: guides/introduction/inbox-integration.md:61-84; guides/introduction/inbox-integration.md:114-145; .planning/phases/106-idempotent-seen-lifecycle-workflow-proof/106-01-SUMMARY.md:22-46] |
| `verify.inbox` proves package + demo only | One alias composes core, package, admin, guide, demo journey, and parity contracts | Phase 107 | Both existing aggregate gates inherit the complete proof without topology growth. [VERIFIED: mix.exs:160-164; .github/workflows/ci.yml:450-469; .github/workflows/ci.yml:1540-1568] |

**Deprecated/outdated:**

- The guide statement that `mark_seen` is not wired in `BellDropdownLive` is stale after Phase 106. [VERIFIED: guides/introduction/inbox-integration.md:114-145; .planning/phases/106-idempotent-seen-lifecycle-workflow-proof/106-01-SUMMARY.md:22-46]
- Raw email-shaped recipient examples are inconsistent with the current demo's stable opaque mapping. [VERIFIED: guides/introduction/inbox-integration.md:61-84; examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex:13-26]
- Event-rank-first ordering must not be retained under the label “chronological.” [VERIFIED: lib/chimeway/traces.ex:610-632]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | None. Implementation recommendations derive from locked phase decisions, directly read repository definitions, executed baseline tests, or official Elixir/Phoenix documentation. | — | — |

## Resolved Questions

1. **Exact structural hook name**
   - What we know: A stable per-event hook is locked, while naming is delegated. [VERIFIED: .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:23-27; .planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md:41-42]
   - Resolution: Use one extensible `data-cw-timeline-event={Atom.to_string(entry.event)}` attribute on every item and contract the exact `notification_seen` and `notification_read` string values. No additional event-specific attribute is introduced.
   - Evidence: No existing timeline item has an event-specific data attribute, so this single hook extends the current list-item seam without creating parallel selectors. [VERIFIED: chimeway_admin/lib/chimeway_admin/components/timeline_event.ex:18-34]

2. **Release contract tag placement**
   - What we know: The release test is the established topology contract and Phase 107 must touch it, but broad archive tests in the same module contain the cleanup hazard. [VERIFIED: test/chimeway/release_gate_contract_test.exs:1-65; test/chimeway/release_gate_contract_test.exs:2817-2959]
   - Resolution: Tag the new alias/job/aggregate-edge contracts `:inbox_gate_parity`, matching the focused documentation contracts. Tag the owned-temp acceptance/refusal and recursive-call structure contracts separately as `:release_cleanup_safety`, run that safety tag first, and permit `:inbox_gate_parity` plus the full release file only after the cleanup hardening is green and committed.
   - Rationale: Separate tags preserve a runnable safety prerequisite without coupling destructive-boundary validation to the alias contents it protects; the expanded `mix verify.inbox` still owns the focused parity tag, while `mix ci.verify_gates` remains the post-hardening full-file backstop.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | all implementation/tests | ✓ | 1.19.5 / OTP 27 | — [VERIFIED: local `elixir --version`, 2026-09-12] |
| Mix | aliases and ExUnit | ✓ | 1.19.5 | — [VERIFIED: local `mix --version`, 2026-09-12] |
| Docker | `scripts/test-db` PostgreSQL isolation | ✓ | 29.5.2 | Existing `DATABASE_URL` path in CI. [VERIFIED: local `docker --version`; .github/workflows/ci.yml:864-866] |
| PostgreSQL service | focused root tests | ✓ | Docker image 15; baseline healthy | — [VERIFIED: focused root test execution; .github/workflows/ci.yml:852-866] |
| `psql` client | diagnostics only | ✓ | 14.17 | Not required by phase commands. [VERIFIED: local `psql --version`, 2026-09-12] |
| GitHub CLI/auth | optional live-CI backstop | ✓ | gh 2.95.0, authenticated | Use structural local contract if no push is authorized. [VERIFIED: local `gh --version` and `gh auth status`, 2026-09-12] |
| `chimeway_admin` deps | focused component test | ✗ in this checkout | — | Existing gate runs `mix deps.get` before tests. [VERIFIED: mix.exs:100-109; .github/workflows/ci.yml:901-910] |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** Optional admin dependencies are not fetched locally; the existing alias convention fetches nested-project dependencies before executing tests.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit 1.19.5; Phoenix.LiveViewTest at each optional project's lock |
| Config file | root `test/test_helper.exs`; `chimeway_admin/test/test_helper.exs`; `examples/chimeway_demo_host/test/test_helper.exs` |
| Quick run command | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` |
| Full phase command | `mix verify.inbox` after alias expansion |
| Release parity command | `mix ci.verify_gates` after safe temp cleanup is hardened |

Baseline evidence gathered this session: the root traces/SafeEvidence command passed 49 tests with 0 failures in 1.0 seconds, and the existing root doc contract passed 484 tests with 0 failures in 0.3 seconds. [VERIFIED: local ExUnit runs, 2026-09-12] The optional admin focused command could not start because its local deps are absent; no dependency fetch was performed during read-only research. [VERIFIED: local Mix dependency check, 2026-09-12]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INT-02 | Conditional independent facts, sibling agreement, exact timestamps, timestamp-first order, seen-before-read tie, empty detail, hostile-sentinel privacy | integration | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/traces_test.exs test/chimeway/safe_evidence_test.exs --warnings-as-errors` | ✅ extend |
| INT-02 | Explicit labels, time element, stable hooks, admin re-redaction | component | `cd chimeway_admin && mix deps.get && mix test test/chimeway_admin/components/timeline_event_test.exs test/chimeway_admin/redaction_test.exs --warnings-as-errors` | ❌ Wave 0 component file |
| INT-02 / GATE-03 | Actual arrival, bell-open seen, explicit read, one workflow progression, mounted Trace Detail labels/hooks | e2e LiveView | `cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors` | ✅ extend |
| DOCS-03 | Complete config/auth/ownership/semantics/reconnect guidance and stale/raw examples forbidden | doc contract | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | ✅ extend/tag |
| GATE-03 | Alias contains every evidence class; CI job invokes it; both aggregates consume the same lane; nightly topology unchanged | structural + mutation | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --only inbox_gate_parity --warnings-as-errors` | ✅ extend/tag |
| GATE-03 | Complete local phase surface | integration aggregate | `mix verify.inbox` | ✅ expand |
| GATE-03 | Docs/release parity | integration aggregate | `mix ci.verify_gates` | ✅ existing, run after cleanup hardening |

### Recommended `mix verify.inbox` Composition

Order commands from cheapest/closest to broadest so failures localize cleanly:

1. Root focused lifecycle/timeline/privacy/Phoenix-optional tests: include `inbox_state_transition_test.exs`, `inbox_change_publisher_test.exs`, `trigger_inbox_change_test.exs`, `traces_test.exs`, and `safe_evidence_test.exs` under `scripts/test-db`.
2. Full `chimeway_inbox` suite with `mix deps.get` and warnings as errors.
3. Focused `chimeway_admin` timeline component plus redaction tests, not `mix verify.admin` and not Playwright.
4. Focused tagged inbox guide and release-parity contracts under `scripts/test-db`.
5. Demo-host `--only inbox` last, because it composes the real package route, durable rows, Oban signal progression, explicit read, and mounted admin Trace Detail.

All five commands are required; avoid `|| true`, path filters, environment skips, or test-count-only proxies.

### Sampling Rate

- **Per core task commit:** focused root traces/SafeEvidence command.
- **Per admin task commit:** focused admin timeline/redaction command.
- **Per docs/gate task commit:** tagged doc/release parity command.
- **Per plan merge:** expanded `mix verify.inbox`.
- **Phase gate:** `mix verify.inbox` and `mix ci.verify_gates` green; if pushed CI is used, query the implementation SHA with `gh` and programmatically assert `verify_inbox` plus the applicable aggregate job result. No conversational UAT.

### Wave 0 Gaps

- [ ] `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` — direct component labels/hooks/timestamp/redaction coverage for INT-02.
- [ ] New cross-rank, equal-timestamp, independence, sibling, and hostile-sentinel fixtures in `test/chimeway/traces_test.exs`.
- [ ] Direct new-event admission/unknown-event rejection coverage in `test/chimeway/safe_evidence_test.exs`.
- [ ] Tagged Phase 107 guide contract(s) in `test/chimeway/doc_contract_test.exs`.
- [ ] Tagged alias/aggregate/temp-cleanup mutation contracts in `test/chimeway/release_gate_contract_test.exs`.
- [ ] Expanded demo journey assertions in `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs`.

## Security Domain

Security enforcement is enabled because `.planning/config.json` does not set `security_enforcement: false`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no new control | Host authentication remains outside Chimeway; do not modify it. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/auth.ex:1-23] |
| V3 Session Management | no new control | Existing LiveView session context is retained only for reauthorization. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/live_auth.ex:14-51] |
| V4 Access Control | yes | Preserve host `current_recipient/2` + `current_tenant/2`, exact mounted authority, tenant-scoped core query, and fail-closed admin auth. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/auth.ex:13-23; chimeway_inbox/lib/chimeway_inbox/live_auth.ex:14-80; chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex:12-27] |
| V5 Input Validation | yes | Closed `SafeEvidence` event/detail allowlists plus admin redaction; new details remain empty. [VERIFIED: lib/chimeway/safe_evidence.ex:32-78; lib/chimeway/safe_evidence.ex:355-366; chimeway_admin/lib/chimeway_admin/redaction.ex:82-96] |
| V6 Cryptography | yes, unchanged | Existing HMAC-SHA256 opaque topic derivation with host-secret minimum; do not hand-roll or expose topic inputs. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/change_stream.ex:12-30; chimeway_inbox/lib/chimeway_inbox/change_stream.ex:65-80] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Timeline leaks recipient/caller/content metadata | Information Disclosure | New event detail exactly `%{}`; SafeEvidence admission; serialized sentinel tests; admin re-redaction. |
| Cross-tenant trace access | Spoofing / Information Disclosure | Preserve `TenantScope.resolve/1` joins in `explain_delivery/2` and mounted admin context; never accept tenant from timeline detail. [VERIFIED: lib/chimeway/traces.ex:190-207; chimeway_admin/lib/chimeway_admin/live/trace_detail_live.ex:12-27] |
| Lossy reload hint treated as engagement truth | Tampering / Repudiation | Timeline reads only durable notification columns; PubSub remains a reload trigger. [VERIFIED: chimeway_inbox/lib/chimeway_inbox/change_stream.ex:1-14] |
| Misordered facts create a false causal narrative | Repudiation | Timestamp-first comparison, deterministic closed rank only for equal timestamps, explicit inversion/tie tests. |
| Recursive deletion escapes test-owned temp directory | Tampering / Denial of Service | Validate expanded ownership at the deletion boundary and refuse system temp root/arbitrary paths before any full release test. |

## Implementation-Ready Plan Shape

### Plan 107-01 — Safe operator timeline vertical slice

1. Add RED core contracts for absent/seen-only/read-only/both states, sibling delivery equality, exact empty detail, hostile metadata exclusion, cross-rank chronology, and equal-time seen-before-read.
2. Add both events to `SafeEvidence`, project from parent notification timestamps, and correct the global sort key to timestamp-first/rank-second.
3. Add the focused admin component test, explicit label clauses, and one stable `data-cw-timeline-event` hook while preserving `<time>`, `<dl>`, status, suppression, and redaction behavior.
4. Extend the demo `:inbox` journey to cover durable arrival → mounted visible seen → one workflow progression → explicit read → repeat idempotency → mounted admin Trace Detail with both labels/hooks and no raw recipient/caller sentinel.
5. Verify focused commands, then the current package/demo portions of `mix verify.inbox`.

### Plan 107-02 — Canonical guidance and gate parity

1. Extend the inbox guide contract first: require the four config keys/both auth callbacks, ownership paragraphs, opaque identities, lifecycle semantics table, reconnect-as-reload, and separation from provider handoff/protected activation/presentation/engagement; forbid the stale deferred-seen and raw-email examples.
2. Rewrite only the canonical inbox guide using the live demo config/auth and link `guides/introduction/mobile-adoption-operations.md`, the existing authority for provider-handoff, visible-presentation, protected-activation, inbox-state, and engagement boundaries. [VERIFIED: guides/introduction/mobile-adoption-operations.md:18-40]
3. Harden every recursive cleanup path exercised by `release_gate_contract_test.exs` through an owned-temp guard and add refusal tests before running that full file.
4. Add tagged release contracts that mutation-test every `verify.inbox` evidence command, the unchanged CI job's alias call, both aggregate `needs`/result tokens, and exclusion of nightly admin/browser jobs.
5. Expand the `verify.inbox` alias, update `MAINTAINING.md` evidence-class prose, run `mix verify.inbox`, then `mix ci.verify_gates`. Run `actionlint` only if `.github/workflows/ci.yml` changes; research indicates no workflow edit is necessary.

## Sources

### Primary (HIGH confidence)

- `.planning/phases/107-operator-timeline-guidance-gate-parity/107-CONTEXT.md` — locked scope, event names, ownership, guidance, and gate topology.
- `.planning/REQUIREMENTS.md` — INT-02, DOCS-03, GATE-03 exact acceptance.
- `lib/chimeway/traces.ex` — preloading, builder, SafeEvidence projection, and current ordering defect.
- `lib/chimeway/safe_evidence.ex` — closed event/detail admission.
- `lib/chimeway/notifications/notification.ex` and `lib/chimeway/inbox.ex` — authoritative fields and independent idempotent transitions.
- `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex`, `redaction.ex`, and `trace_detail_live.ex` — rendering and defense-in-depth seams.
- `guides/introduction/inbox-integration.md`, demo config/auth, and doc contracts — current guidance gaps and working examples.
- `guides/introduction/mobile-adoption-operations.md` — existing provider-handoff, visible-presentation, protected-activation, inbox-state, and engagement semantics authority.
- `mix.exs`, `.github/workflows/ci.yml`, `MAINTAINING.md`, and `test/chimeway/release_gate_contract_test.exs` — current alias/topology and cleanup hazard.
- Phase 104–106 summaries/verifications — previously green publisher, opaque PubSub, visible seen, and workflow proof surfaces.

### Secondary (MEDIUM confidence)

- https://hexdocs.pm/elixir/DateTime.html — proper datetime comparison guidance.
- https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html — function-component and mounted LiveView testing helpers.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no dependency changes; exact repository toolchain and lockfiles were read.
- Architecture: HIGH — every integration seam and locked ownership boundary was traced in current source.
- Pitfalls: HIGH — the rank-first ordering and temp cleanup patterns are present in current code; privacy/gate failure modes have direct executable seams.
- Validation: HIGH — existing tests, aliases, CI jobs, and prior phase evidence were read; two focused root baselines were executed successfully.

**Research date:** 2026-09-12
**Valid until:** 2026-10-12 (stable internal integration phase; re-check immediately if Phases 104–106 or CI topology change)
