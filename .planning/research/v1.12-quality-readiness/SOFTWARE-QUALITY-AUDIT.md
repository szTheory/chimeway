# Software Quality Audit: Chimeway

**Date:** 2026-06-30  
**Baseline:** current working tree, with shipped `v1.11` evidence separated from uncommitted drift  
**Method:** repo inspection, local read-only/verification commands, parallel read-only subagent audits, and official ecosystem docs

## 1. Executive Summary

**Weakest dimension:** release/package truth and upgrade trust  
**Score:** 1/5  
**Why weakest:** the repo is tagged as shipped `v1.11`, while the public package version and release artifacts still say `1.0.0`; optional package docs claim `~> 1.0` even though `chimeway_admin` and `chimeway_inbox` are `0.1.0` and lack package/docs metadata. A stranger cannot tell what is actually released, supported, or installable.

**If ignored:** serious users will lose trust before they even evaluate the engine. Maintainers will get avoidable "which version do I install?" and "why does this dependency not exist?" support load.

**Second-weakest dimension:** database/schema hygiene and host-app respect  
**Score:** 2/5  
**Why:** Chimeway creates 31 first-party `chimeway_*` tables in the host app's default schema today. Prefix support is partial and mostly read-side. A dedicated `chimeway` Postgres schema is feasible, but runtime/write paths, installer templates, raw SQL migrations, Oban config, docs, and tests are not ready.

**Third-weakest dimension:** adoption front door and documentation IA  
**Score:** 2/5  
**Why:** the README is thin for the size and seriousness of the project, several flow guides linked from README are stubs, and doc-contract coverage protects many detailed guides but not the front-door adoption story.

**Overall quality read:** useful-but-rough. The engine and verification surface are substantial, but the OSS package/readiness layer is not adoption-ready in the current working tree.

**Blunt diagnosis:** Chimeway has a real product core, but the public package story, storage boundary, and CI/local trust story are not yet as disciplined as the notification engine.

## 2. Dimension Ranking Table

