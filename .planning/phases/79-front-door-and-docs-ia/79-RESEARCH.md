# Phase 79: Front Door and Docs IA - Research

**Researched:** 2026-07-03
**Domain:** Public documentation / information architecture rewrite enforced by executable ExUnit doc-truth contracts (Elixir / Hex library)
**Confidence:** HIGH (every claim grounded against live code read this session)

## Summary

Phase 79 is a documentation and information-architecture rewrite, not a new integration. The
codebase already treats docs/release truth as executable ExUnit contracts, so the "how to build
it" question is really "which existing contract blocks to extend, which exact marker strings to
preserve, and which forbidden strings to avoid." The CONTEXT.md did deep analysis; this research
**verifies every one of its load-bearing claims against the live source** (file:line cited) and
surfaces the landmines the planner must design around.

All four public-API claims in D-04 are confirmed: `Chimeway.trigger/3` exists and requires
`tenant_id`; there is **no** `Chimeway.explain_delivery` delegate (trace lookups live on
`Chimeway.Traces.explain_delivery/1,2`); the notifier `notification_key/0` + `version/0` callback
pattern is a real behaviour. All three insertion points in D-07/D-09 exist at the stated line
ranges with the stated assertion style. The three Flows stubs are confirmed 9 lines each and
**not content-enforced by any contract**, so delinking them breaks nothing.

**Primary recommendation:** Rewrite `README.md` as an additive superset that (1) preserves every
string already required by the "README install doc contract" block, (2) adds the four decision
sections and the DOCS-16 snippet chain, and (3) **never introduces the substring `identity:`** —
because the README forbid guard is a plain `String.contains?`, not the negative-lookbehind regex
golden-path uses, so `recipient_identity:` would fail the gate. Extend the three named contract
blocks in place; do not create a new test file.

## Architectural Responsibility Map

This is a docs/IA phase; "tiers" map to documentation-truth surfaces rather than runtime tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| README decision-page content (DOCS-14/15) | Public docs (`README.md`) | HexDocs extras (`mix.exs`) | README is the first hop; HexDocs mirrors it |
| Canonical adoption snippets (DOCS-16) | Public docs (`README.md`) | Golden-path guide (already correct) | Snippets must match the real `lib/` API surface |
| Stub/stale guide disposition (DOCS-17) | HexDocs IA (`mix.exs docs.extras`) + `README.md` nav | In-repo guide cross-links | Delink from first-hop nav; keep files on disk |
| Packaged-doc truth (ADPT-01) | Release contract (`release_gate_contract_test.exs`) | `mix hex.build --unpack` artifact | Proves the public story survives packaging |
| Contract enforcement (D-09) | `doc_contract_test.exs` | `mix ci.verify_gates` lane | Docs truth is an executable ExUnit contract here |

## Standard Stack

No new libraries. This phase edits Markdown, `mix.exs`, and two existing ExUnit contract files.

### Core (existing, reused)
| Tool | Where | Purpose | Why Standard |
|------|-------|---------|--------------|
| ExUnit doc contracts | `test/chimeway/doc_contract_test.exs` | String-assertion truth over first-hop docs | Project convention: docs truth = executable contract [VERIFIED: doc_contract_test.exs:1330-1391] |
| ExUnit release contracts | `test/chimeway/release_gate_contract_test.exs` | Unpacked-Hex artifact truth | Runs `mix hex.build --unpack` under prod [VERIFIED: release_gate_contract_test.exs:466-531] |
| `mix hex.build --unpack` | `build_unpacked_package!/0` | Produces the packaged artifact under `MIX_ENV=prod` | Already the ADPT-01 shape [VERIFIED: release_gate_contract_test.exs:533-539] |
| `mix ci.verify_gates` | CI release-blocking lane | Runs the doc/release contracts | Release source of truth (per CONTEXT + Phase 78) [ASSUMED: named as the blocking lane in CONTEXT] |

