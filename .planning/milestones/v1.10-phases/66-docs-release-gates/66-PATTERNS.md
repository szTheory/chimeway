# Phase 66: Docs & Release Gates - Pattern Map

**Mapped:** 2026-05-30
**Files analyzed:** 8 new/modified files
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/introduction/threadline-integration.md` | doc | transform | `guides/introduction/accrue-dunning-integration.md` | exact |
| `guides/introduction/sigra-auth-integration.md` | doc | transform | `guides/introduction/accrue-dunning-integration.md` | exact |
| `test/chimeway/doc_contract_test.exs` | test | request-response | `test/chimeway/doc_contract_test.exs` lines 502–599 (DOCS-08/09 accrue block) | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | request-response | `test/chimeway/release_gate_contract_test.exs` (current file) | exact |
| `mix.exs` (verify aliases) | config | batch | `mix.exs` lines 113–118 (`verify.accrue` alias) | exact |
| `mix.exs` (docs extras) | config | transform | `mix.exs` lines 181–202 (`docs/0` extras list) | exact |
| `.github/workflows/ci.yml` (new jobs + ci-gate) | config | event-driven | `.github/workflows/ci.yml` lines 251–295 (`verify_accrue` job) | exact |
| `MAINTAINING.md` (pre-ship checklist) | doc | transform | `MAINTAINING.md` lines 46–72 (pre-ship section) | exact |

---

## Pattern Assignments

### `guides/introduction/threadline-integration.md` (doc, transform)

**Analog:** `guides/introduction/accrue-dunning-integration.md`

**Overall structure pattern** (full file, lines 1–159):
The guide opens with a one-paragraph intro linking to a blueprint, then a "## Responsibility split (SEED-003)" section, then numbered sections, then "## Related guides" footer. Threadline uses 4 sections (no migrations); the accrue guide uses 6.

**Intro + responsibility split pattern** (lines 1–13):
```markdown
# Accrue Dunning Integration

This guide is the canonical adoption path for composing Chimeway with [Accrue](...). Follow it when you want one credible vertical slice: add both libraries, configure..., inspect the workflow trace, and verify...

For copy-paste notifier and engine config sections, see the [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md). This guide owns the end-to-end path from dependency to verification.

## Responsibility split (SEED-003)

**Chimeway orchestrates the when and why:** durable notification lifecycle, workflow progression ..., suppression and preference gates, idempotency, Outcome Signal routing, and operator traces you can search at `/admin/chimeway`.

**Accrue owns billing state:** subscriptions, invoices, payment failure and recovery anchors, and dunning campaign timestamps on domain models. Accrue emits billing events; Chimeway does not mutate Accrue records.
```

**Dependencies section pattern** (lines 15–41):
```markdown
## 1. Dependencies

Add Chimeway and Accrue to your host `mix.exs`:

```elixir
def deps do
  [
    {:chimeway, "~> 1.0"},
    accrue_dep()
  ]
end

defp accrue_dep do
  case System.get_env("ACCRUE_PATH") do
    nil -> {:accrue, "~> 1.3", optional: true}
    path -> {:accrue, path: path, runtime: false}
  end
end
```

For local development and integration proof, check out the Accrue repo as a sibling and point `ACCRUE_PATH` at it...

```bash
ACCRUE_PATH=../accrue/accrue mix deps.get
```

Production adopters use `{:accrue, "~> 1.3"}` from Hex.
```

**Verification section pattern** (lines 126–157):
```markdown
## 6. Verification

After wiring dependencies and config, run the named proof command:

```bash
ACCRUE_PATH=../accrue/accrue mix verify.accrue --warnings-as-errors
```

This exercises ECOS-06 lifecycle proof at the Chimeway root and DEMO-07 demo host proof.

Seed the demo host dunning scenario:

```elixir
DemoHost.Seeds.seed_accrue_dunning/0
```

Then search `/admin/chimeway` by customer email (...) to inspect `accrue.dunning` workflow progression...
```

**Related guides footer pattern** (lines 153–159):
```markdown
## Related guides

