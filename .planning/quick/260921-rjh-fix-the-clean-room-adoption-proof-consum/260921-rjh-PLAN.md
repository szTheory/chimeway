---
phase: quick-260921-rjh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - priv/adoption_proof/artifact_consumer_fixture.ex
  - test/chimeway/release_gate_contract_test.exs
  - test/chimeway/doc_contract_test.exs
  - guides/introduction/mailglass-integration.md
  - examples/chimeway_demo_host/config/config.exs
autonomous: true
requirements: [QUICK-260921-RJH]
estimate:
  tokens: 60000
  raw_tokens: 40000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "The clean-room adoption-proof consumer boots and completes priv/prove_mailglass.exs under swoosh 1.28.x with no mix.lock."
    - "test/chimeway/release_gate_contract_test.exs:1691 passes locally against a live Postgres."
    - "A cheap source-level contract test fails if the generated consumer config ever loses its Swoosh api_client setting again."
    - "An adopter following guides/introduction/mailglass-integration.md configures Swoosh's api_client explicitly and does not rely on hackney being incidentally present."
    - "ci-gate is green on the pushed SHA, asserted programmatically via gh."
    - "nightly-gate is green on that same SHA, asserted programmatically via gh."
  artifacts:
    - priv/adoption_proof/artifact_consumer_fixture.ex
    - test/chimeway/release_gate_contract_test.exs
    - guides/introduction/mailglass-integration.md
    - examples/chimeway_demo_host/config/config.exs
  key_links:
    - "config_exs/3 mailglass? branch -> generated consumer config/config.exs -> swoosh application start"
    - "doc_contract_test guide assertions -> guides/introduction/mailglass-integration.md clean-consumer config block"
    - "local mix ci -> push main -> ci-gate run -> nightly dispatch -> nightly-gate run"
---

<objective>
Fix the clean-room adoption-proof consumer that fails to boot under swoosh 1.28.x, close the same gap on
every adopter-facing surface, and drive both `ci-gate` and `nightly-gate` green on the pushed SHA.

Purpose: nightly CI has been red three nights on the unchanged SHA `a653535e`; 11 jobs (including `pr-gate`
and `ci-gate`) cascade from one test. Root cause is upstream drift, not a regression: the generated consumer
project carries no `mix.lock`, so swoosh resolves fresh to 1.28.x, which raises at application start unless
`:hackney` is present or `config :swoosh, :api_client` is set.

Output: a fixed fixture, executable regression guards, corrected adopter docs/config, and green gates.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/.continue-here.md
@AGENTS.md
@priv/adoption_proof/artifact_consumer_fixture.ex
@guides/introduction/mailglass-integration.md

Verified live at planning time (2026-09-21, HEAD `a653535e`):
- `config_exs/3` is at `priv/adoption_proof/artifact_consumer_fixture.ex` line 462; the `mailglass?` branch
  interpolation is line 471. It configures `:chimeway`, `:mailglass` and Oban — nothing for `:swoosh`.
- `defp deps` is emitted inside `mix_exs/4` at line 458; the generated project writing happens in
  `scaffold!/4` at lines 394-435 and writes no `mix.lock`.
- `prove_mailglass!/2` (line 161) returns `config_source` in its result map, so the expensive end-to-end test
  can assert on the generated config directly.
- Adapter in play is `Mailglass.Adapters.Fake` (fixture line 471, `adapter: {Mailglass.Adapters.Fake, []}`),
  so no real HTTP client is ever needed by the proof.
- `grep` across `config/`, `guides/`, `docs/`, `README.md`, `examples/` finds zero `api_client` mentions.
- Root `mix.lock` and `examples/chimeway_demo_host/mix.lock` both pin `hackney 1.25.0` and `swoosh 1.28.0` —
  those two projects only boot today because hackney is incidentally locked in, which is exactly the latent
  footgun a real adopter hits.
- Failing nightly jobs on `35572571029`: Release gate contract, Optional APNs adapter gate, Adoption proof
  paths, Test (1.17 floor / OTP 27), Test (1.19 / OTP 26), Test (1.19 / OTP 27), Nightly cold build, Test
  ordering guard (--seed 0), pr-gate, ci-gate, nightly-gate.