**Installation:** none. `Package Legitimacy Audit` is N/A — this phase installs no external packages.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOCS-14 | README leads with local-first embedded notification value prop + explainability promise | Rewrite README additively (D-01); add value-prop marker to README contract (D-09). Current README lead is thin/generic [VERIFIED: README.md:1-3] |
| DOCS-15 | README states use cases, non-goals, host-owned boundaries, optional surface status | Add four decision sections (D-01); add non-goals/host-boundary/optional-surface markers to README contract [VERIFIED: README.md has none of these today:1-70] |
| DOCS-16 | Public snippets show stable notification key, `tenant_id`, `idempotency_key`, storage prefix, trace lookup | Real API confirmed below; golden-path is the working reference snippet chain [VERIFIED: golden-path.md:90,93,122,143] |
| DOCS-17 | Stub/stale guides completed or removed from primary paths | Delink 3 Flows stubs (not contract-enforced); fix stale `jonlunsford` URLs in golden-path [VERIFIED: stubs 9 lines each, zero test refs; golden-path.md:167,171,191,192] |
| ADPT-01 | Fresh-host/unpacked-Hex smoke path proves the public story | Extend the unpacked-artifact `describe` block [VERIFIED: release_gate_contract_test.exs:466-531] |

## API Surface Verification (DOCS-16 ground truth)

Every snippet the rewritten README shows must match this surface exactly.

### 1. Notifier callback pattern — the stable notification key
- `@callback notification_key() :: String.t()` [VERIFIED: lib/chimeway/notifier.ex:47]
- `@callback version() :: pos_integer()` [VERIFIED: lib/chimeway/notifier.ex:48]
- Working example in golden-path: `def notification_key, do: "welcome_user"` and `def version, do: 1` [VERIFIED: guides/introduction/golden-path.md:90,93]
- **Show the stable key as the notifier's `notification_key/0` return value** (e.g. `"welcome_user"`), never as a raw string argument to `trigger`.

### 2. `Chimeway.trigger/3` — requires `tenant_id`
- `def trigger(notifier, params, opts \\ [])` delegates to `Trigger.trigger/3` [VERIFIED: lib/chimeway.ex:15-17]
- Missing `tenant_id` → `{:error, :missing_tenant_id}` [VERIFIED: lib/chimeway/trigger.ex:140-143]
- Empty/non-binary `tenant_id` → `{:error, :invalid_tenant_id}` [VERIFIED: lib/chimeway/trigger.ex:147-155]
- Canonical call shape: `Chimeway.trigger(Notifier, params, idempotency_key: ..., tenant_id: ...)` — **both opts always present** [VERIFIED: golden-path.md:122; README.md:48-53 already shows this]

### 3. Storage prefix config
- `config :chimeway, prefix: "chimeway"` for new isolated schema; `prefix: false` for legacy public-schema [VERIFIED: README.md:31-33,38-40]

### 4. Trace/explainability lookup — NOT on `Chimeway`
- **There is no `Chimeway.explain_delivery` delegate.** The full `Chimeway` module exposes only `trigger`, `preview_rendering`, `recover_event`, `recover_delivery`, `admin_*`, `list_for_recipient`, `unread_count`, `mark_seen`, `mark_read`, `archive` [VERIFIED: lib/chimeway.ex:1-131 — no `explain_delivery`, no trace delegate]
- Trace lookups live on `Chimeway.Traces`:
  - `explain_delivery(delivery_id, opts \\ [])` → arities /1 and /2 [VERIFIED: lib/chimeway/traces.ex:135]
  - `get_trace/2` [VERIFIED: traces.ex:46], `find_traces_for_recipient/2` [VERIFIED: traces.ex:69], `find_traces_by_correlation_id/2` [VERIFIED: traces.ex:104]
- `delivery_id` is sourced from the trigger result trace; golden-path shows the pattern:
  `{:ok, explanation} = Chimeway.Traces.explain_delivery(delivery_id)` and
  `{:ok, event} = Chimeway.Traces.get_trace(result.trace.event_id)` [VERIFIED: golden-path.md:143,157]

## Architecture Patterns

### Contract-extension pattern (the whole phase in one sentence)
Docs are edited to satisfy new string assertions added to existing `describe` blocks; the assertion
loop pattern is `for marker <- @list, do: test(...) assert/refute String.contains?(content, marker)`.
Extend the `@required` / `@storage_prefix_required_strings` module attributes and the per-block
tests — **do not create a new test file** (D-09).

### The three exact insertion points (all verified present)

