---
phase: 66-docs-release-gates
reviewed: 2026-06-02T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - .github/workflows/ci.yml
  - MAINTAINING.md
  - guides/introduction/sigra-auth-integration.md
  - guides/introduction/threadline-integration.md
  - mix.exs
  - test/chimeway/doc_contract_test.exs
  - test/chimeway/release_gate_contract_test.exs
findings:
  critical: 1
  warning: 6
  info: 4
  total: 11
status: issues_found
---

# Phase 66: Code Review Report

**Reviewed:** 2026-06-02T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This phase ships docs (Sigra auth + Threadline integration guides), CI release gates, and contract tests that pin those docs/gates in place. The CI workflow, mix aliases, and the contract tests themselves are internally consistent and well-constructed. However, the two new integration guides contain copy-paste errors and convention drift that the contract tests do **not** catch (the tests only assert substring presence, not correctness of the embedded code), and the doc-contract test for the Sigra guide has a substring assertion that is satisfied by an incidental match rather than the intended content. There is one correctness bug in a guide code example that, if a reader copies it, breaks the documented behavior.

## Critical Issues

### CR-01: Sigra guide dependency snippet contradicts mix.exs and breaks documented optional/runtime contract

**File:** `guides/introduction/sigra-auth-integration.md:25-31` (and `guides/introduction/threadline-integration.md:25-31`)
**Issue:** The guide tells adopters to add this to their host `mix.exs`:

```elixir
defp sigra_dep do
  case System.get_env("SIGRA_PATH") do
    nil -> {:sigra, "~> 0.3", optional: true}
    path -> {:sigra, path: path, runtime: false}
  end
end
```

The path branch drops `optional: true`, so a sibling-checkout adopter gets a **required, non-optional** dependency — the opposite of the Hex branch. The canonical project declaration in `mix.exs:174-180` is `{:sigra, path: path, optional: true, runtime: false, override: true}`. The guide's path branch also omits `runtime: false` on... no — it keeps `runtime: false` on the path branch but drops it on the `nil` branch (`{:sigra, "~> 0.3", optional: true}` has no `runtime: false`). The net effect: the two branches have inconsistent dependency flags, neither matches the proven project config, and a reader who copies this will either compile Sigra into their release (Hex branch, no `runtime: false`) or get a hard dependency (path branch, no `optional: true`). For an auth integration guide whose whole premise (Section 0) is "optional, attach-only / event-bridge only," shipping a dependency snippet that makes the dep mandatory is a behavioral defect in the canonical adoption path. The same defect is present verbatim in the Threadline guide.

The doc-contract tests (`doc_contract_test.exs` Sigra/Threadline describes) assert only that strings like `Sigra.Integrations.Chimeway` and `idempotency_key` appear — they never validate the dependency block — so this passes CI while being wrong.

**Fix:** Make both branches match the project's proven flags:

```elixir
defp sigra_dep do
  case System.get_env("SIGRA_PATH") do
    nil -> {:sigra, "~> 0.3", optional: true, runtime: false}
    path -> {:sigra, path: path, optional: true, runtime: false}
  end
end
```

Apply the analogous fix to `guides/introduction/threadline-integration.md:25-31` (`{:threadline, "~> 0.7", optional: true, runtime: false}` on both branches). Consider adding a doc-contract assertion that the dependency snippet contains `optional: true` on both branches to prevent regression.

## Warnings

### WR-01: SIGRA_PATH / THREADLINE_PATH convention is contradictory within the same guide and against MAINTAINING.md

**File:** `guides/introduction/sigra-auth-integration.md:36` and `:90`
**Issue:** Line 36 instructs `SIGRA_PATH=../sigra mix deps.get` but line 90 instructs `SIGRA_PATH=../sigra mix verify.sigra`. MAINTAINING.md:84 declares the convention as `SIGRA_PATH=../sigra/sigra` (the nested `sigra/sigra` layout that CI uses — `ci.yml:401` sets `SIGRA_PATH=${{ github.workspace }}/sigra/sigra` and checks the repo out to `path: sigra/sigra`). The guide's `../sigra` (single segment) does not match the documented `../sigra/sigra` convention, so a maintainer following the guide points the env var one directory too high and `verify.sigra` fails to find the package. The Threadline guide has the identical split: line 36 uses `../threadline` while line 93 uses `../threadline/threadline` (matching MAINTAINING.md:83 and `ci.yml:355`). Within the Threadline guide the two commands disagree with each other.
**Fix:** Standardize all `*_PATH` references in both guides to the nested `../sigra/sigra` and `../threadline/threadline` form that MAINTAINING.md and ci.yml use. If the single-segment form is intentional for `deps.get` (host repo layout) vs. nested for verify (chimeway repo layout), state that distinction explicitly — as written it reads as an error.

