# Chimeway — GSD new-project idea document

Use with: `/gsd-new-project --auto @prompts/CHIMEWAY-GSD-IDEA.md` from the **chimeway** repo root (`/Users/jon/projects/chimeway`).

For **interactive** questioning plus Step 6 **four parallel researchers + synthesizer**, omit `--auto` and follow **`prompts/INTERACTIVE-GSD-NEW-PROJECT.md`** (first-message `@` list and Step 3/5/6 notes).

## One-line pitch

**Chimeway** is an open-source **embedded notification layer** for Elixir and Phoenix: one **event**, many **recipients**, many **channels**, **durable** records, and **explainable** delivery—from trigger through policy to provider attempt—with **operator-grade** debugging and an optional **admin UI**.

## Problem

The ecosystem has strong **channel** building blocks (Swoosh, Oban, Pigeon, webhooks, and so on) but no **first-class** Elixir answer for **routing, preferences, fanout, idempotency, read/seen state, retries, digests, and “why wasn’t this sent?”** across channels. Teams rebuild the same Ecto schemas, Oban jobs, and support dashboards in every SaaS.

## Product principles (table stakes)

- **Explainable by default:** every notification can be traced from definition through policy to delivery attempts.
- **Embedded, local-first:** data lives in the host app’s database—not a hosted notification SaaS.
- **Idiomatic Elixir:** explicit behaviours, small surfaces, optional generators; **no** opaque Rails-style magic.
- **Composable:** Swoosh, Oban, Plug, Phoenix, and LiveView fit naturally; adapters stay **replaceable**.
- **Great adoption DX:** short happy path (in-app + one channel), clear upgrade path to jobs, extra channels, and admin.
- **Batteries included:** optional mountable **admin / trace** UI and installer path—without forcing a monolith package shape in v0.1 if the API is still stabilizing.

## Non-goals (initial milestones)

- Not a multi-tenant notification **hosted** product, not open-core billing on delivery volume.
- Not competing with Swoosh or Oban at their core—**integrate**, do not reimplement.
- Not prescribing a single SMS or push vendor; **adapter seams** win.

## Technical direction (high level)

- **Stable notification keys** (e.g. `"comment.created"`) as persisted identity—not raw module names that break on rename.
- **Event → recipient resolution → per-channel delivery plans → durable rows → jobs (or sync path)** with explicit modes (`:sync`, `:job`, `:inline_db`, etc.) as in the domain research brief.
- **Policy twice** where it matters: before enqueue and before perform (late suppression, quiet hours).
- **Killer operator story:** filters, timelines, redacted views, and correlation IDs for support.

## OSS / engineering constraints

Ship with the same discipline as sibling libraries (`accrue`, `scrypath`, `lattice_stripe`, `sigra`, `mailglass`, `lockspire`, `rulestead`, `threadline`):

- Named **`mix verify.*` / `mix ci.*`** entrypoints; stable CI job **`id:`** keys; honest default `mix test` story.
- **Doc contract** tests once public docs and config schemas exist.
- **Release Please**, post-publish verification patterns, and `api_stability.md` when a public API is declared.
- **Golden-diff installer tests** when a generator/installer ships.

Full synthesis: **`prompts/chimeway-engineering-dna-from-prior-libs.md`**.

## Prior research (read during GSD research / planning)

1. **`prompts/chimeway-brand-book.md`** — naming, voice, positioning.
2. **`prompts/elixir_notifykit_research_brief.md`** — ecosystem map, Rails Noticed / Laravel lessons, data model sketch, API ideas (canonical product name is **Chimeway**; body may still say NotifyKit in places).
3. **`prompts/chimeway-engineering-dna-from-prior-libs.md`** — OSS DNA checklist + Chimeway-specific translation.
4. **`prompts/chimeway-admin-ui-and-operator-ia.md`** — operator UX and trace UI intent.
5. **`prompts/chimeway-testing-and-e2e-strategy.md`** — shift-left testing and CI.
6. **`prompts/chimeway-release-engineering-and-ci.md`** — lane table and pointers.
7. **`prompts/chimeway-host-app-integration-seam.md`** — host app boundaries, tenancy, auth.
8. **`prompts/prior-art/SOURCE-CANONICAL.md`** — where the seven shared `*-best-practices-deep-research.md` files live (open from **`/Users/jon/projects/rulestead/prompts/`** or run `prompts/prior-art/sync-from-canonical.sh` for a local mirror).

## Suggested first milestone (for roadmap seeding)

**Milestone v0.1 — “Durable spine + one channel”**

- Hex package **`chimeway`** (exact name per Hex availability), Elixir/OTP baseline aligned with active Phoenix LTS in sibling repos.
- **Documented data model:** events, recipients, notifications/inbox, deliveries/attempts—enough to support explainability later even if read APIs are minimal.
- **One vertical slice:** trigger → persist → dispatch (sync path acceptable) for **in-app** and/or **one outbound channel** behind an adapter behaviour (e.g. log/test adapter first, then Swoosh wrapper when ready).
- **Oban optional** in v0.1 if the slice is sync-first; document the upgrade seam in REQUIREMENTS.
- **CI:** format, compile `--warnings-as-errors`, test matrix with Postgres when Ecto is in play; no merge theater.
- **Docs stub:** README thesis + link to research brief and DNA doc; CONTRIBUTING skeleton.

**Subsequent milestones (not all in v0.1):** `chimeway_admin` sibling or in-tree LiveView dashboard, installer + golden diff, property tests for idempotency, full channel matrix, digests, nightly integration against real providers.

## Open decisions for `/gsd-discuss-phase` / planning

- **Package shape:** single hex vs `chimeway` + `chimeway_admin` (see DNA doc recommendation).
- Minimum **Phoenix / Ecto / PostgreSQL** versions and whether v0.1 is **library-only** or ships a **mountable** router scope.
- **Multi-tenancy** strategy: behaviour vs explicit `repo`/`prefix` option vs both.

## GSD bootstrap commands (pick one)

- **In Cursor / Claude Code (slash workflow):** run from repo root with a clean session:

  ```text
  /gsd-new-project --auto @prompts/CHIMEWAY-GSD-IDEA.md
  ```

  Then: `/gsd-plan-phase 1` (add `--text` in non-Claude CLIs if menus are unavailable).

- **Terminal — one-shot init:** requires `git` in the repo root first.

  ```bash
  cd /Users/jon/projects/chimeway
  git init   # if not already a repository
  gsd-sdk init @prompts/CHIMEWAY-GSD-IDEA.md
  ```

---

**Instruction to GSD (auto mode):** Treat this file as authoritative for **vision, constraints, non-goals, and first-milestone intent**. Pull detailed requirements from the research brief, brand book, and DNA doc. Use **research** phases to validate naming on Hex, channel adapter choices, and overlap with existing small libs before locking `REQUIREMENTS.md`.
