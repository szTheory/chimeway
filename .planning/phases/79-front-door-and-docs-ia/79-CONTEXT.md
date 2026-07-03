# Phase 79: Front Door and Docs IA - Context

**Gathered:** 2026-07-03 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Rewrite the public first-hop docs so a new adopter can understand Chimeway's local-first
ownership model, explainability contract, host boundaries, non-goals, optional surfaces, install
flow, and traceable trigger-to-explainability path — and can verify that story from the public
package/docs surface.

**In scope:** README rewrite (DOCS-14/15), accurate public adoption snippets (DOCS-16), stub/stale
guide cleanup in the first-hop path (DOCS-17), and a clean-consumer smoke path that follows the
final public docs (ADPT-01).

**Out of scope:** New product/runtime capabilities, publishing sibling packages, and the
verification-architecture / CI-DX work (Phase 80). Completing the delinked flow stubs is backlogged,
not done here.
</domain>

<decisions>
## Implementation Decisions

### README Rewrite (DOCS-14 / DOCS-15)

- **D-01:** Rewrite `README.md` as an **additive superset** of the current file, not a from-scratch
  replacement. Lead with the local-first embedded notification value proposition and explainability
  promise, then add four decision sections: **When to use / use cases**, **Non-goals**,
  **Host-owned boundaries**, and **Optional surfaces (preview status)**.
- **D-02:** Preserve every string the doc contract already hard-requires: `mix chimeway.gen.migrations`,
  the `Chimeway.trigger` Quick Start snippet, `idempotency_key`, `tenant_id`, the `golden-path` link,
  the `{:chimeway, "~> 1.0"}` install constraint, the canonical CI badge URL, and all six
  storage-prefix phrases (`prefix: "chimeway"`, `prefix: false`, "new isolated Chimeway schema",
  "existing public-schema legacy install", "unprefixed tables", "does not move data"). Do not
  introduce any forbidden strings the contract guards against (`identity:`, `mix chimeway.install`,
  `Chimeway.Workflow`, `resolve_recipients`, storage-drift phrases).
- **D-03:** Frame `chimeway_admin` and `chimeway_inbox` in the "Optional surfaces" section as in-repo
  preview/path packages — never as published Hex installs (`{:chimeway_admin, "~> 1.0"}` is
  forbidden). Consistent with locked Phase 77/78 decisions.

### Canonical Adoption Snippets (DOCS-16)

- **D-04:** The canonical snippet set shows the **real public API**, verified against `lib/chimeway.ex`
  and `lib/chimeway/traces.ex`:
  1. A notifier module exposing `notification_key/0` (+ `version/0`) — the **stable notification key**
     is this string, not a raw argument to `trigger`.
  2. `Chimeway.trigger(Notifier, params, idempotency_key: ..., tenant_id: ...)` — both options always
     present (trigger requires `tenant_id`).
  3. `config :chimeway, prefix: "chimeway"` for the configured storage prefix.
  4. Trace/explainability lookup via **`Chimeway.Traces.explain_delivery(delivery_id)`** (there is no
     `Chimeway.explain_delivery` delegate); `delivery_id` comes from the trigger result trace.

### Stub / Stale Guide Disposition (DOCS-17)

- **D-05:** **Delink** the three 9-line Flows stubs — `guides/flows/async-dispatch.md`,
  `guides/flows/policy-and-preferences.md`, `guides/flows/trigger-to-delivery.md` — from both
  `README.md` and `mix.exs` `docs.extras`. None is content-enforced by a contract, so removal breaks
  nothing. Backlog their completion for a later phase (golden-path already covers the
  trigger→delivery lifecycle). Confirmed by user over completing them.
- **D-06:** Fix stale legacy `github.com/jonlunsford/chimeway` URLs that survive in first-hop guides
  (notably `guides/introduction/golden-path.md` L167/171/191/192) → canonical
  `https://github.com/szTheory/chimeway`.

### ADPT-01 Smoke Path (packaged-doc truth)

- **D-07:** Prove the clean-consumer story by **extending the existing unpacked-Hex artifact test**
  (`test/chimeway/release_gate_contract_test.exs`, "unpacked Hex package artifact truth" describe
  block ~L466-531, which already runs `mix hex.build --unpack` under prod). Assert the *packaged*
  README carries the new DOCS-14/15/16 invariants (value prop, non-goals, host boundary,
  optional-surface status, and the `Chimeway.Traces.explain_delivery` trace snippet). Confirmed by
  user over standing up a new runnable fresh-host harness.