- [Golden Path](golden-path.md) — Chimeway-only first integration
- [Accrue dunning blueprint](../recipes/accrue-dunning-blueprint.md) — focused notifier/engine recipe
- [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) — optional email delivery
- [Installation](installation.md) — Chimeway install and migration depth
```

**Threadline-specific content (from CONTEXT.md D-01):**
- Section 2 heading: "## 2. Attach reporter" (not "Runtime config")
- Section 3 heading: "## 3. What gets recorded" — 4-row outcome table (suppressed/deferred/dispatched/failed) + `correlation_id` callout
- Section 4 heading: "## 4. Verification" — seeds: `DemoHost.Seeds.seed_threadline_notification/0`, verify: `mix verify.threadline`
- Responsibility split: "Threadline owns audit ledger" not "billing state"
- No "## 2. Database / migrations" section

---

### `guides/introduction/sigra-auth-integration.md` (doc, transform)

**Analog:** `guides/introduction/accrue-dunning-integration.md`

Same structural template as Threadline guide. Sigra uses 5 sections (no migrations).

**Dependencies section variation** (adapt from lines 15–41 of accrue guide):
```markdown
## 1. Dependencies

defp sigra_dep do
  case System.get_env("SIGRA_PATH") do
    nil -> {:sigra, "~> 0.3", optional: true}
    path -> {:sigra, path: path, runtime: false}
  end
end
```
Local dev: `SIGRA_PATH=../sigra mix deps.get`

**Responsibility split language** (from RESEARCH.md Code Examples):
```markdown
**Chimeway orchestrates the when and why:** durable notification lifecycle, suppression and preference gates, idempotency, and operator traces you can search at `/admin/chimeway`.

**Sigra owns auth state:** token generation, hashed persistence, rate limits, and magic link / confirmation code TTL. Sigra emits auth events; Chimeway does not mutate Sigra records.
```

**Anti-pattern note in section 4** (from CONTEXT.md D-03, inline in "Auth event triggers"):
```markdown
> **Do not pass** `:raw_token`, `:magic_link_url`, or `:confirmation_code` to `Chimeway.trigger/3`.
> Pass identifier-only params (`user_id`, `email`, opaque ref). Sensitive data resolves inside
> notifier `build/2` at dispatch time and is never written to `chimeway_events.payload`.
```

**Verification section** (adapt from accrue guide lines 126–157):
```markdown
## 5. Verification

```bash
SIGRA_PATH=../sigra mix verify.sigra
```

```elixir
DemoHost.Seeds.seed_sigra_auth/0
```

Then search `/admin/chimeway` to inspect sigra auth workflow traces.
```

**Sigra-specific sections not in accrue template:**
- Section 2: "## 2. Integration seam" — `Sigra.Integrations.Chimeway` runtime config, conditional compile, responsibility split
- Section 3: "## 3. Notifier reference" — `sigra.auth.magic_link` and `sigra.auth.confirmation_code` stable keys; `build/2` resolves at dispatch time
- Section 4: "## 4. Auth event triggers" — `Chimeway.trigger/3` with `idempotency_key` + `tenant_id`; inline redaction note

---

### `test/chimeway/doc_contract_test.exs` — two new `describe` blocks (test, request-response)

**Analog:** `test/chimeway/doc_contract_test.exs` lines 502–599 (DOCS-08/09 accrue integration guide block)

**Module-level file path attribute pattern** (lines 502, 428):
```elixir
@accrue_integration_guide Path.expand("../../guides/introduction/accrue-dunning-integration.md", __DIR__)
# New:
@threadline_integration_guide Path.expand("../../guides/introduction/threadline-integration.md", __DIR__)
@sigra_integration_guide Path.expand("../../guides/introduction/sigra-auth-integration.md", __DIR__)
```

**Full describe block structure pattern** (lines 504–599):
```elixir
describe "accrue dunning integration guide doc contract (DOCS-08 / DOCS-09)" do
  setup do
    content = File.read!(@accrue_integration_guide)
    %{content: content}
  end

  for forbidden <- @recipe_forbidden_strings do
    test "forbids #{forbidden} in accrue dunning integration guide", %{content: content} do
      refute String.contains?(content, unquote(forbidden)),
             "accrue dunning integration guide must not reference #{unquote(forbidden)}"
    end
  end

  test "forbids Chimeway.Workflow module (not Workflows) in accrue dunning integration guide",
       %{content: content} do
    refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
           "accrue dunning integration guide must not reference fictional Chimeway.Workflow"
  end

  @required ~w(
    Accrue.Integrations.Chimeway
    invoice.payment_failed
    invoice.paid
    cancel_campaign
    Chimeway.Signal.track
    workflow/2
    config\ :accrue
    dunning
    idempotency_key
    tenant_id
    orchestrates
    mix\ verify.accrue
    DemoHost.Seeds.seed_accrue_dunning
    /admin/chimeway
    ACCRUE_PATH
  )

  for required <- @required do
    test "requires #{required} in accrue dunning integration guide", %{content: content} do
      assert String.contains?(content, unquote(required)),
             "accrue dunning integration guide must reference #{unquote(required)}"
    end
  end

  test "sections appear in golden-path order from dependencies through verification", %{
    content: content
  } do
    headings = [
      "## 1. Dependencies",
      "## 2. Database / migrations",
      ...
    ]
    indices = Enum.map(headings, fn heading -> ... end)
    assert indices == Enum.sort(indices), "..."
  end
