# Phase 62: Inbox Demo, Docs & Gate - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Inbox UI integration is documented end-to-end, demo-proven on the TeamPulse demo host, contract-tested against doc drift, and gated in the release checklist and CI alongside existing journey/mailglass/accrue verify entrypoints.

**In scope:** Demo host `chimeway_inbox` mount + `:inbox` proof test (DEMO-08), golden-path inbox integration guide (DOCS-08 Inbox), guide doc-contract tests (DOCS-09 Inbox), formal `mix verify.inbox` CI job + MAINTAINING.md pre-ship octet (GATE-05 Inbox half).

**Out of scope (later milestones):** Real-time PubSub bell badge refresh (INBX-03 / v1.10), `mark_seen` wired in BellDropdownLive UI (deferred Phase 61 D-08), inbox-read signal on delivery timeline UI (INT-02), Threadline/Sigra ecosystem slices, new headless API surface (Phase 61 shipped INBX-01).

**Depends on:** Phase 61 (headless API + `chimeway_inbox` package shipped).

**Requirements:** DEMO-08, DOCS-08 (Inbox), DOCS-09 (Inbox), GATE-05 (Inbox)
</domain>

<decisions>
## Implementation Decisions

### Delivery order (ROADMAP waves)
- **D-01:** Follow ROADMAP wave order — **62-01 demo proof (DEMO-08)** and **62-03 GATE-05** may run in parallel in Wave 1; **62-02 guide + doc-contract (DOCS-08/09 Inbox)** is blocked on 62-01 (guide verification must cite runnable demo mount, seeds, and proof test).
- **D-02:** Phase 62 is demo + documentation + release-gate only — no new INBX-01/02 package features; reuse Phase 61 `chimeway_inbox` artifacts as the integration surface.

### Demo host mount (DEMO-08)
- **D-03:** Clone **`chimeway_admin` demo integration pattern**: add `{:chimeway_inbox, path: "../../chimeway_inbox"}` to `examples/chimeway_demo_host/mix.exs`; configure `config :chimeway_inbox, auth_module: DemoHost.InboxAuth` in demo host config; mount `chimeway_inbox_routes/0` in a new browser scope in `examples/chimeway_demo_host/lib/demo_host_web/router.ex` (path likely `/inbox` per package router moduledoc — planner confirms exact scope).
- **D-04:** Implement **`DemoHost.InboxAuth`** behaviour resolving session → recipient identity (e.g. `"user:#{email}"` pattern from existing demo seeds), distinct from admin `"demo:operator"` / `DemoHostWeb.Plugs.AdminActor`.
- **D-05:** Add adopter-copyable **`DemoHost.Seeds.seed_inbox/0`** (or equivalent) using `Chimeway.trigger/3` with `in_app` channel and demo recipient identities — parallel to `seed_accrue_dunning/0` / invite seeds.
- **D-06:** DEMO-08 proof is a **dedicated `@moduletag :inbox` demo-host test module** (e.g. `inbox_bell_proof_test.exs`), mirroring `mailglass_delivery_proof_test.exs` and `accrue_dunning_proof_test.exs` — **not** an extension of `journey_test.exs` (`@tag :journey`). Journey suite keeps Logger adapter defaults (Mailglass D-10 precedent).
- **D-07:** Proof covers **list → mark_read via LiveView (`phx-click="mark_read"`) → badge count update**, plus **`mark_seen` via host/API `Chimeway.mark_seen/3`** (not bell UI) — ROADMAP/REQUIREMENTS require mark_read/seen; Phase 61 D-08 deferred `mark_seen` from BellDropdownLive v1.9.

### Golden-path guide (DOCS-08 Inbox)
- **D-08:** New canonical guide at **`guides/introduction/inbox-integration.md`** — parallel naming/location to `mailglass-integration.md` and `accrue-dunning-integration.md`.
- **D-09:** Guide skeleton mirrors Mailglass/Accrue introduction structure: (1) dependencies (Chimeway + `chimeway_inbox` path/hex dep), (2) database/migrations (Chimeway spine only — no Accrue sibling), (3) runtime config (`config :chimeway_inbox, auth_module:`), (4) **`ChimewayInbox.Auth` behaviour** implementation, (5) router mount (`import ChimewayInbox.Router` / `chimeway_inbox_routes/0`), (6) bell UI surface (`BellDropdownLive`, `data-cw-inbox-*` hooks per UI-SPEC), (7) headless API cross-reference (`Chimeway.unread_count/1`, paginated `list_for_recipient/2`, `mark_read`/`mark_seen`), (8) verification (`mix verify.inbox`, demo route, `DemoHost.Seeds.seed_inbox/0`), (9) related guides.
- **D-10:** No separate inbox blueprint recipe in v1.9 — guide owns end-to-end path (INBX is package mount, not ECOS-style adapter recipe). Optional cross-link to getting-started inbox lifecycle section if present.
- **D-11:** Add README adoption-docs link for the new guide (mirror existing Mailglass/Accrue integration guide entries in `README.md`).

