# Interactive GSD new-project — Chimeway (questions + research subagents)

Use this path when you want **deep questioning**, then **four parallel `gsd-project-researcher` agents** plus **`gsd-research-synthesizer`**, instead of `/gsd-new-project --auto` (which skips questioning).

**Repo root:** `/Users/jon/projects/chimeway`  
**Preconditions:** `git init` done; **no** `.planning/` yet (if a prior init exists, use `/gsd-progress` or intentionally remove `.planning/` only for a full reset).

---

## First message to send (slash + attachments)

Paste in **Claude Code / Cursor** from the chimeway repo root:

```text
/gsd-new-project

@GSD-CONTEXT.md
@prompts/CHIMEWAY-GSD-IDEA.md
@prompts/chimeway-engineering-dna-from-prior-libs.md
@prompts/elixir_notifykit_research_brief.md
```

**Optional** (more context, longer context window):

```text
@prompts/chimeway-brand-book.md
@prompts/chimeway-admin-ui-and-operator-ia.md
@prompts/chimeway-testing-and-e2e-strategy.md
@prompts/chimeway-release-engineering-and-ci.md
@prompts/chimeway-host-app-integration-seam.md
@prompts/prior-art/SOURCE-CANONICAL.md
```

---

## How GSD splits questioning vs research

| Mode | Step 3 deep questioning | Step 6 parallel domain research |
|------|-------------------------|-----------------------------------|
| `/gsd-new-project --auto @idea.md` | Skipped | Always on (auto-approved downstream) |
| `/gsd-new-project` (no `--auto`) | On — until you choose **Create PROJECT.md** | Asked — choose **Research first** for 4× `gsd-project-researcher` + synthesizer → `.planning/research/*.md` |

Subagent types (fixed by GSD): `gsd-project-researcher`, `gsd-research-synthesizer`, `gsd-roadmapper`.

---

## Answering Step 3 without re-writing the pitch

When asked what you want to build, reply along the lines of:

> Use the attached Chimeway prompts as the baseline product definition. Ask follow-ups focused on the **open decisions** in `CHIMEWAY-GSD-IDEA.md` (package shape, Phoenix/Ecto/PG baselines, v0.1 scope vs admin UI timing). I want to refine those with you before we lock `PROJECT.md`.

Continue until you select **Create PROJECT.md**.

---

## Step 5 — workflow preferences (maximize research quality)

- **Research** = **Yes** — per-phase research during execution (separate from Step 6, but aligned with “research-heavy” delivery).
- **Plan check** / **Verifier** = Yes if you want the extra gates (recommended for a new OSS lib).
- **AI models** = **Quality** if you want stronger researcher/roadmapper models (higher cost).

Saved defaults: optionally maintain `~/.gsd/defaults.json` so Step 5 offers “Use as-is” — see GSD `new-project` workflow docs.

---

## Step 6 — research decision (this spawns the subagents)

Choose **Research first (Recommended)**.

That run creates `.planning/research/` with Stack, Features, Architecture, Pitfalls dimensions and a **SUMMARY.md** after synthesis.

---

## After `/gsd-new-project` completes

```text
/gsd-plan-phase 1
```

On CLIs without `AskUserQuestion`, add **`--text`** where your GSD install documents it.

---

## Terminal alternative (if you use `gsd-sdk` instead of slash)

```bash
cd /Users/jon/projects/chimeway
gsd-sdk init @prompts/CHIMEWAY-GSD-IDEA.md
```

Interactive questioning is primarily via the **slash workflow** in the IDE; terminal init may differ — prefer the paste block above for the full interactive + research path.
