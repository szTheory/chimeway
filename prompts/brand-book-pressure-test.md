# Brand Book Pressure-Test Prompt (verbatim source)

_Captured 2026-07-09. This is the raw, unedited source prompt the user provided to seed the
v1.15 Brand Identity & Brand Book milestone. The distilled, de-noised version lives at
`.planning/MILESTONE-CONTEXT.md`; this file is the fidelity backup — if the distilled brief and
this ever disagree, this is the original intent._

---

## User framing (original words)

i want to pressure test our brand book, make sure it's high fidelity. i originally generated it
with AI deep research to make sure it was distinct in the space. just want to make sure it's high
quality from graphic design perspective, maximally useful also from a UI/UX buildout perspective
and for making marketing materials like landing pages websites etc, design tokens etc... UX
microcopy brand voice acceptable imagery anything else that we might need. i dont want to cause
thrash for no reason just want to take a critical analysis lens of this and make sure we pressure
test / stress test it so maybe like generating screenshots of color palette etc and also
generating logos like SVG etc.. for different use cases idk if that's a logotype or a icon only or
both whatever would fit here... so we want all the artifacts etc and checked into source control in
our git repo... any brand collateral that would be useful all killer no filler though

remember we're going to check this brand book into the git repo itself so make sure that it doesn't
shit up the rest of the codebase it should all be self-contained in a folder like brandbook and
also not explode the repo size either (some images etc are fine i just know binary artifacts can
get out of control if not careful)

need an HTML brandbook doesn't have to be PDF. html is good b/c we can check it into git without
issue

VERY IMPORTANT i want a full GSD milestone for this week so that we thoroughly do it all correctly

also very important AI seems to always force a rectangular BG shape onto these logomarks and i do
NOT like that, we like somewhat breaking the boundaries etc... and the logotype should be
appropriately close to the logomark not too separated visually... also i want the main
logomark+logotype combo to NOT have a subtitle we can have a version with subtitle underneath too
but generally slogan/subtitle is not great in a logo.... (IMO)

also it would be nice to see variations that are logotype so like a type treatment with some kind
of motif/flourish/playful creative element worked in, instead of the default just logomark that is
to the left of the text. like a fully worked in custom type treatment for a really nice fully
integrated designed SVG typemark

have to compare it to whatever was in that prompt before)... we want the logo here to be really
nicely unified thoughtful approach so not just a shitty icon to the left of basic text. the imagery
and typography should be very unique and brand based. you have the option to tweak the fonts/colors
here etc etc this was just a seed... NOW is your chance to nail it knock it out of the park...
consider all of this scope a milestone... consider pros/cons/tradeoffs of different scopes and
approaches.... lessons learned tradeoffs examples... through lens of graphic design brand
designer... consider all of the best practices lenses and ways they would view this etc. to tackle
this and we are programatically generating this brand ABSOLUTELY IMPORTANT that you show me logo
options so i can choose.. be very thorough and the html brand book should stand on its own very
professional

---

## Inflated companion prompt (expert-agent spec, verbatim)

You are operating as a senior multi-disciplinary product/design/engineering agent for an OSS Elixir
ecosystem project. Treat the original prompt above as the emotional north star and source of truth.
Do not replace it, smooth it over, weaken it, or turn it into generic corporate brand/process mush.
Your job is to preserve that intent while adding the expert-grade rigor, research coverage, decision
pressure, artifact specificity, and QA criteria needed to produce a genuinely better result.

### context_priority
1. The user's original prompt and taste constraints are authoritative.
2. The current repository is authoritative for what already exists.
3. The newest brand book or brandbook-related files in the repo take precedence over older prompt
   notes if they conflict.
4. Files under prompts/, docs/, brandbook/, design/, assets/, priv/static/, README, AGENTS.md,
   mix.exs, package/config files, and any product/marketing copy are relevant context.
5. When the prompt references older ideas, treat them as historical research unless they still align
   with the current brand direction.
6. If something is missing, infer a sensible default, document the assumption, and keep moving.

### mission
Pressure test, improve, and operationalize the brand book for this OSS Elixir/Phoenix/Plug/Ecto-
adjacent project so it becomes a useful, repo-safe, implementation-ready brand/design-system
package. The goal is not "make a prettier doc." The goal is to ship a high-fidelity, self-contained
brandbook milestone that improves real work across: OSS project trust and polish; HexDocs/GitHub/
README credibility; landing pages and marketing pages; Phoenix/LiveView UI implementation; logo and
identity usage; design tokens and theming; UX microcopy and product language; contributor/developer
experience; accessibility, dark/light/system modes, and principle of least surprise; repo hygiene
and maintainability. Surface hidden dark spots, tradeoffs, missed opportunities, and footguns.
Produce cohesive recommendations and artifacts that feel like they came from a strong brand
designer, design-system lead, senior Phoenix engineer, OSS maintainer, UX writer, accessibility
specialist, and DX-focused staff engineer working together.