| Rank | Dimension | Score | Confidence | Evidence | Practical consequence | Highest-leverage fix | Priority |
|---:|---|---:|---|---|---|---|---|
| 1 | Release quality, versioning, upgrades | 1 | High | `mix.exs` `@version "1.0.0"` while `HEAD` is tagged `v1.11`; `CHANGELOG.md` only has 1.0.0; optional package docs claim `~> 1.0` for packages at 0.1.0 | Users cannot trust install/version guidance | Align package version, changelog, release manifest, docs constraints, and optional package status | Must fix before public adoption |
| 2 | Data model, DB hygiene, persistence | 2 | High | 31 migration templates under `priv/chimeway_migrations`; no generated prefix policy; migration contract checks `public`; raw SQL migrations reference bare table names | Host apps get public-schema table sprawl and hard upgrade choices | Add static Chimeway prefix support and default new installs to schema `chimeway` | Must fix before wider adoption |
| 3 | Adoption ease | 2 | High | README is short and omits local-first, lifecycle spine, non-goals, optional packages, screenshots/status; flow guides linked from README are stubs | Users bounce or misunderstand scope | Rewrite README as adoption landing page and remove/finish stale guide links | Must fix before public adoption |
| 4 | Documentation and information architecture | 2 | High | Good detailed guides exist, but `guides/flows/*` contain stale stub language and cross-doc anchors drift | Docs feel deep but uneven; trust erodes | Replace stubs, add README/doc IA contract tests, fix anchors | Must fix before public adoption |
| 5 | CI/CD and automation | 2 | High | `ci-gate` requires 12 lanes; local `mix ci` is narrower; local root test currently fails; `mix ci.lint` fails format; heavy lanes duplicate setup | Maintainers waste time and contributors cannot reproduce CI simply | Split fast PR gate vs full release gate; add nested caches and local scripts | Should fix before Hex push/release |
| 6 | Compatibility with host apps | 2 | High | Public schema only; incomplete tenant spine; inbox APIs filter by recipient only; Oban optionality not honest | Library can leak across tenants or impose app structure | Prefix support, tenant-scoped APIs, explicit Oban policy | Must fix before serious production use |
| 7 | Configuration quality and safe defaults | 3 | High | `repo` config exists; prefix, Oban, limits, and optional package status are not clearly safe by default | Setup mistakes become runtime surprises | Add validated config for prefix, limits, and dispatch mode | Should fix before 1.0-quality claim |
| 8 | Public API design and DX | 3 | High | `Chimeway` facade is useful, but inbox returns schemas in legacy mode and DTO maps in paginated mode; adapter contract tests not packaged | Client code is brittle; adapter authors copy internals | Stabilize DTO APIs and package contract tests | Should fix before broader adapter ecosystem |
| 9 | Reliability, resilience, fault tolerance | 3 | High | Strong idempotency/retry tests exist; but Oban is optional in deps while core modules call it; trigger has documented post-commit dispatch gap | Some failure modes need manual recovery or optional dep surprises | Decide Oban required vs truly optional; close dispatch gap | Should fix before production-ready claim |
| 10 | Security and abuse resistance | 3 | High | Admin auth is explicit; redaction exists; but sensitive key handling is shallow and inconsistent across trigger, attempts, adapters | PII/secret leakage risk in traces/operator surfaces | Central recursive redaction vocabulary and contracts | Must fix before public adoption if sensitive flows marketed |
| 11 | Privacy and data lifecycle | 3 | Medium | Redaction contracts exist; no clear retention/pruning story for notification history | Tables grow and PII retention is underspecified | Add retention/pruning policy and docs | Should fix before production-heavy use |
| 12 | Performance and resource efficiency | 3 | Medium | No load evidence; unbounded inbox/admin limits; digest planning has N+1 query patterns; local test slow path dominated by installer subprocess tests | Scale problems appear late | Bound reads, add indexes/query tests, measure hot paths | Should fix before high-volume production |
| 13 | SRE, observability, operational readiness | 4 | High | Explainability, telemetry, admin UI, recovery APIs, and verify gates are strong | Operators have useful state, but docs/runbooks still uneven | Add runbook/troubleshooting docs and alertable telemetry list | Nice soon |
| 14 | Testing and QA | 4 | High | 1008 root tests ran locally; many integration/doc contracts; local run found 6 failures and warning noise in current tree | Strong breadth, but current dirty tree is not green and default tests are slow | Fix isolation failures, reduce installer test cost, add prefix/upgrade tests | Must fix before merge/release |
| 15 | Functional suitability and core correctness | 4 | Medium | Durable spine, workflows, adapters, admin and docs gates are implemented; local failures are current-tree isolation issues | Core likely works, but current tree needs cleanup | Re-green current tree and audit runtime edge cases | Should fix before release |
| 16 | Architecture and boundaries | 3 | High | Core/admin/inbox package split is good; large modules hold many invariants; Oban optional boundary leaks | Changes require broad context | Split lifecycle modules around planning/recovery/attempts | Later unless blocking fixes |
| 17 | Maintainability and evolvability | 3 | High | Many phase comments and large modules; strong tests support refactoring | Growth will slow unless cleanup follows GSD velocity | Targeted module extraction after prefix/reliability fixes | Later |
| 18 | Dependency health and supply chain | 3 | Medium | Optional deps are useful but heavy; `postgrex >= 0.0.0` is too loose; actions are SHA-pinned | Host conflicts and CI complexity | Tighten constraints and document optional deps | Should fix before Hex release |
| 19 | Ecosystem fit and interoperability | 4 | High | Ecto/Phoenix/Oban/Swoosh patterns are idiomatic; adapter seams exist | Good fit, with prefix/Oban honesty gaps | Align with Ecto prefix and Oban prefix conventions | Should fix |
| 20 | Portability and deployment compatibility | 3 | Medium | Postgres-only is explicit by stack, but release/container/runtime assumptions are not deeply documented | Deployment support questions | Add release/deployment guide and runtime config notes | Nice soon |
| 21 | Extensibility and customization | 4 | Medium | Behaviours/adapters/workflows are strong; contract tests not packaged | Extension possible but external authors lack reusable test harness | Publish testing support module | Should fix |
| 22 | UI/UX quality | 3 | High | Admin console has real flows; search state clears and URLs do not preserve context | Operators cannot share/replay context easily | Preserve search/filter state in URL | Should fix before UI-heavy release |
| 23 | Design-system coherence | 4 | High | Scoped CSS, tokens, themes, responsive layout, component modules exist | Mostly coherent | Fill missing status CSS mappings | Nice soon |
| 24 | Accessibility | 3 | Medium-High | Native controls and focus styles exist; tables lack captions/scope; no skip link; recovery selection lacks state semantics | Assistive-tech use is weaker than visual use | Add skip link, table captions, `scope`, `aria-pressed` | Should fix before polished UI claim |
| 25 | Internationalization/localization | N/A | High | OSS infra/admin UI is English-only; no stated localization promise | Low adoption risk now | Do not formalize yet | Not worth doing yet |
| 26 | Troubleshooting/supportability | 3 | Medium | Explainability is strong; setup docs lack common failure/runbook depth | Maintainers will field repeated setup questions | Add troubleshooting guide with config/migration/Oban failures | Should fix |
| 27 | Contributor experience | 3 | Medium | CONTRIBUTING exists; local `mix ci` is not the full CI truth; nested gates are hard to reproduce | Contributors get surprised by CI | Rename/expand local gates and document full matrix | Should fix |
| 28 | Maintainer experience/support burden | 3 | High | Release automation exists; CI has many heavy lanes and external pins | Support burden grows with every integration lane | Path-gate heavy lanes and create local scripts | Should fix |
| 29 | OSS polish, trust signals, governance | 3 | High | License/security/contributing/maintaining exist; README does not link them; package truth mismatch | Repo looks alive but not cleanly release-ready | Fix README trust links and release truth | Must fix before strangers |
| 30 | Legal/licensing basics | 4 | High | MIT license present; tracked `.DS_Store` may ship via `guides` whitelist | Minor package hygiene issue | Remove tracked `.DS_Store` from packaged paths | Should fix before Hex release |
| 31 | Backward compatibility/API stability | 2 | High | Public version/changelog mismatch; upgrade path for DB prefix/tenant changes not defined | Upgrades feel risky | Write API/DB stability policy and migration playbooks | Must fix before claiming stable |
| 32 | Safety of defaults/failure behavior | 3 | High | Destructive recovery is guarded; defaults for prefix, limits, and Oban are not fully safe | Bad defaults can create storage/load surprises | Conservative limits and explicit dispatch/storage config | Should fix |
| 33 | Quality of examples/demos | 4 | Medium | Demo host and journey gates are strong; admin anchor drift and optional package status confuse | Good value, needs cleanup | Keep demo, fix stale links/status | Nice soon |
| 34 | Intangible coherence/taste | 3 | Medium | Strong product point of view; GSD velocity left release/doc/package seams rough | Feels like a sharp engine wrapped in uneven packaging | Consolidation milestone before more features | Must do now |
| 35 | Missing dimension: tenant isolation | 2 | High | Tenant stored on deliveries, not events/notifications; inbox recipient-only | Multi-tenant hosts are at risk | Tenant spine and tenant-scoped inbox APIs | Must fix before production-ready |
| 36 | Missing dimension: migration/install safety | 2 | High | 31 migrations, raw SQL, no prefix strategy, slow golden tests | DB changes are high-risk | Dedicated storage milestone with upgrade tests | Must fix before storage refactor |

