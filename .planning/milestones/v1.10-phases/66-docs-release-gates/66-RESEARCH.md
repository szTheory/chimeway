# Phase 66: Docs & Release Gates - Research

**Researched:** 2026-05-30
**Domain:** Elixir documentation guides, ExUnit doc-contract tests, Mix alias patterns, GitHub Actions CI job composition
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Threadline Integration Guide Shape (`guides/introduction/threadline-integration.md`) — D-01**
4-section trimmed structure — attach-only telemetry. Sections:
1. **Dependencies** — `{:threadline, "~> 0.7"}` optional dep with env override pattern
2. **Attach reporter** — `Application.start/2` one-liner for `Chimeway.Telemetry.ThreadlineReporter.attach/0` + config block with `:repo` and `:actor` only
3. **What gets recorded** — 4-row outcome table (suppressed/deferred/dispatched/failed) plus `correlation_id` callout explaining `Threadline.Query.timeline/2` strict filter
4. **Verification** — `DemoHost.Seeds.seed_threadline_notification/0` + `/admin/chimeway` + `mix verify.threadline` gate command

**Sigra Auth Integration Guide Shape (`guides/introduction/sigra-auth-integration.md`) — D-02**
5-section structure (no "Database / migrations" section). Sections:
1. **Dependencies** — `{:sigra, "~> 0.3", optional: true}` + SIGRA_PATH env override
2. **Integration seam** — `Sigra.Integrations.Chimeway`, runtime config, responsibility split
3. **Notifier reference** — `sigra.auth.magic_link` and `sigra.auth.confirmation_code` stable keys; `build/2` resolves at dispatch time
4. **Auth event triggers** — `Chimeway.trigger/3` with `idempotency_key` + `tenant_id`; inline redaction note as anti-pattern
5. **Verification** — `DemoHost.Seeds.seed_sigra_auth/0` + `/admin/chimeway` + `SIGRA_PATH=../sigra mix verify.sigra`

**Inline Redaction Anti-Pattern — D-03**
Inline note lives in section 4 (not standalone section). Leads with "do not pass" statement. Explicit `:raw_token`, `:magic_link_url`, `:confirmation_code` prohibition.

**DOCS-11 Threadline Doc-Contract — D-04**
New `describe "threadline integration guide doc contract (DOCS-10)"` in `test/chimeway/doc_contract_test.exs`. `@required` = 8 strings: `Chimeway.Telemetry.ThreadlineReporter`, `attach/0`, `config :chimeway`, `correlation_id`, `notification_suppressed`, `DemoHost.Seeds.seed_threadline_notification`, `/admin/chimeway`, `mix verify.threadline`. No Threadline-specific additional forbidden phrases. Standard `@recipe_forbidden_strings` applies.

**DOCS-11 Sigra Doc-Contract — D-05**
New `describe "sigra auth integration guide doc contract (DOCS-10)"`. `@sigra_forbidden` atom forms: `:raw_token`, `:magic_link_url`. `@required` strings: `Sigra.Integrations.Chimeway`, `sigra.auth.magic_link`, `sigra.auth.confirmation_code`, `Chimeway.trigger`, `idempotency_key`, `tenant_id`, `DemoHost.Seeds.seed_sigra`, `/admin/chimeway`, `mix verify.sigra`, `SIGRA_PATH`, `orchestrates`. Standard `@recipe_forbidden_strings` also applies.

**GATE-07 Implementation Details — Claude's Discretion**
- `mix verify.threadline`: `deps.compile threadline --force` + `cmd env MIX_ENV=test mix test --only threadline --warnings-as-errors` + `cmd --shell cd examples/chimeway_demo_host && ... mix test --only threadline --warnings-as-errors` with `THREADLINE_PATH` env and `CHIMEWAY_SKIP_THREADLINE_DEP=1`
- `mix verify.sigra`: mirrors `verify.accrue` — `deps.compile sigra --force` + root sigra tests + demo host sigra tests with `SIGRA_PATH` env and `CHIMEWAY_SKIP_SIGRA_DEP=1`
- `verify_threadline` CI job: sibling checkout of `szTheory/threadline`
- `verify_sigra` CI job: sibling checkout of `szTheory/sigra`
- ci-gate `needs` list: grows from 9 to 11 entries
- MAINTAINING.md: pre-ship checklist grows from 8 to 10 commands