**A. README install doc contract** — `test/chimeway/doc_contract_test.exs` describe `"README install doc contract (GATE-01)"` [VERIFIED: L1330-1391]
- Reads `README.md` in setup [L1332]
- Current required markers (`@required` at L1367-1376): `mix chimeway.gen.migrations`, `Chimeway.trigger`, `idempotency_key`, `tenant_id`, `golden-path`, `guides/introduction/mailglass-integration.md`, `guides/introduction/accrue-dunning-integration.md`, `guides/introduction/inbox-integration.md`
- Plus `@storage_prefix_required_strings` applied to README [L1385-1390]
- Forbid guards on README: `@adoption_forbidden_strings` [L1336], `@adoption_forbidden_phrases_readme` [L1343], `@storage_prefix_forbidden_phrases` [L1350], plain `identity:` substring [L1357-1360], `Chimeway.Workflow` (no trailing `s`) regex [L1362-1365]
- **D-09 work:** add new required markers (value-prop phrase, non-goals heading, host-boundary phrase, optional/preview-surface phrase, `Chimeway.Traces.explain_delivery`) and add a per-trigger `idempotency_key`/`tenant_id` invariant test mirroring pattern B.

**B. Golden-path per-trigger invariant** — same file, describe `"golden path doc contract"` [VERIFIED: L1247-1261]
```elixir
test "every Chimeway.trigger example includes idempotency_key and tenant_id", %{content: content} do
  triggers = Regex.scan(~r/Chimeway\.trigger\(/, content) |> length()
  idem = Regex.scan(~r/idempotency_key:/, content) |> length()
  tenant = Regex.scan(~r/tenant_id:/, content) |> length()
  assert triggers > 0
  assert triggers == idem, "expected idempotency_key on every trigger (got #{idem}/#{triggers})"
  assert triggers == tenant, "expected tenant_id on every trigger (got #{tenant}/#{triggers})"
end
```
Reuse this exact counting shape against `README.md` content for the D-09 README invariant.

**C. Unpacked Hex package artifact truth** — `test/chimeway/release_gate_contract_test.exs` describe `"unpacked Hex package artifact truth (TRUTH-01/TRUTH-02/TRUTH-03, D-08)"` [VERIFIED: L466-531]
- `setup` calls `build_unpacked_package!/0` (`mix hex.build --unpack` under prod) [L468, L533-539]
- Test `"unpacked Hex package carries package truth docs and source links"` reads packaged `README.md` and the admin/inbox guides and asserts install constraint + sibling status + absence of legacy URL [L493-530]
- **D-07 work:** add assertions (or a sibling test in this block) that the *packaged* README carries the new DOCS-14/15/16 invariants (value prop, non-goals, host boundary, optional-surface status) and the `Chimeway.Traces.explain_delivery` trace snippet.

### System diagram: what a README edit must keep green

```
                 ┌────────────────────────── README.md (rewrite target) ──────────────────────────┐
 edit README ───▶│ value-prop lead │ 4 decision sections │ DOCS-16 snippet chain │ preserved markers │
                 └───────┬─────────────────────┬───────────────────────┬────────────────────┬───────┘
                         │                      │                       │                    │
              (A) doc_contract_test      (C) release_gate:        preserve D-02          keep req'd links:
              README describe            unpacked README          required strings       mailglass/accrue/
              +new markers (D-09)        +new markers (D-07)      + avoid forbidden      inbox intro guides
                         │                      │                       │                    │
                         └──────────────────────┴───────────┬───────────┴────────────────────┘
                                                             ▼
                                                   mix ci.verify_gates  ── release-blocking lane
```

## Contract-Required Strings (D-02) — grep-verified

Every string below is asserted by a live test. The rewrite MUST preserve all of them in `README.md`.

| Required string | Guarding test | Source of truth |
|-----------------|---------------|-----------------|
| `mix chimeway.gen.migrations` | README `@required` | [VERIFIED: doc_contract_test.exs:1368] |
| `Chimeway.trigger` | README `@required` | [VERIFIED: :1369] |
| `idempotency_key` | README `@required` | [VERIFIED: :1370] |
| `tenant_id` | README `@required` | [VERIFIED: :1371] |
| `golden-path` | README `@required` | [VERIFIED: :1372] |
| `guides/introduction/mailglass-integration.md` | README `@required` | [VERIFIED: :1373] |
| `guides/introduction/accrue-dunning-integration.md` | README `@required` | [VERIFIED: :1374] |
| `guides/introduction/inbox-integration.md` | README `@required` | [VERIFIED: :1375] |
| `prefix: "chimeway"` | `@storage_prefix_required_strings` | [VERIFIED: :1103] |
| `prefix: false` | same | [VERIFIED: :1104] |
| `new isolated Chimeway schema` | same | [VERIFIED: :1105] |
| `existing public-schema legacy install` | same | [VERIFIED: :1106] |
| `unprefixed tables` | same | [VERIFIED: :1107] |
| `does not move data` | same | [VERIFIED: :1108] |
| `{:chimeway, "~> 1.0"}` (install constraint) | release_gate README + unpacked README | [VERIFIED: release_gate_contract_test.exs:343-348, 513-514] |
| canonical CI badge URL `github.com/szTheory/chimeway/actions/workflows/ci.yml` | release_gate README badge | [VERIFIED: release_gate_contract_test.exs:369-374] |