## 3. Top 5 Weakness Deep Dives

### 1. Release/package truth and upgrade trust

**What I observed:** The planning system says v1.11 shipped, but package metadata and changelog still present 1.0.0 as the package version. Optional package docs claim install constraints that do not match the sibling packages.

**Evidence from repo:**
- `mix.exs` still has `@version "1.0.0"`.
- `.release-please-manifest.json` still has `1.0.0`.
- `CHANGELOG.md` has only `1.0.0` plus empty Unreleased.
- `guides/introduction/admin-console-integration.md` says `{:chimeway_admin, "~> 1.0"}` while `chimeway_admin/mix.exs` is `0.1.0`.

**How this hurts users:** They cannot know what to install, whether admin/inbox are published, or whether docs match the package they get from Hex.

**How this hurts maintainers:** Every install issue starts with version archaeology. Release Please and CI gates cannot fully protect a package whose public truth is split.

**Fix first:** Decide whether milestone tags are package tags. If they are, align package version, changelog, manifest, README, docs constraints, and Hex metadata. If they are not, rename milestone tags or document the distinction aggressively.

**Do not over-fix:** Do not create enterprise governance. This needs simple release truth, not process theater.

**Concrete changes:**
- Update `CHANGELOG.md` with v1.1+ or retcon milestone tags as planning-only.
- Add README links to changelog, security, contributing, maintaining.
- Add doc-contract tests that fail when README/install docs reference unpublished package constraints.