### Doc-contract (DOCS-09 Inbox)
- **D-12:** Add **`inbox integration guide doc contract (DOCS-08 / DOCS-09)`** describe block in `test/chimeway/doc_contract_test.exs` — parallel to Accrue guide describe at line 441+.
- **D-13:** Reuse shared **`@recipe_forbidden_strings`** and fictional-module guard (`Chimeway.Workflow` regex) from existing doc-contract describes.
- **D-14:** Required strings (minimum): `ChimewayInbox.Auth`, `chimeway_inbox_routes`, `config :chimeway_inbox`, `auth_module`, `Chimeway.unread_count`, `Chimeway.list_for_recipient`, `Chimeway.mark_read`, `Chimeway.mark_seen`, `BellDropdownLive`, `mix verify.inbox`, `DemoHost.Seeds` inbox seed pointer, mounted route path. Section-order test mirroring Accrue golden-path headings.
- **D-15:** Extend **`hexdocs extras doc contract`** describe to register `guides/introduction/inbox-integration.md` after accrue guide entry.

### Release gate (GATE-05 Inbox half)
- **D-16:** Add **`verify.inbox`** alias to root `mix.exs` composing: (1) `cd chimeway_inbox && mix test --warnings-as-errors` and (2) `cd examples/chimeway_demo_host && mix test --only inbox --warnings-as-errors`. **No** sibling-repo checkout (unlike Accrue `ACCRUE_PATH`). **No** root `mix test --only inbox` unless new root tests are tagged — core inbox API coverage stays in default CI (`test/chimeway/inbox_*_test.exs`).
- **D-17:** Add **`verify_inbox`** job to `.github/workflows/ci.yml` mirroring `verify_mailglass` (Postgres service, deps.get, ecto create/migrate, `mix verify.inbox`). **No** Accrue-style sibling checkout.
- **D-18:** Update **`test/chimeway/release_gate_contract_test.exs`**: add `verify.inbox` to `@pre_ship_verify_commands`, `@ci_gate_lanes`, ci-gate env loop; change seven-gate assertion → **eight-gate** parity.
- **D-19:** Update **`MAINTAINING.md`** pre-ship block: add `mix verify.inbox` command + GATE-05 Inbox description; update checklist count **seven → eight** gates; inbox half of GATE-05 only.

### Claude's Discretion
- Exact demo mount path/scope (`/inbox` vs layout-embedded bell route only).
- `DemoHost.InboxAuth` session key design and default demo recipient identity.
- `seed_inbox/0` notifier key / metadata for bell list assertions (title, body_preview).
- Guide section numbering/titles and copy-paste snippet depth (must satisfy doc-contract required strings).
- Whether doc-contract requires `data-cw-inbox-*` DOM hooks as required vs recommended-only strings.
- HexDocs extras ordering relative to accrue guide.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