Note: CONTEXT D-02 lists "the three intro guide links" implicitly under "golden-path link" — the
README `@required` actually pins **all three** integration-guide links plus golden-path. The
additive-superset rewrite must retain them in the Documentation nav.

## Forbidden Strings (D-02) — grep-verified guards

Do **not** introduce any of these into `README.md`. Each has a live guard.

| Forbidden string/phrase | Guard | Source |
|-------------------------|-------|--------|
| `stop_conditions` | `@adoption_forbidden_strings` | [VERIFIED: doc_contract_test.exs:1092] |
| `Workflows.Workers` | same | [VERIFIED: :1093] |
| `Chimeway.Trigger.trigger` | same | [VERIFIED: :1094] |
| `resolve_recipients` | same | [VERIFIED: :1095] |
| `mix chimeway.install` | `@adoption_forbidden_phrases_readme` | [VERIFIED: :1100] |
| `identity:` (plain substring) | README-only test | [VERIFIED: :1357-1360] |
| `Chimeway.Workflow` (no trailing `s`) | regex `Chimeway\.Workflow(?![s])` | [VERIFIED: :1362-1365] |
| `--prefix`, `automatic data move`, `automatically move`, `automatic public-to-chimeway`, `Oban prefix`, `oban prefix` | `@storage_prefix_forbidden_phrases` | [VERIFIED: :1111-1118] |
| `github.com/jonlunsford/chimeway` (in README, packaged README) | release_gate legacy-URL guard | [VERIFIED: release_gate_contract_test.exs:355-357, 509-510] |
| `{:chimeway_admin, "~> 1.0"}` (in packaged admin guide) | unpacked admin-guide guard | [VERIFIED: release_gate_contract_test.exs:525-526] |

## Common Pitfalls / Landmines

### Pitfall 1: `recipient_identity:` trips the README `identity:` forbid — HIGH RISK
**What goes wrong:** The README guard is `String.contains?(content, "identity:")` [VERIFIED: doc_contract_test.exs:1357], a **plain substring** match. `recipient_identity:` contains the substring `identity:`, so writing `recipient_identity:` anywhere in the README fails the gate. Golden-path uses a smarter negative-lookbehind regex `(?<!recipient_)identity:` [VERIFIED: :1211] — but the **README block does not**.
**How to avoid:** Keep the DOCS-16 README snippets free of the `identity:` substring entirely. The four canonical snippets (notifier key, trigger, prefix, explain_delivery) do not require `recipient_identity:` — show recipient wiring in golden-path, not README. If a recipient example is unavoidable in README, the planner must first upgrade the README guard to the negative-lookbehind form to match golden-path.
**Warning sign:** any `recipients` callback example or `%{recipient_identity: ...}` map in README body.

### Pitfall 2: Deleting stub files vs. delinking them
**What goes wrong:** D-05 says **delink** and backlog completion, not delete. `policy-and-preferences.md` is still linked (relative file links) from `guides/introduction/getting-started.md:97` and `guides/recipes/password-reset-support-trace.md:103,122` [VERIFIED via grep]. Deleting the file would break those in-repo links.
**How to avoid:** Remove the three stub entries from `mix.exs` docs.extras (L241-243) and the README nav link; **leave the files on disk**. The cross-links from getting-started and password-reset remain valid.

### Pitfall 3: Removing the wrong mix.exs extras line
**What goes wrong:** The Flows group in docs.extras also lists `guides/flows/multi-step-journeys.md` (L244) which is a **real, content-enforced** guide [VERIFIED: doc_contract_test.exs:29-90 asserts its content]. Removing it breaks a contract.
**How to avoid:** Delink only L241 (`trigger-to-delivery.md`), L242 (`policy-and-preferences.md`), L243 (`async-dispatch.md`). Keep L244.