### Claude's Discretion
(See GATE-07 implementation details above — all structural decisions for verify aliases and CI jobs are discretion items guided by `verify.accrue` precedent.)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-10 | Golden-path integration guides cover Threadline telemetry bridge setup and Sigra auth notification mount (dependencies → config → trigger → proof) | Guide shape locked by D-01/D-02. Section templates come from `accrue-dunning-integration.md`. Content facts from 63-CONTEXT.md and 64-CONTEXT.md. |
| DOCS-11 | Doc-contract tests lock Threadline and Sigra integration guide truth and forbid regressions | Test structure locked by D-04/D-05. Pattern from existing DOCS-08/09 describe blocks in `doc_contract_test.exs`. |
| GATE-07 | Named verify entrypoints `mix verify.threadline` and `mix verify.sigra` run in CI and appear in MAINTAINING.md pre-ship checklist | `verify.accrue` is the copy/adapt template. `release_gate_contract_test.exs` will need updating to track the new gates. |
</phase_requirements>

---

## Summary

Phase 66 is a documentation, test, and tooling-gate phase — it produces no new library code. All integration behavior was shipped in Phases 63–65; this phase writes the adoption-surface artifacts (two integration guides, two doc-contract describe blocks, two Mix alias verify gates, two CI jobs, and MAINTAINING.md updates) that make those integrations officially documented and release-gated.

The work is almost entirely copy-and-adapt from proven templates within the same repository. The `accrue-dunning-integration.md` guide, the DOCS-08/09 describe blocks in `doc_contract_test.exs`, the `verify.accrue` Mix alias, and the `verify_accrue` CI job all serve as direct structural templates. The only genuine authoring work is composing the guide content accurately from the Phase 63/64/65 CONTEXT files and wiring the new atoms into the doc-contract test.

One important implication: `release_gate_contract_test.exs` currently hardcodes "All eight must pass" and a `@ci_gate_lanes` list of 9 entries. Adding two new gates requires updating that contract test to reflect the new 10-command pre-ship checklist and 11-lane ci-gate, or the `ci.verify_gates` lane will fail. The planner must treat updating `release_gate_contract_test.exs` as a required task alongside MAINTAINING.md and `ci.yml`.

**Primary recommendation:** Plan each deliverable as a focused task matching the decision-per-file breakdown from CONTEXT.md. The natural task split is: (1) Threadline guide, (2) Sigra guide, (3) both doc-contract describe blocks together in one task, (4) Mix aliases + `mix.exs` docs extras, (5) CI jobs + MAINTAINING.md + release gate contract test update.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Threadline integration guide content | Documentation layer | — | Static markdown; no code generation |
| Sigra integration guide content | Documentation layer | — | Static markdown; no code generation |
| Doc-contract test enforcement | Test layer (ExUnit) | CI (`verify_gates` job) | Tests run in `mix ci.verify_gates` and in the `verify_gates` CI lane |
| `mix verify.threadline` alias | Build tooling (mix.exs) | CI (`verify_threadline` job) | Alias drives local run; CI job drives remote proof |
| `mix verify.sigra` alias | Build tooling (mix.exs) | CI (`verify_sigra` job) | Same pattern as `verify.accrue` |
| ci-gate aggregation | CI (`.github/workflows/ci.yml`) | Release gate contract test | ci-gate `needs` list must match `@ci_gate_lanes` in `release_gate_contract_test.exs` |
| MAINTAINING.md pre-ship checklist | Documentation layer | Release gate contract test | Doc references commands; contract test validates they appear |
| Release gate contract coherence | Test layer (ExUnit) | CI (`verify_gates` job) | `release_gate_contract_test.exs` validates MAINTAINING + mix.exs + ci.yml all agree |

---

## Standard Stack

This phase uses only tools already established in the repository. No new packages are installed.

### Core (already installed)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| ExUnit | (OTP built-in) | Doc-contract test describe blocks | Project's established testing framework |
| Mix aliases | (Elixir built-in) | `verify.threadline` / `verify.sigra` | Established pattern: `verify.accrue`, `verify.inbox` |
| GitHub Actions | (CI platform) | `verify_threadline` / `verify_sigra` jobs | Established CI infrastructure |

**No packages to install.** [VERIFIED: codebase inspection of `mix.exs` — `threadline_deps/0` and `sigra_deps/0` already present, env vars already defined]

---

## Package Legitimacy Audit

> **SKIPPED** — Phase 66 installs no external packages. `threadline` and `sigra` deps are already declared in `mix.exs` from Phases 63/64.

---

## Architecture Patterns

### System Architecture Diagram

```
[DOCS-10 Guides] ──read by──► [doc-contract tests] ──enforced by──► [verify_gates CI job]
       │                                                                        │
       │                              [mix.exs aliases]                        ▼
       │                         verify.threadline ────────────────► [verify_threadline CI job]
       │                         verify.sigra ───────────────────► [verify_sigra CI job]
       │                                                                        │
       └──────────────── [MAINTAINING.md pre-ship checklist] ◄──────────────── ┘
                                        │
                         [release_gate_contract_test.exs]
                         validates MAINTAINING + mix.exs + ci.yml all agree
                                        │
                                   [verify_gates CI job]
```

