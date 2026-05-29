# Phase 56: Blueprint & Demo Proof - Context

**Gathered:** 2026-05-29 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Adopters can copy a published Mailglass + Chimeway reference recipe and see the same behaviour proven on the demo host. This phase delivers ECOS-05 (reference blueprint with doc-contract coverage) and DEMO-06 (demo host outbound Mailglass delivery with operator trace inspectability).

**Requirements:** ECOS-05, DEMO-06

**Success criteria (from ROADMAP):**
1. A reference recipe documents notifier authoring, adapter config, and the orchestration vs templating responsibility split with CI doc-contract coverage
2. Demo host TeamPulse notifiers deliver at least one email through `Chimeway.Adapter.Mailglass` with inspectable traces via `/admin/chimeway`
3. Recipe and demo align on stable notification keys and Mailglass template identifiers — no module-name coupling in durable identity

**Out of scope (Phase 57):** Golden-path integration guide (DOCS-06), Mailglass guide doc-contract tests (DOCS-07), `mix verify.mailglass` CI gate (GATE-04), demo host Mailglass inbound webhook route wiring.
</domain>

<decisions>
## Implementation Decisions

### Reference recipe (ECOS-05)
- **D-01:** Publish a new reference recipe at `guides/recipes/mailglass-integration-blueprint.md` documenting the Chimeway orchestration vs Mailglass templating responsibility split (when/why vs what/how).
- **D-02:** Recipe includes copy-paste sections for: notifier authoring with stable `notification_key` + `render_key`, host adapter registration (`:channel_adapters`, `:channel_adapter_configs`), Mailglass mailable module mapping, and trigger example.
- **D-03:** Recipe aligns with demo host identifiers: `teampulse.invite_sent` notification key and `teampulse.invite_sent.email` render key — no module-name coupling in durable identity.
- **D-04:** Recipe references runnable demo host modules (`DemoHost.Notifiers.InviteSent`, `DemoHost.Mailers.InviteEmail`) as the canonical copy-paste source, matching mention-escalation recipe pattern.

### Doc-contract coverage (ECOS-05)
- **D-05:** Add `describe "mailglass blueprint recipe doc contract (ECOS-05)"` in `test/chimeway/doc_contract_test.exs` with required phrases and shared `@recipe_forbidden_strings` — same pattern as RECP-01/02/03.
- **D-06:** Required phrases MUST include at minimum: `Chimeway.Adapters.Mailglass`, `channel_adapters`, `render_key`, and explicit orchestration vs templating responsibility language. Forbidden strings reuse existing recipe anti-patterns (fictional modules, pre-Mailglass assumptions).

### Demo notifier selection (DEMO-06)
- **D-07:** Use `DemoHost.Notifiers.InviteSent` email channel as the Mailglass proof notifier — Alex invite success path (JOUR-01). Do NOT use `PasswordReset` (intentionally suppressed for Sam in JOUR-02) or `PaymentReminder` email step (workflow-dependent second step).
- **D-08:** Proof focuses on outbound email delivery through Mailglass adapter — inbound webhook demo route wiring is out of scope (Phase 57 guide covers optional inbound feedback).

### Demo host Mailglass wiring
- **D-09:** Add `{:mailglass, "~> 1.3"}` (or compatible pin) to `examples/chimeway_demo_host/mix.exs` as a non-optional host dependency.
- **D-10:** Register Mailglass adapter ONLY in a dedicated `:mailglass`-tagged test module — do NOT change global demo host test config. Existing `:journey` suite (JOUR-01..08, 10 tests) keeps default `Chimeway.Adapters.Logger` adapter to avoid breaking journey CI.
- **D-11:** Demo host test config adds Mailglass test harness block (Fake adapter, TestRepo, tenancy) mirroring root `config/test.exs` mailglass section — scoped to mailglass proof tests.
- **D-12:** Per-test setup registers `:channel_adapters` `%{"email" => Chimeway.Adapters.Mailglass}` and `:channel_adapter_configs` with demo mailable map for `teampulse.invite_sent.email`.

