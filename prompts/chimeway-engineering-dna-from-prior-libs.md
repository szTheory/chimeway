# Chimeway engineering DNA — inherited from prior Elixir/Phoenix OSS libs

> **Purpose:** Seed context for GSD and implementation: **what to copy verbatim** from sibling repos, **what Chimeway must translate** for notifications, and **what not to repeat**. This is maintainer intent, not a legal spec.
>
> **Full convergent prose (checklist expansion):** Read **`/Users/jon/projects/rulestead/prompts/rulestead-engineering-dna-from-prior-libs.md`** — especially §2 (convergent DNA), §6 (gotchas), §8 (source map). Chimeway does not fork that document; this file **indexes and specializes** it.

**Source corpus (patterns, not product scope):** `accrue`, `scrypath`, `lattice_stripe`, `sigra`, `mailglass`, `lockspire`, `rulestead`, `threadline` — same family as rulestead’s DNA doc lists.

---

## 1. Convergent OSS DNA — adopt unless Chimeway has a specific reason not to

Treat the rulestead §2 checklist as **default true**. Short form:

| Area | Adopt |
|------|--------|
| Version SSOT | `@version` in `mix.exs`, `release-please-manifest.json`, `docs: [source_ref: "v#{@version}"]` |
| Hex `files:` whitelist | Explicit `~w(lib priv guides ...)`; never ship `test/example/`, `.planning/`, `prompts/` on Hex |
| Root hygiene | README, CHANGELOG, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, **MAINTAINING** (release runbook) |
| API discipline | `Chimeway` as public surface; `@moduledoc false` for internals; **`api_stability.md`** when API is public |
| Errors | Root `%Chimeway.Error{}` + typed sub-errors; **closed `:type` atoms**; pattern match structs, not strings; `:cause` / raw payload excluded from encoders where needed |
| Telemetry | `Chimeway.Telemetry.span/3` → `:telemetry.span/3`; **4-level** `[:chimeway, :domain, :resource, :start\|stop\|exception]`; no PII in meta |
| CI lanes | Lint (format, compile WAE, credo strict, docs WAE, hex.audit); test matrix Elixir/OTP; Postgres service + healthcheck; concurrency group; path filters; cache keys; SHA-pinned actions |
| Release | Conventional Commits + Release Please; PR title semantic lint; post-publish **`mix verify.*`** trio (workspace clean, publish poll + consumer compile, parity diff) when publishing; optional daily drift issue |
| Testing | Sandbox; Mox for behaviours; **Fake / in-memory dispatcher** as merge gate for dispatch logic; golden-diff **installer** when `mix chimeway.install` exists |
| Docs | ExDoc `main`, grouped extras, **doc-contract tests**; **three-folder guides** (`introduction/`, `flows/`, `recipes/`); **cheatsheet.cheatmd** |
| Credo | Project-local checks: e.g. no raw Swoosh/HTTP send outside `Chimeway.Dispatch`; no PII in telemetry; tenancy scope on queries |
| GSD | `.planning/` shape: PROJECT, ROADMAP, REQUIREMENTS, STATE, phases with VERIFICATION / VALIDATION; REQ IDs in commits |

**Threadline addendum:** Verification is a **product surface** — cite `mix verify.phaseNN` or aliases in CONTRIBUTING, not folklore.

---

## 2. Chimeway domain translation (notification-specific)

### 2.1 Stable identity

- Persist **`notification_key`** (string) as the stable type identifier — **not** Elixir module names (rename-safe). Modules are for code organization only.
- Compile-time checks: missing key, missing renderer, missing URL host for link generation, missing adapter config — **fail loud** in dev/test.

### 2.2 Data spine (conceptual)

Align with the research brief’s pipeline:

`domain_event → notifier definition → event row → recipients → per-recipient notification/inbox → per-channel delivery → attempts / telemetry → admin trace`

Keep **read/seen/archived** explicit (`read_at`, `seen_at`, …) — do not equate “rendered in UI” with “read.”

### 2.3 Dispatch modes

Per channel (or per step): **`sync` | `job` | `inline_db`** (names TBD in planning), with Oban as the **blessed** production job engine and a **minimal sync/test** path for onboarding (mailglass / lattice patterns: optional deps gateway).

### 2.4 Adapters

- **Email:** wrap Swoosh; do not compete with it.
- **Jobs:** Oban-first; document transactional enqueue with Ecto.
- **Push / SMS / Slack / webhook:** behaviour-based adapters; **provider SDKs stay optional** deps; tests use Fake.

### 2.5 Policy and suppression

- Recipient-aware routing (Laravel-style `via` analogue).
- **Policy runs** at safe points (before enqueue + before perform) for quiet hours, rate limits, unsubscribes.
- **On-demand recipients** (email string, phone, webhook URL) as first-class routing targets when product requires it.

### 2.6 Explainability (product differentiator)

Every merge-blocking feature should answer: **“What row or log line proves this step happened?”** Reserve UI concepts for admin doc: timeline, attempt replay, correlation id, redacted payload view.

---

## 3. Package shape — recommendation

| Option | When |
|--------|------|
| **Single `chimeway` package** | v0.1 if API is volatile; admin LiveViews live under `lib/chimeway/admin/` behind optional deps (sigra-style). |
| **`chimeway` + `chimeway_admin` sibling** | When admin UI deps (LiveView assets, heavy) should not bloat every API-only consumer (accrue / mailglass pattern, linked Release Please). |

**Recommendation for Chimeway’s stated goals (batteries + admin):** Plan for **`chimeway` + `chimeway_admin`** once the core schemas and dispatch contract stabilize; **start v0.1 as single package** if it reduces planning drag, with a **documented extraction** milestone before 1.0. Either way, **Hex `files:`** must never accidentally ship dev apps or prompts.

---

## 4. What worked elsewhere (keep)

- **scrypath:** post-publish verify trio, daily drift cron + rolling issue, doc-contract tests, milestone audit YAML discipline.
- **lattice_stripe:** `api_stability.md`, cheatsheet, drift monitoring mindset (translate: “provider response shape drift” or adapter contract tests).
- **sigra:** mountable LiveView admin, installer + **golden-diff** stdout/tree, `CONVENTIONS.md`, feature installer behaviours.
- **accrue / mailglass:** sibling admin package, append-only style ledgers where audit matters, browser/UAT CI lanes when UI ships.
- **mailglass:** Fake adapter as release gate, optional-deps gateway, tenancy behaviour.
- **rulestead / lockspire:** topical prompt splits for security, operator IA, host integration seam — reuse **structure**, not OAuth domain text.

---

## 5. What did not work or to avoid

- **Module names in DB** as notification types (Noticed lesson — see research brief).
- **Hidden heavy tests** excluded from default `mix test` without contributor-visible policy (threadline / sigra lesson).
- **Merge-theater** validation markers; deferred Nyquist debt must have owner + trigger (sigra phase hygiene).
- **Opaque macros** with no expansion story — Chimeway should stay inspectable.

---

## 6. Pointers for topical prompts in this folder

- Admin and trace UX → `chimeway-admin-ui-and-operator-ia.md`
- CI, verify scripts, lanes → `chimeway-release-engineering-and-ci.md` + rulestead release doc
- Tests, golden installer, Playwright later → `chimeway-testing-and-e2e-strategy.md`
- Host app, Plug, tenancy → `chimeway-host-app-integration-seam.md`

---

## 7. Shared deep-research files (do not duplicate)

The seven `*-best-practices-deep-research.md` files: see **`prompts/prior-art/SOURCE-CANONICAL.md`**.
