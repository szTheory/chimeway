# Phase 79: Front Door and Docs IA - Pattern Map

**Mapped:** 2026-07-03
**Files analyzed:** 5 (2 docs source, 1 build config, 2 executable contract tests)
**Analogs found:** 5 / 5 (all in-repo; every analog is an existing sibling block the plan extends in place)

> This is a docs/IA rewrite proven by executable ExUnit contracts. There is no "new module"
> here — every file to touch already exists, and the closest analog is almost always **the very
> block being extended** (or its sibling describe block in the same file). The planner should
> **extend/mirror**, never reinvent. All required/forbidden strings are grep-verified in
> `79-RESEARCH.md`; this file supplies the concrete assertion idioms to copy.

## File Classification

| File to modify | Role | Data Flow | Closest Analog (in-repo) | Match Quality |
|----------------|------|-----------|--------------------------|---------------|
| `README.md` | docs source (public front door) | transform (rewrite content to satisfy string contract) | `guides/introduction/golden-path.md` (working DOCS-16 snippet chain) + current `README.md` (superset base) | exact (self + sibling doc) |
| `mix.exs` (`docs.extras`) | build config (HexDocs IA) | config list edit | `mix.exs` `docs/0` L225-262 (self) | exact |
| `guides/introduction/golden-path.md` | docs source (first-hop guide) | transform (URL string replace) | `README.md` L6 canonical badge URL; `@canonical_repo_url` in release gate | exact |
| `test/chimeway/doc_contract_test.exs` (README describe) | executable contract test | request-response (read file → assert String.contains?) | golden-path describe block L1179-1262 **in the same file** (sibling, richer superset of README block) | exact |
| `test/chimeway/release_gate_contract_test.exs` (unpacked describe) | executable contract test | file-I/O (build+unpack artifact → read packaged files → assert) | the same describe block's existing test L493-530 (extend in place) | exact |

## Pattern Assignments

### `test/chimeway/doc_contract_test.exs` — extend `describe "README install doc contract (GATE-01)"` (L1330-1391)

**Analog:** the sibling `describe "golden path doc contract (DOCS-01 / GATE-01)"` (L1179-1262) is the
**richer superset** of the README block — it already contains every assertion idiom D-09 needs
(the `@required` word list, the per-trigger invariant, the `identity:` guard). The README block is a
thinner copy of the same pattern. **Copy the missing idioms down from golden-path into the README block.**

**Idiom 1 — `@required` word-list + generated `for` loop of tests** (README block, L1367-1383). New
DOCS-14/15/16 markers get **appended to this exact list**. Note `~w()` splits on whitespace, so
multi-word markers (`## Non-goals`, `local-first`, phrase anchors) CANNOT go in `~w()` — add those as
a separate string-list attribute with its own `for` loop, mirroring `@storage_prefix_required_strings`
(L1102-1109 / applied at L1385-1390):

```elixir
# EXISTING (L1367-1383) — append single-token markers here (e.g. Chimeway.Traces.explain_delivery)
@required ~w(
  mix chimeway.gen.migrations
  Chimeway.trigger
  idempotency_key
  tenant_id
  golden-path
  guides/introduction/mailglass-integration.md
  guides/introduction/accrue-dunning-integration.md
  guides/introduction/inbox-integration.md
)

for required <- @required do
  test "requires #{required} in README", %{content: content} do
    assert String.contains?(content, unquote(required)),
           "README must reference #{unquote(required)}"
  end
end
```

For **multi-word phrase markers** (value-prop `local-first`, `## Non-goals` heading, host-boundary
`host-owned`, optional-surface `preview`), mirror the `@storage_prefix_required_strings` list idiom
(explicit string list + separate `for` loop), NOT `~w()`:

```elixir
# PATTERN TO MIRROR — @storage_prefix_required_strings (L1102-1109) + its loop (L1385-1390)
@storage_prefix_required_strings [
  "prefix: \"chimeway\"",
  "prefix: false",
  "new isolated Chimeway schema",
  ...
]

for required <- @storage_prefix_required_strings do
  test "requires storage prefix phrase #{required} in README", %{content: content} do
    assert String.contains?(content, unquote(required)),
           "README must reference #{unquote(required)}"
  end
end
```

**Idiom 2 — per-trigger invariant (copy VERBATIM from golden-path L1247-1261 into the README block):**

