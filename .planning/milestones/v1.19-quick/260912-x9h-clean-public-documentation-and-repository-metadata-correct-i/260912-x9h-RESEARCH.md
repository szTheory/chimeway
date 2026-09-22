# Quick 260912-x9h: Clean Public Documentation and Repository Metadata - Research

**Researched:** 2026-09-13
**Domain:** Elixir package documentation, repository metadata, Mix tasks, and formatter topology
**Confidence:** HIGH

## Summary

This is a bounded truth-and-hygiene pass, not another product phase. The milestone audit already records 9/9 requirements, 4/4 phase verifications, 12/12 integration links, and no release blocker; its release recommendation is one stabilization batch followed by archive/release. [VERIFIED: `.planning/v1.19-MILESTONE-AUDIT.md:1-19,39-41,99-101`]

The 15-path execution cap selects the most release-relevant coherent slice: fix the inbox guide and maintainer wording; make README match its already-executable notifier fixture; replace four legacy repository URLs; remove three nine-line placeholder guides and their dead references; repair the repository-only `demo.up` checkout boundary; and replace stale root onboarding with a durable AGENTS pointer. Roadmap checkbox reconciliation, nested formatter topology, the stale bell comment, and broad source chronology become one explicit mechanical follow-up. [VERIFIED: inventory below; selected scope in Resolved Scope Decisions]

**Primary recommendation:** implement the selected 15-path slice with contract tests first, then run focused docs/runtime proof, Demo.Up unit/journey evidence, `mix ci.docs`, and `mix ci.verify_gates`. Record the excluded mechanical cleanup as a separate follow-up instead of declaring or scanning dozens of source files in this quick item. [VERIFIED: `AGENTS.md:25-32`; `mix.exs:125-167`]

## Resolved Scope Decisions

1. **Obsolete root bootstrap:** delete `GSD-CONTEXT.md` after replacing AGENTS' copied phase-count sentence with a durable pointer to `.planning/STATE.md` and `.planning/ROADMAP.md`. Git history preserves the bootstrap; keeping a second live onboarding file would recreate drift. [SELECTED from Open Question 1]
2. **Bounded cleanup boundary:** this quick item owns only current public Markdown/package artifacts plus the selected root metadata/tooling paths enumerated in its 15-path PLAN frontmatter. Broad `lib/**/*.ex` and demo-source Phase/Plan/GSD narration, roadmap checkbox/count repair, the stale bell comment, and nested formatter topology are excluded as a separate mechanical follow-up; `.planning` archives, CHANGELOG, prompts, and test selectors remain historical/executable evidence rather than cleanup targets. [SELECTED from Open Question 2 and second checker revision]
3. **README fixture parity:** the executable fixture is `Chimeway.ReadmeSnippetTest.WelcomeUser`. Preserve its working `recipients/1`, `build/2`, and `rendering/2` callbacks and copy those exact behaviors into README, rather than editing a second file under the 15-path cap. The docs contract binds the module name and callback/literal parity so the public snippet and executable proof cannot drift. [SELECTED after checker correction and 15-path rescope]

## Project Constraints (from AGENTS.md)

- Preserve the product boundary: Chimeway is an embedded, local-first Elixir/Phoenix notification layer, and host applications own their data, policies, delivery history, authentication, tenancy, URL generation, and correlation IDs. [VERIFIED: `AGENTS.md:3-7,17-23`]
- Keep the durable lifecycle spine and stable identity. The exact guidance is: `"Persist stable notification_key + version (never module names as durable identity)."` and `"Keep a durable lifecycle spine: event -> notification -> delivery -> attempt."` [VERIFIED: `AGENTS.md:17-20`]
- Preserve replaceable adapter behaviours, idempotency and suppression semantics, and host ownership boundaries. [VERIFIED: `AGENTS.md:21-23`]
- Keep named `mix verify.*` / `mix ci.*` entrypoints and local/CI parity. [VERIFIED: `AGENTS.md:25-29`]
- Do not leak sensitive payload fields through telemetry or operator surfaces. [VERIFIED: `AGENTS.md:29`]
- Verification is machine evidence; do not create conversational UAT for objectively testable documentation, formatting, link, or Mix-task behavior. [VERIFIED: `AGENTS.md:30-32`]
- Treat `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` as the planning source of truth. [VERIFIED: `AGENTS.md:34-39`]