### Recommended File Touch List

```
guides/introduction/
├── threadline-integration.md       # new — DOCS-10 Threadline guide
├── sigra-auth-integration.md       # new — DOCS-10 Sigra guide
test/chimeway/
├── doc_contract_test.exs           # append two describe blocks — DOCS-11
├── release_gate_contract_test.exs  # update: 8→10 commands, 9→11 ci-gate lanes
mix.exs                             # append verify.threadline + verify.sigra aliases
                                    # append guide paths to docs extras
.github/workflows/
├── ci.yml                          # append verify_threadline + verify_sigra jobs
                                    # update ci-gate needs (9→11 entries)
MAINTAINING.md                      # update pre-ship checklist: 8→10 commands
```

### Pattern 1: Integration Guide Structure (from `accrue-dunning-integration.md`)

**What:** Golden-path guide with responsibility split header, numbered sections (Dependencies → config → trigger → verification), and Related guides footer.

**When to use:** Any SEED-003 ecosystem integration guide.

**Threadline guide variation (4 sections, no migrations):**
```markdown
# Threadline Integration

[intro paragraph + link to blueprint if applicable]

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** ...
**Threadline owns audit ledger:** ...

## 1. Dependencies
## 2. Attach reporter
## 3. What gets recorded
## 4. Verification

## Related guides
```

**Sigra guide variation (5 sections, no migrations):**
```markdown
# Sigra Auth Integration

[intro paragraph]

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** ...
**Sigra owns auth state:** ...

## 1. Dependencies
## 2. Integration seam
## 3. Notifier reference
## 4. Auth event triggers
## 5. Verification

## Related guides
```

[VERIFIED: codebase inspection of `guides/introduction/accrue-dunning-integration.md` and `guides/introduction/mailglass-integration.md`]

### Pattern 2: Doc-Contract Describe Block Structure

**What:** ExUnit `describe` block that reads a guide file and asserts required strings appear and forbidden strings do not.

**Template (from DOCS-08/09 blocks in `doc_contract_test.exs`):**
```elixir
@threadline_integration_guide Path.expand("../../guides/introduction/threadline-integration.md", __DIR__)

describe "threadline integration guide doc contract (DOCS-10)" do
  setup do
    content = File.read!(@threadline_integration_guide)
    %{content: content}
  end

  for forbidden <- @recipe_forbidden_strings do
    test "forbids #{forbidden} in threadline integration guide", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "threadline integration guide must not reference #{unquote(forbidden)}"
    end
  end

  test "forbids Chimeway.Workflow module (not Workflows) in threadline integration guide",
       %{content: content} do
    refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
           "threadline integration guide must not reference fictional Chimeway.Workflow"
  end

  @required ~w(
    Chimeway.Telemetry.ThreadlineReporter
    attach/0
    config\ :chimeway
    correlation_id
    notification_suppressed
    DemoHost.Seeds.seed_threadline_notification
    /admin/chimeway
    mix\ verify.threadline
  )

  for required <- @required do
    test "requires #{required} in threadline integration guide", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "threadline integration guide must reference #{unquote(required)}"
    end
  end
end
```

**Key note:** `@recipe_forbidden_strings` is already defined at module top: `~w(stop_conditions Workflows.Workers Chimeway.Trigger.trigger)`. The new blocks inherit it. [VERIFIED: codebase inspection of `test/chimeway/doc_contract_test.exs` lines 104–108]

**Sigra variation adds `@sigra_forbidden` atom forms:**
```elixir
@sigra_forbidden ~w(:raw_token :magic_link_url)

for forbidden <- @sigra_forbidden do
  test "forbids #{forbidden} in sigra auth integration guide", %{content: content} do
    refute String.contains?(content, unquote(forbidden)),
           "sigra auth integration guide must not reference #{unquote(forbidden)} in code examples"
  end
end
```

[VERIFIED: codebase inspection — ECOS-10 sigra blueprint describe block at line 368 shows this atom-form forbidden pattern already in use]

### Pattern 3: Mix Verify Alias Shape

**Template (from `verify.accrue` in `mix.exs`):**
```elixir
"verify.threadline": [
  "deps.compile threadline --force",
  "cmd env MIX_ENV=test mix test --only threadline --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline CHIMEWAY_PATH=../.. mix deps.compile threadline --force && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline CHIMEWAY_PATH=../.. mix test --only threadline --warnings-as-errors"
],

"verify.sigra": [
  "deps.compile sigra --force",
  "cmd env MIX_ENV=test mix test --only sigra --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra CHIMEWAY_PATH=../.. mix deps.compile sigra --force && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra CHIMEWAY_PATH=../.. mix test --only sigra --warnings-as-errors"
]
```