### WR-02: Sigra guide seed reference uses function-capture syntax in a value position

**File:** `guides/introduction/sigra-auth-integration.md:83-85`
**Issue:** The verification snippet is fenced as `elixir` and reads:

```elixir
DemoHost.Seeds.seed_sigra_auth/0
```

`Mod.fun/0` is function-reference *arity* notation, not a callable expression. A reader copying this into IEx gets a `SyntaxError`; the runnable form is `DemoHost.Seeds.seed_sigra_auth()`. The Threadline guide has the same issue at line 87 (`DemoHost.Seeds.seed_threadline_notification/0` inside an `elixir` fence). This passes the doc-contract test because the test requires the substring `DemoHost.Seeds.seed_sigra` (matches `seed_sigra_auth/0`) — the contract enforces presence, not runnability.
**Fix:** Either change the fence to plain text (documenting the function by name) or make it runnable: `DemoHost.Seeds.seed_sigra_auth()`. Apply the same to the Threadline guide line 87.

### WR-03: Sigra doc-contract `DemoHost.Seeds.seed_sigra` assertion is satisfied by an unintended match

**File:** `test/chimeway/doc_contract_test.exs:787` (and `:405` for the blueprint)
**Issue:** The `@required` list for the Sigra integration guide includes `DemoHost.Seeds.seed_sigra`. The guide actually contains `seed_sigra_auth`, so `String.contains?(content, "DemoHost.Seeds.seed_sigra")` passes on the prefix. If the intent was to pin the exact seed name (`seed_sigra_auth`), the contract is under-specified: a guide that mentioned `seed_sigra_admin` or any `seed_sigra*` would also pass. By contrast the Threadline contract (`:715`) pins the full `DemoHost.Seeds.seed_threadline_notification`. The asymmetry suggests the Sigra contract is weaker than intended and will not catch a wrong/renamed seed function.
**Fix:** Tighten the Sigra required string to the exact `DemoHost.Seeds.seed_sigra_auth` to match the Threadline contract's specificity, or document deliberately that any `seed_sigra*` is acceptable.

### WR-04: `verify_inbox` is in the ten pre-ship commands and ci-gate needs, but is NOT in the @pre_ship_verify_commands parity table

**File:** `test/chimeway/release_gate_contract_test.exs:14-22`
**Issue:** `@pre_ship_verify_commands` lists seven gates (example, journeys, mailglass, accrue, inbox, threadline, sigra). It *does* include inbox — good. But note the broader parity risk: the test asserts MAINTAINING lists each command and mix.exs defines each alias and ci.yml defines each job, yet there is **no test** asserting that the set of ci-gate `needs` lanes equals the set of MAINTAINING "ten" commands plus lint/test/verify_gates/verify_docs. `ci-gate aggregates 11 required lanes` (`:146`) only checks each `@ci_gate_lanes` entry is *present* in needs — it never checks the converse (no extra/missing lane). If someone adds a `verify_foo` job to ci.yml and ci-gate needs but forgets MAINTAINING, or vice versa, the contract stays green. The "11" in the test name and the "ten" in MAINTAINING are maintained by hand in two places with no cross-check.
**Fix:** Add an assertion that `extract_ci_gate_needs(ci_yml)` has exactly the expected count and no unexpected members (e.g. `assert MapSet.new(needs) == MapSet.new(@ci_gate_lanes)`), and an assertion tying the MAINTAINING ten-command count to the verify-command table length.

### WR-05: `verify.example` alias silently runs chimeway_inbox tests, contradicting its CI job name and MAINTAINING description

**File:** `mix.exs:86-90`
**Issue:** The `verify.example` alias runs three suites: demo host, chimeway_admin, **and** `chimeway_inbox` (`mix test --warnings-as-errors`). But the CI job is named "Example host + admin smoke" (`ci.yml:132`) and MAINTAINING.md:66 describes `verify.example` as "demo host webhook E2E + chimeway_admin operator smoke" — neither mentions inbox. Meanwhile a *separate* `verify.inbox` gate (`mix.exs:121-124`) also runs chimeway_inbox tests. So chimeway_inbox package tests run twice across the gate matrix, and the `verify.example` scope is undocumented. This is drift between the alias and its two human-facing descriptions; the contract test only checks that the job runs `mix verify.example` (string match), not what the alias expands to.
**Fix:** Either remove the `chimeway_inbox` line from `verify.example` (it is already covered by `verify.inbox`), or update the CI job name and MAINTAINING.md:66 to state that `verify.example` also exercises chimeway_inbox.