- The failing test runs inside `mix ci.verify_contracts` (root `mix.exs` line 134), which runs
  `release_gate_contract_test.exs` excluding only `adoption_paths_e2e` and `accrue_packaged_cli`.
- `mix ci` = `ci.lint` + `ci.test` (root `mix.exs` line 68). `ci.lint` includes format checks for
  `chimeway_admin`, `chimeway_inbox`, and `examples/chimeway_demo_host`.
- `scripts/test-db` (executable) is the DB wrapper used by every DB-touching alias.
- `ci.yml` nightly tier is gated on `run_nightly`, settable by
  `gh workflow run ci.yml --ref main -f run_nightly=true`; aggregate job names are `ci-gate` and
  `nightly-gate`.

Decision D-01 (chosen fix): write `config :swoosh, :api_client, false` into the generated consumer config
rather than adding `{:hackney, "~> 1.9"}` to the consumer deps. Rationale: the proof's adapter is
`Mailglass.Adapters.Fake`, so no HTTP client is exercised; adding hackney would pull an entire HTTP/TLS
dependency subtree (certifi, idna, metrics, mimerl, parse_trans, ssl_verify_fun, unicode_util_compat) into a
clean-room proof that must stay minimal, and would enlarge the supply-chain surface of the adoption proof for
zero functional gain. It is also the guidance a real adopter on a fake/test adapter should follow.

Working-tree note: `.planning/config.json` is an intentional GSD runtime switch from this session (fine to
include or leave). `.tool-versions` carries a pre-existing stray local edit that is NOT ours — do NOT stage it.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Boot the clean-room consumer end-to-end under swoosh 1.28.x</name>
  <files>priv/adoption_proof/artifact_consumer_fixture.ex, test/chimeway/release_gate_contract_test.exs</files>
  <precondition>A local Postgres reachable through `scripts/test-db` (the alias wrapper used by every DB-touching lane).</precondition>
  <action>
Re-confirm the line numbers before editing (the file may have moved): grep for `defp config_exs` and for the
`mailglass?` interpolation inside it.

In `priv/adoption_proof/artifact_consumer_fixture.ex`, extend the `mailglass?` branch of `config_exs/3` so the
generated `config/config.exs` also sets the Swoosh api_client to `false`, per D-01. Emit it as its own
`config :swoosh, ...` line alongside the existing `:mailglass` lines, matching the surrounding
escaped-heredoc interpolation style and the same leading indentation the sibling lines use, so the generated
file stays readable. Do not add `:hackney` to `deps` in `mix_exs/4`, and do not start generating a `mix.lock`
for the consumer — a floating resolve is part of what this proof is meant to exercise.

Then add two executable guards in `test/chimeway/release_gate_contract_test.exs`:
  1. A cheap source-grep test in the existing fast describe block that already reads
     `priv/adoption_proof/artifact_consumer_fixture.ex` (near the mailable render-alias test, ~line 1680):
     assert the fixture source emits the Swoosh api_client setting. This guard costs no DB and no compile of a
     generated project, so it catches a future regression in the fast lane rather than only in the 2-minute
     end-to-end proof.
  2. In the expensive `prove_mailglass!` test at ~line 1691, add an assertion on the returned `config_source`
     that the generated consumer config actually carries the Swoosh setting — proving the fixture change
     reached the file on disk, not just the source template.

Both new assertions must use the exact literal that the fixture now emits.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway &amp;&amp; scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors</automated>
  </verify>
  <done>The previously failing test "a clean consumer proves one host-owned Mailglass transaction from only the unpacked artifact" passes, the whole `release_gate_contract_test.exs` file is green under the `ci.verify_contracts` exclusion set, and both new guards pass.</done>
  <reversibility rating="reversible">A config line in a generated fixture plus two test assertions; revertable in one commit.</reversibility>
</task>

<task type="auto">
  <name>Task 2: Close the same gap on every adopter-facing surface</name>
  <files>guides/introduction/mailglass-integration.md, test/chimeway/doc_contract_test.exs, examples/chimeway_demo_host/config/config.exs</files>
  <action>
The fixture fix alone is a band-aid: the demo host and the published guides only work today because hackney
happens to be pinned in their lockfiles. Close the gap everywhere an adopter reads or copies.

