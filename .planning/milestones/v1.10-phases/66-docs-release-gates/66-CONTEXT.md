# Phase 66: Docs & Release Gates - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Threadline and Sigra integrations are documented with golden-path integration guides, contract-tested with doc-contract truth locks, and gated in CI and the release pre-ship checklist.

**In scope:**
- `guides/introduction/threadline-integration.md` — Threadline telemetry bridge integration guide (DOCS-10)
- `guides/introduction/sigra-auth-integration.md` — Sigra auth notification integration guide (DOCS-10)
- `test/chimeway/doc_contract_test.exs` — two new `describe` blocks for Threadline and Sigra integration guides (DOCS-11)
- `mix verify.threadline` and `mix verify.sigra` aliases in `mix.exs` (GATE-07)
- `verify_threadline` and `verify_sigra` CI jobs in `.github/workflows/ci.yml` (GATE-07)
- MAINTAINING.md pre-ship checklist update: 8 → 10 verify commands (GATE-07)

**Out of scope:** All ECOS/DEMO deliverables — those shipped in Phases 63–65.

**Depends on:** Phase 63 (ThreadlineReporter shipped), Phase 64 (Sigra.Integrations.Chimeway shipped), Phase 65 (blueprint recipe + demo proof tests shipped)

**Requirements:** DOCS-10, DOCS-11, GATE-07
</domain>

<decisions>
## Implementation Decisions

### Threadline Integration Guide Shape (`guides/introduction/threadline-integration.md`)
- **D-01:** 4-section trimmed structure — Threadline is attach-only telemetry (no Chimeway migrations, no notifier authoring, no host-triggered events). Sections:
  1. **Dependencies** — optional `{:threadline, "~> 0.7"}` dep with env override pattern
  2. **Attach reporter** — `Application.start/2` one-liner calling `Chimeway.Telemetry.ThreadlineReporter.attach/0` + config block with `:repo` and `:actor` only; no THREADLINE_PATH local dev docs (keeps section tight)
  3. **What gets recorded** — 4-row outcome table (suppressed → `:notification_suppressed`, deferred → `:notification_deferred`, dispatched → `:notification_dispatched`, failed → `:notification_failed`) plus `correlation_id` callout explaining how it threads through to `Threadline.Query.timeline/2` strict filter
  4. **Verification** — `DemoHost.Seeds.seed_threadline_notification/0` as runnable demo pointer + `/admin/chimeway` search for operator trace inspectability + `mix verify.threadline` gate command

### Sigra Auth Integration Guide Shape (`guides/introduction/sigra-auth-integration.md`)
- **D-02:** 5-section structure (drops the "Database / migrations" section from the accrue 6-section template; no new Chimeway schema changes needed for Sigra integration). Sections:
  1. **Dependencies** — `{:sigra, "~> 0.3", optional: true}` + SIGRA_PATH env override pattern (mirrors ACCRUE_PATH in accrue guide)
  2. **Integration seam** — how `Sigra.Integrations.Chimeway` attaches to the host (runtime config, conditional compile, responsibility split: Chimeway orchestrates when/why; Sigra owns auth state, token generation, rate limits)
  3. **Notifier reference** — `sigra.auth.magic_link` and `sigra.auth.confirmation_code` stable notification keys; `build/2` resolves the magic link URL and confirmation code at dispatch time from Sigra repo — sensitive values never in Chimeway event payload
  4. **Auth event triggers** — how Sigra auth events (request_magic_link success, confirmation code generated) call `Chimeway.trigger/3` with `idempotency_key` + `tenant_id` (= user id). **Inline redaction note (anti-pattern focus):** "Do not pass `:raw_token`, `:magic_link_url`, or `:confirmation_code` to `Chimeway.trigger/3`. Pass identifier-only params (`user_id`, `email`, opaque ref). Sensitive data resolves inside notifier `build/2` at dispatch time and is never written to `chimeway_events.payload`."
  5. **Verification** — `DemoHost.Seeds.seed_sigra_auth/0` + `/admin/chimeway` trace inspectability + `SIGRA_PATH=../sigra mix verify.sigra`