### Pitfall 4: golden-path stale URLs have NO existing guard
**What goes wrong:** The canonical-URL guard only iterates `@package_facing_source_files` = `mix.exs`, `README.md`, `CHANGELOG.md`, `release.yml`, `publish-hex.yml` [VERIFIED: release_gate_contract_test.exs:16, 351-357]. `guides/introduction/golden-path.md` is **not** in that list, so the four stale `jonlunsford` URLs (L167, L171, L191, L192) are currently unguarded and will silently regress after being fixed.
**How to avoid:** Fix the four URLs (D-06). Consider adding a guard so the fix stays fixed — either add golden-path to a first-hop-guide legacy-URL guard, or a targeted test. (CONTEXT D-06 only mandates the fix; the guard is Claude's discretion but strongly recommended given the executable-contract philosophy.)

### Pitfall 5: README requires `Chimeway.trigger` but forbids `Chimeway.Trigger.trigger`
**What goes wrong:** Public snippets must use `Chimeway.trigger(` (lowercase entrypoint), never the internal `Chimeway.Trigger.trigger`. The forbid is exact [VERIFIED: :1094].
**How to avoid:** Snippet chain uses only the public `Chimeway.trigger/3` and `Chimeway.Traces.*` names.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Prove packaged docs are truthful | New fresh-host runner harness | Extend `build_unpacked_package!/0` block (D-07) | Already builds+unpacks the real prod package [VERIFIED: release_gate_contract_test.exs:533-539] |
| Enforce README markers | New shell/markdown linter | Extend README `describe` in `doc_contract_test.exs` (D-09) | Project convention: docs truth = ExUnit contract |
| Per-trigger opt invariant on README | Bespoke parser | Reuse the golden-path regex-count test verbatim | Proven pattern [VERIFIED: :1247-1261] |
| Sibling package status copy | New wording | Reuse enforced phrases `in-repo preview/path package`, `not published on Hex yet` | Already asserted in unpacked guides [VERIFIED: :518-522] |

**Key insight:** Every "how do I make this stick?" answer in this repo is "add/extend a string
assertion in an existing contract `describe` block." Fight the urge to build new tooling.

## Runtime State Inventory

This is a docs/IA rewrite. Per the rename/refactor discipline, the "stale string" surfaces are docs
and config, not runtime datastores — but the audit is included because DOCS-17/D-06 involves string
cleanup and delinking.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB keys, collections, or IDs embed the edited strings (docs-only) | none |
| Live service config | None — HexDocs is regenerated from `mix.exs`+guides at publish; no external UI holds this state | none |
| OS-registered state | None | none |
| Secrets/env vars | None | none |
| Build artifacts | Packaged Hex artifact carries `README.md` + guides; **rebuilt by `mix hex.build`**, asserted by the unpacked-artifact test | code edit only (README/guides); test re-verifies |
| Doc cross-links (docs-specific) | `policy-and-preferences.md` linked from getting-started.md:97 and password-reset-support-trace.md:103,122; `trigger-to-delivery.md` linked from README.md:65 + mix.exs:241; `async-dispatch.md` + `policy-and-preferences.md` in mix.exs:242-243 | delink from README nav + mix.exs extras; keep files; keep in-repo cross-links valid |
| Stale URLs (docs-specific) | `github.com/jonlunsford/chimeway` at golden-path.md:167,171,191,192 | replace with `https://github.com/szTheory/chimeway` (D-06) |

**The canonical question — after every file edit, what still carries the old string?** The packaged
Hex artifact (rebuilt from source at `hex.build`, re-verified by the unpacked test) and HexDocs
(regenerated from `mix.exs` extras + guides). No manual re-registration needed.

## Flows Stub Disposition (DOCS-17 / D-05) — verified

| Stub (9 lines each) | Linked from README? | Linked from mix.exs extras? | Content-enforced by any test? | Other in-repo links |
|---------------------|---------------------|-----------------------------|-------------------------------|---------------------|
| `guides/flows/trigger-to-delivery.md` | Yes — README.md:65 | Yes — mix.exs:241 | **No** | none |
| `guides/flows/policy-and-preferences.md` | No | Yes — mix.exs:242 | **No** | getting-started.md:97; password-reset-support-trace.md:103,122 |
| `guides/flows/async-dispatch.md` | No | Yes — mix.exs:243 | **No** | none |

[VERIFIED: `wc -l` = 9 each; grep of `test/` returns zero content assertions for any of the three;
hexdocs-extras contract requires only introduction integration guides, not flows stubs — doc_contract_test.exs:1448-1463]

**Delink scope precisely:** README edit removes only the `trigger-to-delivery.md` link (L65).
mix.exs edit removes extras L241-243. Do not touch `multi-step-journeys.md` (L244, real guide).

## Validation Architecture

> `workflow.nyquist_validation: true` [VERIFIED: .planning/config.json] — section required.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs` |
| Full suite command | `mix ci.verify_gates` (release-blocking lane running the doc/release contracts) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-14 | README leads with value prop + explainability promise | contract | `mix test test/chimeway/doc_contract_test.exs -k "README install doc contract"` (new value-prop marker in `@required`) | ✅ block exists; ❌ marker Wave 0 |
| DOCS-15 | README states non-goals, host boundary, optional-surface status | contract | same describe; new non-goals/host-boundary/optional-surface markers | ✅ block; ❌ markers Wave 0 |
| DOCS-16 | Snippets show notification key, tenant_id, idempotency_key, prefix, `Chimeway.Traces.explain_delivery` | contract | same describe; add `Chimeway.Traces.explain_delivery` to `@required` + per-trigger idem/tenant invariant (mirror L1247-1261) | ✅ block; ❌ new assertions Wave 0 |
| DOCS-17 | Stubs delinked; stale URLs fixed | contract | hexdocs-extras contract stays green after mix.exs edit (L1442-1587); add golden-path legacy-URL guard (recommended) | ✅ extras block; ❌ URL guard Wave 0 |
| ADPT-01 | Packaged README carries the new public-story invariants | contract | `mix test test/chimeway/release_gate_contract_test.exs -k "unpacked Hex package artifact truth"` (extend L493-530) | ✅ block; ❌ new assertions Wave 0 |

### Marker strings to assert (exact — Claude's discretion on wording, these are candidate anchors)
The planner picks final phrasing (D-09 discretion) but each new marker must be a stable substring
present in both `README.md` and the packaged README. Candidate anchors: a value-prop phrase
(e.g. `local-first`), a `## Non-goals` heading, a host-boundary phrase (e.g. `host-owned`), an
optional-surface phrase (e.g. `preview`), and `Chimeway.Traces.explain_delivery`.

### Sampling Rate
- **Per task commit:** `mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs`
- **Per wave merge:** `mix ci.verify_gates`
- **Phase gate:** `mix ci.verify_gates` green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] New README markers added to `@required` (value-prop, non-goals, host-boundary, optional-surface, `Chimeway.Traces.explain_delivery`) in `doc_contract_test.exs` README describe
- [ ] README per-trigger `idempotency_key`/`tenant_id` invariant test (mirror L1247-1261)
- [ ] Extended assertions in the unpacked-artifact test for packaged README invariants (D-07)
- [ ] (Recommended) golden-path legacy-URL guard so the D-06 fix cannot regress
- [ ] (Recommended, D-03) README guard forbidding `{:chimeway_admin, "~> 1.0"}` / `{:chimeway_inbox, "~> 1.0"}` install claims and requiring preview-status language, mirroring the unpacked-guide phrases