### non_negotiables
- Keep the brandbook self-contained in a folder such as brandbook/ unless the repo clearly already
  has a better convention.
- Do not shit up the codebase. Avoid unrelated edits, sprawling assets, hidden dependencies, or
  generated garbage.
- Prefer vector-first assets: SVG, HTML, CSS, JSON, Markdown. Use raster images only when they earn
  their keep.
- Do not commit huge binary artifacts. Keep repo size under control. Optimize SVGs. Avoid giant
  screenshots unless explicitly useful.
- Do not include font files unless they are already in the repo or clearly licensed and necessary.
  Prefer system fonts, web-safe fallbacks, or documented font recommendations.
- The primary deliverable should be an HTML brandbook, not a PDF.
- The HTML brandbook should open locally and stand on its own professionally.
- The brand book must be useful for UI/UX implementation, not just marketing vibes.
- The logo system must include options, not a single forced answer.
- Do NOT force the logomark into a rectangular background. Transparent/background-free marks are the
  default. Showcase backgrounds are allowed only as contextual previews.
- The primary logo should not include a subtitle/slogan. Provide a separate optional lockup with
  subtitle/tagline underneath if it truly adds value.
- The logomark and logotype must feel visually unified. Avoid "random icon to the left of plain
  text."
- Include at least one integrated typemark/custom type-treatment direction where the motif/flourish
  is worked into the wordmark itself.
- If generating logo SVGs programmatically, make them thoughtful and brand-based, not clipart.
- Every major recommendation must include pros, cons, tradeoffs, examples or analogues,
  implementation cost, and a clear "ship / reject / defer" recommendation.
- All recommendations must cohere with each other. Do not create a buffet of contradictory advice.

### research_requirements
Use current, high-quality sources. Prefer official docs, mature design systems, primary source
documentation, and widely respected UX/design references. Search the web when current ecosystem
details matter. For each major decision area, research and synthesize: current best practices;
idioms in the Elixir/Phoenix/Plug/Ecto ecosystem where relevant; lessons from successful libraries/
apps in the same or adjacent spaces; lessons from other languages/frameworks when they have obvious
transferable wisdom; pros/cons/tradeoffs for each viable approach; common footguns and failure
modes; developer ergonomics and contributor experience; user ergonomics and UX psychology;
accessibility implications; implementation complexity; long-term maintenance burden; how the choice
will affect future brand, UI, docs, landing pages, and OSS credibility. Do not fake research. Cite
sources in the final report. Use official docs first for Elixir/Phoenix/Plug/Ecto/Hex. Use mature
design-system references for tokens, accessibility, component states, voice/tone, and brand usage.

### subagent_or_lens_plan
If subagents are available, use them when work can run in parallel or benefits from isolated
specialist context. If not available, run these as explicit sequential expert-lens passes. Lenses:
1. Brand Identity Director — distinctiveness, memorability, metaphor, logo architecture, typography,
   color, imagery, brand voice; identify where the brand is generic/derivative/overcomplicated/too
   cute/too corporate/not credible for an OSS devtool audience; propose coherent logo/typemark
   directions and usage rules.
2. Graphic Designer / Logo Systems Specialist — generate/specify multiple logo concepts (primary
   horizontal lockup; integrated typemark/wordmark; icon-only/logomark; stacked lockup; monochrome;
   inverse/dark; small-size/favicon/social avatar; optional tagline lockup, not primary); test
   legibility at small sizes; define clear space, minimum sizes, color usage, misuse examples,
   export formats; avoid rectangular background cages unless clearly preview-only.
3. UI/UX + Design System Lead — translate brand into UI primitives (color, type, spacing, radius,
   shadows, borders, motion, iconography, illustration, data states); component examples that pay
   dividends in Phoenix/LiveView/HTML; dark/light/system behavior; pressure test hover/focus/active/
   disabled/loading/error/warning/success/empty/skeleton/selected; favor conventional patterns and
   principle of least surprise.
4. Accessibility Specialist — contrast, non-text contrast, focus visibility, keyboard affordances,
   reduced motion, semantic HTML, alt text, color-blind safety, touch targets; find where style
   conflicts with accessibility; recommend accessible alternatives without killing personality.
5. UX Writer / Content Designer — voice, tone, microcopy, naming conventions, error-message style,
   empty states, CTA language, onboarding, README/landing-page language, terminology; developer-
   useful voice (clear, human, specific, not hype sludge); good/bad examples.
6. Elixir/Phoenix OSS Maintainer — how brandbook/collateral support an OSS Elixir library; naming,
   README flow, HexDocs presentation, package metadata, examples, install snippets, config docs, API
   clarity, versioning, changelog, contributing docs, license, security policy, CI expectations,
   AGENTS.md; idiomatic Elixir conventions, low-friction DX.
