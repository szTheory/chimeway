# Requirements: Chimeway v1.13 Storage Isolation and Upgrade Path

**Defined:** 2026-06-30  
**Core Value:** Every notification decision is explainable, so teams can reliably answer why a notification sent, failed, was deferred, or was suppressed.

## v1.13 Requirements

### Storage Prefix Contract

- [x] **PFX-01**: Host apps can configure Chimeway storage with `prefix: "chimeway"` for default new installs or `prefix: false` for explicit public-schema legacy mode.
- [x] **PFX-02**: Chimeway validates prefix config early and fails with actionable errors for unsupported prefix values.
- [x] **PFX-03**: Chimeway exposes one internal repo-option helper or equivalent contract so runtime code does not hand-roll prefix logic.
- [x] **PFX-04**: Existing public-schema installs remain supported without silent migration or changed runtime behavior when configured for legacy mode.

### Migration Generation

- [ ] **MIG-01**: `mix chimeway.gen.migrations` defaults to generating migrations for a dedicated `chimeway` schema.
- [ ] **MIG-02**: Generated prefixed migrations create the schema when needed and apply explicit prefixes to Chimeway tables, indexes, references, alters, drops, and raw SQL.
- [ ] **MIG-03**: The installer supports explicit public/legacy generation, such as `--prefix public` or equivalent, and emits unprefixed migrations for existing public-schema users.
- [ ] **MIG-04**: Golden fixture, idempotency, and migration contract tests prove prefixed and public generation are deterministic and reversible where practical.

### Runtime Prefix Propagation

- [ ] **RUN-01**: Trigger fanout persists events, notifications, deliveries, and attempts into the configured Chimeway prefix.
- [ ] **RUN-02**: Idempotency, duplicate detection, lifecycle reads, traces, and explainability queries resolve data from the configured prefix, not accidentally from `public`.
- [ ] **RUN-03**: Workflow progression, signal routing, digest buckets, policy/preferences, webhook ingress, dispatch workers, and string-source `insert_all` calls propagate prefix options correctly.
- [ ] **RUN-04**: Admin, inbox, trace, and recovery read/write surfaces use the configured prefix and remain tenant/redaction-safe.

### Upgrade and Compatibility

- [x] **UPG-01**: Existing public-schema installs have an explicit compatibility path that does not move data automatically.
- [ ] **UPG-02**: Documentation includes an optional manual move guide for teams that choose to move `public.chimeway_*` tables into the `chimeway` schema.
- [ ] **UPG-03**: Rollback and failure-mode guidance is documented clearly enough that operators know when the library can help and when the move is a manual database operation.

### Docs, Demo, and Gates

- [ ] **DOCS-01**: README, installation, golden path, and troubleshooting docs explain the default `chimeway` schema, explicit public mode, and copy-paste config.
- [ ] **DOCS-02**: Oban guidance states that Oban's prefix is separate from Chimeway's table prefix and shows safe test/production examples.
- [ ] **DEMO-01**: The demo host or equivalent example runs against the default `chimeway` schema and proves a trigger-to-trace flow.
- [ ] **GATE-01**: Named verify/CI gates cover prefixed install/runtime behavior and public-schema legacy compatibility.

## Future Requirements

### Storage and Tenancy

- **PFX-F01**: Dynamic per-tenant database prefixes for host apps that physically shard tenant data by Postgres schema.
- **PFX-F02**: A first-party automated production data move task for public-to-`chimeway` schema migrations.
- **PFX-F03**: Broader tenant spine redesign across events, notifications, deliveries, inbox, and admin APIs.

### Quality and Adoption

- **CI-F01**: Fast PR gate vs full release gate reshaping from the CI/CD audit.
- **DOCS-F01**: Full README/package/release truth cleanup beyond storage-prefix documentation.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dynamic per-tenant DB prefixes | Too much runtime/job/Oban/idempotency complexity for this milestone; tenant identity belongs in domain data first. |
| Silent migration of existing public data | Unsafe for production host apps; existing users must opt into any data move. |
| Moving host `schema_migrations` history | Copied host migrations should remain normal Phoenix/Ecto migrations. |
| CI/CD pipeline optimization | Important, but intentionally sequenced as v1.14 so storage behavior can land cleanly first. |
| Release/package truth and README rewrite beyond prefix-specific docs | Important, but intentionally sequenced as v1.15 except where storage docs require updates. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PFX-01 | Phase 73 | Complete |
| PFX-02 | Phase 73 | Complete |
| PFX-03 | Phase 73 | Complete |
| PFX-04 | Phase 73 | Complete |
| MIG-01 | Phase 74 | Pending |
| MIG-02 | Phase 74 | Pending |
| MIG-03 | Phase 74 | Pending |
| MIG-04 | Phase 74 | Pending |
| RUN-01 | Phase 75 | Pending |
| RUN-02 | Phase 75 | Pending |
| RUN-03 | Phase 75 | Pending |
| RUN-04 | Phase 75 | Pending |
| UPG-01 | Phase 73 | Complete |
| UPG-02 | Phase 76 | Pending |
| UPG-03 | Phase 76 | Pending |
| DOCS-01 | Phase 76 | Pending |
| DOCS-02 | Phase 76 | Pending |
| DEMO-01 | Phase 76 | Pending |
| GATE-01 | Phase 76 | Pending |

**Coverage:**
- v1.13 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0

---
*Requirements defined: 2026-06-30*
*Last updated: 2026-06-30 after v1.13 milestone initialization*