### 2. Database/schema hygiene and host-app respect

**What I observed:** Chimeway owns many durable tables but installs them into the host's public schema by default. Prefix support is not end-to-end.

**Evidence from repo:**
- `priv/chimeway_migrations` contains 31 templates.
- Docs teach `mix chimeway.gen.migrations` then `mix ecto.migrate`, with no schema/prefix guidance.
- `test/chimeway/migration_contract_test.exs` checks public schema.
- Prefix tests exist only for some trace read APIs.

**How this hurts users:** Production apps get a large set of infrastructure tables mixed into app tables. Moving later is harder than doing it intentionally now.

**How this hurts maintainers:** Every future migration must support public and prefixed installs if the decision is delayed.

**Fix first:** Build static storage-prefix support. Default new generated installs to `chimeway`, support explicit `public`/unprefixed legacy mode, and do not attempt dynamic per-tenant prefixes in the same milestone.

**Do not over-fix:** Do not build dynamic tenant prefixes. The project already has tenant IDs and workflow/Oban jobs; dynamic prefixes would explode job semantics.

**Concrete changes:**
- Add `config :chimeway, prefix: "chimeway"` default for new installs.
- Generate migrations with explicit `prefix: @prefix` table/index/reference options and `CREATE SCHEMA IF NOT EXISTS`.
- Add prefixed integration tests for trigger -> delivery -> attempt -> trace -> inbox -> workflow -> webhook -> recovery.

### 3. CI/CD and local developer trust

**What I observed:** CI is serious but heavy. Local `mix ci` is not the full CI truth. The current working tree fails both root tests and lint.

**Evidence from local commands:**
- `mix test --exclude mailglass --exclude accrue --exclude threadline --exclude sigra --slowest 20` ran 1008 tests in 73.3s with 6 failures and 41 excluded.
- The same run reported `max_cases: 1`, meaning most root tests are serialized locally.
- Three installer/golden tests consumed about 68s combined: 24.4s, 24.0s, 19.7s.
- `mix ci.lint` failed on formatting drift in tracked files.
- `mix xref graph --format cycles --label compile-connected` found no cycles.

**How this hurts users:** CI badge trust is weaker when local reproduction is unclear and current tree is not green.

**How this hurts maintainers:** Heavy always-on external lanes burn runner minutes and make unrelated PRs wait for ecosystem proof.

**Fix first:** Keep high-value gates, but separate fast PR gate from full release gate. Add path-gated ecosystem lanes, nested caches, and local scripts for non-trivial CI.

**Do not over-fix:** Do not delete slow tests just because they are slow. The installer tests are valuable, but they should not dominate every root test run.

**Concrete changes:**
- Fix current formatting and DB isolation failures before any release.
- Move full 12-lane sweep to release/main/scheduled, with path-gated PR lanes.
- Add nested caches for demo/admin/inbox and Node/Playwright.

### 4. Adoption front door and docs IA

**What I observed:** Detailed guides are strong, but the README and some linked flow docs do not match the maturity of the project.

**Evidence from repo:**
- README is short and omits local-first ownership, lifecycle spine, non-goals, optional package status, screenshots, and trust boundaries.
- `guides/flows/trigger-to-delivery.md`, `policy-and-preferences.md`, and `async-dispatch.md` contain stale stub language.
- Golden Path links to an admin demo anchor that has drifted.

**How this hurts users:** They do not get a crisp "use this when..." decision in 30 seconds.

**How this hurts maintainers:** Deep docs cannot compensate for a weak front door; issue load increases.

**Fix first:** Rewrite README as a landing page and either finish or delink stub guides.

**Do not over-fix:** The existing detailed guides should not be expanded first. Fix discoverability and stale links before adding volume.

**Concrete changes:**
- README sections: what this is, when to use, when not to use, 5-minute path, concepts, optional packages, production notes, trust links.
- Add README doc-contract tests for these sections.
- Remove `.DS_Store` from tracked package content.

### 5. Reliability/API/privacy seams

**What I observed:** The engine has many reliability contracts, but a few seams are still too leaky for a stable OSS library.