*Test infrastructure exists; gaps are new assertions inside existing blocks, not new files.*

## Security Domain

`security_enforcement` not present in config → treated as enabled, but this phase changes only
Markdown, `mix.exs` docs config, and ExUnit string assertions. No auth, input-handling, crypto, or
data-access code is touched.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | no | docs-only; no user input paths added |
| V6 Cryptography | no | none |
| V14 Config | marginal | ensure no secrets/tokens land in public README/snippets — snippets use placeholder values (`"welcome-u1"`, `"default"`) |

**Threat note:** the only public-surface risk is documenting a **wrong or unsafe API** (e.g.
teaching a private module or a runtime prefix option). The existing forbid guards
(`Chimeway.Trigger.trigger`, `identity:`, storage-prefix drift phrases, per-call `prefix:` on public
APIs at doc_contract_test.exs:1171-1174) already mitigate this. Keep snippets on the public surface.

## State of the Art

| Old (current README) | New (Phase 79 target) | Impact |
|----------------------|-----------------------|--------|
| Thin 70-line install-only README | Additive-superset decision page (value prop, use cases, non-goals, host boundary, optional surfaces) | DOCS-14/15 |
| Trace lookup absent from README | `Chimeway.Traces.explain_delivery` snippet in README | DOCS-16 |
| 3 Flows stubs in first-hop nav | Delinked; backlog completion | DOCS-17 |
| Stale `jonlunsford` URLs in golden-path | Canonical `szTheory` URLs | D-06 |
| ADPT-01 unproven | Packaged-README invariants asserted in unpacked test | ADPT-01 |