- **D-03:** Inline redaction note lives in section 4 (not a standalone "## Trace Redaction" section); **anti-pattern focus** — leads with the explicit "do not pass" statement rather than positive framing only. This keeps the guide tight while making the rule undeniable.

### DOCS-11 Doc-Contract Tests
- **D-04:** Threadline integration guide doc-contract — new `describe "threadline integration guide doc contract (DOCS-10)"` block in `test/chimeway/doc_contract_test.exs`. `@required` = 8 strings (user chose core terms only, no `orchestrates`):
  1. `Chimeway.Telemetry.ThreadlineReporter`
  2. `attach/0`
  3. `config :chimeway`
  4. `correlation_id`
  5. `notification_suppressed`
  6. `DemoHost.Seeds.seed_threadline_notification`
  7. `/admin/chimeway`
  8. `mix verify.threadline`
  
  Forbidden: standard `@recipe_forbidden_strings` applies. No Threadline-specific additional forbidden phrases needed (telemetry bridge has no auth-adjacent redaction concern).

- **D-05:** Sigra integration guide doc-contract — new `describe "sigra auth integration guide doc contract (DOCS-10)"` block. `@sigra_forbidden` atom forms (Elixir atom syntax, only fires on code examples with wrong param keys — prose uses "raw token"/"magic link URL" without colon prefix):
  - `:raw_token`
  - `:magic_link_url`
  
  `@required` strings include: `Sigra.Integrations.Chimeway`, `sigra.auth.magic_link`, `sigra.auth.confirmation_code`, `Chimeway.trigger`, `idempotency_key`, `tenant_id`, `DemoHost.Seeds.seed_sigra`, `/admin/chimeway`, `mix verify.sigra`, `SIGRA_PATH`, `orchestrates`.
  
  Standard `@recipe_forbidden_strings` also applies.

### Claude's Discretion (GATE-07 implementation details)
- `mix verify.threadline` alias shape: mirrors `verify.accrue` — `deps.compile threadline --force` + `cmd env MIX_ENV=test mix test --only threadline --warnings-as-errors` (root) + `cmd --shell cd examples/chimeway_demo_host && ... mix test --only threadline --warnings-as-errors` with `THREADLINE_PATH` env and `CHIMEWAY_SKIP_THREADLINE_DEP=1`
- `mix verify.sigra` alias shape: mirrors `verify.accrue` — `deps.compile sigra --force` + root sigra tests + demo host sigra tests with `SIGRA_PATH` env and `CHIMEWAY_SKIP_SIGRA_DEP=1`
- `verify_threadline` CI job: new job in `ci.yml` mirroring `verify_accrue` — sibling checkout of `szTheory/threadline` at the same GitHub Actions structure
- `verify_sigra` CI job: new job in `ci.yml` mirroring `verify_accrue` — sibling checkout of `szTheory/sigra`
- ci-gate `needs` list: grows from 9 to 11 entries — add `verify_threadline` and `verify_sigra`
- MAINTAINING.md: pre-ship checklist grows from 8 to 10 commands, adding `mix verify.threadline` and `mix verify.sigra` with descriptions
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Goals & Requirements
- `.planning/ROADMAP.md` (Phase 66) — success criteria, scope boundary
- `.planning/REQUIREMENTS.md` (DOCS-10, DOCS-11, GATE-07) — locked acceptance criteria

### Prior Phase Context (integration decisions that this phase documents)
- `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` — ThreadlineReporter attach pattern, outcome atoms, deferred verify gate (D-13)
- `.planning/phases/64-sigra-auth-flows-core/64-CONTEXT.md` — Sigra integration seam, magic link + confirmation code flows, redaction decisions (D-07/D-08), deferred verify gate (D-12)
- `.planning/phases/65-ecosystem-blueprints-demo/65-CONTEXT.md` — Blueprint structure, demo proof structure, ECOS-10 doc-contract pattern; reciprocal cross-link requirement (D-08)

### Guide Templates (copy/adapt section structure)
- `guides/introduction/accrue-dunning-integration.md` — golden-path guide template (section numbering, responsibility split language, verification section with seeds + /admin/chimeway + verify command, Related guides footer)
- `guides/introduction/mailglass-integration.md` — second guide template reference