**Evidence from repo:**
- `oban` is optional in `mix.exs`, but `SignalRouterWorker`, `Signal.track/4`, and webhooks call Oban unconditionally.
- Trigger transaction commits before dispatch and the module documents a crash-before-dispatch gap.
- Events/notifications lack tenant ID while deliveries have it.
- Inbox APIs filter by recipient identity only.
- Redaction key lists differ across trigger, attempts, adapter contracts, and admin surfaces.

**How this hurts users:** Multi-tenant hosts can get cross-tenant surprises; Oban-free users can compile/install into runtime failures; sensitive data rules are harder to reason about.

**How this hurts maintainers:** Bugs will be subtle and high-stakes.

**Fix first:** Make Oban policy honest, add tenant spine, normalize inbox APIs, and centralize recursive redaction.

**Do not over-fix:** Do not refactor all large modules before these behavioral seams are addressed.

## 4. Adoption Friction Audit

| Step | Friction | Missing/confusing info | Highest-leverage fix |
|---|---|---|---|
| 1. Landing on README | Medium-high | Value prop is present but too compressed | Rewrite README front door |
| 2. Understanding problem | Medium | Explainability is clear; local-first and lifecycle spine are underplayed | Add "why this exists" and "when to use" |
| 3. Deciding fit | High | Non-goals and alternatives are not visible | Add "Use this if / not if" |
| 4. Installing package | High | Version truth mismatch; optional packages unclear | Align package/changelog/docs |
| 5. Configuring | Medium | Repo config exists; prefix/Oban/limits unclear | Add config table and validation |
| 6. Running migrations | High | 31 tables go public by default; no schema isolation guidance | Prefix/schema install guide |
| 7. Adding supervision/routes | Medium | Installation covers supervision; admin route docs exist | Link from README and Golden Path |
| 8. First useful example | Low-medium | Golden Path is concrete | Keep, update anchors/status |
| 9. Debugging first error | Medium | Explain APIs exist; troubleshooting guide thin | Add setup troubleshooting |
| 10. Realistic app | Medium | Demo host is strong; package status unclear | Clarify demo vs published packages |
| 11. Customizing | Medium | Behaviours exist; contract tests not packaged | Ship public test helpers |
| 12. Upgrading later | High | Changelog/version/DB migration policy weak | Write upgrade policy and migration playbooks |

## 5. Production Readiness / SRE Audit

| Step | What works | Missing/risk | Risk reducer |
|---|---|---|---|
| Deploying | Phoenix/Ecto/Oban ecosystem fit | Prefix, Oban optionality, release docs | Deployment/Oban/prefix guide |
| Configuring safely | Repo config and adapter seams | Config validation gaps | NimbleOptions-backed runtime config |
| Observing normal behavior | Telemetry, traces, admin console | Telemetry catalog/runbook thin | Telemetry reference |
| Detecting failures | Durable attempts and statuses | Alert conditions not documented | SRE guide with alertable states |
| Debugging failures | `explain_delivery/1`, admin timelines | Search state not shareable in UI | URL-backed admin search |
| Recovering bad state | Recovery APIs/UI exist | Tenant spine incomplete for no-delivery events | Tenant on events/notifications |
| Handling scale/load | Indexes and pagination in places | Unbounded limits/N+1s | Bounded reads and query tests |
| Retries/timeouts | Oban/retry behavior exists | Oban not honestly required/optional | Decide and document dispatch mode |
| Data growth | Durable lifecycle is explicit | Retention/pruning not surfaced | Retention config/docs |
| Upgrading safely | Migration templates exist | No prefix/upgrade strategy | Versioned DB upgrade guide |

## 6. UI/UX/Design-System Audit

**Is UI useful enough to ship?** Yes, as an optional operator console, but not as a "polished" surface without a few trust fixes.

**Is it coherent enough to trust?** Mostly. The design system is scoped and coherent, but some lifecycle status classes are missing CSS mappings.

**Needs design-system cleanup before adoption?** Not a full redesign. Needs semantic and state-preservation cleanup.

Top UI fixes:
1. Add CSS mappings for all normalized lifecycle status classes.
2. Preserve trace/feed search state in URL params.
3. Add empty states to Health problem traces and dashboard definitions.
4. Add table captions and `scope="col"` headers.
5. Add skip link and recovery candidate `aria-pressed`/focus semantics.