[VERIFIED: codebase inspection of `mix.exs` lines 113–118, `verify.accrue` alias — `CHIMEWAY_SKIP_THREADLINE_DEP` and `CHIMEWAY_SKIP_SIGRA_DEP` env var names confirmed at lines 137–165]

### Pattern 4: CI Job Shape (sibling checkout)

**Template (from `verify_accrue` in `.github/workflows/ci.yml`):**
```yaml
verify_threadline:
  name: Threadline telemetry gate
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
      ports:
        - 5432:5432
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
    THREADLINE_PATH: ${{ github.workspace }}/threadline
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        repository: szTheory/threadline
        ref: <threadline-integration-ref>
        path: threadline
    - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
      with:
        elixir-version: "1.17"
        otp-version: "27"
    - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-verify-threadline-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-verify-threadline-
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.threadline
```

[VERIFIED: codebase inspection of `.github/workflows/ci.yml` `verify_accrue` job, lines 251–295]

**Open item:** The specific `ref:` SHA for `szTheory/threadline` and `szTheory/sigra` must be confirmed by the implementer. The `verify_accrue` job pins `236fa2f1649e771f3b515603495436badeed3c7b` for accrue. Equivalent pinned refs for threadline and sigra are needed. [ASSUMED — specific SHAs not inspectable without sibling repo access]

### Pattern 5: ci-gate Expansion

**Current ci-gate `needs` (9 entries, line 386 of `ci.yml`):**
```yaml
needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox]
```

**Target (11 entries):**
```yaml
needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra]
```

Also update the `for lane in ...` loop in the ci-gate `run:` step to add `VERIFY_THREADLINE` and `VERIFY_SIGRA`. [VERIFIED: codebase inspection of `.github/workflows/ci.yml` lines 386–414]

### Pattern 6: Release Gate Contract Test Update

**Critical:** `release_gate_contract_test.exs` currently:
- `@ci_gate_lanes` hardcodes 9 lanes (line 12)
- The test "ci-gate aggregates 9 required lanes" asserts exactly 9 lanes (line 113)
- `@pre_ship_verify_commands` has 5 tuples (lines 14–20)
- The test "MAINTAINING documents eight-gate pre-ship requirement" matches `~r/All eight must pass/i` (line 45)

After Phase 66, `@ci_gate_lanes` must add `verify_threadline` and `verify_sigra` (11 total), `@pre_ship_verify_commands` must add the new two entries, the lane-count test must say "11 required lanes", and the MAINTAINING test must match "All ten must pass". [VERIFIED: codebase inspection of `test/chimeway/release_gate_contract_test.exs`]

### Pattern 7: HexDocs Extras Update

The two new guides must be added to `mix.exs` `docs/0` extras list. The existing `hexdocs extras doc contract` test in `doc_contract_test.exs` (lines 908–963) verifies that `mailglass-integration.md`, `accrue-dunning-integration.md`, and `inbox-integration.md` appear in `mix.exs`. The new guides (`threadline-integration.md`, `sigra-auth-integration.md`) should be added after `inbox-integration.md` in the `Introduction:` group. There is no existing test enforcing their presence, but the planner should add this to `doc_contract_test.exs` or accept it as untested. [VERIFIED: codebase inspection of `mix.exs` lines 181–209 and `doc_contract_test.exs` lines 908–963]

### Anti-Patterns to Avoid

- **Mixing Threadline and Sigra sections** — write them as fully separate guides, not a combined "SEED-003 integrations" guide. The CONTEXT.md specifies two distinct files.
- **Adding a standalone "## Trace Redaction" section** in the Sigra guide — D-03 locks the inline placement of the anti-pattern note inside section 4.
- **Using `Chimeway.Workflow` (without `s`)** — forbidden by `@recipe_forbidden_strings` and the `Regex.match?(~r/Chimeway\.Workflow(?![s])/, content)` test.
- **Referencing `stop_conditions`, `Workflows.Workers`, or `Chimeway.Trigger.trigger`** — all in `@recipe_forbidden_strings`.
- **Using prose form `raw token` or `magic link URL` in code examples** — the atom form check (`:raw_token`, `:magic_link_url`) is the primary guard; prose form does not trigger it per D-05 specifics.
- **Forgetting to update `release_gate_contract_test.exs`** — the `ci.verify_gates` lane will fail if lane count and MAINTAINING text diverge from test expectations.
- **Forgetting to add the guides to `mix.exs` docs extras** — `sigra-auth-blueprint.md` was already added in Phase 65 (confirmed in `mix.exs` line 197); the two introduction guides need to follow.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Guide structure | Custom section layout | Copy `accrue-dunning-integration.md` section skeleton | The accrue guide is already the validated, contract-tested template |
| CI job YAML | Custom job structure | Copy `verify_accrue` job block | Proven pattern with postgres service, cache key, sibling checkout |
| Forbidden string detection | Custom regex matchers | Reuse `@recipe_forbidden_strings` module attribute | Already defined; new describe blocks just inherit it |
| Doc-contract describe block | New test file | Append to existing `doc_contract_test.exs` | Established convention; keeps all guide contracts co-located |
| Release gate parity checks | Manual verification | Update `release_gate_contract_test.exs` | The existing contract test is authoritative; updating it IS the gate |

