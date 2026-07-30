---
phase: 91
slug: quality-supply-chain-polish
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-07-30
---

# Phase 91 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Mitigations were verified against **live Phase 91 CI runs** (push 30556372077,
> nightly-dispatch 30556417111, PR 30556437942 — all on fe3f732), not only by grep.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| repo → CI runner | `.tool-versions` (repo-controlled) is read by `setup-beam` to select the installed toolchain | toolchain version strings |
| workflow → GITHUB_TOKEN | the token's declared `permissions:` scope bounds what any action/step in `ci.yml` can do against the repo/actions API | repo + actions API access |
| resolve_tiers → gate jobs | per-event tier flags drive which lanes run and which gate enforces them; a wrong flag can make a required lane silently skip | CI pass/fail authority |
| Dependabot service → repo | automated dependency-update PRs are proposed changes, untrusted until human-reviewed and merged | dependency version bumps |
| Hex registry → build | `mix deps.get` pulls `mix_audit` (dev/test) into the dependency tree | build-time dependency code |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-91-01 | Repudiation / silent failure | `.tool-versions` ↔ setup-beam resolution | high | mitigate | `version-type: strict` fails loudly vs. silent downgrade; **QUAL-01 live**: all 14 version-file jobs resolved identical `Elixir 1.19.5` / OTP `27.3.4.15` | closed |
| T-91-02 | Tampering | `.tool-versions` committed to repo | low | accept | Same review + branch-protection surface as any repo file; no added exposure | closed |
| T-91-SC | Tampering | `mix_audit` dep + Dependabot SHA/dep bumps | high | mitigate | `mix_audit` `~> 2.1`, `only: [:dev, :test]`, `runtime: false` (never in shipped lib), `[VERIFIED: hex.pm]`; Dependabot bumps SHA-pinned actions in place → every change is a reviewable PR, pinning retained | closed |
| T-91-03 | Tampering | stale / compromised pinned action SHA | high | mitigate | Dependabot `github-actions` ecosystem opens grouped weekly SHA-bump PRs; **QUAL-02 live**: config on default branch, both ecosystems declared, schema-valid | closed |
| T-91-04 | Information Disclosure | vulnerable transitive Hex dep | medium | accept | `mix deps.audit` advisory scan surfaces CVEs in job output; advisory-only by explicit decision (D-12 / `DEF-AUDIT-BLOCK`) — see Accepted Risks. Below `high` block threshold → non-blocking | closed |
| T-91-05 | Elevation of Privilege | `GITHUB_TOKEN` default scope in `ci.yml` | high | mitigate | Top-level `permissions: contents: read` revokes broad default; only obs-summary jobs escalate to `actions: read`; **zero `: write` scopes in ci.yml** (grep-confirmed). **QUAL-03 live**: 0 checkout failures / 26 job-instances (contents:read), `/jobs` timing query renders (actions:read) | closed |
| T-91-06 | Repudiation / silent failure (vacuous pass) | `test_floor_1_17` gating on push | high | mitigate | Floor wired into `ci-gate` `needs`/`env`/aggregate; `run_floor` == ci-gate's `if:` (byte-identical) so the floor never `skipped` while ci-gate evaluates; `aggregate-gate.sh` treats any non-`success` (incl. skipped) as fail. **QUAL-05 live**: push → floor + ci-gate success; PR → floor + ci-gate skipped, pr-gate green | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-91-01 | T-91-02 | `.tool-versions` carries no exposure beyond any other repo-controlled config; guarded by the same review + branch-protection surface | project owner | 2026-07-30 |
| AR-91-02 | T-91-04 | Advisory scan (`mix deps.audit` + `hex.audit`) is intentionally advisory-only (`continue-on-error: true`) per decision D-12 / deferred `DEF-AUDIT-BLOCK`; disclosed CVEs are surfaced in CI output (hackney/decimal confirmed) but do not block. Severity medium, below the `high` block threshold | project owner | 2026-07-30 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-30 | 7 | 7 | 0 | gsd-secure-phase (orchestrator, live-CI verified) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-30
