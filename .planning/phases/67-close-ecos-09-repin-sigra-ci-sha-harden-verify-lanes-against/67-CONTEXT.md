# Phase 67: Close ECOS-09 — Sigra integration gap closure - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning
**Source:** v1.10 Milestone Audit Closure Plan (`.planning/v1.10-MILESTONE-AUDIT.md` → "Closure Plan", decided 2026-06-02 from 4-stream parallel research). Synthesized into CONTEXT by /gsd:plan-phase 67 — the closure plan is a research-backed, already-decided design contract; every R-recommendation below is a locked decision.

<domain>
## Phase Boundary

**What this phase delivers:** Prove the Sigra auth notification flow (ECOS-09) end-to-end in **clean CI** — not against a local gitignored dep — and make the vacuous-pass gate footgun that hid the gap structurally impossible to recur.

**Root cause being closed (pin-lag, NOT a missing artifact):** `Sigra.Integrations.Chimeway` (+ `MagicLinkNotifier`, `PendingDelivery`) is already committed to `szTheory/sigra` (introduced `c2a34b76`, completed `c7f06d92`, on `origin/main` HEAD `62ceb46a`). The defect is that `ci.yml:407` pins `b186f03c`, which predates those commits — so the sibling `actions/checkout` is empty, the lifecycle test compiles to **zero** tests, and `mix verify.sigra` passes **vacuously**. This is structurally identical to the **Accrue precedent** (`Accrue.Integrations.Chimeway`, CI ref `236fa2f1` which contains accrue commit `b380e08a`).

**Architectural verdict (LOCKED — do not relitigate):** Do **NOT** vendor the Sigra integration into chimeway. Follow the Accrue precedent exactly. Chimeway's two integration directions have different correct homes:
- **OUT (chimeway → partner):** chimeway owns the adapter/reporter in tracked `lib/` (e.g. `Chimeway.Adapters.Mailglass`, `Chimeway.Telemetry.ThreadlineReporter`).
- **IN (partner → chimeway):** the **partner repo owns** `Partner.Integrations.Chimeway`, pinned in chimeway CI via a sibling checkout at a SHA that contains the integration commit. `Sigra.Integrations.Chimeway` is the IN direction — structurally identical to Accrue. Vendoring would invent a pattern with no precedent and violate the partner-owns-its-domain seam philosophy.

This is a **tightening pass, not a redesign** — the architecture is already correct and proven.

**Scope fence (out of scope):**
- Vendoring any Sigra source into chimeway (explicitly rejected — would invent a no-precedent pattern).
- Any change to the redaction boundary (`@sensitive_keys` denylist at `trigger.ex:44` + ThreadlineReporter allowlist) — verified good in the audit.
- Re-designing the verify-lane architecture — the lanes are sound; only the sigra pin + guard-loudness are defective.
- Nested-key redaction recursion in `trigger.ex sanitize_map/1` (top-level only) — filed as non-blocking follow-up, NOT fixed here.
</domain>

<decisions>
## Implementation Decisions

### D-01 — Repin the Sigra CI SHA [R1]
`ci.yml:407` `ref: b186f03ccc5bbc9416f495df3e5dd0bec2f814a4` → `ref: 62ceb46a38c4e617f6c06d874ecb12e1ab19d97c` (`szTheory/sigra` origin/main HEAD; contains `c2a34b76..c7f06d92`, i.e. `lib/sigra/integrations/chimeway.ex`). Acceptable minimal alternative: pin the exact integration-complete commit `c7f06d92`. This single line is the entire root-cause fix; it exactly mirrors how Accrue (`236fa2f1`) is wired. No vendoring, no new pattern. Closes BLOCKER-1 + BLOCKER-2; unblocks ECOS-09, DEMO-10, GATE-07.

### D-02 — Make the vacuous pass impossible, symmetrically across sigra + accrue + threadline [R2]
Fix the *class* of footgun, not just the sigra instance. The corpus already named it: "Hidden heavy tests excluded from default `mix test` without contributor-visible policy". Three sub-changes:
- **(a) Raise loud on missing integration file:** in `test/test_helper.exs` (sigra + accrue blocks), the "integration file missing on disk" branch currently **silently skips** — change it to **raise loud**, extending the existing failed-*compile* raise to also cover a missing *file*.
- **(b) Harden the always-running harness tests:** `test/chimeway/integrations/sigra_auth_harness_test.exs` must hard-assert `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` AND `function_exported?(Sigra.Integrations.Chimeway, :trigger, 3)` (today it only checks `Sigra.Auth`). Mirror the same module-load + function-export hard assertions in the accrue (`accrue_dunning_harness_test.exs`) and threadline (`threadline_telemetry_harness_test.exs`) harnesses. These guards sit OUTSIDE the lifecycle double-guard, so an absent integration turns RED instead of silently green.
- **(c) Floor-assert test counts:** add to `test/chimeway/release_gate_contract_test.exs` a floor assertion that each verify lane runs ≥ its expected integration-test count (doc-contract discipline applied to test execution). Closes WARNING-2.