- **D-08:** Keep `examples/chimeway_demo_host` (`mix demo.up --check`) as the runtime companion, not
  the primary ADPT-01 anchor.

### Contract Enforcement

- **D-09:** Pin the rewrite by **extending the existing "README install doc contract" block** in
  `test/chimeway/doc_contract_test.exs` with new required markers (value-prop phrase, non-goals
  heading, host-boundary phrase, optional/preview-surface phrase, and a
  `Chimeway.Traces.explain_delivery` trace-snippet requirement), reusing the per-trigger
  `idempotency_key`/`tenant_id` invariant already applied to golden-path. Do **not** create a new
  test file — docs/release truth is treated as executable ExUnit contracts in this project.

### Claude's Discretion

Downstream agents may choose the narrowest implementation shape satisfying these decisions —
exact section wording, snippet phrasing, and the specific asserted marker strings — provided the
contract-required strings in D-02 survive and the API surface in D-04 stays accurate.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 79 goal and success criteria
- `.planning/REQUIREMENTS.md` — DOCS-14, DOCS-15, DOCS-16, DOCS-17, ADPT-01
- `.planning/phases/78-release-and-package-truth/78-CONTEXT.md` — locked root-only package model,
  canonical URL, sibling preview status, executable-doc-contract pattern
- `README.md` — the file being rewritten (current: thin, 70 lines)
- `mix.exs` — `docs.extras` (L230-255) and `package` (L217-223) config
- `lib/chimeway.ex` — public entrypoint (`trigger/3`; no trace delegate)
- `lib/chimeway/traces.ex` — `explain_delivery/2` (L135), `find_traces_for_recipient/2` (L69),
  `find_traces_by_correlation_id/2` (L104)
- `test/chimeway/doc_contract_test.exs` — README install contract (L1330-1391), golden-path
  per-trigger invariant (L1247-1261)
- `test/chimeway/release_gate_contract_test.exs` — unpacked-artifact truth (L466-531), canonical-URL
  guard (L344-374)
- `guides/introduction/golden-path.md` — canonical snippet pattern; stale `jonlunsford` URLs to fix
- `examples/chimeway_demo_host/README.md` — `mix demo.up --check` runtime companion
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Executable doc-truth contracts** already govern every first-hop doc via string assertions in
  `test/chimeway/doc_contract_test.exs` — extend, don't replace.
- **Unpacked-Hex artifact test** in `release_gate_contract_test.exs` already runs `mix hex.build
  --unpack` under prod and asserts packaged README/guide truth — the ADPT-01 insertion point.
- **`mix verify.parity`** (mix.exs L91-93) already proves the package files whitelist survives packaging.
- **Golden-path guide** (`guides/introduction/golden-path.md`) is the working reference for the
  DOCS-16 snippet chain (notifier `notification_key` → `trigger` → prefix → `explain_delivery`).

### Established Patterns

- Public API is data-first: `Chimeway.trigger/3` takes a notifier **module** + params; the stable key
  lives in the notifier's `notification_key/0` callback.
- Trace lookups are NOT delegated from `Chimeway` — they live on `Chimeway.Traces`.
- `trigger/3` requires `tenant_id` (returns `{:error, :missing_tenant_id}` if omitted).

### Integration Points

- `mix.exs` `docs.extras` list drives HexDocs IA — delinking stubs means editing both README links
  and this list.
- `mix ci.verify_gates` is the release-blocking lane that runs the doc/release contracts; the rewrite
  must keep them green.
</code_context>

<specifics>
## Specific Ideas

- Stable notification key must be shown as the notifier's `notification_key/0` string
  (e.g. `"welcome_user"`), not a raw string passed to `trigger`.
- Trace snippet must reference `Chimeway.Traces.explain_delivery/1`, using a `delivery_id` sourced
  from the trigger result trace.
</specifics>

<deferred>
## Deferred Ideas

- **Complete the three Flows stub guides** (`async-dispatch`, `policy-and-preferences`,
  `trigger-to-delivery`) as full reference pages — backlogged; delinked from the first-hop path this
  phase. A future docs phase can write them out if the lifecycle deserves its own reference beyond
  golden-path.
- **Runnable fresh-host consumer harness** (clean project runs install→migrate→trigger→explain from
  public docs) — deferred in favor of packaged-doc-truth for ADPT-01; candidate if a stronger runtime
  guarantee is ever required.

### Reviewed Todos (not folded)

None — no pending todos matched this phase.
</deferred>
