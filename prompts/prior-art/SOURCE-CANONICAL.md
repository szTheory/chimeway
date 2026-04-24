# Prior-art corpus — canonical sources (Chimeway)

Chimeway does **not** vendor the shared OSS deep-research bytes in this repository. **Local dev and AI sessions** should read them from the maintainer checkout below (or run `sync-from-canonical.sh` if you need an offline copy under `oss-deep-research/`).

## Canonical directory for the seven shared files

**Canonical path (this machine):** `/Users/jon/projects/rulestead/prompts/`

These seven filenames are the shared Elixir / Ecto / Phoenix / LiveView / Plug+system-design / OSS-lib / CI-CD deep-research set used across sibling repos (`scrypath`, `sigra`, `lattice_stripe`, `threadline`, `rulestead`, etc.). Historically they were byte-identical where duplicated; **rulestead** is the chosen single place to open them from for Chimeway.

| File |
|------|
| `elixir-best-practices-deep-research.md` |
| `elixir-opensource-libs-best-practices-deep-research.md` |
| `elixir-oss-lib-ci-cd-best-practices-deep-research.md` |
| `phoenix-best-practices-deep-research.md` |
| `ecto-best-practices-deep-research.md` |
| `phoenix-live-view-best-practices-deep-research.md` |
| `elixir-plug-ecto-phoenix-system-design-best-practices-deep-research.md` |

**Not** pulled into this index: Stripe- or payments-specific research under `lattice_stripe/prompts/` (noise for a notification library).

## Optional local mirror

If `prompts/prior-art/oss-deep-research/` exists, it is **generated** (see `sync-from-canonical.sh`), not hand-edited. Prefer the canonical sibling path when both are available.

## Chimeway-native prompts

Product, brand, engineering DNA, and topical docs live under `chimeway/prompts/` at the repo root — see `prior-art/README.md`.