| Ref | Path | Why |
|-----|------|-----|
| Phase goal | `.planning/ROADMAP.md` (Phase 62) | Success criteria, waves 62-01..03 |
| Requirements | `.planning/REQUIREMENTS.md` (DEMO-08, DOCS-08 Inbox, DOCS-09 Inbox, GATE-05 Inbox) | Locked acceptance |
| Phase 61 context | `.planning/phases/61-inbox-headless-package/61-CONTEXT.md` | Package API, deferred demo/guide/gate scope |
| Phase 61 UI contract | `.planning/phases/61-inbox-headless-package/61-UI-SPEC.md` | Bell DOM hooks, events, copy — guide references |
| Phase 60 context | `.planning/phases/60-accrue-docs-release-gate/60-CONTEXT.md` | Docs+gate vertical-slice template |
| Mailglass guide template | `guides/introduction/mailglass-integration.md` | DOCS-08 structure + section depth template |
| Accrue guide template | `guides/introduction/accrue-dunning-integration.md` | DOCS-08 parallel + verification section pattern |
| Mailglass doc-contract | `test/chimeway/doc_contract_test.exs` (DOCS-06/07 describe) | DOCS-09 describe template |
| Accrue doc-contract | `test/chimeway/doc_contract_test.exs` (DOCS-08/09 describe) | Inbox guide contract baseline |
| Release gate contract | `test/chimeway/release_gate_contract_test.exs` | GATE-05 parity — octet update |
| Demo host router | `examples/chimeway_demo_host/lib/demo_host_web/router.ex` | Admin mount template for inbox mount |
| Demo admin auth | `examples/chimeway_demo_host/lib/demo_host/admin_auth.ex` | Auth behaviour template |
| Demo seeds | `examples/chimeway_demo_host/lib/demo_host/seeds.ex` | `seed_inbox/0` insertion point |
| Mailglass demo proof | `examples/chimeway_demo_host/test/demo_host_web/mailglass_delivery_proof_test.exs` | `:mailglass` selective proof pattern |
| Accrue demo proof | `examples/chimeway_demo_host/test/demo_host_web/accrue_dunning_proof_test.exs` | `:accrue` selective proof pattern |
| Package router | `chimeway_inbox/lib/chimeway_inbox/router.ex` | `chimeway_inbox_routes/0` macro |
| Package LiveView | `chimeway_inbox/lib/chimeway_inbox/live/bell_dropdown_live.ex` | Bell UI integration surface |
| Package tests | `chimeway_inbox/test/chimeway_inbox/live/bell_dropdown_live_test.exs` | Badge refresh proof baseline |
| Verify aliases | `mix.exs` (`verify.example`, `verify.mailglass`, `verify.accrue`) | GATE-05 alias template |
| CI jobs | `.github/workflows/ci.yml` (`verify_mailglass`, `verify_accrue`) | GATE-05 CI job template |
| MAINTAINING pre-ship | `MAINTAINING.md` | Checklist septet → octet update |
| Public inbox API | `lib/chimeway.ex`, `lib/chimeway/inbox.ex` | Headless API guide references |
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`chimeway_inbox` package (Phase 61)** — Auth, LiveAuth, Router macro, BellDropdownLive with UI-SPEC `data-cw-inbox-*` hooks; 6 package tests green.
- **`verify.example` chimeway_inbox lane** — already in root `mix.exs` line 88; selective `verify.inbox` alias deferred to Phase 62.
- **Demo host admin mount** — `chimeway_admin` path dep + `DemoHost.AdminAuth` + `chimeway_admin_routes()` in router scope `/admin/chimeway`.
- **Selective proof tests** — `@moduletag :mailglass` / `:accrue` demo modules with moduledoc explaining journey isolation.
- **Phase 60 Accrue vertical slice** — guide + doc-contract + CI job + MAINTAINING + release_gate_contract parity shipped as template.

### Established Patterns
- **Guide vs blueprint separation:** Introduction guide owns end-to-end path; recipe owns copy-paste sections (Phase 57 D-02). Inbox has no blueprint recipe — guide stands alone.
- **Doc-contract truth lock:** `@required` string list + `@recipe_forbidden_strings` + fictional-module regex + section-order test per markdown artifact.
- **Selective CI:** `verify.*` jobs are separate workflow jobs with Postgres; not bundled in default `ci` job.
- **Package path deps:** `chimeway_inbox` and demo host are in-repo — no sibling checkout unlike Accrue.

### Integration Points
- **62-01 → 62-02:** Guide verification section cites demo mount route, `DemoHost.Seeds.seed_inbox/0`, and `:inbox` proof test.
- **62-01 → 62-03:** `verify.inbox` demo lane runs `--only inbox` against shipped proof module.
- **Doc-contract → guide file:** `@inbox_integration_guide Path.expand(...)` pattern matching mailglass/accrue guide constants.
- **CI → verify.inbox:** New job runs alias after Postgres setup; ci-gate aggregates eighth lane.
- **MAINTAINING → CI:** Pre-ship command list must match CI jobs adopters/maintainers run locally.
</code_context>

<specifics>
## Specific Ideas

- ROADMAP success criterion #3: new gate must complete MAINTAINING octet without breaking existing seven verify jobs — inbox job is additive.
- DEMO-08 "journey test" means end-to-end consumer proof, not necessarily `@tag :journey` — use `:inbox` module tag for selective gate parity.
- mark_seen proof via API satisfies REQUIREMENTS without reopening Phase 61 LiveView scope.
</specifics>

<deferred>
## Deferred Ideas

- **`mark_seen` in BellDropdownLive UI** — Phase 61 D-08; optional v1.10 polish.
- **Real-time PubSub bell badge refresh (INBX-03)** — v1.10+.
- **Inbox blueprint recipe** — no ECOS-style adapter recipe needed; package mount is the integration seam.
- **Root `mix test --only inbox` lane** — only if tagged root tests added; not required for GATE-05 acceptance.

None — analysis stayed within phase scope.
</deferred>