---

## Common Pitfalls

### Pitfall 1: Forgetting to update `release_gate_contract_test.exs`

**What goes wrong:** MAINTAINING.md gets 10 commands, ci.yml gets 11 lanes, but `release_gate_contract_test.exs` still expects 8 commands and 9 lanes. The `ci.verify_gates` lane fails in CI.

**Why it happens:** The contract test is easy to miss because it lives in a test file, not the docs or workflow files. Implementers updating MAINTAINING.md and `ci.yml` may not realize the contract test validates them.

**How to avoid:** Treat `release_gate_contract_test.exs` as a required co-update with every MAINTAINING.md + ci.yml change. The planner should put all four files in a single task or wave.

**Warning signs:** `mix ci.verify_gates` fails locally after updating MAINTAINING.md.

### Pitfall 2: Using `config :chimeway` in `@required` without space matching

**What goes wrong:** The required string `"config :chimeway"` includes a space. If `~w()` sigil splits on whitespace, this becomes two tokens. D-04 lists `config :chimeway` as required string #3.

**How to avoid:** Escape the space or use a string list literal instead of `~w()` for multi-word required strings. Inspect how the accrue guide doc-contract handles `"config :accrue"` — at line 536 it is in the `@required ~w(...)` block, which works because `~w()` splits on whitespace... meaning `config :accrue` would appear as two separate tokens if naively added to `~w()`.

**Correct approach:** Add `"config :chimeway"` as a separate string in the list outside `~w()`, or use a list literal for the full `@required`. Looking at line 531 of `doc_contract_test.exs`, `config :accrue` is in the `@required ~w(...)` block — this appears to work because the test uses `String.contains?(content, required)` which checks for literal substring match, and `~w(config)` produces `"config"` not `"config :chimeway"`. The full string `"config :chimeway"` must be a quoted string in the list, not a `~w()` token. [VERIFIED: doc_contract_test.exs line 536 shows `config\ :accrue` with backslash-escaping the space — use the same pattern or a string list]

**Warning signs:** Doc-contract test passes when guide does not contain the config block.

### Pitfall 3: Wrong sibling checkout path in `mix verify.threadline` demo host step

**What goes wrong:** The demo host step uses `THREADLINE_PATH=../../../threadline` but the actual sibling layout differs, causing `deps.get` to fail to find the path dep.

**Why it happens:** The Accrue path layout in CI (`github.workspace/accrue/accrue`) uses a nested path because the repo is checked out with `path: accrue/accrue`. Threadline and Sigra will need matching nested paths. The `ACCRUE_PATH` in CI is `${{ github.workspace }}/accrue/accrue` — two levels. The path in the demo host alias uses `../../../accrue/accrue` (three `..` from `examples/chimeway_demo_host`). Mirror this convention.

**How to avoid:** Set `path: threadline/threadline` in the CI checkout step to get `${{ github.workspace }}/threadline/threadline`, and use `THREADLINE_PATH=../../../threadline/threadline` in the demo host alias step. Or use a flat path consistently. Confirm by looking at accrue: CI `path: accrue/accrue` → `ACCRUE_PATH: ${{ github.workspace }}/accrue/accrue` → demo host `ACCRUE_PATH=../../../accrue/accrue`.

**Warning signs:** `mix deps.get` in verify alias fails with "no such file or directory".

### Pitfall 4: `@sigra_forbidden` atom forms triggering on prose text

**What goes wrong:** If forbidden check uses plain string `"raw_token"` rather than atom form `":raw_token"`, legitimate prose like "avoid passing raw_token" in the guide would trigger the forbidden test.

**Why it happens:** D-05 specifies atom syntax (`:raw_token`, `:magic_link_url`) specifically so that prose references (without the colon) do not trigger false positives. Only code examples with wrong param keys fire the test.

