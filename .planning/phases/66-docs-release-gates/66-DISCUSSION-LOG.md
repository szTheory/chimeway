# Phase 66: Docs & Release Gates - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-30
**Phase:** 66-docs-release-gates
**Areas discussed:** Threadline guide shape, Sigra guide: redaction callout depth, DOCS-11 doc-contract forbidden phrases

---

## Threadline guide shape

| Option | Description | Selected |
|--------|-------------|----------|
| 4 sections (trimmed) | Dependencies → Attach reporter (Application.start/2 + config) → What gets recorded (outcome table) → Verification. Matches the domain: host just attaches and reads outcomes, no authoring required. | ✓ |
| 6 sections (adapted accrue template) | Keep parity with accrue/mailglass guides by mapping to: deps → skip migrations / call out no Chimeway schema change → config → ThreadlineReporter reference → Outcome mapping table → Verification. Consistent numbered structure across all integration guides. | |
| You decide | Claude picks the shape that best serves an adopter reading this for the first time. | |

**User's choice:** 4 sections (trimmed)
**Notes:** None

---

## 'Attach reporter' section scope

| Option | Description | Selected |
|--------|-------------|----------|
| Attach call + config only | Just the Application.start/2 one-liner and the config :repo/:actor block. | ✓ |
| Attach + config + THREADLINE_PATH pattern | Also document local dev: THREADLINE_PATH=../threadline mix deps.get. | |

**User's choice:** Attach call + config only
**Notes:** Keeps section tight

---

## Threadline 'What gets recorded' section

| Option | Description | Selected |
|--------|-------------|----------|
| Outcome table + correlation_id callout | 4-row outcome table plus a note that correlation_id threads through to Threadline.Query.timeline/2 strict filter. | ✓ |
| Outcome table only | Just the 4-row outcome → action table, no correlation_id prose. | |

**User's choice:** Outcome table + correlation_id callout
**Notes:** None

---

## Threadline verification section

| Option | Description | Selected |
|--------|-------------|----------|
| seed_threadline_notification/0 + /admin/chimeway | Document seed helper as runnable demo pointer + /admin/chimeway for operator trace inspectability. | ✓ |
| mix verify.threadline only | Just the gate command; skip demo seeds in the guide. | |

**User's choice:** seed_threadline_notification/0 + /admin/chimeway
**Notes:** Mirrors accrue guide pattern

---

## Sigra guide: redaction callout depth

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated '## Trace Redaction' section | Standalone section before verification with identifier-only trigger params rule, what NEVER to pass, how sensitive data resolves at dispatch time. | |
| Inline note in the trigger section | One callout block inside the triggers section noting the identifier-only rule. | ✓ |
| You decide | Claude picks based on security prominence and doc-contract enforceability. | |

**User's choice:** Inline note in the trigger section
**Notes:** Keeps guide tighter; redaction is an impl detail not a top-level concern for most adopters

---

## Inline redaction note emphasis

| Option | Description | Selected |
|--------|-------------|----------|
| What NOT to pass (anti-pattern focus) | Lead with: "Do not pass :raw_token, :magic_link_url, or :confirmation_code to Chimeway.trigger/3." Show annotated code example of correct identifier-only params. | ✓ |
| What TO pass (positive framing) | Focus on the correct form: user_id, email, opaque ref. Mention that sensitive data resolves at dispatch time. | |

**User's choice:** What NOT to pass (anti-pattern focus)
**Notes:** Makes the contract unambiguous

---

## Sigra guide section count

| Option | Description | Selected |
|--------|-------------|----------|
| Adapted 6-section (accrue template) | deps → migrations → config → notifier reference → auth event triggers + redaction inline → verification | |
| 5 sections (drop migrations) | deps → config (integration seam) → notifier reference → auth event triggers + redaction inline note → verification | ✓ |

**User's choice:** 5 sections (drop migrations)
**Notes:** No new Chimeway migrations needed for Sigra integration

---

## DOCS-11: Sigra doc-contract forbidden phrase approach

| Option | Description | Selected |
|--------|-------------|----------|
| Forbid as Elixir atom forms (:raw_token, :magic_link_url) | Forbid atom forms anywhere in the guide — prose uses non-colon form, so only fires on code examples with wrong param keys. | ✓ |
| Forbid as code block pattern only | Regex test inside fenced code blocks only — more precise but more complex. | |
| You decide | Claude picks the most enforceable approach. | |

**User's choice:** Forbid as Elixir atom forms (:raw_token, :magic_link_url)
**Notes:** Clean and effective; prose naturally avoids atom-form syntax

---

## DOCS-11: Threadline guide required strings

| Option | Description | Selected |
|--------|-------------|----------|
| Core terms only (8 strings) | Chimeway.Telemetry.ThreadlineReporter, attach/0, config :chimeway :threadline_reporter, correlation_id, notification_suppressed, seed_threadline_notification, /admin/chimeway, mix verify.threadline | ✓ |
| Core + responsibility split (add 'orchestrates') | Same 8 plus 'orchestrates' — mirrors all other integration guide doc-contracts. | |

**User's choice:** Core terms only (8 strings)
**Notes:** None

---

## Claude's Discretion

- GATE-07 `mix verify.threadline` alias shape: mirrors `verify.accrue` pattern with `deps.compile threadline --force`, root `mix test --only threadline`, and demo host lane with `CHIMEWAY_SKIP_THREADLINE_DEP=1` + `THREADLINE_PATH`
- GATE-07 `mix verify.sigra` alias shape: mirrors `verify.accrue` with `CHIMEWAY_SKIP_SIGRA_DEP=1` + `SIGRA_PATH`
- CI jobs `verify_threadline` and `verify_sigra`: sibling checkout pattern from `verify_accrue` job
- ci-gate `needs` list: add `verify_threadline` and `verify_sigra` (grows from 9 to 11)
- MAINTAINING.md: add two new commands and descriptions, growing pre-ship checklist from 8 to 10

## Deferred Ideas

None — discussion stayed within phase scope.