end
```

**`@recipe_forbidden_strings` module attribute** (lines 104–108):
```elixir
@recipe_forbidden_strings ~w(
  stop_conditions
  Workflows.Workers
  Chimeway.Trigger.trigger
)
```
New describe blocks inherit this — no redeclaration needed.

**Space-escaping in `~w()` for multi-word required strings** (line 535–536 pattern):
```elixir
config\ :accrue    # backslash-escaped space keeps it as one token in ~w()
mix\ verify.accrue # same pattern
```
Apply: `config\ :chimeway`, `mix\ verify.threadline`, `mix\ verify.sigra`

**Threadline describe block `@required`** (D-04):
```elixir
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
```

**Sigra describe block additions** (D-05) — `@sigra_forbidden` atom forms:
```elixir
@sigra_forbidden ~w(:raw_token :magic_link_url)

for forbidden <- @sigra_forbidden do
  test "forbids #{forbidden} in sigra auth integration guide", %{content: content} do
    refute String.contains?(content, unquote(forbidden)),
           "sigra auth integration guide must not reference #{unquote(forbidden)} in code examples"
  end
end
```
(Pattern from ECOS-10 sigra blueprint describe block at lines 381–389, which uses standalone tests; the atom-form `~w()` loop is the new DOCS-11 pattern per D-05.)

**Sigra describe block `@required`** (D-05):
```elixir
@required ~w(
  Sigra.Integrations.Chimeway
  sigra.auth.magic_link
  sigra.auth.confirmation_code
  Chimeway.trigger
  idempotency_key
  tenant_id
  DemoHost.Seeds.seed_sigra
  /admin/chimeway
  mix\ verify.sigra
  SIGRA_PATH
  orchestrates
)
```

**Hexdocs extras test block** (lines 908–963) — must also gain two ordering tests matching the `inbox_index < threadline_index` pattern. The `@integration_guides` list at line 914 gains the two new paths.

---

### `test/chimeway/release_gate_contract_test.exs` (test, request-response)

**Analog:** `test/chimeway/release_gate_contract_test.exs` (the current file itself — update-in-place)

**Module-level attributes to update** (lines 12–20):

Current `@ci_gate_lanes` (line 12):
```elixir
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox)
```
Target (add two entries, 11 total):
```elixir
@ci_gate_lanes ~w(lint test verify_gates verify_docs verify_example verify_journeys verify_mailglass verify_accrue verify_inbox verify_threadline verify_sigra)
```

Current `@pre_ship_verify_commands` (lines 14–20):
```elixir
@pre_ship_verify_commands [
  {"verify.example", "verify_example", "mix verify.example"},
  {"verify.journeys", "verify_journeys", "mix verify.journeys"},
  {"verify.mailglass", "verify_mailglass", "mix verify.mailglass"},
  {"verify.accrue", "verify_accrue", "mix verify.accrue"},
  {"verify.inbox", "verify_inbox", "mix verify.inbox"}
]
```
Target (add two tuples):
```elixir
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

**Test to update** (line 44–47):
```elixir
# Current:
test "MAINTAINING documents eight-gate pre-ship requirement", %{maintaining: maintaining} do
  assert Regex.match?(~r/All eight must pass/i, maintaining),
         "MAINTAINING.md must state all eight verify gates must pass before publishing"
end
# Target:
test "MAINTAINING documents ten-gate pre-ship requirement", %{maintaining: maintaining} do
  assert Regex.match?(~r/All ten must pass/i, maintaining),
         "MAINTAINING.md must state all ten verify gates must pass before publishing"
end
```