### Doc-Contract Templates (copy/adapt describe block structure)
- `test/chimeway/doc_contract_test.exs` — existing DOCS-06/07 (mailglass) and DOCS-08/09 (accrue) describe blocks as patterns for new DOCS-10 blocks; `@recipe_forbidden_strings` applies to both new guides
- `test/chimeway/doc_contract_test.exs` ~line 368 — ECOS-10 sigra blueprint describe block for cross-reference

### Verify Gate Templates (copy/adapt alias + CI job structure)
- `mix.exs` — `verify.accrue` and `verify.inbox` alias shapes; `threadline_deps/0` and `sigra_deps/0` functions already wired; `CHIMEWAY_SKIP_THREADLINE_DEP` / `CHIMEWAY_SKIP_SIGRA_DEP` env vars already defined
- `.github/workflows/ci.yml` — `verify_accrue` job (sibling checkout pattern) and `verify_inbox` job (no sibling checkout) as templates; ci-gate `needs` list at line ~386

### MAINTAINING.md
- `MAINTAINING.md` — pre-ship octet section to update to decet (10 commands)

### Demo Proof Test Files (for verification section accuracy)
- `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` — `@moduletag :threadline` tag (verify.threadline exercises this)
- `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — `@moduletag :sigra` tag (verify.sigra exercises this)
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — `seed_threadline_notification/0` and `seed_sigra_auth/0` helpers (guide verification section entry points)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`guides/introduction/accrue-dunning-integration.md`** — copy/adapt: section numbering pattern, responsibility-split language ("orchestrates the when and why"), `Related guides` footer, "mix verify.X" verification section structure
- **`test/chimeway/doc_contract_test.exs`** lines ~430 (mailglass guide) and ~545 (accrue guide) — `@required` list format, `sections appear in golden-path order` test pattern, `@recipe_forbidden_strings` reuse
- **`mix.exs`** — `verify.accrue` alias is the copy-paste template for `verify.threadline` / `verify.sigra`; `threadline_deps/0` and `sigra_deps/0` helpers already define the path-dep env patterns
- **`.github/workflows/ci.yml`** `verify_accrue` job — copy-paste for `verify_threadline` and `verify_sigra` jobs (checkout action, env vars, cache key pattern)

### Established Patterns
- Verify gate alias shape: `deps.compile X --force` → root `mix test --only X` → demo host `mix test --only X` with env override
- CI job shape: sibling repo checkout via `actions/checkout@vX` + `CHIMEWAY_SKIP_X_DEP=1` env + `X_PATH` env → `mix verify.X`
- Doc-contract describe block: `setup do: File.read!/1` → `@required` list → `for required <- @required do test...` → specific string assertions → `@forbidden` list → `for forbidden <- @forbidden do test...`
- MAINTAINING.md update: add two new commands + descriptions after existing `mix verify.inbox` entry

### Integration Points
- `test/chimeway/doc_contract_test.exs` — two new `describe` blocks appended after existing DOCS-08/09 accrue guide block
- `mix.exs` `aliases/0` — two new `verify.*` entries after `verify.inbox`
- `.github/workflows/ci.yml` — two new jobs + ci-gate `needs` additions
- `MAINTAINING.md` — pre-ship checklist expansion (text update only)
</code_context>

<specifics>
## Specific Ideas

- Threadline guide section 3 heading suggestion: "## What gets recorded" — plain language that matches adopter mental model ("what does this actually do?")
- Sigra guide section 4 anti-pattern note: explicit `:raw_token` / `:magic_link_url` naming in "do not pass" statement so the rule is unambiguous and doc-contract-enforceable via atom-form forbidden strings
- `@sigra_forbidden` uses atom syntax (`:raw_token`, `:magic_link_url`) rather than plain strings — only fires on code examples with wrong param keys; prose uses "raw token" / "magic link URL" (no colon), so no false positives
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.
</deferred>

---

*Phase: 66-Docs & Release Gates*
*Context gathered: 2026-05-30*