**How to avoid:** Use `@sigra_forbidden ~w(:raw_token :magic_link_url)` — the colon is part of the token. The existing ECOS-10 blueprint doc-contract uses a slightly different approach (`"raw_token"` without colon) at line 381 — the new DOCS-11 test for the integration guide uses colon-prefixed form specifically because section 4 will contain "raw_token" in prose ("Do not pass `:raw_token`...").

**Warning signs:** Doc-contract test fails on the integration guide's section 4 where the anti-pattern statement contains the word "raw_token" in prose.

### Pitfall 5: `mix verify.accrue` demo host step env var interaction

**What goes wrong:** The demo host `mix.exs` sets `CHIMEWAY_SKIP_THREADLINE_DEP` / `CHIMEWAY_SKIP_SIGRA_DEP` to skip the optional dep when doing a cross-repo verify. Without `CHIMEWAY_SKIP_THREADLINE_DEP=1`, the demo host will try to resolve the threadline Hex dep and fail if the path dep is also set.

**How to avoid:** The verify alias demo host step must set `CHIMEWAY_SKIP_THREADLINE_DEP=1` (for threadline) or `CHIMEWAY_SKIP_SIGRA_DEP=1` (for sigra) alongside the `THREADLINE_PATH`/`SIGRA_PATH` env. This is already how `verify.accrue` handles it. [VERIFIED: `mix.exs` lines 136–165]

---

## Code Examples

### Threadline outcome table (section 3 content)

```markdown
| Lifecycle outcome | Threadline action atom | `correlation_id` |
|-------------------|----------------------|------------------|
| Notification suppressed | `:notification_suppressed` | forwarded from Chimeway trigger opts |
| Notification deferred | `:notification_deferred` | forwarded from Chimeway trigger opts |
| Notification dispatched | `:notification_dispatched` | forwarded from Chimeway trigger opts |
| Notification failed | `:notification_failed` | forwarded from Chimeway trigger opts |
```

The `correlation_id` callout:
> Pass `correlation_id:` in `Chimeway.trigger/3` opts to thread the audit row through to `Threadline.Query.timeline/2` strict filter. Without it, the Threadline timeline cannot isolate this notification's lifecycle in a multi-event trace.

[VERIFIED: Phase 63 CONTEXT.md D-05/D-07]

### Sigra auth event triggers section 4 anti-pattern note

```markdown
> **Do not pass** `:raw_token`, `:magic_link_url`, or `:confirmation_code` to `Chimeway.trigger/3`.
> Pass identifier-only params (`user_id`, `email`, opaque ref). Sensitive data resolves inside
> notifier `build/2` at dispatch time and is never written to `chimeway_events.payload`.
```

[VERIFIED: Phase 66 CONTEXT.md D-03, Phase 64 CONTEXT.md D-07]

### Sigra guide section 2 responsibility split language

```markdown
**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, and operator traces you can search at `/admin/chimeway`.

**Sigra owns auth state:** token generation, hashed persistence, rate limits, and magic link / confirmation code TTL. Sigra emits auth events; Chimeway does not mutate Sigra records.
```

[VERIFIED: Phase 64 CONTEXT.md D-01 and sigra-auth-blueprint.md responsibility split section]

### `release_gate_contract_test.exs` target state (key fields)

```elixir
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra)

@pre_ship_verify_commands [
  {"verify.example", "verify_example", "mix verify.example"},
  {"verify.journeys", "verify_journeys", "mix verify.journeys"},
  {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
  {"verify.accrue", "verify_accrue", "mix verify.accrue"},
  {"verify.inbox", "verify_inbox", "mix verify.inbox"},
  {"verify.threadline", "verify_threadline", "mix verify.threadline"},
  {"verify.sigra", "verify_sigra", "mix verify.sigra"}
]
```

The test "MAINTAINING documents eight-gate pre-ship requirement" regex must change from `~r/All eight must pass/i` to `~r/All ten must pass/i`. [VERIFIED: codebase inspection, `release_gate_contract_test.exs` line 45]

