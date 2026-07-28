# Phase 85: Repo Integration (README + HexDocs + Favicon Wiring) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-27
**Phase:** 85-repo-integration-readme-hexdocs-favicon-wiring
**Mode:** assumptions
**Areas analyzed:** README lockup + theming, ExDoc logo/favicon wiring, package() files scope, contract-test/scope safety

## Assumptions Presented

### README lockup + theming
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Replace `# Chimeway` text heading with a `<picture>` swapping `chimeway-logotype.svg` (light) ↔ `chimeway-logotype-inverse.svg` (dark), relative paths | Likely | README.md:1 is plain text (no placeholder); logotype ink `#102027` vs inverse wordmark `#fffdf8` (grep of both SVGs); both fixed-color → `<img>`/`<picture>` correct |

### ExDoc logo/favicon wiring (INTEG-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `docs()` gets `logo: chimeway-mark.svg` (square 48×48) + `favicon: favicon.svg` | Likely | mix.exs:225 `docs()` has no logo/favicon keys; `chimeway-mark.svg` viewBox 24×24 @48px square; ex_doc 0.40.1 (mix.lock) supports SVG logo/favicon + auto-copies |
| No `:assets` map, no `ex_doc` version bump | Likely | ExDoc copies `:logo`/`:favicon` itself; 0.40.1 already resolved |

### package() files scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Do NOT add `brandbook/assets` to `package() files:` | Likely | mix.exs:219 files list; `mix hex.publish docs` bakes SVGs into uploaded HTML, tarball doesn't need them; requirement marks this "optional" |

### Contract-test / scope safety (INTEG-04)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Edits confined to README header + `docs()`; snippet blocks, chimeway_admin, v1.14 gates stay green | Confident | `readme_snippet_test` runs numbered blocks; `release_gate_contract_test` does presence-only asserts on mix.exs/README (additive edits safe) |

## Corrections Made

No corrections — both escalated decisions confirmed as recommended:
- **README theming:** user chose `<picture>` theme-swap (over single `<img>`).
- **package() files:** user chose No — leave package lean (over adding assets).

All other assumptions (ExDoc logo/favicon shape, scope discipline) accepted as presented.

## External Research

None — the codebase (asset fills, ExDoc version in mix.lock, contract-test bodies) provided
sufficient evidence; no library-version or ecosystem ambiguity remained.