```elixir
test "every Chimeway.trigger example includes idempotency_key and tenant_id", %{
  content: content
} do
  triggers = Regex.scan(~r/Chimeway\.trigger\(/, content) |> length()
  idem = Regex.scan(~r/idempotency_key:/, content) |> length()
  tenant = Regex.scan(~r/tenant_id:/, content) |> length()

  assert triggers > 0

  assert triggers == idem,
         "expected idempotency_key on every trigger (got #{idem}/#{triggers})"

  assert triggers == tenant,
         "expected tenant_id on every trigger (got #{tenant}/#{triggers})"
end
```

**Idiom 3 — existing forbid guards (LEAVE IN PLACE, do not weaken).** The README `identity:` guard
(L1357-1360) is a **plain substring** match — unlike golden-path's negative-lookbehind (L1211).
This is the HIGH-RISK landmine (RESEARCH Pitfall 1): `recipient_identity:` would trip it. Keep README
snippets free of the `identity:` substring. If the planner adds a README guard for D-03 sibling
install claims (recommended, RESEARCH Wave-0 gap), mirror the `Chimeway.Workflow` regex-guard idiom:

```elixir
# EXISTING README identity: guard (L1357-1360) — plain substring, keep unchanged
test "forbids identity: in README", %{content: content} do
  refute String.contains?(content, "identity:"),
         "README must not reference identity:"
end

# EXISTING regex-forbid idiom to mirror for a new {:chimeway_admin, "~> 1.0"} guard (L1362-1365)
test "forbids Chimeway.Workflow module (not Workflows) in README", %{content: content} do
  refute Regex.match?(~r/Chimeway\.Workflow(?![s])/, content),
         "README must not reference fictional Chimeway.Workflow"
end
```

---

### `test/chimeway/release_gate_contract_test.exs` — extend `describe "unpacked Hex package artifact truth (...)"` (L466-531)

**Analog:** the existing test `"unpacked Hex package carries package truth docs and source links"`
(L493-530) **in the same block** — extend it (or add a sibling test in the block). Setup already
builds+unpacks the real prod package (`build_unpacked_package!/0`, L537-539) and exposes `root`.
Module attributes to reuse: `@readme` (L12), `@canonical_repo_url` (L14), `@legacy_repo_url` (L15).

**Idiom — read the packaged file from `root`, then assert String.contains? (L493-514):**

```elixir
test "unpacked Hex package carries package truth docs and source links", %{root: root} do
  mix_exs = File.read!(Path.join(root, @mix_exs))
  readme = File.read!(Path.join(root, @readme))
  ...
  refute String.contains?(readme, @legacy_repo_url),
         "unpacked README.md must not carry the legacy repository URL #{@legacy_repo_url}"

  assert String.contains?(readme, ~S({:chimeway, "~> 1.0"})),
         "unpacked README.md must carry the root install constraint {:chimeway, \"~> 1.0\"}"
```

**D-07 work:** after `readme = File.read!(Path.join(root, @readme))`, add `assert String.contains?(readme, ...)`
lines for the new DOCS-14/15/16 invariants (value-prop phrase, `## Non-goals` heading, host-boundary
phrase, optional-surface phrase, and `Chimeway.Traces.explain_delivery`). **Use the identical marker
strings chosen for the doc_contract README block** so the two contracts stay in lockstep — factor them
into a shared list if convenient, but at minimum keep them string-identical. The sibling-status phrases
already enforced on the packaged guides (`"in-repo preview/path package"`, `"not published on Hex yet"`,
L518-522) are the reference wording for the README Optional Surfaces section (RESEARCH "Don't Hand-Roll").

---

### `README.md` — rewrite as additive superset (DOCS-14/15/16)

**Analog:** `guides/introduction/golden-path.md` is the **working, contract-green** reference for the
DOCS-16 snippet chain. Copy the API shapes from there, NOT from memory. Current `README.md` (70 lines)
is the superset base — every existing section stays.

**DOCS-16 snippet chain to reproduce (source: golden-path.md, verified):**

```elixir
# Notifier stable key — notification_key/0 return value, NOT a trigger arg (golden-path L86-93)
def notification_key, do: "welcome_user"
def version, do: 1

# Trigger — both opts ALWAYS present; tenant_id required (golden-path L118-128; README L48-53 already correct)
{:ok, result} =
  Chimeway.trigger(
    MyApp.Notifiers.WelcomeUser,
    params,
    idempotency_key: "signup_user_12345",
    tenant_id: "default"
  )

# Prefix config (README L31-33 already correct)
config :chimeway, prefix: "chimeway"

# Trace lookup — Chimeway.Traces.explain_delivery/1, delivery_id from result.trace (golden-path L141-143)
[delivery_id | _] = result.trace.delivery_ids
{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)
```

