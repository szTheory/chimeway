# Phase 82: Logo Exploration & Shortlist - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-10
**Phase:** 82-logo-exploration-shortlist
**Mode:** assumptions
**Areas analyzed:** Deliverable scope & format, Direction set, Metaphor lanes, Integrated typemark
coverage, Wordmark rendering, Legibility gates, Preview harness, Color & drawing

## Assumptions Presented

### Deliverable Scope & Format
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One committed artifact `notes/logo-options.md`; all directions + rejects inline SVG; no `brandbook/logo/*.svg` family this phase | Confident | SC#1, NOTES-02, Phase 83 owns LOGO-03 |
| Shortlist not gallery — rationale + pros/cons + ship/defer/reject + confidence per direction | Confident | LOGO-01, SC#1 |

### Direction Set
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fully work 5 directions (top of 3–5 range) | Likely | pressure-test "must include options"; user "show me options" |
| ≥2 of 5 are integrated typemarks (motif in the letterforms) | Confident | LOGO-02, pressure-test L110 |

### Metaphor Lanes
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| path/route/signal-arc/waypoint/trace/`cw`-monogram; abstract rings OK; zero literal bell/note/music | Confident | LOGO-06; brand-book §13; "decided not to ring this bell" |

### Wordmark Rendering
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Non-typemark wordmarks as `<text>` Inter; typemark glyphs hand-drawn `<path>`; outline conversion deferred to Phase 83 | Likely | milestone "outlines = ship rule"; tokens Inter stack |

### Legibility Gates
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Each direction embeds inline proof strip: 16px + mono + inverse + clear-space/min-size note | Confident | SC#4 |

### Preview Harness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ephemeral `file://` HTML gallery in scratchpad (not committed); markdown stays the deliverable | Likely | pressure-test "show me options"; repo-size discipline; Phase 84 owns real HTML |

### Color & Drawing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `--cw-ink` primary + `--cw-teal` accent; mono one-color; inverse paper-on-night; no gradients/shadows | Confident | tokens.css; brand-book "one color / no gradients in mark" |

## Corrections Made

No corrections — the confirmation gate (`AskUserQuestion`) received no response within the
timeout window (user away from keyboard). Per project METHODOLOGY.md (Cohesive-Recommendation
Default, One-Shot Recommendation Bias, High-Impact Escalation Gate) and the recorded user
preference for decisive one-shot recommendations, all 8 assumptions were locked as decisions.
The genuinely subjective lever — the actual creative pick among directions — is deferred to
Phase 83 (User Checkpoint), which is where human taste sign-off belongs, so proceeding without
a live confirmation does not foreclose the user's decision authority.

## External Research

Not performed in discuss-phase. One non-blocking topic flagged for the phase researcher:
OSS devtool logo precedents (signalling infra/observability without cliché) + integrated-typemark
construction techniques, to back per-direction rationale with citations.