### Demo mailable module
- **D-13:** Add `DemoHost.Mailers.InviteEmail` in demo host implementing `Mailglass.Mailable` for the invite email template — host-owned, not in Chimeway core test support.
- **D-14:** Mailable map config: `%{"teampulse.invite_sent.email" => {DemoHost.Mailers.InviteEmail, :invite_email}}` (exact function name at planner discretion). Uses assigns from notifier `rendering/2` — Chimeway adapter passes `render_data` through.

### Admin trace inspectability (DEMO-06)
- **D-15:** Mailglass proof test triggers `DemoHost.Seeds.seed_invite/0` (or equivalent) with Mailglass adapter env active, then asserts delivery succeeded with `adapter_module` containing `Chimeway.Adapters.Mailglass`.
- **D-16:** Extend proof with admin trace inspectability via `/admin/chimeway` LiveViewTest — search by Alex identity, open delivery detail, assert `teampulse.invite_sent` notification key and Mailglass adapter in attempt timeline. Pattern from JOUR-04 in `admin_trace_live_test.exs`.

### Phase boundary vs Phase 57
- **D-17:** Phase 56 recipe is a focused blueprint (notifier + adapter + responsibility split + demo pointers). Full golden-path integration guide, Mailglass-specific doc-contract guide tests, and `mix verify.mailglass` named gate remain Phase 57.
- **D-18:** `custom-adapter.md` Mailglass stub section may cross-link to the new blueprint recipe but is NOT replaced — blueprint is additive reference content.

### Claude's Discretion
- Exact recipe filename if `mailglass-integration-blueprint.md` conflicts with Phase 57 guide naming
- Whether mailglass proof test lives in `demo_host/mailglass_delivery_proof_test.exs` or `demo_host_web/mailglass_journey_test.exs`
- Demo host Mailglass test harness: duplicate config vs shared test support import from Chimeway
- Recipe doc-contract required phrase list refinements beyond D-06 minimum
- Whether to add `@moduletag :demo_06` in addition to `:mailglass` for selective CI
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 56 goal, success criteria, dependency on Phase 55
- `.planning/REQUIREMENTS.md` — ECOS-05, DEMO-06 acceptance criteria
- `.planning/seeds/SEED-003-ecosystem-integrations.md` — Chimeway orchestration vs Mailglass templating split
- `.planning/phases/54-mailglass-adapter-core/54-CONTEXT.md` — Outbound adapter decisions (D-01..D-19)
- `.planning/phases/55-inbound-feedback-bridge/55-CONTEXT.md` — Webhook bridge decisions; deferred demo wiring

### Reference recipe patterns
- `guides/recipes/password-reset-support-trace.md` — RECP-01 recipe structure + persona sections
- `guides/recipes/mention-escalation.md` — RECP-03 recipe with demo host module references
- `guides/recipes/custom-adapter.md` — Existing Mailglass adapter stub (D-07 product name note)
- `test/chimeway/doc_contract_test.exs` — Recipe doc-contract describe blocks (RECP-01/02/03 pattern)

### Mailglass adapter (Phases 54–55 baseline)
- `lib/chimeway/adapters/mailglass.ex` — Outbound `deliver/2` + webhook callbacks
- `test/support/chimeway/mailglass_fixtures.ex` — Test mailable pattern (reference only; demo host owns its mailable)
- `test/chimeway/adapters/mailglass_adapter_test.exs` — Contract test + Fake adapter setup pattern
- `test/chimeway/dispatch/executor_mailglass_adapter_test.exs` — Per-channel adapter routing proof
- `config/test.exs` — Root Mailglass test harness config (Fake, TestRepo, tenancy)