**Test to update** (line 112–118):
```elixir
# Current:
test "ci-gate aggregates 9 required lanes", %{ci_yml: ci_yml} do
# Target:
test "ci-gate aggregates 11 required lanes", %{ci_yml: ci_yml} do
```

**New sibling-checkout tests to add** (mirror line 73–84 `verify_accrue` sibling checkout test):
```elixir
test "verify_threadline job checks out szTheory/threadline with THREADLINE_PATH", %{ci_yml: ci_yml} do
  job_block = extract_ci_job_block(ci_yml, "verify_threadline")
  assert String.contains?(job_block, "szTheory/threadline"), "..."
  assert String.contains?(job_block, "THREADLINE_PATH"), "..."
end

test "verify_sigra job checks out szTheory/sigra with SIGRA_PATH", %{ci_yml: ci_yml} do
  job_block = extract_ci_job_block(ci_yml, "verify_sigra")
  assert String.contains?(job_block, "szTheory/sigra"), "..."
  assert String.contains?(job_block, "SIGRA_PATH"), "..."
end
```

---

### `mix.exs` — verify aliases (config, batch)

**Analog:** `mix.exs` lines 113–118 (`verify.accrue` alias)

**Current `verify.accrue` pattern** (lines 113–118):
```elixir
"verify.accrue": [
  "deps.compile accrue --force",
  "cmd env MIX_ENV=test mix test --only accrue --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix deps.compile accrue --force && env CHIMEWAY_SKIP_ACCRUE_DEP=1 ACCRUE_PATH=../../../accrue/accrue CHIMEWAY_PATH=../.. mix test --only accrue --warnings-as-errors"
],
```

**New `verify.threadline` alias** (copy-adapt, swap `accrue` → `threadline`, `ACCRUE` → `THREADLINE`):
```elixir
"verify.threadline": [
  "deps.compile threadline --force",
  "cmd env MIX_ENV=test mix test --only threadline --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline/threadline CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline/threadline CHIMEWAY_PATH=../.. mix deps.compile threadline --force && env CHIMEWAY_SKIP_THREADLINE_DEP=1 THREADLINE_PATH=../../../threadline/threadline CHIMEWAY_PATH=../.. mix test --only threadline --warnings-as-errors"
],
```

**New `verify.sigra` alias** (copy-adapt, swap `accrue` → `sigra`, `ACCRUE` → `SIGRA`):
```elixir
"verify.sigra": [
  "deps.compile sigra --force",
  "cmd env MIX_ENV=test mix test --only sigra --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra CHIMEWAY_PATH=../.. mix deps.get && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra CHIMEWAY_PATH=../.. mix deps.compile sigra --force && env CHIMEWAY_SKIP_SIGRA_DEP=1 SIGRA_PATH=../../../sigra/sigra CHIMEWAY_PATH=../.. mix test --only sigra --warnings-as-errors"
]
```

Note: path nesting convention is `threadline/threadline` and `sigra/sigra` (nested) to mirror `accrue/accrue` — confirmed by CI job `path: accrue/accrue` at ci.yml line 276.

**Placement:** Insert after `verify.inbox` (line 124) before the closing `]` of `aliases/0`.

---

### `mix.exs` — docs extras (config, transform)

**Analog:** `mix.exs` lines 181–202 (`docs/0` function, `extras:` list)

**Current extras list tail** (lines 183–202):
```elixir
extras: [
  "guides/introduction/getting-started.md",
  "guides/introduction/installation.md",
  "guides/introduction/golden-path.md",
  "guides/introduction/mailglass-integration.md",
  "guides/introduction/accrue-dunning-integration.md",
  "guides/introduction/inbox-integration.md",   # <-- insert after this
  ...
]
```

**New entries to insert** (after `inbox-integration.md`, line 188):
```elixir
"guides/introduction/threadline-integration.md",
"guides/introduction/sigra-auth-integration.md",
```

---

### `.github/workflows/ci.yml` — new CI jobs (config, event-driven)

**Analog:** `.github/workflows/ci.yml` lines 251–295 (`verify_accrue` job)