### WR-06: `verify.parity` alias does not verify parity — it only lists files

**File:** `mix.exs:80-82`
**Issue:** MAINTAINING.md:24 states `verify.parity` "confirms the published file list matches the `files:` whitelist in `mix.exs`." The actual alias is:

```elixir
"verify.parity": [
  "cmd mix hex.build --unpack --output /tmp/chimeway_verify && ls /tmp/chimeway_verify"
]
```

It unpacks the built package and `ls` lists the directory — it never compares the result against the `files:` whitelist (`mix.exs:184`) or asserts anything. Exit status is whatever `ls` returns (always 0 for an existing dir), so this gate cannot fail on a parity mismatch. The documented guarantee ("confirms the published file list matches") is not implemented; a maintainer relying on it gets false assurance before announcing a release.
**Fix:** Make the alias actually diff the unpacked file list against the expected whitelist (or invoke a Mix task that does), so a missing/extra file produces a non-zero exit. At minimum, downgrade the MAINTAINING wording to match what `ls` provides ("prints the published file list for manual inspection").

## Info

### IN-01: Duplicate `actions/checkout` step in sibling-checkout jobs

**File:** `.github/workflows/ci.yml:271-276` (also `:357-362`, `:403-408`)
**Issue:** `verify_accrue`, `verify_threadline`, and `verify_sigra` each invoke `actions/checkout` twice in a row — once bare (the chimeway repo) and once for the sibling repo. This is intentional and correct (you need both checkouts), but the bare first checkout has no `path:`, and the sibling checkout uses `path: accrue/accrue`. It is worth a one-line comment clarifying the first checkout is the chimeway repo, since a reader skimming sees two identical-looking `uses:` lines and may think it is a copy-paste error.
**Fix:** Add `# chimeway repo` / `# sibling integration repo` comments to disambiguate the paired checkouts.

### IN-02: Integration guides pin `~> 1.0` while project is at 1.0.0 — not covered by version-alignment contract

**File:** `guides/introduction/sigra-auth-integration.md:21`, `guides/introduction/threadline-integration.md:21`
**Issue:** Both guides show `{:chimeway, "~> 1.0"}`. The `consumer version alignment` contract (`doc_contract_test.exs:1143`) only checks README, installation, and golden-path — not the integration guides. `~> 1.0` is currently correct, but when `@version` bumps to e.g. `1.1.0` these guides will silently drift out of the alignment guarantee that the three pinned consumer files enjoy.
**Fix:** Either add the integration guides to `@consumer_files`, or accept the looser `~> 1.0` form intentionally and note it.

### IN-03: `extract_ci_job_block` regex can over-capture across jobs

**File:** `test/chimeway/release_gate_contract_test.exs:220-225`
**Issue:** `~r/#{job_id}:(.*?)(?:\n  [a-z_]+:|\z)/s` stops at the next two-space-indented `[a-z_]+:` key. Job step keys like `name:`, `runs-on:`, `steps:` are indented four spaces, so they don't terminate the block — good. But any future top-of-job key with two-space indent matching `[a-z_]+:` inside the *first* job would truncate the captured block early, and `job_id` is interpolated unescaped, so a job id containing regex metacharacters (none today) would break. Low risk given current naming, but the helper is fragile for a contract that is meant to be a durable guardrail.
**Fix:** Anchor `job_id` with `Regex.escape/1` (as `:68` already does for alias names) and consider matching on the known 2-space job boundary explicitly.

### IN-04: `extract_pre_ship_block` depends on the pre-ship block being the first `mix ci`-leading bash fence

**File:** `test/chimeway/release_gate_contract_test.exs:206-218`
**Issue:** The helper finds the first ```` ```bash ```` block starting with `mix ci\n`. MAINTAINING.md currently has the pre-ship block at lines 50-61 and the post-publish trio block earlier (lines 17-21, which starts with `mix verify.clean`, not `mix ci`), so the match is correct today. But the contract silently depends on no earlier block beginning with `mix ci`. If a maintainer adds an example block higher in the doc that starts with `mix ci`, the parity assertions would run against the wrong block. Brittle coupling between doc prose ordering and the contract.
**Fix:** Match on a more specific anchor (e.g. require the block to contain all ten commands) or scope the search to the "Pre-ship local commands" heading.

---

_Reviewed: 2026-06-02T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