### MAINTAINING.md pre-ship section target state

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
mix verify.threadline
mix verify.sigra
```

The descriptive text below must change to "All ten must pass before publishing." and add descriptions for the two new commands. [VERIFIED: `MAINTAINING.md` lines 47–68]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual doc verification | Doc-contract ExUnit tests (`@required` / `@forbidden`) | Established in Phase 57 (DOCS-06/07) | Any guide regression fails CI via `verify_gates` lane |
| Ad-hoc verify scripts | Named Mix aliases (`mix verify.X`) | Established in v1.8 (GATE-04) | Maintainers have canonical pre-ship commands; CI mirrors them |
| `verify.accrue` as sole sibling-checkout gate | Two more sibling-checkout gates (`verify.threadline`, `verify.sigra`) | Phase 66 (GATE-07) | ci-gate grows from 9 to 11 lanes |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `szTheory/threadline` has a stable pinnable commit SHA for the integration ref used in Phase 63 | Code Examples — CI job template | CI job will fail if the ref doesn't exist; implementer must look up actual SHA from the Threadline repo |
| A2 | `szTheory/sigra` has a stable pinnable commit SHA for the integration ref used in Phase 64 | Code Examples — CI job template | Same as A1 for sigra |
| A3 | Sigra blueprint `sigra-auth-blueprint.md` already exists at `guides/recipes/sigra-auth-blueprint.md` (added in Phase 65) | Don't Hand-Roll / Standard Stack | Confirmed by `ls` of `guides/recipes/` directory |
| A4 | `threadline-integration.md` and `sigra-auth-integration.md` do NOT yet exist in `guides/introduction/` | Standard Stack | Confirmed by `ls` of `guides/introduction/` — neither file is present |
| A5 | The `verify.threadline` demo host step path structure mirrors `verify.accrue` exactly (nested `threadline/threadline`) | Code Examples — Mix alias | CI behavior depends on consistent path nesting; implementer must verify actual checkout path convention |

---

## Open Questions

1. **Sibling repo commit SHAs for threadline and sigra**
   - What we know: `verify_accrue` pins `236fa2f1649e771f3b515603495436badeed3c7b` for accrue. The equivalent is needed for threadline and sigra.
   - What's unclear: The actual SHAs for `szTheory/threadline` and `szTheory/sigra` at the integration-compatible refs.
   - Recommendation: Implementer checks out the sibling repos and runs `git log --oneline -1` to get the SHA, then substitutes it in the CI job. The plan should include a step to confirm and record these SHAs.

2. **Sigra forbidden string scope in DOCS-11**
   - What we know: D-05 specifies `@sigra_forbidden` as atom forms (`:raw_token`, `:magic_link_url`). The guide section 4 anti-pattern note will contain "`:raw_token`" (with backtick/colon) in prose.
   - What's unclear: Whether the guide text using `` `:raw_token` `` (Markdown inline code) passes or fails `String.contains?(content, ":raw_token")`.
   - Recommendation: Markdown inline code renders as `` `:raw_token` `` which contains the substring `:raw_token`. If the forbidden test checks for `:raw_token` as a substring, the guide's own anti-pattern note would fail the test. The implementer must ensure the guide only uses plain prose like "the raw token" and "raw_token" without the colon prefix in the "do not pass" statement, reserving the colon form for the explicit code example comment only. Or the test should use the `@recipe_forbidden_strings` pattern only for code-context detection (not prose). This needs careful phrasing alignment.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | All tasks | ✓ | 1.17 (from ci.yml) | — |
| ExUnit | Doc-contract tests | ✓ | built-in | — |
| Postgres | `verify.threadline` / `verify.sigra` CI jobs | ✓ (in CI services) | postgres:15 | — |
| `szTheory/threadline` repo | `verify_threadline` CI job | Assumed ✓ | pinned SHA TBD | — |
| `szTheory/sigra` repo | `verify_sigra` CI job | Assumed ✓ | pinned SHA TBD | — |

**Step 2.6: Environment Availability Audit** — This phase produces only docs, tests, and CI/tool config changes. All required runtime tools (Elixir, Mix, ExUnit, Postgres) are confirmed available in the existing CI environment. The sibling repos for threadline and sigra are assumed accessible on GitHub under `szTheory/` (consistent with the accrue pattern).

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir built-in) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix ci.verify_gates` |
| Full suite command | `mix ci` then `mix verify.threadline` and `mix verify.sigra` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-10 | Threadline guide exists with all required content | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 (guide file + describe block) |
| DOCS-10 | Sigra guide exists with all required content | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 (guide file + describe block) |
| DOCS-11 | Threadline describe block in `doc_contract_test.exs` | unit | `mix ci.verify_gates` | ❌ Wave 0 |
| DOCS-11 | Sigra describe block in `doc_contract_test.exs` | unit | `mix ci.verify_gates` | ❌ Wave 0 |
| GATE-07 | `verify.threadline` alias exercises threadline tests | integration | `mix verify.threadline` | ❌ Wave 0 (alias) |
| GATE-07 | `verify.sigra` alias exercises sigra tests | integration | `mix verify.sigra` | ❌ Wave 0 (alias) |
| GATE-07 | `verify_threadline` CI job in `ci.yml` | CI | GitHub Actions | ❌ Wave 0 |
| GATE-07 | `verify_sigra` CI job in `ci.yml` | CI | GitHub Actions | ❌ Wave 0 |
| GATE-07 | MAINTAINING.md lists 10 commands | doc-contract | `mix ci.verify_gates` | ❌ Wave 0 (MAINTAINING update + contract test update) |