**CRITICAL — do NOT copy golden-path's `recipients/1` callback (golden-path L96-98):** it contains
`recipient_identity:`, whose substring `identity:` trips the README plain-substring forbid
(doc_contract L1357). Show recipient wiring only in golden-path, never in README (RESEARCH Pitfall 1).

**Preserve every D-02 required string** (RESEARCH "Contract-Required Strings" table) and **the required
nav links** at README L57-63 (`golden-path`, `mailglass-integration.md`, `accrue-dunning-integration.md`,
`inbox-integration.md`). **DOCS-17 delink:** remove ONLY the `trigger-to-delivery.md` link (README L65).
Add the four new decision sections (When to use / Non-goals / Host-owned boundaries / Optional surfaces)
using the exact marker strings the two contract blocks will assert.

---

### `mix.exs` — delink 3 Flows stubs from `docs.extras` (DOCS-17 / D-05)

**Analog:** the `docs/0` extras list itself (L230-255). Surgical deletion only.

```elixir
# DELETE exactly these three lines (L241-243):
"guides/flows/trigger-to-delivery.md",
"guides/flows/policy-and-preferences.md",
"guides/flows/async-dispatch.md",
# KEEP L244 — multi-step-journeys.md is a REAL content-enforced guide (RESEARCH Pitfall 3):
"guides/flows/multi-step-journeys.md",
```

Leave the three stub **files on disk** (they are cross-linked from getting-started.md:97 and
password-reset-support-trace.md:103,122 — RESEARCH Pitfall 2). Delink = remove from README nav +
mix.exs extras only.

---

### `guides/introduction/golden-path.md` — fix stale legacy URLs (D-06)

**Analog:** the canonical URL already used in `README.md` L6 and pinned as `@canonical_repo_url`
(release_gate L14). Replace 4 occurrences (golden-path L167, L171, L191, L192):

```
https://github.com/jonlunsford/chimeway   →   https://github.com/szTheory/chimeway
```

**Guard gap (RESEARCH Pitfall 4 + Open Q1, recommended):** golden-path is NOT in
`@package_facing_source_files` (release_gate L16), so this fix is currently unguarded and can silently
regress. Recommended: add golden-path (ideally all first-hop guides) to a legacy-URL guard mirroring
the existing loop at release_gate L351-357:

```elixir
# EXISTING legacy-URL guard idiom to mirror (release_gate L351-357)
for file <- @package_facing_source_files do
  content = File.read!(file)
  refute String.contains?(content, @legacy_repo_url),
         "#{file} must not reference the legacy repository URL #{@legacy_repo_url}"
end
```

## Shared Patterns

### Contract assertion idiom (applies to BOTH test edits)
**Source:** `test/chimeway/doc_contract_test.exs` (throughout) + `release_gate_contract_test.exs` L493-530
**Apply to:** every new marker.
```elixir
# Required marker: read content in setup, then per-marker generated test
assert String.contains?(content, unquote(required)), "<file> must reference #{unquote(required)}"
# Forbidden marker:
refute String.contains?(content, unquote(forbidden)), "<file> must not reference #{unquote(forbidden)}"
```
`~w()` for single-token markers only; explicit `[ "multi word", ... ]` list for phrases/headings.

### Marker-string lockstep (D-07 ↔ D-09)
**Source:** the two contract blocks above.
**Apply to:** all new DOCS-14/15/16 markers. The same phrase must be asserted in BOTH the source-tree
README (doc_contract) AND the packaged README (release_gate). Keep the strings byte-identical.

### Canonical URL constant
**Source:** `release_gate_contract_test.exs` L14 `@canonical_repo_url "https://github.com/szTheory/chimeway"`
**Apply to:** golden-path URL fix + any new guard.

## No Analog Found

None. Every file in scope already exists and has an in-repo analog (usually the block being extended
or its sibling). No file requires falling back to RESEARCH.md-only patterns.

## Metadata

**Analog search scope:** `test/chimeway/` (contract tests), `mix.exs`, `README.md`, `guides/introduction/`
**Files scanned:** 5 (all reads targeted to verified line ranges from 79-RESEARCH.md; no whole-file loads of the >1500-line test files)
**Pattern extraction date:** 2026-07-03