**Deprecated/outdated:** legacy `github.com/jonlunsford/chimeway` owner URL (Phase 78 already
canonicalized package-facing files; golden-path was out of that guard's scope and still carries it).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `mix ci.verify_gates` is the release-blocking lane that runs these contracts | Standard Stack / Validation | Low — stated in CONTEXT + Phase 78; verify the alias exists in mix.exs before relying on the exact name |
| A2 | Final marker wording (value-prop/non-goals/host-boundary/optional-surface phrases) is Claude's discretion | Validation Architecture | Low — D-09 explicitly grants discretion on marker strings; only the required D-02 strings are fixed |

*All API-surface, insertion-point, forbidden/required-string, and stub-disposition claims are
[VERIFIED] against files read this session — see inline file:line tags.*

## Open Questions

1. **Should the golden-path stale-URL fix get its own guard?**
   - Known: golden-path.md is outside the current canonical-URL guard's file list.
   - Unclear: whether the planner wants a new guard vs. a one-time fix.
   - Recommendation: add golden-path (and ideally all first-hop guides) to a legacy-URL guard — consistent with the executable-contract philosophy; prevents silent regression.

2. **Does D-03 warrant a README-level `{:chimeway_admin, "~> 1.0"}` forbid?**
   - Known: the forbid is enforced only on the packaged admin/inbox *guides*, not README.
   - Recommendation: add a README guard when introducing the Optional Surfaces section, so the "never a published Hex install" rule is enforced where the new copy lives.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir + Mix | running all contracts | assumed ✓ (project builds) | project-pinned | — |
| `mix hex.build --unpack` | ADPT-01 unpacked test | ✓ (already used by existing test) | Hex bundled | — |

No new external tools. (Not independently probed this session; the unpacked-artifact test already
runs in CI, so `hex.build` availability is established.)

## Sources

### Primary (HIGH confidence — direct file reads this session)
- `lib/chimeway.ex:1-131` — public entrypoint; confirms no `explain_delivery` delegate
- `lib/chimeway/traces.ex:46,69,104,135` — trace API arities
- `lib/chimeway/notifier.ex:47-48` — `notification_key/0` + `version/0` callbacks
- `lib/chimeway/trigger.ex:140-155` — `tenant_id` requirement
- `test/chimeway/doc_contract_test.exs:1091-1118,1222-1261,1330-1391,1442-1587` — contract blocks, attrs
- `test/chimeway/release_gate_contract_test.exs:14-16,330-375,460-539` — URL guards, unpacked-artifact block
- `README.md:1-70`, `mix.exs:217-262`, `guides/introduction/golden-path.md:1-194`
- `guides/flows/{async-dispatch,policy-and-preferences,trigger-to-delivery}.md` — 9 lines each
- `.planning/config.json` — `nyquist_validation: true`

### Secondary
- `.planning/phases/79-front-door-and-docs-ia/79-CONTEXT.md` — locked decisions D-01→D-09
- `.planning/phases/78-release-and-package-truth/78-CONTEXT.md` — package model / canonical URL / contract philosophy
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` — DOCS-14/15/16/17, ADPT-01 + success criteria

## Metadata

**Confidence breakdown:**
- API surface (DOCS-16): HIGH — every function/callback read at file:line
- Contract insertion points: HIGH — all three ranges opened and confirmed
- Required/forbidden strings: HIGH — grep-verified against live attrs
- Stub disposition: HIGH — line counts + zero-reference grep confirmed
- Landmines (identity: substring, multi-step-journeys, golden-path guard gap): HIGH — verified from guard source

**Research date:** 2026-07-03
**Valid until:** 2026-08-03 (stable; docs/contract surface changes slowly — re-verify line numbers if `doc_contract_test.exs` or `release_gate_contract_test.exs` are edited before planning)