Good enough:
- Scoped styles and tokens.
- Light/dark/system themes.
- Responsive shell.
- Visible focus styles.
- Reduced-motion handling.
- Host-mounted auth boundary.
- Redacted DTO/render contracts.

## 7. Maintainer Friction Audit

| Activity | Friction | Risk | Fix |
|---|---|---|---|
| Setup repo | Medium | Optional ecosystem deps add complexity | Document fast path vs full path |
| Run tests | High | Root suite currently fails and is dominated by installer subprocess tests | Fix isolation, split installer slow lane |
| Understand architecture | Medium | Large core modules hold many invariants | Add architecture map and later split modules |
| Make small change | Medium | Broad tests help but CI lanes are heavy | Path-gated verify lanes |
| Add feature | Medium-high | Tenant/prefix/reliability seams affect many paths | Resolve seams before more features |
| Debug user report | Medium | Explainability helps; package/version truth hurts | Version/support matrix |
| Review PR | High | Many gates and external pins | CI summary and local scripts |
| Cut release | Medium-high | Release automation exists; package truth is split | Align Release Please/changelog/tag policy |
| Support old versions | High | DB upgrade policy thin | API/DB stability document |
| Keep deps current | Medium | Optional deps and SHA pins | Dependabot/renovate policy and lane ownership |

## 8. GSD Sanity Check

**Probably overkill right now:**
- Internationalization.
- Dynamic per-tenant Postgres prefixes.
- Enterprise governance/process.
- Full visual redesign of admin.
- Broad OS/browser matrix for every PR.

**Not optional even for small OSS:**
- Release/package truth.
- README front door.
- Migration/install safety.
- Tenant/privacy boundaries.
- Local command parity.
- Green lint/test baseline.

**Accept rough edges:**
- Some advanced flow guides can be concise if they are honest.
- Admin UI can be utilitarian.
- Full load testing can wait until bounded query defaults exist.

**Rough edges that damage trust:**
- Version/docs/package mismatch.
- Public-schema sprawl without explicit choice.
- Optional dependency that is required at runtime.
- Current working tree failing local lint/tests.
- Stub docs linked as product docs.

**Clean up now that GSD produced working software:**
- Package/release truth.
- CI lane shape.
- README/docs IA.
- Storage prefix strategy.
- API/redaction/tenant seams.

**Do not prematurely formalize:**
- Dynamic multi-prefix tenancy.
- Heavy governance docs.
- Broad compatibility matrix beyond supported Elixir/OTP claims.

## 9. Top 10 Concrete Changes

| Rank | Area | Dimension improved | Why it matters | Impact | Effort | Risk reduction | Timing | Good looks like |
|---:|---|---|---|---|---|---|---|---|
| 1 | Release metadata/changelog/docs | Release trust | Users know what to install | High | Medium | High | Before showing strangers | Version, tag, changelog, docs constraints all agree |
| 2 | Storage prefix/migrations | DB hygiene | Host apps are respected | High | High | High | Before next storage release | New installs use `chimeway` schema; public is explicit legacy |
| 3 | README/front door | Adoption | Strangers understand fit quickly | High | Medium | High | Before showing strangers | README answers why/use/not-use/setup/trust |
| 4 | Current lint/test failures | QA/CI trust | No audit matters if tree is red | High | Medium | High | Before any merge/release | `mix ci.lint` and root fast test pass |
| 5 | CI gate shape/caches | Maintainer DX | Cuts wait and runner waste | High | Medium | Medium-high | Before Hex release | Fast PR gate plus full release gate |
| 6 | Oban policy | Reliability/DX | Optional means optional or docs say required | High | Medium | High | Before production-ready claim | Compile/runtime path is clear without surprises |
| 7 | Tenant spine/inbox scope | Host compatibility | Prevents cross-tenant leaks | High | High | High | Before production-ready claim | Events/notifications/inbox APIs have tenant story |
| 8 | Redaction centralization | Privacy/security | Sensitive data rules are coherent | High | Medium | High | Before public adoption | One recursive redaction module and contracts |
| 9 | Optional package publication/status | Adoption | Admin/inbox install docs become true | Medium | Medium | Medium | Before public docs push | Packages published or docs say path-only |
| 10 | Packaged contract tests | Extensibility | Adapter authors can verify integrations | Medium | Low-medium | Medium | Before adapter ecosystem push | Public `Chimeway.Testing.AdapterContract` style module |