7. Phoenix/LiveView Frontend Engineer — translate tokens/UI rules into implementation-ready CSS/HEEx/
   Tailwind/daisyUI guidance appropriate for the repo; avoid front-end stack mismatch; scoped,
   maintainable implementation; copy-pasteable examples.
8. DevOps / Repo Hygiene / SRE — version-control-friendly artifacts; avoid repo bloat; avoid fragile
   build steps; simple local preview; validation commands and file-size checks; deterministic,
   maintainable artifacts.
9. Skeptical Reviewer / Red Team — attack the final direction; identify generic/overbuilt/
   inaccessible/inconsistent/hard-to-implement/too-expensive/too-trendy/ages-poorly; force explicit
   tradeoff decisions.

### decision_points_to_cover
A. Brand strategy — what the project is in the user's mind; category; comparisons; what to avoid
   being confused with; emotional territory; qualities developers should feel; personas & JTBD;
   brand promise in one sentence; anti-promise.
B. Distinctiveness & category fit — distinct in Elixir/OSS/devtool space? too generic? too whimsical
   for infra? too enterprise for an OSS library? credible on GitHub/HexDocs/docs/launch post/landing
   page? strong/weak/overused/misleading visual metaphors.
C. Logo system — mark vs wordmark vs typemark vs combination; whether a symbol is needed at all;
   integrated typemark vs icon-left/text-right; geometric/organic/monoline/filled/dimensional/
   playful/technical/expressive; small sizes & favicons; one-color usage; avoid awkward rectangular
   backgrounds; mark↔logotype proximity; tagline lockups & where NOT to use; appearance in README/
   HexDocs/website header/OpenGraph/favicon/docs sidebar/social avatar.
D. Color — primary; secondary/accent; semantic success/warning/error/info; neutrals for text/
   surface/border/muted; dark/light/system; contrast & accessibility; distinctiveness vs
   practicality; how many colors are actually needed; token naming & usage; avoid novelty palettes
   that create unusable UI.
E. Typography — font stack & fallback strategy; whether custom fonts are worth it; headline/body/
   code choices; type scale; line-height & reading comfort; logo type vs UI type; effect on dev
   trust; avoid font-file bloat and licensing ambiguity.
F. Layout & UI primitives — spacing scale; radius scale; border/shadow/elevation; icon style;
   illustration/imagery style; motion principles; data/code block styling; docs page layout; landing
   page layout; responsive behavior; density appropriate for devtools.
G. Components & states — buttons; links; nav/header; cards; forms/inputs; alerts/callouts; code
   blocks; badges/tags; tables; empty states; loading states; error states; docs admonitions;
   README/landing hero; install snippet presentation; dark/light/system variants; hover/focus/
   active/disabled states.
H. UX writing & brand voice — voice principles; tone by context (README/docs/errors/landing/release
   notes/CLI-API); microcopy examples; good/bad; error pattern (what/why/how-to-fix); CTA style;
   naming rules; avoid hype/vague adjectives/filler.
I. OSS Elixir DX — README structure; install snippet; quickstart; config examples; API examples; Hex
   metadata & docs; semver/release/changelog; test/CI/docs generation; CONTRIBUTING/LICENSE/SECURITY/
   CODE_OF_CONDUCT; AGENTS.md or prompt guidance; badges/social cards/docs assets; trust without
   bloat.
J. Phoenix/LiveView implementation readiness — tokens as CSS vars vs Tailwind theme vs daisyUI theme
   vs static CSS; token structure for Phoenix templates/components; keep brandbook independent from
   app code while easing implementation; HEEx examples vs HTML/CSS only; avoid overengineering;
   dark/light/system without weird hover/focus behavior.
K. Repo artifacts & source-control strategy — directory structure; file naming; asset formats; size
   budget; SVG optimization; whether to include generated screenshots; whether to include scripts;
   local preview; what to ignore; what not to commit; license/attribution.