**Full `verify_accrue` job pattern** (lines 251–295):
```yaml
verify_accrue:
  name: Accrue dunning integration gate
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
    ACCRUE_PATH: ${{ github.workspace }}/accrue/accrue
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        repository: szTheory/accrue
        ref: 236fa2f1649e771f3b515603495436badeed3c7b
        path: accrue/accrue
    - uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
      with:
        elixir-version: "1.17"
        otp-version: "27"
    - uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
      with:
        path: |
          deps
          _build
        key: ${{ runner.os }}-mix-verify-accrue-${{ hashFiles('**/mix.lock') }}
        restore-keys: |
          ${{ runner.os }}-mix-verify-accrue-
    - run: |
        mix local.rebar --force
        mix local.hex --force
        mix deps.get
    - run: mix ecto.create --quiet
    - run: mix ecto.migrate --quiet
    - run: mix verify.accrue
```

**New `verify_threadline` job** (copy-adapt, all `accrue` → `threadline`, `ACCRUE` → `THREADLINE`, SHA is TBD — implementer must supply from `szTheory/threadline`):
```yaml
verify_threadline:
  name: Threadline telemetry gate
  # ... same postgres service block ...
  env:
    MIX_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost/chimeway_test
    THREADLINE_PATH: ${{ github.workspace }}/threadline/threadline
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        repository: szTheory/threadline
        ref: <THREADLINE_INTEGRATION_SHA>    # implementer must look up
        path: threadline/threadline
    # ... same setup-beam, cache, deps.get, ecto steps ...
    - run: mix verify.threadline
```

**New `verify_sigra` job** (same pattern, `sigra`):
```yaml
verify_sigra:
  name: Sigra auth integration gate
  env:
    SIGRA_PATH: ${{ github.workspace }}/sigra/sigra
  steps:
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      with:
        repository: szTheory/sigra
        ref: <SIGRA_INTEGRATION_SHA>    # implementer must look up
        path: sigra/sigra
    # ... same steps ...
    - run: mix verify.sigra
```

**ci-gate `needs` update** (line 386):
```yaml
# Current (9 entries):
needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox]

# Target (11 entries):
needs: [lint, test, verify_gates, verify_docs, verify_example, verify_journeys, verify_mailglass, verify_accrue, verify_inbox, verify_threadline, verify_sigra]
```

**ci-gate `env:` block update** (lines 391–399 — add two new env vars):
```yaml
VERIFY_THREADLINE: ${{ needs.verify_threadline.result }}
VERIFY_SIGRA: ${{ needs.verify_sigra.result }}
```

**ci-gate `for lane in ...` loop update** (line 403 — add two new lanes):
```bash
for lane in LINT TEST VERIFY_GATES VERIFY_DOCS VERIFY_EXAMPLE VERIFY_JOURNEYS VERIFY_MAILGLASS VERIFY_ACCRUE VERIFY_INBOX VERIFY_THREADLINE VERIFY_SIGRA; do
```

---

### `MAINTAINING.md` — pre-ship checklist (doc, transform)

**Analog:** `MAINTAINING.md` lines 46–72 (current pre-ship section)

**Current pre-ship section** (lines 46–72):
```markdown
### Pre-ship local commands

Run all eight before opening or merging release-related changes:

```bash
mix ci
mix ci.docs
mix ci.verify_gates
mix verify.example
mix verify.journeys
mix verify.mailglass
mix verify.accrue
mix verify.inbox
```

- `mix ci` — lint + full test suite
- `mix ci.docs` — HexDocs build with warnings-as-errors
- `mix ci.verify_gates` — adoption-surface doc-contract and release gate parity (GATE-01 + GATE-06)
- `mix verify.example` — demo host webhook E2E + chimeway_admin operator smoke
- `mix verify.journeys` — TeamPulse consumer journey proof ...
- `mix verify.mailglass` — Mailglass integration gate (GATE-04): ...
- `mix verify.accrue` — Accrue dunning integration gate (GATE-05 Accrue): ... requires sibling Accrue checkout — set `ACCRUE_PATH=../accrue/accrue` locally
- `mix verify.inbox` — Inbox integration gate (GATE-05 Inbox): ...

All eight must pass before publishing.
```

**Target changes:**
1. "Run all eight" → "Run all ten"
2. Add `mix verify.threadline` and `mix verify.sigra` to the bash block (after `mix verify.inbox`)
3. "All eight must pass" → "All ten must pass"
4. Add bullet descriptions for the two new commands (mirror `verify.accrue` style with sibling checkout note)
5. Update the sibling checkout subsection (lines 74–76) to cover threadline and sigra alongside accrue