### D-03 — Fix the Sigra golden-path guide [R3]
`guides/introduction/sigra-auth-integration.md:66` shows the INVALID `Chimeway.trigger("sigra.auth.magic_link", recipient, params: …)`. `trigger/3` takes a **notifier module** first arg (`trigger.ex:46,60 validate_module!`) and has no `params:` option. Correct it to the real call shape: notifier module first arg + params map + `idempotency_key` / `tenant_id` / `correlation_id` opts — matching the Phase 65 blueprint and `seeds.ex:280`. Also fix WR-2: the `Mod.fun/0` arity notation inside ```elixir fences in BOTH guides (raises on copy-paste) → move to inline code or a non-elixir fence. Closes WARNING-1; restores DOCS-10.

### D-04 — Strengthen the doc-contract so it would have CAUGHT D-03 [R4]
The sigra describe block in `test/chimeway/doc_contract_test.exs` is substring-only. Add forbidden patterns `Chimeway.trigger("` (string-first-arg) and `params:` in the guide, and assert the trigger example references a `*Notifier` module. Tighten WR-3: the prefix-only `seed_sigra` seed pin → full seed name. DOCS-11.

### D-05 — Verify Phase 64 and reconcile tracking [R5]
After D-01..D-04, run `mix verify.sigra` under clean-CI conditions, then produce `.planning/phases/64-sigra-auth-flows-core/64-VERIFICATION.md` proving ECOS-09 E2E. Commit the currently-untracked `64-02-SUMMARY.md`. Flip ROADMAP (64-02 `[x]`, phase 64 → Complete) and REQUIREMENTS/Traceability (ECOS-09 `[x]`, → Complete/Satisfied). Closes the unverified-phase blocker; satisfies ECOS-09.

### D-06 — Nyquist closeout + minor hygiene [R6]
The corpus forbids silently-deferred Nyquist debt ("deferred Nyquist debt must have owner + trigger"). Close out the draft `*-VALIDATION.md` files — at minimum Phase 64's `64-VALIDATION.md` (status: draft → closed/compliant) consistent with the new VERIFICATION. Add a one-line comment on chimeway's optional `:sigra` dep `override: true` explaining the diamond-resolution reason (inert for adopters since optional deps aren't pulled transitively).

### Claude's Discretion
- Wave/plan decomposition (audit suggests ~2 waves: R1 is one line; R2/R4 harden gates; R3 fixes docs; R5 verifies; R6 hygiene). Planner decides exact plan count and wave assignment respecting dependencies (D-01 must land before D-05's clean-CI verify; D-03 before D-04 can be meaningfully tested, though they can co-land).
- Exact wording of test assertions, comment text, and VERIFICATION.md structure.
- Whether to pin `62ceb46a` (HEAD) vs `c7f06d92` (exact integration-complete commit) for D-01 — both are acceptable; prefer HEAD `62ceb46a` per audit primary recommendation.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth for this phase
- `.planning/v1.10-MILESTONE-AUDIT.md` — the full audit + Closure Plan (R1–R6) this CONTEXT is synthesized from; architectural verdict, blockers, and exact coordinates.

### CI / gate wiring
- `.github/workflows/ci.yml` — `verify_sigra` job (line 383+); the stale sigra pin is at `ci.yml:407`; Accrue precedent pin at `ci.yml:275`.
- `test/test_helper.exs` — sigra + accrue conditional-compile blocks (silent-skip branch to make loud).
- `test/chimeway/release_gate_contract_test.exs` — where the per-lane test-count floor assertions go.

### Harness tests (always-running guards)
- `test/chimeway/integrations/sigra_auth_harness_test.exs`
- `test/chimeway/integrations/accrue_dunning_harness_test.exs`
- `test/chimeway/integrations/threadline_telemetry_harness_test.exs`

### Docs + doc-contract
- `guides/introduction/sigra-auth-integration.md` — invalid example at line 66.
- `test/chimeway/doc_contract_test.exs` — substring-only sigra describe block to strengthen.

### Precedent (the proven IN-direction pattern to mirror)
- Accrue wiring across `ci.yml`, `test_helper.exs`, `accrue_dunning_harness_test.exs` — `Accrue.Integrations.Chimeway`, CI ref `236fa2f1`.
- `prompts/chimeway-host-app-integration-seam.md` — partner-owns-its-domain seam philosophy.
- `prompts/chimeway-engineering-dna-from-prior-libs.md` — the named vacuous-pass / hidden-heavy-tests footgun + Nyquist-debt rule.

### Tracking to reconcile
- `.planning/ROADMAP.md` (Phase 64 + 67 sections), `.planning/REQUIREMENTS.md` (ECOS-09 line 15 + traceability line 59), `.planning/phases/64-sigra-auth-flows-core/` (64-02-SUMMARY.md untracked; no 64-VERIFICATION.md; 64-VALIDATION.md draft).

</canonical_refs>

<specifics>
## Specific Ideas

- D-01 exact edit: `ci.yml:407` `ref: b186f03ccc5bbc9416f495df3e5dd0bec2f814a4` → `ref: 62ceb46a38c4e617f6c06d874ecb12e1ab19d97c`.
- D-02b assertions to add to sigra harness: `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` + `function_exported?(Sigra.Integrations.Chimeway, :trigger, 3)`.
- D-03 correct call shape: notifier module first arg (e.g. a `*Notifier` module), params map, plus `idempotency_key` / `tenant_id` / `correlation_id` opts — mirror the Phase 65 blueprint + `seeds.ex:280`.
- D-04 forbidden doc-contract patterns: `Chimeway.trigger("` and `params:`; assert presence of a `*Notifier` reference; full-name seed pin (not prefix `seed_sigra`).
</specifics>

<deferred>
## Deferred Ideas

Non-blocking follow-ups — track, do NOT fix in this phase:
- `trigger.ex sanitize_map/1` redacts top-level keys only; nested `primary_action.url` is not recursed. Current flows use top-level keys → non-blocking. File it.
- Broader Nyquist closeout for Phases 63/65/66 VALIDATION.md beyond what D-06 covers (Phase 64 is the in-scope minimum).
</deferred>

---

*Phase: 67-close-ecos-09-repin-sigra-ci-sha-harden-verify-lanes-against*
*Context synthesized 2026-06-02 from v1.10 Milestone Audit Closure Plan*
