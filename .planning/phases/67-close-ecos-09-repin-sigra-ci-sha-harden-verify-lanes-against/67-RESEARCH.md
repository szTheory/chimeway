# Phase 67: Close ECOS-09 — Sigra integration gap closure - Research

**Researched:** 2026-06-02
**Domain:** CI gate hardening / cross-repo integration seam / Elixir conditional-compile guards / doc-contract tightening
**Confidence:** HIGH (every coordinate verified against live HEAD; SHA provenance CITED from audit)

## Summary

This is a **closure/hardening pass**, not a feature. The architecture (partner-owns-`Partner.Integrations.Chimeway`, pinned in chimeway CI via sibling checkout — the Accrue precedent) is already correct and LOCKED. The single root-cause defect is a **stale CI pin**: `ci.yml:407` pins `szTheory/sigra@b186f03c`, which predates the integration module, so the sibling checkout is empty, the lifecycle test compiles to **0 tests**, and `mix verify.sigra` passes **vacuously**.

Every coordinate the audit named was verified against current HEAD and **all confirmed** (line numbers had not drifted). The Accrue precedent maps cleanly: the difference between the accrue and sigra wiring is (a) the pinned SHA, and (b) **two asymmetries in the test guards** that let the sigra gap hide — the sigra harness is guarded only on `Code.ensure_loaded?(Sigra)` (not the integration module) and only asserts `Sigra.Auth`; the accrue harness is double-guarded on both `Accrue` AND `Accrue.Integrations.Chimeway` (so it silently *skips* when the integration is absent rather than going red). Neither is correct for "fail loud on missing integration" — D-02 must make *both* loud while respecting that Threadline is the OUT direction (chimeway owns the reporter; there is no `Threadline.Integrations.Chimeway`).

