# v1.12 Quality Readiness Synthesis and Follow-On Roadmap

**Date:** 2026-06-30  
**Current status:** audit artifacts produced for planning; production code not changed

## Executive Synthesis

Chimeway's core engine is not the weak part. The weak parts are the seams that make serious OSS adoption safe:

1. Release/package truth.
2. Database/schema ownership.
3. CI/local reproducibility and cost.
4. README/docs front door.
5. Tenant/privacy/reliability seams.

The project should stop adding product breadth until these seams are cleaned up. The next implementation work should be sequenced, not bundled into one giant refactor.

## Top 10 Ranked Changes

| Rank | Change | Area | Impact | Effort | Risk reduction | Timing | Done when |
|---:|---|---|---|---|---|---|---|
| 1 | Align release/package truth | Release/docs | High | Medium | High | Before showing strangers | Version, tag, changelog, manifest, README, docs constraints agree |
| 2 | Re-green current working tree | QA/CI | High | Medium | High | Before any release | `mix ci.lint` and root fast test pass |
| 3 | Default new installs to `chimeway` DB schema | Storage/host respect | High | High | High | Next storage milestone | Prefixed install works end-to-end; public is explicit legacy |
| 4 | Rewrite README/front door | Adoption | High | Medium | High | Before public push | README answers what/why/use/not-use/setup/trust |
| 5 | Split fast PR gate from full release gate | CI/DX | High | Medium | Medium-high | Before heavy PR flow | PRs are fast; release still runs full sweep |
| 6 | Make Oban policy honest | Reliability/DX | High | Medium | High | Before production-ready claim | Oban is either required or truly optional |
| 7 | Add tenant spine and tenant-scoped inbox/admin APIs | Host compatibility | High | High | High | Before multi-tenant marketing | Tenant isolation is durable and tested |
| 8 | Centralize recursive redaction | Privacy/security | High | Medium | High | Before sensitive-flow marketing | One redaction module used by trigger/attempt/telemetry/admin |
| 9 | Package public adapter contract tests | Extensibility | Medium | Low-medium | Medium | Before adapter ecosystem push | External adapters can import test contracts |
| 10 | Bound admin/inbox reads and fix N+1 digest queries | Performance | Medium | Medium | Medium | Before high-volume production | Limits validated; hot paths measured |

## Proposed Milestone Sequence

### v1.13 Storage Isolation and Upgrade Path

Goal: make Chimeway a respectful guest in host databases.

Phases:
1. **Phase 73: Storage Prefix Contract**
   - Add validated `config :chimeway, prefix: "chimeway" | false`.
   - Add internal repo option helper.
   - Decide public/legacy semantics.
   - Tests for config validation and repo opts.

2. **Phase 74: Prefixed Migration Generator**
   - Update `mix chimeway.gen.migrations`.
   - Generate default prefixed migrations.
   - Support explicit public/legacy generation.
   - Update golden fixtures.
   - Qualify raw SQL.

3. **Phase 75: Runtime Prefix Propagation**
   - Thread repo opts through Trigger, Deliveries, Workflows, Digests, Policy, Inbox, Signal, Webhooks, Admin, Traces.
   - Fix string-source `insert_all`.
   - Add prefixed integration suite.

4. **Phase 76: Prefix Docs and Demo Host**
   - Update README, Installation, Golden Path, Oban integration, demo host config.
   - Add public legacy upgrade/move guide.
   - Add doc-contracts for prefix guidance.

Acceptance:
- New install uses `chimeway` schema by default.
- Explicit public mode remains green.
- Prefix tests cover trigger, trace, inbox, workflow, digest, webhook, and recovery.
- `mix ci.verify_gates` includes prefix doc contracts.

### v1.14 CI/CD and Contributor DX Optimization

Goal: keep the quality signal, cut waste, and make failures reproducible.

Phases:
1. **Phase 77: Green Baseline and CI Telemetry**
   - Fix current format/test failures.
   - Add job summaries for versions, cache hits, slow tests, timings.
   - Document measured baseline.

2. **Phase 78: Cache and Script Cleanup**
   - Add nested caches for demo/admin/inbox.
   - Add npm and Playwright caches.
   - Move Sigra/admin/release polling inline scripts into local scripts or Mix tasks.

3. **Phase 79: Gate Shape and Test Cost**
   - Define fast PR aggregate vs full release aggregate.
   - Path-gate ecosystem/admin/inbox/installer lanes.
   - Keep full sweep on release/main/schedule.
   - Move or optimize expensive installer subprocess tests.

Acceptance:
- Fast PR gate is materially faster.
- Full release gate remains at least as trustworthy.
- CONTRIBUTING and MAINTAINING local commands match CI.
- No required-check pending traps.

### v1.15 Adoption, Release Truth, and API Hardening

Goal: make Chimeway understandable, installable, and supportable by strangers.

Phases:
1. **Phase 80: Release and Package Truth**
   - Align version, changelog, manifest, docs constraints.
   - Decide sibling package publication/status.
   - Remove package artifacts like tracked `.DS_Store`.

2. **Phase 81: README and Docs IA**
   - Rewrite README.
   - Finish or delink stub flow guides.
   - Fix stale anchors.
   - Add README IA doc-contract tests.

3. **Phase 82: API/Privacy/Reliability Seams**
   - Make Oban required or truly optional.
   - Normalize inbox return types.
   - Add bounded pagination defaults.
   - Centralize recursive redaction.
   - Package adapter contract tests.

4. **Phase 83: Tenant Spine Decision**
   - Add tenant ID to event/notification spine or explicitly document recipient identity requirements.
   - Update inbox/admin APIs to require/accept tenant scope.
   - Add multi-tenant regression tests.

Acceptance:
- Stranger can install from README without version/package ambiguity.
- No stub docs are linked as current product docs.
- Public APIs have stable return shapes.
- Tenant and redaction behavior are test-backed.

## What Not To Do Next

- Do not add another ecosystem integration before storage/release/docs cleanup.
- Do not build dynamic DB-prefix tenancy.
- Do not delete high-value tests only because they are slow.
- Do not rewrite the admin UI visually before fixing URL state and accessibility semantics.
- Do not claim production-ready while current tree is red.

## Suggested Immediate Next Command

Start with the storage milestone if the goal is architectural cleanliness:

```bash
$gsd-new-milestone v1.13 Storage Isolation and Upgrade Path
```

Start with CI if maintainer velocity is the bottleneck:

```bash
$gsd-new-milestone v1.14 CI/CD and Contributor DX Optimization
```

Recommended order: **v1.13 -> v1.14 -> v1.15**. Storage decisions affect docs, tests, CI, and upgrade policy; do that before polishing the public story too heavily.

