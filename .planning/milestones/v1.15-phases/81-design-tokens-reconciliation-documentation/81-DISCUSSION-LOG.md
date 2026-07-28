# Phase 81: Design Tokens (Reconciliation & Documentation) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-09
**Phase:** 81-design-tokens-reconciliation-documentation
**Mode:** assumptions
**Areas analyzed:** Semantic tier naming + selector/theming; `--cw-info` value + error/danger naming; tokens.json DTCG structure

## Assumptions Presented

### Semantic tier naming + copy-safe selector/theming
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `tokens.css` publishes `--cw-*` on global `:root` (no wrapper/`@scope`); prefix is the collision guard | Confident (research-resolved) | `chimeway_admin.css:101/131/176`; Shoelace/Pico/Open Props/Primer/GitLab precedent |
| Theming = `prefers-color-scheme: dark` system default + optional `[data-theme]` override, same `--cw-*` names, no `filter: invert()` | Confident | shipped light/dark/system triple; TOKEN-05 |
| Generalize `--cw-admin-*` → `--cw-surface-*`/`--cw-fg`/`--cw-fg-muted`/`--cw-border`/`--cw-accent`/`--cw-focus` | Confident | `chimeway_admin.css:67-78` alias layer |
| Copy already-neutral semantic vars verbatim (`--cw-status-*`, `--cw-control-*`, etc.) | Confident | `chimeway_admin.css:51-64,80-96` |

### `--cw-info` value + error/danger naming
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `--cw-info: var(--cw-blue)` alias (net-new primitive, DOCUMENTED), not a new hex | Confident | brand book `:612` info→blue vs shipped teal triad `:60-62`; TOKEN-04 pre-names it |
| Keep `--cw-danger`/`--cw-status-danger-*` verbatim; "error" is a documented role → danger | Confident | shipped `:18,:57-59`; TOKEN-01 verbatim rule outranks TOKEN-03 "error" wording |
| Log all named divergences (radius-sm, info triad, status-pill mapping, motion/z-index) as DOCUMENTED/DEFERRED; admin CSS untouched | Confident | TOKEN-04; `chimeway-brand-book.md:674/678/679` |

### tokens.json DTCG structure
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Nested groups; alias refs (`{color.primitive.teal}`), no duplicated hex | Confident | TOKEN-02/03; CSS `var()` model `:67-78` |
| Light/dark as sibling semantic groups (`color.semantic.light.*`/`.dark.*`); "system" CSS-only; no `$extensions`/value-objects/`$themes` | Confident (was Unclear; research-resolved) | DTCG Format Module 2025.10 |

## Corrections Made

No corrections — confirmation gate returned no response after 60s; proceeded on best judgment per project methodology (Low-Escalation Recommendation Default, One-Shot Recommendation Bias). All four assumptions were Confident and research-resolved; choices are reversible in a doc/asset-only phase, and the user can edit CONTEXT.md before planning.

## External Research

- **DTCG light/dark convention:** Recommend two sibling semantic groups (`color.semantic.light.*` / `color.semantic.dark.*`) aliasing one primitive tier — the only spec-valid, tool-agnostic, hand-authorable, diff-legible option. `$extensions` mode blobs, mode-keyed `$value`, and `$themes` manifests rejected (spec guidance / spec-invalid / build-time). Source: DTCG Format Module 2025.10 (https://www.designtokens.org/tr/drafts/format/), Resolver Module 2025.10 (https://www.designtokens.org/tr/drafts/resolver/), Style Dictionary DTCG notes (https://styledictionary.com/info/dtcg/).
- **Copy-safe distribution:** Recommend prefixed global `:root` + `prefers-color-scheme` + optional `[data-theme]` override; the `--cw-` prefix is the sanctioned collision guard; no wrapper/`@scope`. Source: Shoelace (https://shoelace.style/getting-started/customizing), Pico (https://picocss.com/docs/css-variables), Open Props (https://open-props.style/), Radix/Primer/GitLab Pajamas (https://design.gitlab.com/product-foundations/design-tokens-using/).