**Primary recommendation:** Repin `ci.yml:407` → `62ceb46a` (D-01, the entire root-cause fix); add raise-loud-on-missing-file to `test_helper.exs` sigra+accrue blocks (D-02a); hard-assert integration-module-load + `function_exported?(…, :trigger, 3)` outside the lifecycle guards in all three harnesses (D-02b, with Threadline asserting its OUT-direction reporter, not a partner integration module); floor-assert per-lane test counts in `release_gate_contract_test.exs` (D-02c, floors: sigra ≥ 5 root, accrue ≥ 11, threadline ≥ 7); rewrite the sigra guide's invalid `Chimeway.trigger("sigra.auth.magic_link", recipient, params: …)` to the `seeds.ex:280` shape (D-03); add forbidden-pattern + `*Notifier` assertions to the doc-contract (D-04); verify Phase 64 in clean CI and reconcile tracking (D-05); close Nyquist + comment `override: true` (D-06).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sigra→Chimeway integration glue (`Sigra.Integrations.Chimeway`) | Partner repo (`szTheory/sigra`) | — | IN direction; BEAM single-module-load rule + Accrue precedent. NEVER vendored into chimeway. [CITED: 67-CONTEXT.md D-domain] |
| CI sibling checkout + SHA pin | chimeway `.github/workflows/ci.yml` | — | chimeway's CI must pin the partner SHA that contains the integration commit |
| Conditional-compile bootstrap (load partner integration in test) | chimeway `test/test_helper.exs` | — | chimeway test harness owns the optional-dep boot path |
| Always-running guard (module-load + function-export assertion) | chimeway harness tests | — | sits OUTSIDE the lifecycle double-guard so an absent integration goes RED |
| Per-lane test-count floor | chimeway `release_gate_contract_test.exs` | — | doc-contract discipline applied to test *execution* |
| Golden-path guide correctness | chimeway `guides/introduction/sigra-auth-integration.md` | doc-contract test | guide must match the real `trigger/3` API |
| Threadline reporter (OUT direction) | chimeway `lib/.../threadline_reporter.ex` | — | chimeway OWNS this — distinct seam from IN-direction partners |

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 — Repin the Sigra CI SHA [R1]:** `ci.yml:407` `ref: b186f03ccc5bbc9416f495df3e5dd0bec2f814a4` → `ref: 62ceb46a38c4e617f6c06d874ecb12e1ab19d97c` (`szTheory/sigra` origin/main HEAD; contains `c2a34b76..c7f06d92`). Acceptable minimal alternative: pin `c7f06d92`. This single line is the entire root-cause fix; mirrors how Accrue (`236fa2f1`) is wired. No vendoring. Closes BLOCKER-1 + BLOCKER-2; unblocks ECOS-09, DEMO-10, GATE-07.
- **D-02 — Make the vacuous pass impossible, symmetrically across sigra + accrue + threadline [R2]:** (a) raise loud on missing integration file in `test/test_helper.exs` (sigra + accrue blocks); (b) harden harness tests to hard-assert `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` AND `function_exported?(Sigra.Integrations.Chimeway, :trigger, 3)` (mirror for accrue/threadline), placed OUTSIDE the lifecycle double-guard; (c) floor-assert per-lane test counts in `release_gate_contract_test.exs`. Closes WARNING-2.
- **D-03 — Fix the Sigra golden-path guide [R3]:** `guides/introduction/sigra-auth-integration.md:66` invalid `Chimeway.trigger("sigra.auth.magic_link", recipient, params: …)` → real call shape (notifier module first arg + params map + `idempotency_key`/`tenant_id`/`correlation_id` opts), matching the Phase 65 blueprint and `seeds.ex:280`. Also fix WR-2 (`Mod.fun/0` arity inside ```elixir fences in BOTH guides → inline code or non-elixir fence). Closes WARNING-1; restores DOCS-10.
- **D-04 — Strengthen the doc-contract so it would have CAUGHT D-03 [R4]:** add forbidden patterns `Chimeway.trigger("` and `params:` to the sigra describe block in `doc_contract_test.exs`; assert the trigger example references a `*Notifier` module. Tighten WR-3 (prefix-only `seed_sigra` → full seed name). DOCS-11.
- **D-05 — Verify Phase 64 and reconcile tracking [R5]:** after D-01..D-04, run `mix verify.sigra` clean-CI, produce `64-VERIFICATION.md` proving ECOS-09 E2E. Commit untracked `64-02-SUMMARY.md`. Flip ROADMAP (64-02 `[x]`, phase 64 → Complete) and REQUIREMENTS/Traceability (ECOS-09 `[x]`, → Complete/Satisfied).
- **D-06 — Nyquist closeout + minor hygiene [R6]:** close out `64-VALIDATION.md` (draft → closed/compliant) consistent with the new VERIFICATION. Add a one-line comment on chimeway's optional `:sigra` dep `override: true` explaining diamond-resolution (inert for adopters since optional deps aren't pulled transitively).

### Claude's Discretion
- Wave/plan decomposition (audit suggests ~2 waves). Planner decides exact plan count and wave assignment respecting dependencies (D-01 before D-05's clean-CI verify; D-03 before D-04 meaningfully testable, though may co-land).
- Exact wording of test assertions, comment text, and VERIFICATION.md structure.
- Whether to pin `62ceb46a` (HEAD) vs `c7f06d92` (exact integration-complete commit) — both acceptable; prefer HEAD `62ceb46a` per audit.

### Deferred Ideas (OUT OF SCOPE)
- Vendoring any Sigra source into chimeway (explicitly rejected — no-precedent pattern).
- Any change to the redaction boundary (`@sensitive_keys` denylist at `trigger.ex:44` + ThreadlineReporter allowlist) — verified good.
- Re-designing the verify-lane architecture — lanes are sound; only the sigra pin + guard-loudness are defective.
- Nested-key redaction recursion in `trigger.ex sanitize_map/1` (top-level only) — non-blocking follow-up, NOT fixed here.
- Broader Nyquist closeout for Phases 63/65/66 VALIDATION.md beyond D-06 (Phase 64 is the in-scope minimum).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ECOS-09 | Sigra auth events trigger Chimeway notifiers with redacted trace payloads — sensitive tokens never persisted | Currently `[ ]` Pending (REQUIREMENTS.md:15,59). Closed by D-01 (repin) + D-05 (clean-CI verify → 64-VERIFICATION.md). The lifecycle test (`sigra_auth_lifecycle_test.exs`) already proves the redacted-trace assertions once the integration module loads. |
| DEMO-10 | Demo host proves Sigra auth flow E2E with operator trace inspectability | Currently `[x]` but PARTIAL (verified against local hand-copied dep). `sigra_auth_proof_test.exs` runs in the demo-host lane of `verify.sigra` (mix.exs:137). Restored to satisfied by D-01 making the demo-host lane real in clean CI. |
| DOCS-10 | Golden-path integration guides cover Sigra auth mount | Currently `[x]` but PARTIAL (invalid API example at guide:66). Restored by D-03. |
| GATE-07 | Named `mix verify.sigra` runs in CI + MAINTAINING pre-ship | Currently `[x]` but PARTIAL (sigra lane vacuous). Restored by D-01 + D-02c (floor assertion proves the lane runs >0 tests). |
</phase_requirements>

## Verified Live-Code Coordinates

> Every coordinate the audit/objective named was checked against current HEAD. **All confirmed; no line drift.**

### Coordinate 1 — `.github/workflows/ci.yml` verify_sigra + Accrue precedent

[VERIFIED: Read ci.yml]

- **`verify_sigra` job:** starts at `ci.yml:383`. Sibling checkout block `ci.yml:404-408`:
  ```yaml
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    with:
      repository: szTheory/sigra
      ref: b186f03ccc5bbc9416f495df3e5dd0bec2f814a4   # ← ci.yml:407, the stale pin (D-01 target)
      path: sigra/sigra
  ```
  `SIGRA_PATH: ${{ github.workspace }}/sigra/sigra` at `ci.yml:401`. Runs `mix verify.sigra` at `ci.yml:427`.
- **Accrue precedent (`verify_accrue`):** job at `ci.yml:251`. Sibling checkout `ci.yml:272-276`:
  ```yaml
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    with:
      repository: szTheory/accrue
      ref: 236fa2f1649e771f3b515603495436badeed3c7b   # ← ci.yml:275, the working pin
      path: accrue/accrue
  ```
  `ACCRUE_PATH` at `ci.yml:269`. Runs `mix verify.accrue` at `ci.yml:295`.
- **Threadline precedent (`verify_threadline`):** job at `ci.yml:337`, sibling checkout `ci.yml:358-362` ref `46375fafc4df30fc916244ee4a21b7cae01f1ddc`.
- **`ci-gate` aggregator:** `ci.yml:475-508`. `needs:` lists all 11 lanes incl. `verify_sigra` (`ci.yml:478`); a per-lane loop fails if any is not `success` (`ci.yml:497-503`). This is sound — the footgun is upstream (vacuous green), not in the aggregator.

**Structural diff — accrue vs sigra CI blocks:** identical except (1) `repository`/`path`/`SIGRA_PATH` names, and (2) the **SHA**. The fix is one line. No new wiring needed.

### Coordinate 2 — `test/test_helper.exs` conditional-compile blocks

[VERIFIED: Read test_helper.exs]

- **Sigra block:** `test_helper.exs:140-210`. The compile guard is `test_helper.exs:141-167`. Critical branch (the silent-skip footgun):
  ```elixir
  if is_binary(source) and File.exists?(source) do        # line 160
    _ = Code.compile_file(source)
    unless Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
      raise "failed to compile Sigra.Integrations.Chimeway from #{source}"   # line 164 — raises on FAILED COMPILE
    end
  end                                                       # ← NO else: when file ABSENT, silently skips
  ```
  Sigra has a `SIGRA_PATH` env fallback (`test_helper.exs:153-154`) that accrue lacks.
- **Accrue block:** `test_helper.exs:35-98`. The same pattern at `test_helper.exs:43-49`:
  ```elixir
  if File.exists?(source) do                               # line 43
    _ = Code.compile_file(source)
    unless Code.ensure_loaded?(Accrue.Integrations.Chimeway) do
      raise "failed to compile Accrue.Integrations.Chimeway from #{source}"  # line 47 — raises on FAILED COMPILE
    end
  end                                                       # ← NO else: when file ABSENT, silently skips
  ```
- **D-02a change (both blocks):** add an `else` to the `if File.exists?(source)` (and the sigra `is_binary(source) and File.exists?(source)`) that **raises** when the partner module is loaded as a dep (`Code.ensure_loaded?(Sigra)`/`Accrue`) yet the integration source file is absent on disk. Extends the existing "failed to compile" raise to also cover "file missing". Note the outer guard is `Code.ensure_loaded?(Sigra) and Code.ensure_loaded?(Chimeway) and not Code.ensure_loaded?(Sigra.Integrations.Chimeway)` — so the raise only fires when the partner is present but its integration file is missing (the exact vacuous-pass scenario), not when the optional dep is simply absent.

### Coordinate 3 — Harness tests (the always-running guards)

[VERIFIED: Read all three harness test files]

| Harness | File | Outer guard | What it currently asserts | Gap |
|---------|------|-------------|----------------------------|-----|
| Sigra | `sigra_auth_harness_test.exs` | `if Code.ensure_loaded?(Sigra) do` (**line 1** — single guard) | `Code.ensure_loaded?(Sigra)`, `Code.ensure_loaded?(Sigra.Auth)`, `function_exported?(Sigra.Auth, :request_magic_link, 3)` (lines 14-16) | Does **NOT** check `Sigra.Integrations.Chimeway` or `:trigger/3`. Runs even when integration absent — so it goes GREEN while the integration is missing. **This is the vacuous footgun.** |
| Accrue | `accrue_dunning_harness_test.exs` | `if Code.ensure_loaded?(Accrue) and Code.ensure_loaded?(Accrue.Integrations.Chimeway) do` (**line 1** — DOUBLE guard) | `function_exported?(ChimewayDunningEngine, :start_campaign, 3)` (line 27) where `ChimewayDunningEngine = Accrue.Integrations.Chimeway` (alias line 11) | Double-guard means it **silently SKIPS** when the integration module is absent (never goes red). Asserts the wrong arity (`start_campaign/3`, the dunning-engine fn, not `:trigger/3`). |
| Threadline | `threadline_telemetry_harness_test.exs` | `if Code.ensure_loaded?(Threadline) do` (**line 1** — single guard) | `function_exported?(Threadline, :record_action, 2)` (line 24) | **OUT direction** — there is NO `Threadline.Integrations.Chimeway`; chimeway owns `Chimeway.Telemetry.ThreadlineReporter` in `lib/`. The correct hard-assert is the OUT-direction reporter, e.g. `Code.ensure_loaded?(Chimeway.Telemetry.ThreadlineReporter)` + `function_exported?(…, :attach, 0)`, plus the partner fn `Threadline.record_action/2` it calls. |

**Module names + guards (exact):**
- Sigra: partner module `Sigra`; integration module `Sigra.Integrations.Chimeway`; guard sits on `Sigra` only.
- Accrue: partner module `Accrue`; integration module `Accrue.Integrations.Chimeway` (aliased `ChimewayDunningEngine`); guard sits on BOTH.
- Threadline: partner module `Threadline`; chimeway-owned reporter `Chimeway.Telemetry.ThreadlineReporter` (`lib/chimeway/telemetry/threadline_reporter.ex:1`); guard sits on `Threadline` only.

**D-02b nuance for the planner (IMPORTANT):** D-02 says "mirror the same `function_exported?(…, :trigger, 3)` assertions across all three." This is only literally correct for **sigra** (IN direction with `Sigra.Integrations.Chimeway.trigger/3`-style seam). For:
- **Accrue:** the loud assertion must move the integration-module check OUT of the outer `and` guard (so absence goes RED not skipped) and assert `function_exported?(Accrue.Integrations.Chimeway, :start_campaign, 3)` (its real seam fn — Accrue is a dunning engine, not a notifier; `start_campaign/3` is the verified exported arity).
- **Threadline:** assert the OUT-direction reporter loads + exports `attach/0`, NOT a partner integration module. Mirroring a `*.trigger/3` check verbatim would be **wrong** (no such function/module exists). The *principle* mirrors (every lane fails loud when its integration glue is missing); the *exact symbol* differs per direction.

  Verify the exact sigra integration seam function before writing the assertion — D-02b/D-03 reference `function_exported?(Sigra.Integrations.Chimeway, :trigger, 3)`, but the live lifecycle test (Coordinate "lifecycle", below) calls `SigraChimeway.dispatch_magic_link_after_request/3` and `dispatch_confirmation_after_generate/3`, NOT a 3-arity `trigger`. [ASSUMED] that `Sigra.Integrations.Chimeway` exports `trigger/3` — see Assumptions Log A1. The planner MUST confirm the actual exported function name/arity against the live `deps/sigra` (or pinned SHA) before locking the assertion, or assert a function that is verified to exist (e.g. `dispatch_magic_link_after_request/3`).

### Coordinate 4 — `test/chimeway/release_gate_contract_test.exs`

[VERIFIED: Read release_gate_contract_test.exs]

- **Structure:** two `describe` blocks — "release gate parity doc contract (GATE-05)" (`:24`) and "release pipeline contract (GATE-06)" (`:121`). The first iterates `@pre_ship_verify_commands` (`:14-22`, the 7 verify lanes incl. `verify.sigra`) asserting MAINTAINING, mix.exs aliases, and ci.yml job presence — all **substring/regex on file contents**, NOT runtime test counts.
- **Where the floor slots in:** add a new `describe "verify-lane test-count floor (WARNING-2)"` block. It cannot count tests by *running* them (this file is a fast `async: true` static-contract test). Two viable approaches:
  1. **Static count** of `test "` occurrences in the lane's tagged files (regex over the source) — proves the *suite* declares ≥ floor tests. Simple, fast, but doesn't prove they *execute* (could be guarded out).
  2. **Manifest assertion** that the integration module is loaded + a count check inside the lifecycle/harness test itself (e.g. a `test "lane runs >0 integration tests"` that asserts `Code.ensure_loaded?(Sigra.Integrations.Chimeway)`). Combine with the D-02b harness hard-assert (which already makes "module absent" go red).
  The audit/D-02c phrasing ("each verify lane runs ≥ its expected integration-test count") favors a count that fails when the lane degrades to 0. Recommended: assert in the **harness** (which always runs) that the integration module is loaded (covers "0 tests because compiled-out"), AND add a static `test "` floor in `release_gate_contract_test.exs` per lane as defense-in-depth.
- **Concrete floor numbers** [VERIFIED: grep test counts]:

  | Lane | Root `--only <tag>` files | Test count | Floor (suggested) |
  |------|---------------------------|-----------|-------------------|
  | sigra | `sigra_auth_harness_test.exs` (3) + `sigra_auth_lifecycle_test.exs` (2) | **5** root | `>= 5` (root lane) |
  | accrue | `accrue_dunning_harness_test.exs` (4) + `accrue_dunning_lifecycle_test.exs` (7) | **11** | `>= 11` |
  | threadline | `threadline_telemetry_harness_test.exs` (3) + `threadline_telemetry_lifecycle_test.exs` (4) | **7** | `>= 7` |

  **Caveat:** `verify.sigra` (mix.exs:134-137) has TWO lanes — the root `--only sigra` lane (5 tests) AND a demo-host lane (`sigra_auth_proof_test.exs`, **2 tests**, in `examples/chimeway_demo_host`). The floor for the demo-host proof is `>= 2`. Set floors conservatively at the *current* counts so the assertion catches regressions to 0 without being brittle to additions. Prefer "≥ N" not "== N".

### Coordinate 5 — `guides/introduction/sigra-auth-integration.md`

[VERIFIED: Read the guide]

- **The invalid example (D-03 / WR-1) — confirmed at lines 65-70** (audit said "line 66"; the `Chimeway.trigger(` opener is line 66):
  ```elixir
  Chimeway.trigger("sigra.auth.magic_link", recipient,
    idempotency_key: "sigra.magic_link:#{user_id}:#{token_inserted_at}",
    tenant_id: user_id,
    params: %{user_id: user_id, email: email}
  )
  ```
  Two defects: (1) **string first arg** `"sigra.auth.magic_link"` — `trigger/3` requires a notifier **module**; (2) **`params:` option** — no such option exists (params are the 2nd positional arg).
- **The CORRECT shape (from `seeds.ex:280`)** [VERIFIED: Read seeds.ex]:
  ```elixir
  Chimeway.trigger(Sigra.Integrations.Chimeway.MagicLinkNotifier, trigger_params, [
    idempotency_key: idempotency_key,
    tenant_id: @tenant_id,
    correlation_id: correlation_id
  ])
  ```
  i.e. **notifier module first** (`Sigra.Integrations.Chimeway.MagicLinkNotifier`), **params map second** (identifier-only keys), **opts keyword third** (`idempotency_key`, `tenant_id`, `correlation_id`). This matches the Phase 65 blueprint and the live demo seed.
- **WR-2 (`Mod.fun/0` arity inside ```elixir fences) — confirmed:**
  - Sigra guide **line 84**: `DemoHost.Seeds.seed_sigra_auth/0` inside an ```elixir fence (fence lines 83-85). `Foo.bar/0` is NOT valid Elixir expression syntax → raises on copy-paste. Fix: move to inline `` `DemoHost.Seeds.seed_sigra_auth/0` `` or a non-elixir (```text / no-lang) fence, or write the real call `DemoHost.Seeds.seed_sigra_auth()`.
  - Threadline guide **line 87**: `DemoHost.Seeds.seed_threadline_notification/0` inside an ```elixir fence (fence lines 86-88) — same defect, same fix.
  - Arity references inside *prose backticks* (e.g. sigra guide lines 11, 50, 59, 63, 73, 75) are fine — only the ones inside ```elixir fences are the bug.

### Coordinate 6 — `lib/chimeway/trigger.ex` (grounds D-03/D-04)

[VERIFIED: Read trigger.ex:1-90]

- **`trigger/3` signature — confirmed `trigger.ex:46-48`:**
  ```elixir
  @spec trigger(module(), map(), keyword()) ::
          {:ok, map()} | {:duplicate, struct()} | {:error, term()}
  def trigger(notifier, params, opts \\ []) do
  ```
  First arg is `module()`, second `map()`, third `keyword()`. **No `params:` option.**
- **`validate_module!` — confirmed at `trigger.ex:59`:** `:ok <- Notifier.validate_module!(notifier)` inside the `with`. (Audit said "lines 46,60"; live: the `@spec`/`def` is 46-48 and the `validate_module!` call is line 59. Close enough; the substance — module-first validation — is confirmed.)
- **`@sensitive_keys` redaction boundary — confirmed `trigger.ex:44`:**
  ```elixir
  @sensitive_keys ~w(password token secret url code raw_token magic_link_url)
  ```
  This is the LOCKED, out-of-scope boundary (do not touch). The moduledoc (`trigger.ex:22-29`) documents the top-level-only sanitization (the deferred nested-key follow-up).
- **Opts the guide should show:** `correlation_id` (line 50), `idempotency_key` (line 55), `tenant_id` (line 56) — all read from `opts`. These are the exact opts in `seeds.ex:280`.

### Coordinate 7 — `test/chimeway/doc_contract_test.exs` (sigra describe)

[VERIFIED: Read doc_contract_test.exs]

- **Sigra integration-guide describe block: `doc_contract_test.exs:752-823`** ("sigra auth integration guide doc contract (DOCS-10)"). It is **substring/order-only**:
  - `@recipe_forbidden_strings` loop (`:758-763`) — generic forbidden tokens.
  - `@sigra_forbidden ~w(:raw_token :magic_link_url)` (`:771-778`) — atom-form secret leaks.
  - `@required` list (`:780-799`) incl. `Chimeway.trigger`, `Sigra.Integrations.Chimeway`, `idempotency_key`, `tenant_id`, `DemoHost.Seeds.seed_sigra`, etc.
  - Section-order check (`:801-822`).
- **It would NOT have caught D-03:** `Chimeway.trigger` as a substring is present in BOTH the valid and invalid forms, and there is no forbidden pattern for `Chimeway.trigger("` (string-first) or `params:`.
- **Where D-04 slots in:** add to this describe block (a) a `@sigra_invalid_patterns ~w(...)` forbidden loop including `Chimeway.trigger("` and `params:`; (b) a positive assertion that the guide references a `*Notifier` module — e.g. `assert Regex.match?(~r/Sigra\.Integrations\.Chimeway\.\w*Notifier/, content)` or `assert String.contains?(content, "Notifier")` scoped to the trigger example. Pattern precedent: the mailglass guide already does `Regex.match?(~r/Chimeway\.Webhooks\.process\(\s*(?:adapter_module|Chimeway\.Adapters\.Mailglass)/, content)` (`:471-476`) — mirror that regex style for the trigger-first-arg-is-a-module check.
- **WR-3 (prefix-only seed pin) — confirmed:** `@required` at `doc_contract_test.exs:787` pins `DemoHost.Seeds.seed_sigra` (prefix). The blueprint describe also pins prefix `DemoHost.Seeds.seed_sigra` (`:405`). The **actual function is `seed_sigra_auth/0`** (`seeds.ex:255`). A rename to `seed_sigra_xyz` would still pass the prefix check. Fix: pin the full name `DemoHost.Seeds.seed_sigra_auth`.

### Coordinate 8 — Phase 64 state + what `mix verify.sigra` runs

[VERIFIED: git ls-files, Read 64-VALIDATION.md, grep mix.exs]

- **`64-02-SUMMARY.md` is UNTRACKED** — present on disk (`64-sigra-auth-flows-core/64-02-SUMMARY.md`, 2353 bytes) but absent from `git ls-files`. D-05 must `git add` + commit it.
- **No `64-VERIFICATION.md`** — confirmed absent in the dir listing. D-05 produces it.
- **`64-VALIDATION.md` is `status: draft`, `nyquist_compliant: false`, `wave_0_complete: false`** (frontmatter lines 4-6). All 7 per-task rows are `⬜ pending`. D-06 flips this to closed/compliant after the new VERIFICATION.
- **`mix verify.sigra` (mix.exs:134-137)** runs three steps:
  1. `deps.compile sigra --force`
  2. root lane: `cmd env MIX_ENV=test mix test --only sigra --warnings-as-errors` → exercises `sigra_auth_harness_test.exs` (3) + `sigra_auth_lifecycle_test.exs` (2) = **5 tests** (the lifecycle is the ECOS-09 redacted-trace proof: `dispatch_magic_link_after_request/3` + `dispatch_confirmation_after_generate/3`, asserting `Traces.get_trace`, `length(deliveries) >= 1`, `refute_sensitive_in_trace!`, `refute_sensitive_in_telemetry!`).
  3. demo-host lane: `cd examples/chimeway_demo_host && CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra CHIMEWAY_PATH=../.. mix deps.get && … deps.compile sigra --force && … mix test --only sigra --warnings-as-errors` → exercises `sigra_auth_proof_test.exs` (2 tests, DEMO-10).
  For D-05's reproducible clean-CI verify: the harness double-guard on the lifecycle test (`sigra_auth_lifecycle_test.exs:1` requires BOTH `Sigra` AND `Sigra.Integrations.Chimeway`) is exactly what compiles to 0 tests at the stale SHA — repinning makes it real.

### Coordinate 9 — `:sigra` dep `override: true` (D-06 R6 comment target)

[VERIFIED: Read mix.exs:166-180]

- `sigra_dep` (`mix.exs:174-180`):
  ```elixir
  defp sigra_dep do
    # Local dev: SIGRA_PATH=../sigra mix deps.get
    case System.get_env("SIGRA_PATH") do
      nil -> {:sigra, "~> 0.3", optional: true, runtime: false, override: true}
      path -> {:sigra, path: path, optional: true, runtime: false, override: true}
    end
  end
  ```
- **`override: true` is unique to sigra** — `accrue_dep` (`mix.exs:142-148`) and `threadline_dep` (`mix.exs:158-164`) do NOT have it. D-06 wants a one-line comment explaining the diamond-resolution reason (and that it's inert for adopters since optional deps aren't pulled transitively). The planner should investigate *why* sigra needs `override: true` (likely a transitive version conflict between sigra's own deps and chimeway's) before writing the comment — the comment must be accurate, not guessed. [ASSUMED] the reason is diamond version resolution — see Assumptions Log A2.

## Architecture Patterns

### IN vs OUT integration direction (the load-bearing distinction)

```
   PARTNER → CHIMEWAY (IN)                        CHIMEWAY → PARTNER (OUT)
   ────────────────────────                       ─────────────────────────
   Sigra auth event                               Chimeway notification telemetry
        │                                                │
        ▼                                                ▼
   Sigra.Integrations.Chimeway   ◄── lives in         Chimeway.Telemetry.ThreadlineReporter
   (partner repo szTheory/sigra)     PARTNER repo      (lives in chimeway lib/)  ──┐
        │                                                                          │
        ▼                                                                          ▼
   Chimeway.trigger(Notifier, params, opts)        Threadline.record_action(...)
        │                                                │
        ▼                                                ▼
   chimeway events/notifications/deliveries        Threadline AuditAction row
        │
        ▼
   redacted trace @ /admin/chimeway

   CI wiring (IN):  sibling actions/checkout @ pinned SHA + conditional-compile in test_helper
   CI wiring (OUT): no checkout needed — chimeway owns the code; partner module need only exist
```

- **Sigra + Accrue = IN.** Glue lives in the partner repo, pinned via sibling checkout. Guard must fail loud when the partner integration module is missing.
- **Threadline = OUT.** Glue (`ThreadlineReporter`) lives in chimeway `lib/`. The harness asserts the *reporter* loads, not a partner integration module. **Do not symmetrize Threadline as if it had a `Partner.Integrations.Chimeway`.**

### Pattern: raise-loud-on-missing-file (D-02a)
**What:** when the optional partner dep is loaded (`Code.ensure_loaded?(Sigra)`) and Chimeway is loaded, but the integration source file is absent on disk → raise, don't skip.
**When to use:** the two IN-direction conditional-compile blocks in `test_helper.exs` (sigra:160, accrue:43).
**Example (sigra block, the `else` to add):**
```elixir
# Source: extends existing raise at test_helper.exs:163-165
if is_binary(source) and File.exists?(source) do
  _ = Code.compile_file(source)
  unless Code.ensure_loaded?(Sigra.Integrations.Chimeway) do
    raise "failed to compile Sigra.Integrations.Chimeway from #{source}"
  end
else
  raise "Sigra is loaded but Sigra.Integrations.Chimeway source is missing — " <>
        "verify_sigra is pinned to a SHA without the integration module (see ci.yml verify_sigra)"
end
```

### Anti-Patterns to Avoid
- **Vendoring `Sigra.Integrations.Chimeway` into chimeway `lib/`** — explicitly rejected (no precedent, violates partner-owns-its-domain). OUT of scope.
- **Mirroring `function_exported?(…, :trigger, 3)` verbatim onto Threadline** — Threadline is OUT direction; there is no such module/function. Assert the reporter instead.
- **`== N` test-count floors** — brittle; use `>= N` so adding tests doesn't break the gate.
- **Touching `@sensitive_keys`** — verified good, out of scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-repo integration glue compile | a chimeway-side shim for the sigra integration | the existing `test_helper.exs` `Code.compile_file` + sibling checkout (Accrue precedent) | Already proven; vendoring invents a no-precedent pattern |
| Detecting "lane ran 0 tests" | parsing `mix test` output | hard-assert integration-module-load in the always-running harness + static `test "` count floor | Robust to the compiled-out-to-zero case |
| Verifying the guide API matches | manual review | extend `doc_contract_test.exs` with forbidden-pattern + `*Notifier` regex | The doc-contract is the existing truth-lock mechanism |

**Key insight:** every mechanism this phase needs already exists in the codebase (sibling checkout, conditional-compile-with-raise, doc-contract forbidden/required patterns, release-gate-contract assertions). This is a tightening pass — reuse the precedents, don't invent.

## Runtime State Inventory

> This is a CI/test/docs hardening phase. No stored data, no live external service config, no OS-registered state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — verified by grep; no DB keys/collections embed renamed strings (no renames in this phase). | none |
| Live service config | **The pinned SHA `b186f03c` in `ci.yml:407` is config that lives in git** (good — not in a UI/DB). The partner-side integration commits live in `szTheory/sigra` at `62ceb46a`/`c7f06d92` — chimeway only references them by SHA. No GitHub-Actions UI state to change. | D-01 edits `ci.yml` (in git). Verify the target SHA exists on `szTheory/sigra` before merge. |
| OS-registered state | None — no Task Scheduler/launchd/systemd/pm2 involvement. Verified: phase touches CI yaml, Elixir test files, markdown guides, planning docs. | none |
| Secrets/env vars | `SIGRA_PATH`/`ACCRUE_PATH`/`THREADLINE_PATH` are CI workspace paths set inline in `ci.yml` (not secrets), already correct. `CHIMEWAY_SKIP_SIGRA_DEP` used by the demo-host lane (mix.exs:167). No secret renames. | none |
| Build artifacts / installed packages | `deps/sigra/` is a **gitignored local copy** (`git check-ignore` confirms) — it is present on the dev machine with the integration file, which is exactly why local SUMMARYs passed while clean CI failed. The fix does NOT depend on the local copy; clean CI gets the file from the pinned sibling checkout. `64-02-SUMMARY.md` is an untracked build artifact of Phase 64 that D-05 must commit. | D-05 commits `64-02-SUMMARY.md`. No package reinstall needed. |

## Common Pitfalls

### Pitfall 1: Symmetrizing Threadline as an IN-direction partner
**What goes wrong:** Planner writes `function_exported?(Threadline.Integrations.Chimeway, :trigger, 3)` into the threadline harness; it fails to compile (module doesn't exist).
**Why it happens:** D-02b says "mirror across sigra/accrue/threadline"; the literal mirror is wrong for OUT direction.
**How to avoid:** Threadline asserts `Chimeway.Telemetry.ThreadlineReporter` (chimeway-owned) + `Threadline.record_action/2`. Accrue asserts `Accrue.Integrations.Chimeway.start_campaign/3`. Only sigra's seam is the `Sigra.Integrations.Chimeway` IN-direction module.
**Warning signs:** a `function_exported?` check referencing a nonexistent partner integration module.

### Pitfall 2: Asserting `Sigra.Integrations.Chimeway.trigger/3` without verifying it exists
**What goes wrong:** D-02b/D-03 reference `function_exported?(Sigra.Integrations.Chimeway, :trigger, 3)`, but the live lifecycle test calls `dispatch_magic_link_after_request/3` and `dispatch_confirmation_after_generate/3` on that module — there may be no public `trigger/3` on it (the `trigger/3` is on `Chimeway`, not on `Sigra.Integrations.Chimeway`).
**Why it happens:** conflating `Chimeway.trigger/3` (verified, `trigger.ex:46`) with a same-named function on the integration module.
**How to avoid:** before locking the harness assertion, grep the pinned `deps/sigra/lib/sigra/integrations/chimeway.ex` for its actual public exports. Assert a function VERIFIED to exist (`dispatch_magic_link_after_request/3` is confirmed via the lifecycle test). See Assumptions Log A1.
**Warning signs:** harness goes red even after repinning to a SHA that has the module.

### Pitfall 3: Floor count counts the wrong lane
**What goes wrong:** Setting the sigra floor to 7 (treating it like a single lane) when the root lane has 5 and the demo-host lane has 2 in a separate mix project.
**Why it happens:** `verify.sigra` is two `mix test` invocations across two projects (mix.exs:134-137).
**How to avoid:** floor the root lane at ≥5 and the demo-host proof at ≥2 separately, or assert per-file. Use the verified counts in Coordinate 4.

### Pitfall 4: D-04 forbidden patterns also match the fixed guide
**What goes wrong:** forbidding the substring `params:` could false-positive if the corrected guide legitimately uses `params:` anywhere (it shouldn't — `trigger/3` has no such option — but prose might).
**Why it happens:** substring forbidden-patterns are blunt.
**How to avoid:** scope the forbidden pattern tightly — `Chimeway.trigger("` (string-first-arg, unambiguous) is safe; for `params:` prefer a regex anchored to the trigger call or confirm the corrected guide contains zero `params:` occurrences before adding the blanket forbid.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ci.yml:407` ref `b186f03c` (pre-integration) | ref `62ceb46a` (origin/main HEAD, contains integration) | this phase (D-01) | sibling checkout becomes non-empty; lifecycle test compiles real tests |
| Silent-skip on missing integration file | raise-loud (D-02a) | this phase | vacuous green becomes impossible |
| Substring-only sigra doc-contract | forbidden-pattern + `*Notifier` assertion (D-04) | this phase | invalid `trigger` shape would be caught |
| Prefix-only `seed_sigra` pin | full name `seed_sigra_auth` (WR-3) | this phase | rename-resilient |

**Deprecated/outdated:**
- The local gitignored `deps/sigra/` as the de-facto source of truth — replaced by the pinned sibling checkout (it was never the right source; it masked the CI gap).

## Validation Architecture

> Nyquist enabled (`config.json: nyquist_validation: true`). This section drives the VALIDATION.md the orchestrator creates.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17 / OTP 26+27 matrix) |
| Config file | `mix.exs` aliases (`ci.test`, `verify.sigra` at mix.exs:134-137) |
| Quick run command | `SIGRA_PATH=../sigra/sigra mix test --only sigra --warnings-as-errors` (root lane) |
| Full suite command | `SIGRA_PATH=<sibling> mix verify.sigra` (root + demo-host lanes) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command / Evidence | File Exists? |
|--------|----------|-----------|------------------------------|-------------|
| ECOS-09 | clean-CI sigra root lane runs >0 integration tests | integration | `verify_sigra` job (ci.yml:427) → root lane runs harness(3)+lifecycle(2) | ✅ (repin makes real) |
| ECOS-09 | raise loud when `Sigra.Integrations.Chimeway` absent | guard | `test_helper.exs` sigra block `else`-raise (D-02a) | ❌ Wave 0 (add else) |
| ECOS-09 | magic-link + confirmation dispatch create durable delivery with redacted trace | integration | `sigra_auth_lifecycle_test.exs:30,63` (`refute_sensitive_in_trace!`, `refute_sensitive_in_telemetry!`) | ✅ |
| ECOS-09 | symmetric raise-loud across sigra/accrue (IN) | guard | `test_helper.exs` accrue block `else`-raise (D-02a) | ❌ Wave 0 |
| ECOS-09 | harness hard-asserts integration module loads (outside lifecycle guard) | integration | `sigra_auth_harness_test.exs` + accrue + threadline (D-02b) | ❌ Wave 0 (add assertions) |
| GATE-07 | per-lane test-count floor (sigra ≥5 root / ≥2 demo, accrue ≥11, threadline ≥7) | contract | new describe in `release_gate_contract_test.exs` (D-02c) | ❌ Wave 0 |
| DOCS-10 | guide uses valid `trigger(Notifier, params, opts)` shape; no `params:`/string-first | contract | `doc_contract_test.exs` sigra describe forbidden-pattern + `*Notifier` assert (D-04) | ❌ Wave 0 (extend) |
| DEMO-10 | demo-host proof creates durable delivery + admin trace | e2e | `sigra_auth_proof_test.exs:44,52` (demo-host lane) | ✅ |
| ECOS-09 | Phase 64 E2E proof captured | doc | `64-VERIFICATION.md` (D-05) | ❌ Wave 0 (produce) |

### Sampling Rate
- **Per task commit:** `SIGRA_PATH=<sibling> mix test --only sigra --warnings-as-errors` (~5 tests, <90s)
- **Per wave merge:** `mix verify.sigra` (root + demo-host) + `mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs`
- **Phase gate:** full `mix verify.sigra` green in clean CI (the D-05 reproduction) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/test_helper.exs` — add `else`-raise to sigra block (≈line 160-166) and accrue block (≈line 43-49) — covers ECOS-09 raise-loud
- [ ] `test/chimeway/integrations/sigra_auth_harness_test.exs` — hard-assert `Code.ensure_loaded?(Sigra.Integrations.Chimeway)` + a VERIFIED exported function (confirm `:trigger/3` vs `dispatch_*` first)
- [ ] `test/chimeway/integrations/accrue_dunning_harness_test.exs` — move integration-module check out of outer guard; assert `start_campaign/3` loud
- [ ] `test/chimeway/integrations/threadline_telemetry_harness_test.exs` — assert `Chimeway.Telemetry.ThreadlineReporter` + `attach/0` (OUT direction)
- [ ] `test/chimeway/release_gate_contract_test.exs` — new floor describe (sigra/accrue/threadline counts)
- [ ] `test/chimeway/doc_contract_test.exs` — extend sigra describe (forbidden `Chimeway.trigger("`, `params:`; require `*Notifier`; full `seed_sigra_auth` pin)
- [ ] `.planning/phases/64-sigra-auth-flows-core/64-VERIFICATION.md` — produce (D-05)

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | all tests | ✓ (CI: 1.17) | local unverified this session | — |
| `szTheory/sigra` @ `62ceb46a` integration file | D-01 clean-CI verify | ✗ remote (not network-fetched this session); ✓ as gitignored `deps/sigra` local copy | — | local `deps/sigra` proves the file exists; remote SHA presence is CITED from audit, must be confirmed at merge |
| PostgreSQL 15 | all integration tests | ✓ in CI (ci.yml services) | 15 | — |

**Missing dependencies with no fallback:** none blocking (the integration file exists locally and per the audit on the remote SHA).
**Critical confirm-before-merge:** the planner/executor MUST verify `62ceb46a` (or `c7f06d92`) actually contains `lib/sigra/integrations/chimeway.ex` on `szTheory/sigra` before merging D-01 — this session could not reach the remote. The audit's 4-stream research asserts it does.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Sigra.Integrations.Chimeway` exports `trigger/3` (per D-02b/D-03 wording) | Coordinate 3, Pitfall 2 | Harness hard-assert fails even after correct repin. The live lifecycle test calls `dispatch_magic_link_after_request/3` / `dispatch_confirmation_after_generate/3`, NOT `trigger/3`, on this module — `trigger/3` is on `Chimeway`. Planner must grep `deps/sigra/.../chimeway.ex` and assert a VERIFIED export. |
| A2 | `:sigra` `override: true` reason is diamond version resolution | Coordinate 9, D-06 | The D-06 comment would be inaccurate. Planner must investigate the actual conflict (`mix deps.tree`/sigra's mix.exs) before writing the comment. |
| A3 | `szTheory/sigra@62ceb46a` contains the integration file on the remote | D-01, Environment | If the SHA is wrong, repin still leaves the lane vacuous. CITED from audit 4-stream research; confirm at merge (could not fetch remote this session). |
| A4 | Floor counts (sigra 5/2, accrue 11, threadline 7) stay stable | Coordinate 4, D-02c | Floors set too high break on legitimate additions; use `>=` not `==`. Counts are VERIFIED at current HEAD via grep. |

## Open Questions (RESOLVED)

1. **Exact public export to assert in the sigra harness (`trigger/3` vs `dispatch_*`)?**
   - What we know: `Chimeway.trigger/3` exists (`trigger.ex:46`); the lifecycle test calls `SigraChimeway.dispatch_magic_link_after_request/3` + `dispatch_confirmation_after_generate/3`.
   - What's unclear: whether `Sigra.Integrations.Chimeway` itself exports a `trigger/3`.
   - Recommendation: grep the pinned `deps/sigra/lib/sigra/integrations/chimeway.ex` during planning; assert `dispatch_magic_link_after_request/3` (confirmed to exist) OR confirm `trigger/3` before using the CONTEXT's literal wording.
   - **(RESOLVED):** the verified export is `dispatch_magic_link_after_request/3` (NOT `trigger/3`, which lives on `Chimeway`). The harness hard-asserts `function_exported?(Sigra.Integrations.Chimeway, :dispatch_magic_link_after_request, 3)` per the plans (closes A1).

2. **Static count vs runtime count for the floor (D-02c)?**
   - What we know: `release_gate_contract_test.exs` is a fast static-contract test; counting executed tests there isn't natural.
   - Recommendation: combine — harness module-load hard-assert (catches compiled-to-0) + a static `test "` regex floor per lane file. Belt and suspenders, both cheap.
   - **(RESOLVED):** the plans implement the combined floor — the always-running harness hard-asserts integration-module load (catches the compiled-to-0 case) AND `release_gate_contract_test.exs` adds a static per-lane `test "` count floor (sigra >=5 root / >=2 demo, accrue >=11, threadline >=7, all `>=`).

## Sources

### Primary (HIGH confidence — verified against live HEAD)
- `Read .github/workflows/ci.yml` — verify_sigra:383, sigra pin:407, accrue:251/275, threadline:337/361, ci-gate:475-508
- `Read test/test_helper.exs` — sigra block 140-210 (silent-skip 160-166), accrue block 35-98 (silent-skip 43-49)
- `Read test/chimeway/integrations/{sigra_auth,accrue_dunning,threadline_telemetry}_harness_test.exs` — guard asymmetries
- `Read test/chimeway/integrations/sigra_auth_lifecycle_test.exs` — ECOS-09 redacted-trace proof, dispatch fn names
- `Read test/chimeway/release_gate_contract_test.exs` — gate-contract structure
- `Read test/chimeway/doc_contract_test.exs` — sigra describe 752-823, WR-3 pin 787
- `Read guides/introduction/sigra-auth-integration.md` — invalid example 65-70, WR-2 line 84
- `Read lib/chimeway/trigger.ex` — signature 46-48, validate_module! 59, @sensitive_keys 44
- `Read examples/chimeway_demo_host/lib/demo_host/seeds.ex` — correct call shape seeds.ex:280
- `Read examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — DEMO-10 lane
- `Read mix.exs` — verify.sigra 134-137, sigra_dep override:true 174-180
- `Read .planning/phases/64-sigra-auth-flows-core/64-VALIDATION.md` — draft status
- `git ls-files` / `git check-ignore` — 64-02-SUMMARY untracked, deps/sigra gitignored
- grep test counts — sigra 3+2, accrue 4+7, threadline 3+2

### Secondary (CITED — design contract / audit)
- `.planning/v1.10-MILESTONE-AUDIT.md` — Closure Plan R1-R6, SHA provenance (`62ceb46a`/`c7f06d92`/`b186f03c`), architectural verdict
- `.planning/phases/67-.../67-CONTEXT.md` — LOCKED decisions D-01..D-06

### Tertiary (LOW / could not verify this session)
- Remote `szTheory/sigra@62ceb46a` content — not network-fetched; CITED from audit; confirm at merge (A3)

## Metadata

**Confidence breakdown:**
- Live coordinates (CI/tests/guide/trigger/seeds): HIGH — all read directly at current HEAD, no drift
- Floor counts: HIGH — grep-verified, but set `>=` to stay robust
- Sigra integration-module public export (`trigger/3`): LOW — A1, must confirm against deps/sigra before locking the harness assertion
- Remote SHA contents: MEDIUM — CITED from audit, locally corroborated by gitignored copy, remote unconfirmed this session
- `override: true` rationale: LOW — A2, planner must investigate before writing the comment

**Research date:** 2026-06-02
**Valid until:** 2026-06-16 (coordinates can drift if other PRs touch ci.yml / test files; re-grep if stale)