1. `guides/introduction/mailglass-integration.md`: in the "Clean-consumer repository topology" elixir block
   (~lines 55-58, the block that currently lists the four `ecto_repos` / `:chimeway` / `:mailglass` repo
   lines), add the Swoosh api_client line so the documented config stays byte-compatible with what the
   fixture generates. Then, in the "Runtime config" section (~line 90, the paragraph beginning "Configure
   Mailglass per its docs"), add a short prose sentence explaining that Swoosh requires an api_client
   selection at application start: hosts on a fake or local adapter should disable it, and hosts using an
   HTTP-backed provider adapter must supply a real client (hackney, Finch, or Req) — otherwise the VM refuses
   to boot. Name swoosh 1.28 as the version where this became a hard start-time failure.

2. `test/chimeway/doc_contract_test.exs`: the describe block "mailglass integration guide doc contract
   (DOCS-06 / DOCS-07)" already couples the guide's clean-consumer config block to the executable fixture
   topology (~lines 656-673, the test "couples clean-consumer repo guidance to the executable fixture
   topology"). Add an assertion there that the guide contains the same Swoosh api_client line the fixture
   emits, so guide and fixture cannot drift apart again.

3. `examples/chimeway_demo_host/config/config.exs`: add an explicit Swoosh api_client setting with a one-line
   comment naming why (the demo host uses a fake/local mail adapter and must not depend on hackney being
   incidentally present in its lock). Put it near the existing `config :chimeway` / `config :chimeway_inbox`
   entries. Keep the file formatted — `mix ci.lint` runs `mix format --check-formatted` inside
   `examples/chimeway_demo_host`.

Check `guides/recipes/mailglass-integration-blueprint.md` and `README.md` for a copyable Mailglass config
block; if either presents one an adopter would paste, extend it the same way. If neither does, leave them
alone and say so in the summary.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway &amp;&amp; scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors &amp;&amp; (cd examples/chimeway_demo_host &amp;&amp; mix deps.get &amp;&amp; mix format --check-formatted)</automated>
  </verify>
  <done>`mix ci.verify_contracts`-equivalent tests pass including the new guide↔fixture coupling assertion, the demo host config is formatted, and every adopter-facing Mailglass config surface states the Swoosh api_client requirement explicitly.</done>
</task>

<task type="auto">
  <name>Task 3: Full local mix ci, push, and assert both gates green on the pushed SHA</name>
  <files>(no source edits — gate execution and evidence capture)</files>
  <precondition>`gh` is authenticated for the szTheory/chimeway repo, and the owner can push directly to `main` (ruleset 18486746 grants bypass).</precondition>
  <action>
1. Run the FULL gate locally, not just the test lane: `mix ci` (= `ci.lint` + `ci.test`). The Lint lane
   (format / compile --warnings-as-errors / credo --strict) is required by ci-gate and `mix ci.test` skips it.
   Capture the exit status directly — never through a pipe, because `cmd | tail; echo $?` reports tail's
   status rather than the command's.
2. Also run `mix ci.verify_gates` locally, since the failing test lives in that alias chain.
3. Stage ONLY the files this plan touched, plus `.planning/config.json` if you choose to include the GSD
   runtime switch. Do NOT stage `.tool-versions` — it carries a pre-existing stray local edit that is not ours.
4. Commit with a `fix(ci):` subject describing the swoosh 1.28 api_client boot fix and the adopter-surface
   follow-through, and push to `main`.
5. Record the pushed SHA (`git rev-parse HEAD`). Wait for the push-tier run and assert `ci-gate` programmatically:
   resolve the run for that SHA with `gh run list --branch main --commit <SHA>` or
   `gh api repos/szTheory/chimeway/actions/runs?head_sha=<SHA>`, then assert the `ci-gate` job's conclusion is
   `success` via `gh run view <run_id> --json jobs`. Assert against the SHA — do not accept a green run on a
   different commit.
6. Dispatch the nightly tier on the same SHA: `gh workflow run ci.yml --ref main -f run_nightly=true`. Confirm
   the dispatched run's `headSha` equals the pushed SHA before trusting it, then assert `nightly-gate`
   concluded `success` the same programmatic way. `Adoption proof paths`, the 1.17 floor lane, and the cold
   build only run in that tier, and they were among the 11 red jobs.
7. If either gate is red, diagnose and fix the root cause and repeat from step 1. Do not disable, skip, or
   tag-exclude a lane to make it pass.
8. Write the run IDs, the job conclusions, and the asserting commands into the SUMMARY as the evidence trail.
   This is machine-testable, so no human UAT and no human-verify checkpoint applies.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/chimeway &amp;&amp; SHA=$(git rev-parse HEAD) &amp;&amp; gh api "repos/szTheory/chimeway/actions/runs?head_sha=$SHA" --jq '[.workflow_runs[].id] | .[]' | while read -r RID; do gh run view "$RID" --json headSha,jobs --jq "select(.headSha==\"$SHA\") | .jobs[] | select(.name==\"ci-gate\" or .name==\"nightly-gate\") | \"\(.name)=\(.conclusion)\""; done | sort -u</automated>
  </verify>
  <done>`mix ci` and `mix ci.verify_gates` pass locally; the fix is committed and pushed to `main`; `ci-gate=success` and `nightly-gate=success` are both asserted on the pushed SHA with run IDs recorded in the SUMMARY; `.tool-versions` remains unstaged.</done>
  <reversibility rating="costly">Pushes directly to `main`; revertable by a follow-up revert commit, but the history entry is permanent.</reversibility>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| hex.pm → generated clean-room consumer | The consumer resolves deps fresh with no lockfile, so upstream package contents cross an unpinned boundary into a project this repo compiles and runs in CI. |
| repo docs → adopter host application | Config text in `guides/` and `examples/` is copied verbatim into third-party applications. |
| local working tree → `main` | Task 3 pushes directly to the default branch. |

## STRIDE Threat Register (ASVS L1, block on high)

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-rjh-01 | Tampering | clean-room consumer dependency resolution (no `mix.lock`) | medium | accept | Unpinned resolution is the deliberate purpose of the adoption proof — it is how this very drift was detected. D-01 explicitly declines to add `{:hackney, "~> 1.9"}`, so the change adds zero new packages and does not widen this surface. |
| T-rjh-02 | Information disclosure | Swoosh api_client in the generated consumer and demo host | low | mitigate | Setting the api_client to `false` disables outbound HTTP from the proof entirely; the proof's adapter is `Mailglass.Adapters.Fake`, so no message and no credential can leave the machine. |
| T-rjh-03 | Tampering | adopter-facing guidance in `guides/` and `examples/` | medium | mitigate | Task 2 adds a doc-contract assertion coupling the guide's config block to the executable fixture, so the published guidance cannot silently drift from what is actually proven. |
| T-rjh-04 | Repudiation | direct push to `main` in Task 3 | low | mitigate | Evidence is programmatic: run IDs and `ci-gate`/`nightly-gate` conclusions are asserted against the pushed SHA and recorded in the SUMMARY. |
| T-rjh-SC | Tampering | npm/pip/cargo installs | n/a | accept | No package-manager install tasks in this plan. The only dependency-adjacent decision (D-01) was resolved in favor of adding no package at all. |
</threat_model>

<verification>
- `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/release_gate_contract_test.exs test/chimeway/doc_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors` is green.
- `mix ci` (lint + test) is green locally, exit status read directly.
- `mix ci.verify_gates` is green locally.
- `ci-gate` concluded `success` on the pushed SHA (run ID recorded).
- `nightly-gate` concluded `success` on the same SHA via a `run_nightly=true` dispatch (run ID recorded).
</verification>

<success_criteria>
- The clean-room adoption-proof consumer boots and completes its Mailglass proof under a fresh swoosh 1.28.x resolve.
- A regression in the generated consumer's Swoosh config fails a cheap test in the fast lane, not only in the 2-minute end-to-end proof.
- Adopter-facing Mailglass guidance and the demo host both state the Swoosh api_client requirement explicitly, guarded by a doc-contract assertion.
- No new dependency was added to the clean-room consumer.
- `ci-gate` and `nightly-gate` are both green on the pushed SHA, asserted programmatically.
- `.tool-versions` was never staged.
</success_criteria>

<output>
Create `.planning/quick/260921-rjh-fix-the-clean-room-adoption-proof-consum/260921-rjh-SUMMARY.md` when done.
</output>
