# Phase 85: Repo Integration (README + HexDocs + Favicon Wiring) - Context

**Gathered:** 2026-07-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the real brand mark visible on the two surfaces adopters actually see — the **GitHub README** and **HexDocs** — through minimal, tightly-scoped edits that leave every v1.14 contract green. This is wiring already-shipped assets into config/markup, **not** authoring anything new.

**Requirements:** INTEG-01 (README lockup), INTEG-02 (ExDoc `:logo` + `:favicon`), INTEG-04 (scope + green gates). INTEG-03 (assets themselves) shipped in Phase 83.

**Scope anchor:** edits limited to the README header region, `mix.exs` `docs()` config, and — as a deliberately-declined option — `package() files:`. No runtime code, no new assets, no `chimeway_admin` changes, no touching the README's numbered snippet blocks (guarded by `readme_snippet_test`).
</domain>

<decisions>
## Implementation Decisions

### README lockup + theming
- **D-01:** Replace the plain `# Chimeway` text heading (README.md:1) with the real primary lockup rendered as a GitHub-native `<picture>` element that theme-swaps: `<source media="(prefers-color-scheme: dark)" srcset="brandbook/assets/logo/chimeway-logotype-inverse.svg">` with a default `<img src="brandbook/assets/logo/chimeway-logotype.svg" alt="Chimeway" width="380">`. Both are relative paths GitHub resolves natively; both are fixed-color assets (no `currentColor`), so `<img>`/`<picture>` is the correct rendering path.
  - *Rationale:* `chimeway-logotype.svg` uses dark ink `#102027` for the wordmark — near-invisible on GitHub dark mode. `chimeway-logotype-inverse.svg` (paper `#fffdf8` wordmark) exists precisely to cover the dark theme. Confirmed by user: `<picture>` theme-swap over a single `<img>`.
  - Width ~380px (the asset's native aspect is 381.7×90.4) — planner may tune within a sane header range.

### ExDoc `:logo` + `:favicon` wiring (INTEG-02)
- **D-02:** Add to `mix.exs` `docs()`: `logo: "brandbook/assets/logo/chimeway-mark.svg"` and `favicon: "brandbook/assets/favicon/favicon.svg"`. Use the **square** `chimeway-mark.svg` (48×48, fixed-color teal+ink) for the logo — ExDoc renders the logo in a small square sidebar slot; the wide logotype would render cramped.
  - *Rationale:* ExDoc 0.40.1 (mix.lock) natively supports SVG logo + favicon and copies both referenced files into the doc output `assets/` automatically. A `currentColor` mono asset would resolve to black in an `<img>` context and disappear in HexDocs dark mode — so use the fixed-color mark, not `mark-mono`.
- **D-03:** No `:assets` map is needed (ExDoc copies `:logo`/`:favicon` itself). No `ex_doc` version bump — `0.40.1` already satisfies SVG-logo support; leave the `~> 0.31` requirement as-is.

### package() files scope
- **D-04:** Do **not** add `brandbook/assets` to `package() files:` (leave the list `~w(lib priv guides CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs)` unchanged). `mix hex.publish docs` builds docs from the working tree and bakes the SVGs into the uploaded HTML, so the release tarball never needs them. Keeps the tarball minimal and INTEG-04's scope tightest.
  - *Rationale:* Confirmed by user. The only cost is that `mix docs` run against a downloaded hex tarball (a rare edge case) wouldn't render the logo — an acceptable tradeoff, and reversible by appending the assets later if that path ever matters.

### Scope + green-gate discipline (INTEG-04)
- **D-05:** Confine edits to (a) the README header region above the badges, and (b) the `mix.exs` `docs()` function. Do **not** touch the README's numbered snippet blocks ("1. Define a notifier" … "4. Explain the delivery") — they are the runtime contract asserted by `test/chimeway/integration/readme_snippet_test.exs`. `chimeway_admin` stays untouched.
- **D-06:** After the edits, re-run the v1.14 contract/gate suite and confirm green: `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs` (reads `mix.exs` + `README.md` as package-facing source — presence checks, unaffected by header/`docs()` additions), and `test/chimeway/integration/readme_snippet_test.exs`. Verify HexDocs rendering with a local `mix docs` build (logo in sidebar, favicon in tab).

### Claude's Discretion
- Exact README header markup details (centered vs left, whether an `<h1>`/`<a>` wraps the `<picture>` for an accessible heading + repo link, precise `width`) — left to the planner/executor within GitHub-Flavored-Markdown norms, provided `alt="Chimeway"` is present and the badges/tagline below stay intact.
- Whether to add a short HTML comment marking the header region as the in-scope edit boundary.

### Folded Todos
None — no pending todos matched this phase (`todo.match-phase 85` → 0).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 85 goal + success criteria (lines 165–180)
- `.planning/REQUIREMENTS.md` — INTEG-01/02/03/04 (lines 56–59); INTEG-03 already Complete (Phase 83)
- `README.md` — header region to edit is lines 1–9 (`# Chimeway` heading + badges); numbered snippet blocks below are OFF-LIMITS
- `mix.exs` — `docs()` at line 225 (add `logo:`/`favicon:`); `package()` at line 217 (leave `files:` unchanged per D-04)
- `brandbook/assets/logo/chimeway-logotype.svg` — primary lockup, light-mode (`#102027` ink, `#0e7c86` teal)
- `brandbook/assets/logo/chimeway-logotype-inverse.svg` — dark-mode lockup (`#fffdf8` wordmark, `#0e7c86` teal)
- `brandbook/assets/logo/chimeway-mark.svg` — square 48×48 mark for ExDoc `:logo`
- `brandbook/assets/favicon/favicon.svg` — ExDoc `:favicon`
- `test/chimeway/doc_contract_test.exs`, `test/chimeway/release_gate_contract_test.exs`, `test/chimeway/integration/readme_snippet_test.exs` — v1.14 contracts that must stay green
- `.planning/phases/84-html-brandbook-voice-component-states/84-CONTEXT.md` — upstream phase that finalized the asset filenames this phase consumes
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Logo family** — all fixed-color and `currentColor` variants already on disk under `brandbook/assets/logo/` (Phase 83). `chimeway-logotype.svg` (dark ink) + `chimeway-logotype-inverse.svg` (paper) are the light/dark README pair; `chimeway-mark.svg` (48×48 square) suits the ExDoc sidebar.
- **Favicon** — `brandbook/assets/favicon/favicon.svg` (+ `favicon.ico`, `apple-touch-icon.png`) shipped & verified in Phase 83 (83-VERIFICATION passed).
- **ExDoc 0.40.1** (mix.lock) — supports SVG `:logo` + `:favicon` natively; copies referenced files into doc output automatically.

### Established Patterns
- README currently has a **plain text** `# Chimeway` heading — there is no placeholder image to replace, so INTEG-01 is a net-add of the lockup markup.
- `release_gate_contract_test` treats `mix.exs` + `README.md` as package-facing source but only does **presence** assertions (aliases, gate commands, MAINTAINING references) — additive header/`docs()` edits don't disturb them.
- `readme_snippet_test` compiles/runs the README's numbered code blocks as the documented adopter path — the header edit must not touch those blocks.

### Integration Points
- `README.md` header → relative-path `<picture>`/`<img>` into `brandbook/assets/logo/`.
- `mix.exs` `docs()` → `:logo`/`:favicon` pointing at `brandbook/assets/` (build-time copy into HexDocs output).
- Phase 86's red-team `git diff --stat` will audit exactly these integration edits for scope leak.
</code_context>

<specifics>
## Specific Ideas

- Primary README lockup = the horizontal `chimeway-logotype*.svg` pair (not the mark alone) — adopters see the full wordmark on the repo front door.
- ExDoc sidebar logo = the square `chimeway-mark.svg` — icon-scale slot favors the mark over the wide lockup.
- Both README theme variants ship today; the `<picture>` swap needs no new assets.
</specifics>

<deferred>
## Deferred Ideas

- Adding `brandbook/assets` to `package() files:` so `mix docs` from a downloaded hex tarball also renders the mark — declined for v1.15 (D-04); a reversible append if that path ever matters.
- `chimeway_admin` re-theme with the new mark — out of scope (future ADMIN-RETHEME-01 milestone).
- OG/social preview wiring into the README or docs `<head>` — not in INTEG-01/02 scope for this phase.

### Reviewed Todos (not folded)
None — `todo.match-phase 85` returned 0 matches.
</deferred>