---

## Shared Patterns

### Forbidden string detection
**Source:** `test/chimeway/doc_contract_test.exs` lines 104–108
**Apply to:** Both new describe blocks in `doc_contract_test.exs`
```elixir
@recipe_forbidden_strings ~w(
  stop_conditions
  Workflows.Workers
  Chimeway.Trigger.trigger
)
```
Both new describe blocks inherit this via `for forbidden <- @recipe_forbidden_strings`. No redeclaration.

### `Chimeway.Workflow` regex forbidden test
**Source:** `test/chimeway/doc_contract_test.exs` lines 517–520
**Apply to:** Both new describe blocks
```elixir
test "forbids Chimeway.Workflow module (not Workflows) in [guide name]", %{content: content} do
  refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
         "[guide name] must not reference fictional Chimeway.Workflow"
end
```

### Sibling-checkout env var pair in verify aliases
**Source:** `mix.exs` lines 115–118 (`verify.accrue` demo host step)
**Apply to:** `verify.threadline` and `verify.sigra` aliases
Pattern: `CHIMEWAY_SKIP_X_DEP=1 X_PATH=../../../x/x CHIMEWAY_PATH=../..` — all three env vars must appear together in the demo host step.

### Postgres service block in CI jobs
**Source:** `.github/workflows/ci.yml` lines 253–265
**Apply to:** Both new CI jobs (`verify_threadline`, `verify_sigra`)
```yaml
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
```

### CI job steps boilerplate
**Source:** `.github/workflows/ci.yml` lines 277–295
**Apply to:** Both new CI jobs
```yaml
- uses: erlef/setup-beam@8251c48667b97e88a0a24ec512f5b72a039fcea7
  with:
    elixir-version: "1.17"
    otp-version: "27"
- uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-mix-verify-{NAME}-${{ hashFiles('**/mix.lock') }}
    restore-keys: |
      ${{ runner.os }}-mix-verify-{NAME}-
- run: |
    mix local.rebar --force
    mix local.hex --force
    mix deps.get
- run: mix ecto.create --quiet
- run: mix ecto.migrate --quiet
```

---

## No Analog Found

None — all 8 files have direct analogs within the codebase.

---

## Critical Implementation Notes

1. **Sibling repo SHAs are TBD.** The `verify_threadline` and `verify_sigra` CI jobs need pinned `ref:` SHAs for `szTheory/threadline` and `szTheory/sigra`. Implementer must run `git log --oneline -1` on those repos and substitute the actual SHA. Placeholder token in PATTERNS.md: `<THREADLINE_INTEGRATION_SHA>` and `<SIGRA_INTEGRATION_SHA>`.

2. **Path nesting convention.** Accrue uses `path: accrue/accrue` (nested), producing `${{ github.workspace }}/accrue/accrue`. Threadline and Sigra must use `path: threadline/threadline` and `path: sigra/sigra` respectively, matching the demo host alias paths `THREADLINE_PATH=../../../threadline/threadline` and `SIGRA_PATH=../../../sigra/sigra`.

3. **`release_gate_contract_test.exs` is a required co-update.** The test currently asserts "All eight must pass" (line 44) and "ci-gate aggregates 9 required lanes" (line 112). Both must change alongside MAINTAINING.md and ci.yml or `mix ci.verify_gates` fails.

4. **Atom-form forbidden strings and prose safety.** `@sigra_forbidden ~w(:raw_token :magic_link_url)` uses the colon prefix so prose references like "raw token" (no colon) do not trigger false positives. The guide's anti-pattern note should use prose form "raw token" / "magic link URL" without backtick-colon formatting, reserving `:raw_token` atom syntax only for code comment examples (which the integration guide should not include per D-03).

5. **`config\ :chimeway` space escaping.** In `~w()` sigil, backslash-escape the space: `config\ :chimeway` and `mix\ verify.threadline` / `mix\ verify.sigra`. This matches the existing `config\ :accrue` pattern at doc_contract_test.exs line 535.

---

## Metadata

**Analog search scope:** `guides/introduction/`, `test/chimeway/`, `mix.exs`, `.github/workflows/ci.yml`, `MAINTAINING.md`
**Files scanned:** 8 analog files read in full
**Pattern extraction date:** 2026-05-30
