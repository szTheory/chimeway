# Security Policy

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

To report a security issue:
1. Use [GitHub's private vulnerability reporting](https://github.com/szTheory/chimeway/security/advisories/new), or
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

### Accepted risk (pending upstream compatibility)

These advisories affect transitive dependencies already pinned to the latest
version their constraints allow. Re-run `mix hex.audit` to check current
status; the accepted risk is documented here, not hidden in a checked-in audit
ignore.

| Package | Version | Advisories | Source | Notes |
|---------|---------|------------|--------|-------|
| `hackney` | 1.25.0 | CVE-2026-47069 / CVE-2026-47071 / CVE-2026-47075 / CVE-2026-47076 (LOW–HIGH) — CRLF / SSRF / SOCKS5 | `accrue → braintree → hackney`; `threadline → hackney`; `tzdata → hackney` | Fixed in 4.0.1. Braintree 0.16 and Threadline 0.9 constrain the shared graph to Hackney 1.x. Chimeway adds no attacker-controlled URL or SOCKS5 configuration entrypoint. Remove this exception when Accrue/Braintree and Threadline permit Hackney 4.0.1+ and the integration gates pass. |

### Cowlib 2.20.0 scanner-feed exception

The demo's raw `mix hex.audit` currently maps Cowlib 2.20.0 to
CVE-2026-43971, CVE-2026-43969, and CVE-2026-43966. The authoritative GitHub
advisory range for GHSA-g2wm-735q-3f56 is `>= 2.9.0, <= 2.16.1`, while
GHSA-w4f7-4cxr-rv3c affects Cowboy `< 2.16.0` and Gun rather than Cowlib
2.20.0. Cowlib 2.20.0 also contains the upstream fix ancestry recorded for
CVE-2026-43971. These three findings are a bounded feed-mapping exception for
Cowlib 2.20.0 only; future Cowlib findings remain blocking.

### Resolved by dependency bump (2026-07-03)

Cleared during a repo-hygiene sweep by bumping to patched versions:

- `plug` 1.19.2 → 1.20.2 (CVE-2026-54892)
- `mint` 1.8.0 → 1.9.0 (CVE-2026-48861 / 48862 / 49753 / 49754)
- `req` 0.5.18 → 0.6.2 (CVE-2026-49755 / 49756)

When compatible upstream releases permit Hackney 4.0.1+, bump it, drop the
accepted-risk row, and consider restoring `ci.audit` to a blocking step.