The final sentence of `AGENTS.md` is itself stale: `"Current roadmap has 5 phases, with Phase 1 (Durable Core Spine) as the immediate focus."` [VERIFIED: `AGENTS.md:41`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Public adoption truth | Package documentation | Contract tests | README/guides teach the API; executable contracts prevent future drift. [VERIFIED: `test/chimeway/doc_contract_test.exs:1783-1907`] |
| Repository identity | Package metadata | Release contracts | `mix.exs`, README, SECURITY, and guide links must agree on one canonical repository. [VERIFIED: `test/chimeway/release_gate_contract_test.exs:18-20,1053-1076`] |
| Demo command | Mix task | Demo host | The root task orchestrates repository migrations and the nested demo host; it must state and enforce that checkout boundary. [VERIFIED: `lib/mix/tasks/demo.up.ex:1-61`] |
| Formatting | Root formatter | Nested project formatters | Root owns orchestration; each nested Mix project owns its local rules. [VERIFIED: `.formatter.exs:1-10`; `chimeway_admin/.formatter.exs:1-4`; `chimeway_inbox/.formatter.exs:1-4`] |
| Planning status | GSD lifecycle artifacts | Agent guide | ROADMAP/STATE remain authoritative; AGENTS should point to them without copying a phase count that immediately becomes stale. [VERIFIED: `AGENTS.md:34-41`] |

## Exact Drift Inventory

### 1. Inbox guide: callback type, version, and proof vocabulary

The guide says there is no separate recipe `"in v1.9"`, shows the root dependency as `{:chimeway, "~> 1.0"}`, and says both auth callbacks receive `"a context keyword list"`. [VERIFIED: `guides/introduction/inbox-integration.md:1-3,24-30,104-109`]

The source-of-truth callback values are verbatim:

```elixir
@callback current_recipient(session :: map(), context :: map()) ::
            {:ok, String.t()} | {:error, :unauthorized}

@callback current_tenant(session :: map(), context :: map()) ::
            {:ok, String.t()} | {:error, term()}
```

[VERIFIED: `chimeway_inbox/lib/chimeway_inbox/auth.ex:13-17`]

The runtime constructs that context as the map `%{live_view: socket.view, session: session}`. [VERIFIED: `chimeway_inbox/lib/chimeway_inbox/live_auth.ex:53-63`]

The current root version is verbatim `@version "1.1.1"`, and the README/golden path already use `{:chimeway, "~> 1.1"}`. [VERIFIED: `mix.exs:1-9`; `README.md:69-75`; `guides/introduction/golden-path.md:7-17`]

The last verification paragraphs expose internal acceptance vocabulary (`DEMO-08`, `D-06`) instead of describing behavior. [VERIFIED: `guides/introduction/inbox-integration.md:194-209`]

**Bounded fix:** use version-neutral prose for the recipe ownership sentence; change the dependency to `~> 1.1`; say `context map`; describe the five verification layers and the mounted proof by behavior without requirement/decision IDs. Add doc-contract assertions for the callback type and version alignment so this exact regression cannot return. [VERIFIED: `test/chimeway/doc_contract_test.exs:1210-1280,2223-2255`]

### 2. README notifier snippet is not independently runnable

The README's notifier contains only `notification_key/0` and `version/0`, then immediately triggers it. [VERIFIED: `README.md:114-145`]

The required callback values are verbatim:

```elixir
@callback notification_key() :: String.t()
@callback version() :: pos_integer()
@callback recipients(map()) :: {:ok, [map()]} | {:error, term()}
@callback build(map(), map()) :: {:ok, map()} | {:error, term()}
```

[VERIFIED: `lib/chimeway/notifier.ex:47-50`]

Validation explicitly returns `:missing_recipients_callback` and `:missing_build_callback` when those functions are absent. [VERIFIED: `lib/chimeway/notifier.ex:72-83`]

The existing README runtime test quietly supplies `recipients/1`, `build/2`, and `rendering/2` even though its comments say it mirrors the README. [VERIFIED: `test/chimeway/integration/readme_snippet_test.exs:21-61`]

**Bounded fix:** copy the existing working `Chimeway.ReadmeSnippetTest.WelcomeUser` callback behavior into README: all four required callbacks plus its explicit `rendering/2` declaration for the in-app proof. Keep the fixture unchanged and add a lightweight doc contract that binds the module name, callback set, render key/version, and safe synthetic literals across README and the executable test. This spends one path instead of two while making the public example honestly match what CI executes. [VERIFIED: `test/chimeway/integration/readme_snippet_test.exs:14-60`; selected 15-path cap]

### 3. Repository links have four public legacy-owner stragglers

The canonical and legacy URL values are verbatim:

```elixir
@canonical_repo_url "https://github.com/szTheory/chimeway"
@legacy_repo_url "https://github.com/jonlunsford/chimeway"
```

[VERIFIED: `test/chimeway/release_gate_contract_test.exs:18-20`]

The remaining public legacy links are:

- `SECURITY.md:8` private vulnerability reporting.
- `guides/flows/multi-step-journeys.md:175` demo E2E proof.
- `guides/recipes/feedback-escalation-workflow.md:87` demo E2E proof.
- Two links on `guides/recipes/password-reset-support-trace.md:90`. [VERIFIED: `SECURITY.md:8`; `guides/flows/multi-step-journeys.md:175`; `guides/recipes/feedback-escalation-workflow.md:87`; `guides/recipes/password-reset-support-trace.md:90`]

The current contract only rejects the legacy URL across five package-facing files and in one guide-specific test, which is why these stragglers survived. [VERIFIED: `test/chimeway/release_gate_contract_test.exs:20,1053-1059`; `test/chimeway/doc_contract_test.exs:1660-1675`]

**Bounded fix:** replace all four locations with the canonical owner and extend one contract over public Markdown/package guides rather than adding one assertion per file. Do not rewrite historical URLs in `.planning/` or generated CHANGELOG entries. [VERIFIED: `mix.exs:250-265`; `test/chimeway/release_gate_contract_test.exs:1053-1076`]

### 4. Three tracked placeholder guides should not ship

Each of these tracked files is only nine lines and contains both `"This guide is a stub. Full content coming in v1.0 docs."` and `"<!-- TODO: expand with full content -->"`:

- `guides/flows/trigger-to-delivery.md`
- `guides/flows/async-dispatch.md`
- `guides/flows/policy-and-preferences.md` [VERIFIED: each file `:1-9`; `git ls-files` on 2026-09-13]

They are not included in the ExDoc `extras` list, but the Hex package includes the entire `guides` directory. The exact package entry is `~w(lib priv guides scripts/prove-accrue-consumer.exs scripts/prove-adoption-paths.exs CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)`. [VERIFIED: `mix.exs:250-290`]

`password-reset-support-trace.md` still tells users the policy guide is a stub at lines 103 and 122. [VERIFIED: `guides/recipes/password-reset-support-trace.md:96-122`]

**Bounded fix:** delete the three placeholder-only files and replace the password-reset stub references with direct, accurate links to the existing golden path, getting-started, Oban, and tracing material as appropriate. Add a contract that packaged/public guides contain neither the stub banner nor the TODO marker. Do not spend this stabilization batch authoring three new long-form guides; the existing complete guides cover the practical adoption paths. [VERIFIED: `mix.exs:266-297`]

### 5. `Mix.Tasks.Demo.Up` needs an explicit repository boundary

The task derives its demo path with `Path.expand("examples/chimeway_demo_host", File.cwd!())` and invokes nested `mix demo.seed` / `mix demo.admin` there. [VERIFIED: `lib/mix/tasks/demo.up.ex:31-61`]

The package ships all of `lib` but not `examples`, so the compiled Mix task is present to Hex consumers while the directory it requires is absent. [VERIFIED: `mix.exs:250-254`; `lib/mix/tasks/demo.up.ex:1-61`]

In a source checkout, the smoke is a real gate and its previous CI hang has a documented, verified fix: it requires inherited `DATABASE_URL` and a warmed `:dev` build; the retained timeout is intentionally 300 seconds. [VERIFIED: `.planning/CI-HARDENING-BACKLOG.md:23-29`; `.github/workflows/ci.yml:527-529,666-669`; `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:5-29`]

The demo host currently has no `.formatter.exs`, and its `demo_up_test.exs` body at lines 14-28 is visibly outside the test block indentation. [VERIFIED: absence from `find . -name .formatter.exs`; `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:11-29`]

**Bounded fix:** keep the source-checkout command, but resolve the checkout root from the active Mix project instead of arbitrary `File.cwd!()` and fail immediately with an actionable `Mix.raise/1` when `examples/chimeway_demo_host` is absent. Update the task moduledoc/shortdoc to say it is a repository-checkout helper. Keep `DATABASE_URL`, dev pre-warm, DB sequencing, and the 300-second CI timeout unchanged. Add a unit-level path/boundary test plus retain `mix verify.journeys` as the real smoke. [VERIFIED: cited task and CI sources]

Changing Hex's package file topology solely to hide this one task, publishing the whole demo host, or redesigning the demo database bootstrap is an over-refactor for this batch. [ASSUMED]

### 6. Public source still narrates old implementation plans

The clearest false or expired public comments/moduledocs are:

- `Chimeway.Dispatch`: Oban `"will be the Phase 3 alternative"`, although `Chimeway.Dispatch.Oban` is present. [VERIFIED: `lib/chimeway/dispatch.ex:1-14`; source file `lib/chimeway/dispatch/oban.ex` exists]
- `Chimeway.Dispatch.Sync`: `"Swap to Chimeway.Dispatch.Oban in Phase 3"`. [VERIFIED: `lib/chimeway/dispatch/sync.ex:1-16`]
- `Chimeway.Policy`: `policy_module` is described as an undispatched future-phase hook. [VERIFIED: `lib/chimeway/policy.ex:15-23`]
- `Chimeway.DeliveryAttempt`: its public moduledoc narrates temporary Plan 14 task sequencing that is already complete. [VERIFIED: `lib/chimeway/delivery_attempt.ex:1-18,51-55`]
- `Chimeway.Dispatch.Executor` and `ObanWorker`: public headings and prose refer to Phase/Plan 14 rather than the current contract. [VERIFIED: `lib/chimeway/dispatch/executor.ex:1-20`; `lib/chimeway/dispatch/oban_worker.ex:1-13,71-99`]
- `ProcessFeedbackWorker`: promises removal in `"Phase 34 or v1.5"`, both long past, while the compatibility clauses remain. [VERIFIED: `lib/chimeway/webhooks/process_feedback_worker.ex:30-34,69-76`]
- Package guides and demo README still expose `SEED-*`, `JOUR-*`, `DEMO-*`, `DOCS-*`, `D-*`, and phase labels even when ordinary behavioral prose is clearer. [VERIFIED: repository-wide `rg` inventory on 2026-09-13; representative locations `examples/chimeway_demo_host/README.md:1-76`; `guides/recipes/mention-escalation.md:84-95`; `guides/flows/multi-step-journeys.md:173-225`]

**Selected disposition:** defer this broad source-comment sweep to a separate mechanical follow-up. The follow-up starts from the repository-wide inventory already recorded above, rewrites comments/docstrings only, excludes active CrossWake machine identifiers and immutable history/evidence, and owns its own bounded path manifest. This 15-path quick item does not declare or scan the source corpus. [SELECTED by second checker revision]

Removing the legacy webhook job clauses is a runtime compatibility decision, not comment cleanup; leave the clauses intact and reword the expired removal promise unless a separate compatibility audit authorizes deletion. [VERIFIED: `lib/chimeway/webhooks/process_feedback_worker.ex:69-76,170-175`]

### 7. Roadmap and agent metadata contradict completion

The roadmap phase list and progress table say Phases 106 and 107 are complete, while their four plan checkboxes remain unchecked. The exact stale values are:

```markdown
**Plans**: 2 plans
- [ ] `106-01`
- [ ] `106-02`

**Plans**: 2 plans
- [ ] `107-01`
- [ ] `107-02`
```

[VERIFIED: `.planning/ROADMAP.md:19-22,59-91,106-113`]

STATE likewise says `status: completed` and `completed_plans: 8`, but its prose says `Plan: Not started` and keeps Phase 107 as the current focus. [VERIFIED: `.planning/STATE.md:1-34`]

`GSD-CONTEXT.md` is an obsolete fresh-project bootstrap: it tells a cleared session to run `/gsd-new-project` and `/gsd-plan-phase 1`. [VERIFIED: `GSD-CONTEXT.md:1-26`]

**Selected 15-path fix:** replace AGENTS' duplicated phase-count sentence with a durable instruction to read STATE/ROADMAP, then delete `GSD-CONTEXT.md`; Git history preserves the obsolete bootstrap. Defer the four roadmap checkboxes/counts to the mechanical follow-up, and let milestone completion own final PROJECT/STATE archive transitions. [SELECTED by second checker revision]

Do not flatten or delete `.planning/`, `prompts/`, milestone archives, or requirement-tagged tests in this quick pass. Those are development history and executable evidence, not public package surfaces; wholesale removal has poor benefit-to-risk ratio. [VERIFIED: `mix.exs:250-254` excludes `.planning`, `prompts`, and tests from the Hex package]

### 8. Formatter topology misses two real boundaries

Current observed results on 2026-09-13:

| Command | Result | Evidence |
|---|---|---|
| `mix format --check-formatted` | PASS | Root formatter checks root inputs only. [VERIFIED: command output; `.formatter.exs:1-10`] |
| `cd chimeway_admin && mix format --check-formatted` | PASS | Nested formatter exists. [VERIFIED: command output; `chimeway_admin/.formatter.exs:1-4`] |
| `cd chimeway_inbox && mix format --check-formatted` | FAIL | `router.ex` and `test/support/endpoint.ex` are unformatted. [VERIFIED: command output; `chimeway_inbox/.formatter.exs:1-4`] |
| `cd examples/chimeway_demo_host && mix format --check-formatted` | FAIL | No formatter inputs/subdirectories exist. [VERIFIED: command output; absence from formatter inventory] |

Installed Mix 1.19.5 documents `:subdirectories` as the built-in mechanism for nested projects with their own formatter rules. [VERIFIED: local `mix help format` output on 2026-09-13]

**Selected disposition:** defer formatter topology and the two inbox formatting fixes to the same mechanical follow-up as source-comment and roadmap cleanup. Format the two Demo.Up files explicitly in this item so its own touched Elixir stays clean; do not spend five additional declared paths on repository-wide formatter routing under the 15-path cap. [SELECTED by second checker revision]

## Recommended Bounded Implementation

### Slice A — Public Markdown and runnable snippet

1. Extend `test/chimeway/doc_contract_test.exs` with README/inbox callback and version contracts plus canonical-link, no-stub, and no-deleted-guide assertions. [VERIFIED: existing doc-contract patterns at `test/chimeway/doc_contract_test.exs:1210-1280,1783-1907,2223-2255`]
2. Copy the working `Chimeway.ReadmeSnippetTest.WelcomeUser` callback behavior, including `rendering/2`, into README without modifying the executable fixture.
3. Correct inbox wording, replace the four legacy-owner links, delete the three placeholder guides, and repair their password-reset references.

### Slice B — Repository-only Demo.Up boundary

1. Add an explicit-root helper and fail-fast source-checkout guard before database/subprocess work.
2. Add focused path success/failure cases beside the existing tagged journey smoke.
3. Format the two touched files explicitly and retain `mix verify.journeys`.

### Slice C — Maintainer and agent truth

1. Update MAINTAINING after sibling item `260912-x9g` so Release Please fallback and `verify.clean` wording match the hardened implementation.
2. Replace AGENTS' copied phase focus/count with durable STATE/ROADMAP pointers, then delete `GSD-CONTEXT.md`.
3. Record roadmap, bell-comment, broad source-comment, and nested formatter cleanup as the bounded mechanical follow-up.

[VERIFIED: `mix.exs:71-76,125-167`; `MAINTAINING.md:48-78`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Nested formatting | A shell script that `cd`s through projects | Mix `.formatter.exs` `:subdirectories` | Built-in routing preserves each nested project's own formatter config. [VERIFIED: local `mix help format`] |
| Version drift | Another literal version in a test | Derive `MAJOR.MINOR` from root `@version` | Existing contracts already use this pattern. [VERIFIED: `test/chimeway/doc_contract_test.exs:2223-2255`; `test/chimeway/release_gate_contract_test.exs:1045-1050`] |
| Link checking | Per-file one-off assertions | One canonical/legacy URL contract over public/package Markdown | The repository already centralizes these values. [VERIFIED: `test/chimeway/release_gate_contract_test.exs:18-20,1053-1076`] |
| New placeholder guides | Three rushed long documents | Delete empty stubs and route to complete guides | Stubs are not ExDoc extras and already have complete adjacent material. [VERIFIED: `mix.exs:266-297`; stub files `:1-9`] |
| Demo task packaging redesign | Shipping the example app in Hex | Checkout guard + actionable error | The task is a repository convenience; examples are outside the package whitelist. [VERIFIED: `mix.exs:250-254`; `lib/mix/tasks/demo.up.ex:1-61`] |

## Common Pitfalls

### Pitfall 1: Making the README test pass without making the README runnable

The current runtime test already demonstrates this failure mode by supplying callbacks absent from the public snippet. Make the fixture mirror the exact snippet, then execute the existing trigger-to-explanation path. [VERIFIED: `README.md:114-150`; `test/chimeway/integration/readme_snippet_test.exs:21-90`]

### Pitfall 2: Breaking the demo CI fix while cleaning comments

Do not remove the job-level `DATABASE_URL`, dev build warming, or 300-second timeout. Those are load-bearing, documented CI behavior rather than stale phase artifacts. [VERIFIED: `.planning/CI-HARDENING-BACKLOG.md:23-29`; `.github/workflows/ci.yml:527-529,666-669`]

### Pitfall 3: Treating requirement selectors as mere prose

Test tags such as `:jour_05` and `:inbox` are executable selectors. Keep them unless all aliases and CI consumers are updated together; clean public prose first. [VERIFIED: `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:5-11`; `mix.exs:142-167`]

### Pitfall 4: Rewriting generated history

CHANGELOG contains historical conventional-commit scopes with phase numbers. Editing old release history creates noise and does not improve current API truth. [VERIFIED: `CHANGELOG.md:18-130`]

### Pitfall 5: Manually editing workflow-owned completion state too early

ROADMAP checkbox correction is safe because it reconciles already-complete records. PROJECT/STATE archive changes should occur through the milestone completion workflow after stabilization, or they can be overwritten/re-diverge. [VERIFIED: `.planning/STATE.md:1-34`; `.planning/ROADMAP.md:19-22,59-113`]

### Pitfall 6: Weakening privacy wording during prose simplification

The inbox guide's tenant/recipient authorization, opaque identity, topic-secret custody, lossy-hint, and durable-reload boundaries are current security contracts. Remove internal IDs, not these constraints. [VERIFIED: `guides/introduction/inbox-integration.md:5-20,55-117,145-186`]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit under Mix [VERIFIED: `mix.exs:71-167`] |
| Root formatter | `.formatter.exs` [VERIFIED: `.formatter.exs:1-10`] |
| Focused docs command | `scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --exclude accrue_packaged_cli --warnings-as-errors` [VERIFIED: `mix.exs:127-130`] |
| Docs build | `mix ci.docs` [VERIFIED: `mix.exs:85-87`] |
| Demo journey | `mix verify.journeys` [VERIFIED: `mix.exs:142-145`] |
| Release-facing aggregate | `mix ci.verify_gates` [VERIFIED: `mix.exs:125-139`] |

### Change → Evidence Map

| Change | Test Type | Automated Evidence |
|---|---|---|
| README callbacks | integration + contract | Focused docs contracts plus `test/chimeway/integration/readme_snippet_test.exs`. [VERIFIED: cited files] |
| Inbox callback/version wording | contract | `test/chimeway/doc_contract_test.exs`. [VERIFIED: `test/chimeway/doc_contract_test.exs:1210-1280,2223-2255`] |
| Canonical links / no stubs | contract | Extend existing docs/release contracts, then package proof in `mix ci.verify_gates`. [VERIFIED: `test/chimeway/release_gate_contract_test.exs:1053-1076,1197-1235`] |
| Demo.Up boundary | unit + integration | Focused task test and `mix verify.journeys`. [VERIFIED: `examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs:1-29`; `mix.exs:142-145`] |
| Touched Demo.Up formatting | static | Explicit `mix format --check-formatted` over the two touched files; repository-wide topology is deferred. [SELECTED] |
| Broad public moduledocs | follow-up | Separate mechanical path manifest and docs build, outside this 15-path item. [SELECTED] |
| Root agent metadata | contract | AGENTS points to STATE/ROADMAP and obsolete root GSD-CONTEXT is absent; roadmap row reconciliation is deferred. [SELECTED] |

### Sampling Rate

- Per task commit: focused contract or formatter command for the changed surface. [VERIFIED: existing gate structure]
- Per merged selected slice: explicit touched-file formatting + focused docs/release contracts + `mix ci.docs`. [SELECTED]
- Batch gate: `mix verify.journeys` and `mix ci.verify_gates`; broader release stabilization can run the full twelve-command maintainer suite once, not after every prose edit. [VERIFIED: `MAINTAINING.md:48-78`]

### Wave 0 Gaps

- Add contract coverage for all four README notifier callbacks, global canonical public links, no shipped stub markers, and inbox `context map` wording. [VERIFIED: gaps shown above]
- Repository-wide formatter routing is intentionally not a Wave 0 gap for this item; it is assigned to the separate mechanical follow-up. [SELECTED]
- Add focused Demo.Up checkout-boundary coverage while retaining the existing database smoke. [VERIFIED: current task test]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | Indirectly | Preserve host-auth callback responsibility; no auth behavior change. [VERIFIED: `chimeway_inbox/lib/chimeway_inbox/auth.ex:1-17`] |
| V3 Session Management | Indirectly | Continue passing the Phoenix session map only to host auth callbacks and reauthorize before reload. [VERIFIED: `chimeway_inbox/lib/chimeway_inbox/live_auth.ex:14-69`] |
| V4 Access Control | Yes | Preserve independent tenant membership and opaque recipient resolution wording. [VERIFIED: `guides/introduction/inbox-integration.md:85-117`] |
| V5 Input Validation | Yes | Keep doc-contract negative assertions for raw recipient/caller/content examples and validate Demo.Up's checkout path before use. [VERIFIED: `test/chimeway/doc_contract_test.exs:1240-1350`; `lib/mix/tasks/demo.up.ex:31-61`] |
| V6 Cryptography | No implementation change | Keep the host-custodied high-entropy topic-secret guidance; do not alter topic derivation in this batch. [VERIFIED: `guides/introduction/inbox-integration.md:55-72`] |

### Threats to Preserve Against

| Pattern | STRIDE | Mitigation |
|---|---|---|
| Tenant/recipient authority copied from browser/PubSub input | Spoofing / elevation | Document and contract independent host authorization on mount and reload. [VERIFIED: `guides/introduction/inbox-integration.md:15-18,104-117,178-186`] |
| Raw identity or content introduced while simplifying examples | Information disclosure | Retain opaque references and existing negative docs contracts. [VERIFIED: `guides/introduction/inbox-integration.md:111-117`; `test/chimeway/doc_contract_test.exs` negative inbox contracts] |
| Demo task operates on an unintended checkout path | Tampering | Resolve the active project root and validate the exact demo-host directory before spawning nested commands. [VERIFIED: current weakness at `lib/mix/tasks/demo.up.ex:31-61`] |

## Safe Low-Hanging Work vs. Over-Refactors

| Selected now | Explicitly defer / follow up |
|---|---|
| README callbacks + matching runtime test | New notifier DSL or README rewrite |
| Inbox callback/version/gate prose + contracts | Inbox auth/PubSub/runtime behavior changes |
| Four canonical URL replacements + global contract | Rewriting historical planning/CHANGELOG URLs |
| Delete three empty stub files + stale mentions | Authoring three comprehensive new guides |
| Checkout guard/path resolution for Demo.Up | Packaging the entire demo host or redesigning its DB bootstrap |
| Explicit formatting of the two touched Demo.Up files | Root/nested formatter topology plus known inbox drift |
| Public Markdown/package artifact truth | Broad root/demo source moduledoc chronology sweep |
| Durable AGENTS pointer and obsolete bootstrap deletion | Roadmap checkbox/count reconciliation; deletion of planning/history artifacts |
| Let milestone completion finalize PROJECT/STATE | Hand-maintaining duplicate lifecycle state in several files |

[VERIFIED: all do-now items trace to the inventory above; deferrals are scope recommendations]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir | format, compile, tests | Yes | 1.19.5 | Project CI floor remains 1.17+. [VERIFIED: local command; `AGENTS.md:9-15`] |
| Mix | nested formatter + gates | Yes | 1.19.5 | None needed. [VERIFIED: local command] |
| PostgreSQL | focused ExUnit and Demo.Up journey | Project wrapper/CI | Project-scoped DB via `scripts/test-db`; Demo.Up uses inherited `DATABASE_URL` in CI. [VERIFIED: `MAINTAINING.md:80-94`; `.planning/CI-HARDENING-BACKLOG.md:23-29`] | Use the project wrapper/hosted gate rather than a developer's shared DB. |

No new packages are required, so package legitimacy research is not applicable. [VERIFIED: recommended implementation uses only existing Mix/ExUnit/project tooling]

## Assumptions Log

| # | Claim | Risk if Wrong |
|---|---|---|
| A1 | A checkout guard is sufficient repair for the dependency-exposed `demo.up` task; hiding the task from Hex is unnecessary for this release. [ASSUMED] | A consumer may still see a repository-only task in `mix help`; if that is considered unacceptable, package file selection needs a separate design. |

## Resolved Questions

1. **`GSD-CONTEXT.md`:** delete it after AGENTS points to the durable state/roadmap sources. [RESOLVED]
2. **Comment cleanup boundary:** this item is capped at its 15 declared public-Markdown/root metadata/tooling paths; broad source chronology, roadmap, bell-comment, and nested formatter cleanup are a separate mechanical follow-up. [RESOLVED]

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` — project constraints and stale current-focus sentence.
- `.planning/v1.19-MILESTONE-AUDIT.md` — release readiness and exact stabilization debt.
- `README.md`, `guides/`, `MAINTAINING.md`, `SECURITY.md` — public documentation inventory.
- `lib/chimeway/notifier.ex`, `chimeway_inbox/lib/chimeway_inbox/auth.ex`, `chimeway_inbox/lib/chimeway_inbox/live_auth.ex` — callback source of truth.
- `lib/mix/tasks/demo.up.ex`, demo task tests, CI workflow, and CI hardening backlog — demo behavior and protected CI mechanism.
- `mix.exs`, `.formatter.exs`, nested formatter files, and local `mix help format` — package/formatter topology.
- `.planning/ROADMAP.md`, `.planning/STATE.md`, `GSD-CONTEXT.md` — metadata contradictions.
- `test/chimeway/doc_contract_test.exs` and `test/chimeway/release_gate_contract_test.exs` — existing executable truth-lock patterns.

No external web research was needed; this is codebase-only research against the live repository and installed toolchain. [VERIFIED: research method]

## Metadata

**Confidence breakdown:**
- Public drift inventory: HIGH — every item was opened or found with repository-wide search and cross-checked against source-of-truth code.
- Bounded implementation: HIGH — it reuses existing tests, Mix aliases, and formatting mechanisms.
- Demo.Up packaging disposition: MEDIUM — the defect is verified, but whether an actionable checkout-only error is sufficient is a maintainer policy choice.
- Pitfalls: HIGH — each is tied to an existing regression, selector, or contract.

**Research date:** 2026-09-13
**Valid until:** 2026-10-13 (stable repository-local findings; recheck after release/version bump)
