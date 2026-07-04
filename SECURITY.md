# Security Policy

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

To report a security issue:
1. Use [GitHub's private vulnerability reporting](https://github.com/jonlunsford/chimeway/security/advisories/new), or
2. Email `security@jonlunsford.com` with a description of the issue and steps to reproduce.

We aim to acknowledge reports within **72 hours**.

## Disclosure Policy

We follow coordinated disclosure: no public CVE or announcement until a fix is ready and tested. We will credit reporters in the release notes unless they prefer to remain anonymous.

## Dependency Advisories

CI runs `mix hex.audit` (via `mix ci.audit`) on every push and pull request. As
of 2026 it is configured **advisory-only** (`continue-on-error`) so that
externally-disclosed CVEs with no available upstream fix do not wedge the merge
pipeline (the lint job feeds the required `pr-gate` check). New advisories are
still surfaced in CI logs and reviewed here.

### Accepted-risk (pending upstream fix)

These advisories affect transitive dependencies already pinned to the latest
version their constraints allow; no patched release exists yet. Re-run
`mix hex.audit` to check current status.

| Package | Version | Advisories | Source | Notes |
|---------|---------|------------|--------|-------|
| `decimal` | 2.4.1 | CVE-2026-32686 (MEDIUM) — unbounded exponent DoS | via `ecto` | Latest published; no fixed release yet. |
| `hackney` | 1.25.0 | CVE-2026-47069 / 47071 / 47075 / 47076 (LOW–HIGH) — CRLF / SSRF / SOCKS5 | via optional `accrue → braintree`, `tzdata` | Latest published; no fixed release yet. Only pulled when the optional Accrue integration or tzdata HTTP refresh is used. |

### Resolved by dependency bump (2026-07-03)

Cleared during a repo-hygiene sweep by bumping to patched versions:

- `plug` 1.19.2 → 1.20.2 (CVE-2026-54892)
- `mint` 1.8.0 → 1.9.0 (CVE-2026-48861 / 48862 / 49753 / 49754)
- `req` 0.5.18 → 0.6.2 (CVE-2026-49755 / 49756)

When upstream patches for `decimal` / `hackney` ship, bump them, drop the
accepted-risk row, and consider restoring `ci.audit` to a blocking step.
