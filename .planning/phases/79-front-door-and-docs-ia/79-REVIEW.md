---
phase: 79-front-door-and-docs-ia
reviewed: 2026-07-03T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - guides/introduction/golden-path.md
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 79: Code Review Report

**Reviewed:** 2026-07-03
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This phase is a docs-IA rewrite LOCKed by two ExUnit string-contract test files. I
verified the golden-path guide's content against the actual library source and it is
accurate: `:missing_tenant_id` (lib/chimeway/trigger.ex:143), `explain_delivery/1`
returning `status` / `suppression_reason` / a `timeline` whose entries carry an
`:event` key (lib/chimeway/traces.ex:135-180, 319-327), `:succeeded` as a real
delivery status (lib/chimeway/delivery.ex:23), the `trace.{event_id, correlation_id,
delivery_ids}` result shape (lib/chimeway/trigger.ex:237-240), and `{:chimeway, "~>
1.0"}` matching `@version "1.0.0"`. All referenced guide files exist; the canonical
`szTheory` owner is used and the legacy `jonlunsford` URL is absent and guarded.

No BLOCKERs: the contracts run and fail loud on missing files. The defects are all
**enforcement-strength** problems — the exact "silently stops enforcing the public
story" and "brittle/overspecified" failure modes this review targets. The two most
material are a document-wide count-equality that does not actually prove the
per-trigger invariant it claims, and a CI-job-block extractor that over-captures
across hyphen-named jobs and can pass an assertion against a *different* job's text.

## Warnings

### WR-01: "every trigger includes idempotency_key and tenant_id" is a document-wide count, not a per-trigger check

**File:** `test/chimeway/doc_contract_test.exs:1255-1269` (and the byte-identical mirror at `1424-1438` for README)
**Issue:** The test title and failure message assert that *every* `Chimeway.trigger(`
example carries both required opts, but the body only compares three independent
document-wide occurrence counts:

```elixir
triggers = Regex.scan(~r/Chimeway\.trigger\(/, content) |> length()
idem = Regex.scan(~r/idempotency_key:/, content) |> length()
tenant = Regex.scan(~r/tenant_id:/, content) |> length()
assert triggers == idem
assert triggers == tenant
```

There is no association between a given trigger call and its opts. Two failure modes:
(1) **Vacuous pass** — a `Chimeway.trigger(` example missing both opts still passes if
some other block mentions `idempotency_key:`/`tenant_id:` twice (e.g. a config sample,
a keyword-list schema, or a second correct trigger), so the lock silently stops
enforcing the story. (2) **False fail** — documenting a legitimate negative example
(an actual `Chimeway.trigger(` call that intentionally omits `tenant_id` to show
`{:error, :missing_tenant_id}`) breaks the count equality even though the doc is
correct, so the contract prevents teaching the error path with real code.
**Fix:** Match each trigger invocation's argument span and assert both keys are present
within it, e.g. scan `~r/Chimeway\.trigger\((?:[^()]|\([^()]*\))*\)/s` and, for each
captured call, `assert String.contains?(call, "idempotency_key:") and
String.contains?(call, "tenant_id:")`. This proves the per-call invariant and stops
counting opts that live outside any trigger call.

### WR-02: `extract_ci_job_block/2` over-captures across hyphen-named jobs → assertions can pass against the wrong job

**File:** `test/chimeway/release_gate_contract_test.exs:625-630` (impacts callers at `256`, `111`, `196`, `200`, `218`)
**Issue:** The job-block terminator only recognizes underscore/lowercase job names:

```elixir
Regex.run(~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s, yml)
```