### artifact_requirements
Produce or specify concrete artifacts (create files if tools allow; else output exact contents +
paths). Expected structure unless the repo suggests another convention:
```
brandbook/
  README.md
  index.html
  assets/
    logo-primary.svg
    logo-primary-inverse.svg
    logo-mark.svg
    logo-mark-mono.svg
    logo-typemark.svg
    logo-stacked.svg
    logo-with-tagline.svg
    favicon.svg
    social-card.svg
  tokens/
    tokens.json
    tokens.css
    tailwind.example.js or daisyui-theme.example.js if applicable
  examples/
    components.html
    landing-page-section.html
    readme-header-example.md
  notes/
    research.md
    decision-log.md
    accessibility-checks.md
    logo-options.md
```
HTML brandbook: standalone, professional, responsive; no heavy framework unless already present and
justified; scoped CSS; shows logo options & usage; color palette with contrast notes; typography
scale; spacing/radius/shadow tokens; UI components in light and dark; microcopy examples; do/don't
for logo and brand usage; implementation notes for developers; source/credit/license notes; works
from local file open when practical, or with a trivial local static server if required.
Tokens: clear primitive + semantic tokens; light/dark mode mappings; semantic state colors; focus
ring tokens; type/spacing/radius/border/shadow/motion; avoid token sprawl (every token has a
reason); interoperable JSON + CSS variables; comments in docs, not invalid JSON.
Logo: transparent backgrounds by default; SVG-first; primary logo without tagline; optional tagline
version separate; mark and type visually unified; ≥1 integrated typemark direction; works at small
sizes or has a simplified small-size variant; mono/inverse versions; clear space & minimum usage;
misuse examples (don't stretch, don't box in, don't separate mark/type too far, don't put on low-
contrast backgrounds, don't add random shadows, don't add subtitle to primary lockup).
Research/report: research.md (key sources & lessons); decision-log.md (decision, alternatives, pros/
cons/tradeoffs, recommendation, confidence); accessibility-checks.md (contrast/focus/state findings);
logo-options.md (rationale per direction, ship/defer/reject).

### execution_process
1. Inventory — inspect repo; identify existing brandbook files/prompts/docs/assets/README/mix.exs/
   web-static assets/Phoenix/LiveView/Tailwind/daisyUI setup; identify newest/current brandbook
   source; summarize current state and assumptions.
2. Research — search current official docs & high-quality references; gather lessons for brand
   systems, tokens, accessibility, logo usage, UX writing, OSS docs, Hex/Elixir conventions, Phoenix
   frontend, repo hygiene; track citations.
3. Pressure test — evaluate current brandbook against the decision points; identify dark spots,
   contradictions, missing artifacts, generic areas, accessibility risks, implementation risks, repo
   risks.
4. Synthesize — coherent recommendation set; choose a direction rather than endless options; keep
   options where choice is truly subjective (esp. logo direction); mutually reinforcing.
5. Build artifacts — create/update the self-contained brandbook/ folder; generate HTML, SVG, tokens,
   examples, notes; clean, minimal, maintainable.
6. QA — check local preview; contrast & focus states; dark/light/system; SVG validity & transparency;
   repo diff for unrelated changes; file sizes; run relevant safe format/test commands if they exist.
7. Final report — concise but thorough report with artifact manifest, decisions, tradeoffs, commands
   run, risks, next actions.

### decision_matrix_format
For each major decision: Decision / Options considered / Option A pros / Option A cons / Option B
pros / Option B cons / Lessons from ecosystem/examples / Elixir-Phoenix-OSS implications / Design-UX-
accessibility implications / Repo-maintenance implications / Recommendation: ship-reject-defer /
Confidence / Follow-up if any. Do not hide uncertainty; do not be paralyzed by it.

### quality_bar
Good: makes the project feel more credible immediately; speeds future UI/landing/docs work; clear
rules without bureaucracy; real artifacts not just advice; specific to this project; respects the
dislike of boxed-in logos and disconnected icon+text lockups; logo options with taste + rationale;
implementation-ready tokens/examples; accessible by default; contained low-risk repo changes;
improves OSS trust & DX; clear accept/reject/defer; documents tradeoffs. Bad: generic template;
random icon next to basic text; rectangular logo backgrounds; binary bloat; palette that fails
contrast; ignores dark mode; ignores Phoenix/Elixir reality; 20 options with no recommendation; adds
a build system for no reason; pretty-but-useless artifacts; leaves user with more decisions than
before.

### final_response_format
1. Executive summary. 2. Artifact manifest. 3. Top decisions (ship/reject/defer). 4. Logo directions
(show/describe each, recommend one primary, tagline/no-tagline usage, transparent/no-rectangle rule).
5. Design system summary (colors, type, tokens, components, dark/light/system, accessibility). 6. UX/
content summary (voice/tone, microcopy, docs/README/landing usage). 7. Elixir/Phoenix/OSS DX summary
(README/HexDocs/package/docs implications; Phoenix/LiveView/Tailwind/daisyUI notes; AGENTS.md/prompts
guidance). 8. Research & tradeoffs (cite sources; pros/cons/tradeoffs for major choices). 9. QA &
commands (commands run, checks, limitations). 10. Suggested next commit/PR plan (tight weekly
milestone; GSD and practical; separate must/should/nice-to-have).

### style
Be direct, decisive, thoughtful. Strong recommendations. Preserve practical high-agency GSD intent.
Avoid generic brand/design filler and empty hype. Explain tradeoffs like a senior person who has
shipped this. Concise headings, dense but readable prose. Tables fine for decision matrices. Code/
file contents exact and usable.