### Demo host (Phase 56 modification targets)
- `examples/chimeway_demo_host/lib/demo_host/notifiers/invite_sent.ex` — Proof notifier with stable keys
- `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — `seed_invite/0` for JOUR-01 / DEMO-06 trigger
- `examples/chimeway_demo_host/mix.exs` — Add Mailglass dep
- `examples/chimeway_demo_host/config/test.exs` — Mailglass test harness (to add)
- `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` — JOUR-04 admin trace pattern
- `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` — Journey suite (must not break)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Complete Phase 54–55 Mailglass adapter: outbound `deliver/2`, webhook callbacks, contract tests, pipeline integration test
- `Chimeway.TestSupport.MailglassFixtures` — mailable map + sample_delivery pattern (reference for demo host mailable)
- Root `config/test.exs` Mailglass harness — Fake adapter, TestRepo, tenancy config ready to mirror
- Demo host TeamPulse notifiers with stable string keys (`teampulse.invite_sent`, `teampulse.invite_sent.email`)
- `DemoHost.Seeds.seed_invite/0` — idempotent trigger for successful multi-channel delivery
- Admin trace LiveView at `/admin/chimeway` with search + delivery detail (JOUR-04/07/08)
- Recipe doc-contract infrastructure in `doc_contract_test.exs` with shared forbidden strings

### Established Patterns
- Reference recipes: persona sections, prerequisites, copy-paste notifier code, runnable demo host module pointers
- Doc-contract: `@required_phrases` + `@recipe_forbidden_strings` per recipe describe block
- Mailglass tests: `@moduletag :mailglass`, `Mailglass.Adapters.Fake.checkout/0`, Application.put_env for channel_adapters/configs in setup/on_exit
- Journey tests: `@tag :journey`, default Logger adapter, `mix verify.journeys` selective run
- Demo host seeds: public `Chimeway.trigger/3` API, stable idempotency keys, tenant_id `"teampulse"`
- Product name `Chimeway.Adapter.Mailglass` vs module `Chimeway.Adapters.Mailglass` (D-07 from Phase 54)

### Integration Points
| Seam | Role in Phase 56 |
|------|------------------|
| `guides/recipes/mailglass-integration-blueprint.md` | ECOS-05 published blueprint |
| `test/chimeway/doc_contract_test.exs` | ECOS-05 CI truth lock |
| `DemoHost.Notifiers.InviteSent` | DEMO-06 proof notifier |
| `DemoHost.Mailers.InviteEmail` (new) | Host mailable for render_key mapping |
| `:channel_adapters` / `:channel_adapter_configs` | Demo host Mailglass registration |
| `Chimeway.Adapters.Mailglass` | Outbound delivery adapter in proof test |
| `/admin/chimeway` LiveView | DEMO-06 operator trace inspectability |
| `DemoHost.Seeds.seed_invite/0` | Deterministic trigger for proof test |
</code_context>

<specifics>
## Specific Ideas

- SEED-003 vision: Chimeway orchestrates when/why; Mailglass handles templating, MJML, Swoosh delivery. Phase 56 makes this adoptable via recipe + demo proof.
- Invite notifier is the natural success-path email — password reset is intentionally a suppression demo for Support Operator JTBD.
- Recipe and demo MUST share stable identifiers (`teampulse.invite_sent`, `teampulse.invite_sent.email`) — no module-name durable identity.
- Journey CI isolation is critical: 10 existing journey tests must remain green without Mailglass dependency in default path.

</specifics>

<deferred>
## Deferred Ideas

- Demo host Mailglass inbound webhook route (`/webhooks/chimeway/mailglass`) — Phase 57 integration guide scope
- Golden-path integration guide covering dependency → config → trigger → delivery → inbound feedback — Phase 57 (DOCS-06)
- Mailglass guide doc-contract tests beyond blueprint recipe — Phase 57 (DOCS-07)
- `mix verify.mailglass` named CI entrypoint — Phase 57 (GATE-04)
- Wiring all three TeamPulse notifiers through Mailglass — only invite email required for DEMO-06
- Global demo host Mailglass config in dev/test — rejected; would risk journey CI breakage

### Reviewed Todos (not folded)
None — no pending todos matched Phase 56.

</deferred>

---

*Phase: 56-blueprint-demo-proof*
*Context gathered: 2026-05-29 (assumptions mode)*