`[a-z_]+` excludes `-`, so any job whose *following* job is hyphen-named
(`ci-gate:`, `gate-ci-green:`, `publish-hex:`, `bootstrap-release-pr-ci:`) is not
terminated and the block extends to the next underscore-named job or EOF. Concretely,
`extract_ci_job_block(release_yml, "publish-hex")` at line 256 then feeds
`String.contains?(publish_block, "gate-ci-green")` — which can be satisfied by text
belonging to a *later* job, so the "publish-hex needs gate-ci-green" gate passes even
if that dependency were removed from the publish-hex job itself. Same over-capture
weakens the `verify_admin`/`verify_sigra` per-command assertions whenever the adjacent
job is hyphen-named.
**Fix:** Allow hyphens in the terminator and anchor the start to a job (2-space indent
under `jobs:`): `~r/\n  #{Regex.escape(job_id)}:\n(.*?)(?=\n  [a-z0-9_-]+:\n|\z)/s`.
Broadening the terminator character class to `[a-z0-9_-]+` is the minimum fix.

### WR-03: `identity:` forbid is inconsistent across the three doc surfaces and would false-fail a legitimate `recipient_identity:` in README/installation

**File:** `test/chimeway/doc_contract_test.exs:1211` vs `1304` and `1366`
**Issue:** The golden-path guard correctly permits the canonical key via a negative
lookbehind: `refute Regex.match?(~r/(?<!recipient_)identity:/, content)`. But the
installation and README guards use a plain substring check:

```elixir
refute String.contains?(content, "identity:")
```

`String.contains?("...recipient_identity: ...", "identity:")` is `true`, so those two
surfaces forbid the *canonical* `recipient_identity:` key as well as the deprecated
`identity:`. Enforcement is asymmetric (golden-path teaches `recipient_identity:`; the
other two are barred from showing it), and any future README/installation edit that
includes a recipients example with the correct key would fail the lock for the wrong
reason.
**Fix:** Use the same lookbehind form in all three surfaces:
`refute Regex.match?(~r/(?<!recipient_)identity:/, content)`.

### WR-04: Job existence / needs extraction is unanchored and first-match — brittle substring matching

**File:** `test/chimeway/release_gate_contract_test.exs:108`, `626`, `633`
**Issue:** `~r/#{unquote(job_id)}:/` (line 108) and the interpolated start of
`extract_ci_job_block` (line 626) are unanchored, so a job id appearing earlier as a
mapping key, list item, or comment (`verify_sigra:` anywhere) is the first match
`Regex.run` returns, extracting the wrong span. `extract_ci_gate_needs` (line 633)
also only matches the flow-list `needs: [ ... ]` form; a valid block-list YAML
(`needs:\n  - lint`) flunks. The block-list case fails loud (acceptable), but the
unanchored existence/extraction is a silent mis-scope risk that compounds WR-02.
**Fix:** Anchor to line-start job headers, e.g. `~r/^  #{Regex.escape(job_id)}:$/m`
for existence and the anchored form in WR-02 for extraction; make the needs extractor
tolerate both flow-list and block-list YAML.

## Info

### IN-01: Duplicate and fragile manifest-version verification

**File:** `test/chimeway/release_gate_contract_test.exs:229-241` and `327-333`
**Issue:** The manifest-vs-mix.exs version equality is asserted twice. The first uses
a hand-rolled regex `~r/"\."\s*:\s*"([^"]+)"/` (line 234) that is brittle to JSON
formatting; the second decodes with `Jason.decode!` (line 327-333) which is robust.
The regex variant is redundant with the JSON-parsing variant.
**Fix:** Drop the line-234 regex path and keep the `Jason.decode!` assertion as the
single source of truth for manifest version parity.

### IN-02: `@required` / `@forbidden_strings` module attributes redefined ~15 times

**File:** `test/chimeway/doc_contract_test.exs` (e.g. `@required` at `72, 130, 165, 225, 445, 499, 578, 666, 719, 821, 951, 1046, 1230, 1315, 1375`)
**Issue:** The same attribute names are reassigned per describe block. This is
compile-correct in Elixir (each `for required <- @required` reads the value in lexical
scope), but it is a maintenance hazard: reordering blocks or hoisting a `for` loop
above its `@required` reassignment would silently use a neighboring block's list.
**Fix:** Give each block a distinct attribute name (e.g. `@golden_path_required`,
`@readme_required`) so the required-string sets are self-documenting and order-independent.

---

_Reviewed: 2026-07-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
