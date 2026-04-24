# Chimeway `prior-art/`

This folder explains **where shared reference material lives** so we do not maintain duplicate copies of the seven OSS “deep research” markdown files inside the Chimeway repo.

## Read first

- **`SOURCE-CANONICAL.md`** — Absolute (or team-agreed) path to the seven shared files; Chimeway CI does not depend on vendoring them.
- **`sync-from-canonical.sh`** — Optional: copies those seven files into `oss-deep-research/` for offline work or `@`-ing from a single tree. That directory is **gitignored** at the repo root so the canonical sibling stays the source of truth for version control.

## What is Chimeway-specific (not here)

Under `../` (repo `prompts/`):

- Brand and domain research (`chimeway-brand-book.md`, `elixir_notifykit_research_brief.md`).
- GSD bootstrap (`CHIMEWAY-GSD-IDEA.md`).
- Engineering DNA and topical prompts (`chimeway-*.md`).

## What lives only in sibling repos

- Full convergent OSS DNA prose: `rulestead/prompts/rulestead-engineering-dna-from-prior-libs.md` (Chimeway’s DNA doc summarizes and points there).
- Lockspire / Rulestead topical operator and security docs: read for **patterns** when drafting Chimeway admin and threat-model prompts; do not copy OAuth domain content wholesale.