### Sampling Rate
- **Per task commit:** `mix ci.verify_gates`
- **Per wave merge:** `mix ci` (lint + test suite including updated contract tests)
- **Phase gate:** `mix verify.threadline` and `mix verify.sigra` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `guides/introduction/threadline-integration.md` — covers DOCS-10 Threadline
- [ ] `guides/introduction/sigra-auth-integration.md` — covers DOCS-10 Sigra
- [ ] Two new `describe` blocks in `test/chimeway/doc_contract_test.exs` — covers DOCS-11
- [ ] Updated `release_gate_contract_test.exs` — covers GATE-07 release gate parity
- [ ] `verify.threadline` and `verify.sigra` aliases in `mix.exs` — covers GATE-07
- [ ] Two new guide paths in `mix.exs` docs extras — covers HexDocs discoverability
- [ ] `verify_threadline` and `verify_sigra` jobs in `ci.yml` — covers GATE-07 CI
- [ ] ci-gate `needs` expansion — covers GATE-07 ci-gate aggregation
- [ ] MAINTAINING.md pre-ship checklist update — covers GATE-07

---

## Security Domain

> Phase 66 produces only markdown guides, ExUnit test code, YAML CI config, and Mix alias config. No new authentication, session management, cryptography, or input validation code is introduced. The Sigra guide documents an anti-pattern (never pass sensitive tokens to Chimeway) but does not implement auth behavior.

**Applicable ASVS Categories:**

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No | — |
| V6 Cryptography | No | — |

**Redaction documentation (not implementation):** The Sigra integration guide section 4 documents the redaction anti-pattern. The actual enforcement (`sanitize_payload/1`, `@sensitive_keys` extension) was implemented in Phase 64. This phase only ensures the guide text makes the rule undeniable.

---

## Sources

### Primary (HIGH confidence)
- Codebase: `test/chimeway/doc_contract_test.exs` — full file read; all describe block patterns verified
- Codebase: `test/chimeway/release_gate_contract_test.exs` — full file read; current gate count and lane list verified
- Codebase: `mix.exs` — full file read; `verify.accrue` alias, `threadline_deps/0`, `sigra_deps/0`, `CHIMEWAY_SKIP_*` vars verified
- Codebase: `.github/workflows/ci.yml` — full file read; `verify_accrue` job structure, ci-gate needs list verified
- Codebase: `MAINTAINING.md` — full file read; current 8-command pre-ship checklist verified
- Codebase: `guides/introduction/accrue-dunning-integration.md` — full file read; section structure template verified
- Codebase: `examples/chimeway_demo_host/lib/demo_host/seeds.ex` — full file read; `seed_threadline_notification/0` and `seed_sigra_auth/0` verified
- Codebase: `examples/chimeway_demo_host/test/demo_host_web/threadline_telemetry_proof_test.exs` — full file read; `@moduletag :threadline` confirmed
- Codebase: `examples/chimeway_demo_host/test/demo_host_web/sigra_auth_proof_test.exs` — full file read; `@moduletag :sigra` confirmed

### Secondary (MEDIUM confidence)
- `.planning/phases/66-docs-release-gates/66-CONTEXT.md` — locked decisions D-01 through D-05; GATE-07 discretion items
- `.planning/phases/63-threadline-telemetry-bridge/63-CONTEXT.md` — ThreadlineReporter outcome atoms, attach pattern
- `.planning/phases/64-sigra-auth-flows-core/64-CONTEXT.md` — Sigra integration seam, redaction decisions
- `.planning/phases/65-ecosystem-blueprints-demo/65-CONTEXT.md` — Blueprint cross-link requirement (D-08)

### Tertiary (LOW confidence — flagged in Assumptions Log)
- Specific commit SHAs for `szTheory/threadline` and `szTheory/sigra` — not inspectable without sibling repo access

---

## Metadata

**Confidence breakdown:**
- Guide content and structure: HIGH — locked by CONTEXT.md decisions; templates from verified existing guides
- Doc-contract test structure: HIGH — verified directly from existing describe block patterns in `doc_contract_test.exs`
- Mix alias shape: HIGH — verified directly from `verify.accrue` in `mix.exs`
- CI job structure: HIGH — verified directly from `verify_accrue` job in `ci.yml`
- Release gate contract test changes: HIGH — verified directly from `release_gate_contract_test.exs`
- Sibling repo SHAs: LOW — not verifiable without repo access

**Research date:** 2026-05-30
**Valid until:** Stable (30+ days) — all patterns from established repo conventions; no fast-moving external dependencies
