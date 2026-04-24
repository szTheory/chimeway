Below is a paste-ready BRAND.md for Chimeway.

One note before locking it in: a quick web check found Chimeway mostly as non-software/music/Sims references, while plain Chime is much more crowded through things like the Python chime package and Amazon Chime SDK. This is good enough for brand-direction work, but not a legal trademark clearance.  ￼

⸻

Chimeway Brand Book

Version: 0.1
Date: 2026-04-23
Project type: Open-source Elixir notification library
Commercial status: Non-commercial OSS project; not a SaaS, not open-core, not a hosted product.

1. Brand summary

Chimeway is an open-source notification library for Elixir and Phoenix applications.

It helps app developers define, route, persist, deliver, inspect, and debug notifications across in-app, email, push, SMS, Slack, webhook, and future channels.

Chimeway is not a notification SaaS. It is an embedded library: users keep their notification data, preferences, delivery records, traces, attempts, and admin surfaces inside their own application and database.

2. Name meaning

Chime suggests a clear, gentle signal.

Way suggests routing, direction, method, path, and judgment.

Together, Chimeway means:

A notification that knows where to go, when to go there, and how to explain the path it took.

The name should feel calm, useful, and quietly reliable. It should not feel loud, gamified, salesy, or “growth-hacky.”

3. Core brand idea

One-line idea

Notifications that know the way.

Expanded idea

Chimeway gives Phoenix apps a durable, local-first notification layer: one event, many recipients, many channels, full traceability.

Strategic promise

From trigger to delivery attempt, every notification is explainable.

Emotional promise

When someone asks, “Why didn’t this user get notified?”, Chimeway helps you answer calmly and precisely.

4. Positioning

Primary positioning statement

Chimeway is the embedded notification layer for Elixir apps: durable, traceable, local-first, and built for Phoenix/Ecto/Oban workflows.

Practical positioning

Use Chimeway when you need:

* in-app notification records
* recipient fanout
* per-channel delivery planning
* preferences and suppressions
* delayed fallback
* digests
* retries
* delivery attempts
* audit trails
* admin/debug tooling
* “why wasn’t this sent?” answers

What Chimeway is

Chimeway is:

* an OSS library
* an embedded notification framework-like layer, but do not call it “a framework” in primary copy
* Ecto/Oban/Phoenix-friendly
* local-first
* code-first
* durable
* inspectable
* adapter-based
* beginner-friendly without hiding advanced control
* practical infrastructure for product apps

What Chimeway is not

Chimeway is not:

* a SaaS
* a hosted notification platform
* an open-core commercial product
* a marketing automation platform
* a campaign builder
* a customer engagement product
* a replacement for Swoosh, Oban, Pigeon, Twilio, Slack, or webhook clients
* a magic Rails clone
* a black-box message broker
* a generic event bus
* an activity-feed/social-feed product

The Open Source Initiative describes open-source licenses as allowing software to be freely used, modified, and shared; Chimeway’s brand should align with that spirit in copy, governance, and contribution language.  ￼

5. Taglines and messaging

Primary tagline

Notifications that know the way.

Secondary taglines

Use these depending on context:

* One event. Every route. Full trace.
* Durable notifications for Phoenix apps.
* The local-first notification layer for Elixir.
* Send the right notification, through the right channel, for the right reason.
* From domain event to delivery trace.
* App-owned notifications, without the plumbing.
* A calmer way to build notifications.

Avoided taglines

Do not use:

* “The ultimate notification platform”
* “Engage users everywhere”
* “Omnichannel customer engagement”
* “The notification SaaS for Elixir”
* “Campaigns, journeys, and growth automation”
* “Send more messages”
* “Blast every channel”
* “Never miss a user again”

These sound commercial, SaaS-like, growth-marketing-oriented, or overpromising.

6. Brand pillars

1. Local-first ownership

Chimeway belongs inside the app. Data stays in the user’s database. The app owns the notification record, preferences, routes, delivery state, and trace.

Copy direction:

Keep notification infrastructure close to your app, your data, and your code.

2. Explainable delivery

Every event, recipient, channel, delivery, suppression, and attempt should be traceable.

Copy direction:

Know what sent, what failed, what was suppressed, and why.

3. Respectful routing

Notifications should not blindly blast people. Chimeway values preferences, quiet hours, fallbacks, consent, and late policy checks.

Copy direction:

The right channel is sometimes no channel.

4. Elixir-native explicitness

Chimeway should feel like Elixir: explicit data, small behaviours, clean supervision, telemetry, adapters, and predictable state.

Copy direction:

No black boxes. No hidden magic. Just inspectable notification paths.

5. Batteries without lock-in

Chimeway should offer a fast beginner path, but every layer should remain replaceable.

Copy direction:

Start with in-app and email. Grow into jobs, push, SMS, Slack, webhooks, digests, and admin traces without rewrites.

7. Audience

Primary audience

Phoenix SaaS builders and Elixir developers who need durable product notifications without outsourcing the whole problem to a SaaS.

Secondary audiences

Staff/backend engineers who care about reliability, idempotency, auditability, and multi-tenancy.

LiveView/frontend developers who need inbox components, unread badges, read/seen semantics, and real-time updates.

OSS contributors who want clean adapter behaviours and a well-scoped project.

Security/compliance reviewers who need consent, redaction, audit logs, retention, and unsubscribe flows.

What each audience should feel

Indie builders should feel:

“I can finally add notifications without wiring everything myself.”

Backend engineers should feel:

“This won’t create duplicate sends or invisible failures.”

Frontend developers should feel:

“The UI states are explicit and usable.”

Admins/support teams should feel:

“I can answer the customer’s question.”

OSS contributors should feel:

“The project is approachable and well organized.”

8. Brand personality

Personality traits

Chimeway is:

* calm
* precise
* helpful
* transparent
* practical
* trustworthy
* quietly warm
* developer-native
* stewardship-minded

Chimeway is not

Chimeway is not:

* cute for the sake of cute
* loud
* whimsical to the point of confusion
* enterprise-buzzwordy
* salesy
* smug
* overdesigned
* hyper-minimal at the cost of clarity
* mystical
* growth-hacky

9. Voice principles

1. Clear before clever

Prefer:

Email was suppressed because the user disabled comment.created email notifications.

Avoid:

Chimeway decided not to ring this bell.

Brand metaphors are allowed in headlines and marketing, but operational docs and admin UI must be literal.

2. Explain decisions

Every state should say what happened and why.

Prefer:

Scheduled email skipped because read_at was present before delivery.

Avoid:

Email skipped.

3. Be calm about failure

Failures are normal in notification systems. The voice should help users debug, not panic.

Prefer:

Delivery failed after 3 attempts. The provider returned a retryable rate-limit error.

Avoid:

Something went terribly wrong.

4. Respect the recipient

Do not imply that sending more notifications is always better.

Prefer:

Respect preferences, quiet hours, and channel consent.

Avoid:

Reach users everywhere, instantly.

5. Speak developer-to-developer

Use accurate technical language, but do not overcomplicate.

Prefer:

Use an idempotency key to prevent duplicate deliveries during retries.

Avoid:

Chimeway’s advanced deduplicative substrate prevents unwanted message multiplicity.

10. Copy vocabulary

Preferred words

Use:

* notification
* event
* recipient
* channel
* route
* delivery
* attempt
* trace
* policy
* preference
* suppression
* fallback
* digest
* inbox
* local-first
* embedded
* durable
* explainable
* inspectable
* adapter
* behaviour
* explicit
* app-owned
* code-first

Use sparingly

Use carefully:

* chime
* path
* way
* signal
* ring
* resonate
* melody
* cadence

These are good brand words, but they should not obscure technical clarity.

Avoid

Avoid:

* blast
* campaign
* journey
* engagement automation
* growth
* funnel
* omnichannel
* customer messaging platform
* AI-powered
* magical
* zero-config, unless literally true
* enterprise-grade, unless specifically substantiated
* hosted
* cloud-native notification platform
* monetization
* paid tier
* freemium
* open-core

11. Naming rules

Product name

Use:

Chimeway

Do not use:

ChimeWay
Chime Way
Chime-Way
ChimewayKit
Chimeway Framework
NotifyKit

Package naming

Use lowercase package names:

chimeway
chimeway_ecto
chimeway_oban
chimeway_phoenix
chimeway_admin
chimeway_swoosh
chimeway_pigeon
chimeway_web_push
chimeway_twilio
chimeway_slack
chimeway_webhook
chimeway_batteries

Module naming

Use:

Chimeway
Chimeway.Ecto
Chimeway.Oban
Chimeway.Phoenix
Chimeway.Admin
Chimeway.Adapters.Swoosh
Chimeway.Adapters.Pigeon
Chimeway.Adapters.WebPush
Chimeway.Adapters.Twilio
Chimeway.Adapters.Slack
Chimeway.Adapters.Webhook

Internal feature names

Use practical names first:

Event
Notification
InboxItem
Recipient
Channel
Route
Delivery
DeliveryAttempt
Preference
Policy
Digest
Suppression
Trace

Avoid over-branding internal concepts. Do not rename DeliveryAttempt to something like RingPass or ChimeStep.

12. Visual identity overview

Visual thesis

Chimeway should look like calm infrastructure.

The visual system should combine:

* quiet confidence
* routed paths
* warm technical precision
* readable documentation
* tasteful admin UI
* subtle motion
* accessible contrast
* no SaaS-gloss excess

Visual metaphors

Primary metaphors:

* paths
* routes
* traces
* gentle rings
* waypoints
* inbox cards
* timelines
* delivery rails
* signal arcs
* quiet maps

Secondary metaphors:

* chimes
* bells
* resonance
* cadence
* woven routes

Avoid making the brand literally about music. Chimeway is not an audio product.

13. Logo direction

Recommended logo concept

The logo should be a simple mark combining:

1. a path or route line
2. a small chime/bell-like endpoint
3. one or two signal arcs
4. a wordmark

The mark should suggest:

A signal moving through a deliberate path.

Wordmark

Preferred wordmark:

chimeway

Use lowercase in the graphic wordmark for friendliness and package-name alignment.

In prose, use title case:

Chimeway

Logomark concept

A good logomark could be:

* a rounded path entering a small bell-shaped endpoint
* a c-like curve that becomes a route
* two route nodes connected by a line with a gentle chime arc
* a simple cw monogram where the w implies a path

Logo construction rules

* Use rounded terminals.
* Use simple geometry.
* Use no more than two visual ideas at once.
* Must work at 16px as a favicon.
* Must work in one color.
* Must work in dark mode.
* Must be recognizable without the wordmark.
* Avoid tiny clappers, musical notes, staff lines, or detailed bell drawings.

Logo clearspace

Minimum clearspace around the logo:

1x = height of the lowercase “c” in the wordmark

No text, icons, or UI edges should enter that clearspace.

Minimum sizes

Digital:

Full horizontal logo: 120px wide minimum
Logomark only: 16px minimum, 24px preferred

Print:

Full horizontal logo: 30mm wide minimum
Logomark only: 8mm minimum

Logo usage

Use the logo on:

* GitHub README
* HexDocs landing pages
* docs sidebar
* admin dashboard header
* Open Graph images
* release banners
* conference slides
* stickers

Do not:

* add drop shadows
* use gradients inside the mark
* stretch or skew
* put the full-color logo on noisy backgrounds
* replace the mark with a generic bell emoji
* use musical-note imagery
* make the logo look like a sound-effects/audio app

14. Color system

Color personality

The palette should feel:

* quiet
* technical
* warm
* trustworthy
* accessible
* slightly editorial
* not corporate-blue-only
* not neon
* not childish

The core palette combines deep ink, warm paper, route teal, and soft brass.

Core palette

Token	Hex	Use
--cw-ink	#102027	Primary text, headings, logo on light backgrounds
--cw-night	#07131A	Dark backgrounds, code frames, deep hero sections
--cw-paper	#FFFDF8	Main page background
--cw-porcelain	#F7F4EA	Secondary background, docs panels
--cw-line	#D8D3C7	Borders, dividers, subtle diagrams
--cw-muted	#5E6B72	Secondary text on light backgrounds
--cw-teal	#0E7C86	Primary action, links, route lines
--cw-blue	#2D6CDF	Interactive secondary, info states
--cw-brass	#D6A84F	Brand accent, highlights, small decorative details
--cw-mint	#9ADBCF	Soft accent, diagrams, background fills
--cw-violet	#6D5DF6	Trace/debug accents, admin timeline highlights
--cw-success	#0B7A50	Success states
--cw-warning	#8A5A00	Warning states
--cw-danger	#B83232	Error/failure states
--cw-code	#0B1720	Code block background

CSS variables

:root {
  --cw-ink: #102027;
  --cw-night: #07131A;
  --cw-paper: #FFFDF8;
  --cw-porcelain: #F7F4EA;
  --cw-line: #D8D3C7;
  --cw-muted: #5E6B72;
  --cw-teal: #0E7C86;
  --cw-blue: #2D6CDF;
  --cw-brass: #D6A84F;
  --cw-mint: #9ADBCF;
  --cw-violet: #6D5DF6;
  --cw-success: #0B7A50;
  --cw-warning: #8A5A00;
  --cw-danger: #B83232;
  --cw-code: #0B1720;
}

Primary combinations

Use these combinations frequently:

Foreground	Background	Use
--cw-ink	--cw-paper	Normal text
--cw-ink	--cw-porcelain	Docs panels
--cw-paper	--cw-night	Dark hero, code areas
--cw-teal	--cw-paper	Links and primary actions
--cw-brass	--cw-night	Dark-mode accent
--cw-mint	--cw-night	Dark-mode soft accent
--cw-danger	--cw-paper	Error text
--cw-warning	--cw-paper	Warning text

Accessibility rules

Design to meet or exceed WCAG AA contrast: normal text should have at least 4.5:1 contrast, and large text should have at least 3:1 contrast. W3C’s guidance also notes that thin or unusual fonts can appear lower contrast in practice because of anti-aliasing, so Chimeway should avoid ultra-light text weights in UI and docs.  ￼

Rules:

* Never use brass text on paper for body copy.
* Never use muted text below 14px.
* Never rely on color alone for status.
* Pair status colors with labels and icons.
* Use visible focus states.
* Keep code samples high contrast.
* Prefer real text over images of text; W3C notes that images of text do not scale or adapt as well as real text.  ￼

Status colors

Status	Color	Label style
Planned	--cw-muted	neutral pill
Enqueued	--cw-blue	blue pill
Sending	--cw-violet	violet pill
Succeeded	--cw-success	green pill
Failed	--cw-danger	red pill
Suppressed	--cw-warning	amber/brown pill
Cancelled	--cw-muted	neutral outline
Expired	--cw-warning	warning outline

15. Typography

Typography personality

Typography should be readable, technical, and calm.

Chimeway should not look like a corporate sales deck or a startup landing page template. It should feel like an excellent open-source project with unusually good taste.

Recommended type stack

Primary UI and docs font

Use Inter.

Reason: Inter is designed for computer screens and has a tall x-height for readable mixed-case and lowercase text. It is free and open-source under the SIL Open Font License.  ￼

font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont,
  "Segoe UI", sans-serif;

Code font

Use IBM Plex Mono.

Reason: it fits the technical/editorial tone, and IBM Plex is available under the Open Font License.  ￼

font-family: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Monaco,
  Consolas, "Liberation Mono", monospace;

Optional editorial/display font

Use Source Serif 4 sparingly for hero pull quotes, essays, and major narrative pages. Source Serif 4 is available through Google Fonts and its license is the SIL Open Font License.  ￼

font-family: "Source Serif 4", Georgia, serif;

Type scale

Use a restrained modular scale.

12px  / 0.75rem   captions, metadata
14px  / 0.875rem  small UI, table metadata
16px  / 1rem      body, docs
18px  / 1.125rem  large body
20px  / 1.25rem   h5
24px  / 1.5rem    h4
32px  / 2rem      h3
44px  / 2.75rem   h2 / landing sections
60px  / 3.75rem   hero headline
76px  / 4.75rem   rare oversized display

Font weights

Use:

400 Regular: body
450/500 Medium: navigation, labels, buttons
600 Semibold: headings and emphasis
700 Bold: hero headings only

Avoid:

100 Thin
200 Extra Light
900 Black

Line heights

Body: 1.55–1.7
Docs body: 1.65
Headings: 1.05–1.2
Code: 1.55
Small UI: 1.35–1.45

Typographic tone

Headlines should be plain and confident.

Good:

Durable notifications for Phoenix apps.

Good:

Every delivery leaves a trace.

Good:

The right channel is sometimes no channel.

Avoid:

Supercharge your omnichannel engagement workflow.

Avoid:

Say goodbye to notification chaos forever.

16. Layout system

Grid

Use an 8px spacing system.

4px   micro-gap
8px   compact gap
12px  small internal gap
16px  normal internal gap
24px  card padding
32px  section cluster
48px  major section gap
64px  page section gap
96px  large marketing gap
128px hero spacing

Page width

Recommended max widths:

Docs content: 760px
Docs wide/code pages: 960px
Marketing content: 1120px
Full dashboard UI: 1280px

Corners

Chimeway should use soft but not bubbly radii.

4px  small UI controls
8px  inputs/buttons/code chips
12px cards
16px feature blocks
24px large marketing panels

Borders and shadows

Use borders more than shadows.

Preferred:

border: 1px solid var(--cw-line);
box-shadow: 0 1px 2px rgb(7 19 26 / 0.06);

Avoid heavy floating-card shadows.

UI density

Chimeway is infrastructure. It should be information-rich but calm.

Admin UI should prioritize:

* filters
* status labels
* timelines
* trace readability
* source-of-truth details
* copyable IDs
* redacted payload previews
* clear retry/requeue actions

17. Iconography

Icon style

Use outline icons with:

1.5px or 2px stroke
rounded caps
rounded joins
simple geometry
minimal detail

Recommended icon sets

Heroicons are MIT-licensed and work well for simple UI and docs icons. GitHub’s Octicons are also MIT-licensed and may fit README/GitHub-adjacent surfaces. Keep third-party icon license notices in the repository when required.  ￼

Core icon concepts

Use icons for:

* event
* route
* recipient
* inbox
* bell/chime
* database
* delivery
* attempt
* clock
* shield
* preferences
* webhook
* email
* push
* SMS
* Slack/chat
* trace
* suppression
* retry
* archive
* read/seen

Icon rules

Do:

* pair status icons with labels
* use icons to support scanning
* use route/path icons in diagrams
* use bell/chime icons sparingly

Do not:

* use musical notes
* use alarm sirens
* use megaphones as the main metaphor
* use emoji as primary icons
* use overly cute mascots
* use generic SaaS 3D blobs

18. Illustration direction

Illustration style

Use:

* monoline vector diagrams
* soft route paths
* waypoint nodes
* trace timelines
* layered cards
* inbox snippets
* database rows
* quiet signal arcs
* simple geometric backgrounds
* subtle paper texture if desired

Line style

Stroke: 1.5px–2px
Caps: rounded
Joins: rounded
Primary line: teal
Secondary line: line/neutral
Highlight node: brass or violet

Illustration themes

Good themes:

* event fanout to recipients
* recipient preference gate
* delayed email if unread
* trace timeline
* delivery attempt retry loop
* admin “why wasn’t this sent?” panel
* local database ownership
* channel adapter map
* quiet hours window
* digest batch

Avoid:

* people holding phones with notification bubbles
* stock photos of developers pointing at screens
* cartoon mascots
* megaphones
* growth charts
* confetti
* noisy sound-wave art
* 3D rendered bells
* generic cloud-platform isometric scenes

19. Acceptable imagery

Preferred imagery

Image type	Use
Abstract route diagrams	Homepage hero, feature pages
Trace timelines	Admin/debug marketing
Code + UI split screens	README, docs, landing page
Database row illustrations	Local-first ownership messaging
Calm system maps	Architecture pages
Subtle chime arcs	Brand accents
Inbox cards	In-app notification demos
Admin dashboards	Product screenshots

Photography

Photography is optional and usually unnecessary.

If used, choose:

* quiet workspaces
* real developer environments
* warm natural light
* minimal staging
* no corporate stock-photo feeling

Avoid:

* fake team high-fives
* people staring at notification bubbles
* sales-call imagery
* glassmorphism dashboards floating over clouds
* futuristic AI/cyberpunk aesthetics

20. Motion

Motion personality

Motion should feel like a signal calmly finding a path.

Use:

* route-line drawing
* soft pulse on a waypoint
* timeline step reveal
* gentle badge increment
* subtle accordion expansion
* delivery attempt progress
* suppressed-state fade

Avoid:

* flashing alerts
* bouncing bells
* shaking icons
* confetti
* aggressive notification popups
* looping animations that distract from docs

Accessibility

Respect prefers-reduced-motion.

@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
    scroll-behavior: auto !important;
  }
}

21. Product UI direction

Admin UI emotional goal

The admin UI should make operators feel:

“I can understand this system.”

Admin UI principles

1. Always show current state.
2. Always show why a decision happened.
3. Always show timestamps.
4. Always separate planned, enqueued, sending, succeeded, failed, suppressed, cancelled, and expired.
5. Always redact sensitive data by default.
6. Always make IDs copyable.
7. Always expose retry/requeue actions with confirmation.
8. Always distinguish provider acceptance from user-visible delivery.

Trace page structure

A Chimeway trace page should show:

Event
  -> Recipient resolution
  -> Policy checks
  -> Notification row
  -> Channel route
  -> Delivery plan
  -> Queue/enqueue state
  -> Delivery attempts
  -> Provider response
  -> Final state

“Why wasn’t this sent?” UI

This is a signature feature. It should have its own section, not be buried in logs.

Possible answer states:

No event was created.
No recipients were resolved.
Recipient had no route for this channel.
Preference disabled this channel.
Quiet hours delayed the delivery.
Frequency cap suppressed the delivery.
The in-app item was read before fallback email.
The delivery was planned but not enqueued.
The job has not run yet.
The provider rejected the payload.
The provider accepted the message, but user-visible delivery cannot be guaranteed.

UI copy examples

Good:

Email suppressed
The recipient read the in-app notification before the delayed email window.

Good:

Route missing
No active push token exists for this recipient.

Good:

Retryable provider error
Twilio returned a rate-limit response. Chimeway will retry with backoff.

Avoid:

Oops.
Unknown problem.
Notification failed.
User not notified.

22. Documentation direction

Docs personality

Docs should be:

* practical
* example-heavy
* explicit
* path-based
* searchable
* LLM-friendly
* copy/paste-friendly

Docs information architecture

Recommended docs sections:

Introduction
Quickstart
Concepts
Guides
Recipes
Adapters
Admin UI
Testing
Security
Troubleshooting
Reference
Upgrade Guides
Contributing

Key docs pages

Must-have pages:

What is Chimeway?
Install in Phoenix
Core Concepts
Event vs Notification vs Delivery vs Attempt
Define a Notifier
Trigger a Notification
In-App Notifications
Delayed Email if Unread
Preferences and Suppressions
Using Oban
Using Swoosh
Testing Notifications
Admin Trace UI
Why Wasn’t This Sent?
Adapter Contract
Security and Redaction
Multi-Tenancy
Upgrade Guide

Documentation style

Use this structure for guides:

# Guide title
One-sentence outcome.
## When to use this
## What you will build
## Prerequisites
## Step 1
## Step 2
## Verify it works
## Common mistakes
## Next steps

Docs code style

* Prefer complete snippets.
* Show module names in realistic Phoenix contexts.
* Use stable notification keys like "comment.created".
* Include idempotency keys.
* Include policy explanations.
* Include test examples.
* Include what gets persisted.
* Include what happens on failure.
* Avoid unexplained macros.
* Always offer a plain-data escape hatch when appropriate.

Docs example tone

Good:

NotifyKit.trigger(MyApp.Notifiers.CommentCreated,
  %{post_id: post.id, comment_id: comment.id},
  actor: current_user,
  idempotency_key: "comment:#{comment.id}:created"
)

When renamed for Chimeway:

Chimeway.trigger(MyApp.Notifiers.CommentCreated,
  %{post_id: post.id, comment_id: comment.id},
  actor: current_user,
  idempotency_key: "comment:#{comment.id}:created"
)

23. Marketing direction

Homepage headline options

Preferred:

Notifications that know the way.

Alternate:

Durable notifications for Phoenix apps.

Alternate:

One event. Every route. Full trace.

Alternate:

The local-first notification layer for Elixir.

Homepage subhead

Recommended:

Chimeway is an open-source notification library for Elixir apps. Define one event, fan out to many recipients and channels, persist every delivery, and answer exactly why something sent, failed, or was suppressed.

Hero CTA

Use:

Get started
Read the docs
View on GitHub

Avoid:

Book a demo
Start free trial
Contact sales
See pricing

Homepage sections

Recommended homepage structure:

Hero
  Headline
  Subhead
  Install snippet
  GitHub / Docs CTAs
Problem
  Notifications are easy to send but hard to operate.
Core idea
  Event -> Recipients -> Channels -> Deliveries -> Attempts -> Trace
Feature grid
  In-app records
  Durable fanout
  Preferences
  Delayed fallback
  Oban dispatch
  Swoosh email
  Admin trace
  Adapter contracts
Signature feature
  Why wasn’t this sent?
Local-first
  Your app. Your DB. Your policies.
Code example
  Define + trigger a notifier.
Admin preview
  Trace timeline screenshot/mockup.
OSS promise
  Open-source, non-commercial, no hosted lock-in.
Install
  mix archive / hex package / GitHub.

Feature copy examples

Durable fanout

Create one event, resolve many recipients, and plan one delivery per channel without losing the audit trail.

Delayed fallback

Show an in-app notification immediately. Send email later only if it remains unread.

Full trace

Follow each notification from trigger to route, policy, queue, provider response, and final state.

App-owned data

Events, inbox items, deliveries, attempts, preferences, and audit logs live in your own database.

Adapter-based

Wrap Swoosh, Pigeon, Slack, Twilio, webhooks, and future providers behind small explicit behaviours.

Marketing copy rules

Do:

* lead with developer pain
* show code early
* show the trace/debug differentiator
* emphasize local-first ownership
* mention Phoenix/Ecto/Oban clearly
* use screenshots/diagrams, not vague claims
* be honest about maturity

Do not:

* imply Chimeway is a hosted product
* imply every notification is guaranteed to be seen by users
* use “omnichannel engagement”
* compare aggressively against SaaS products
* overpromise zero configuration
* present the project as commercial or venture-backed

24. README direction

README opening

# Chimeway
Notifications that know the way.
Chimeway is an open-source notification library for Elixir and Phoenix apps. It helps you define notification events, resolve recipients, route across channels, persist in-app records, deliver through adapters, and trace every send, suppression, retry, and provider response.
Chimeway is embedded by design: your app owns the data, the policies, and the delivery history.

README feature bullets

- Stable notification keys and versions
- In-app notification records
- Recipient fanout
- Per-channel delivery planning
- Delivery and attempt persistence
- Idempotency keys
- Preferences and suppressions
- Delayed fallback, such as email if unread
- Oban-backed dispatch
- Swoosh email adapter
- Phoenix LiveView inbox/admin tools
- Adapter behaviours and shared contract tests

README non-goals

## Non-goals
Chimeway is not a SaaS, a marketing automation platform, a campaign builder, or an activity feed framework. It is focused on transactional/product notifications that live inside your Elixir application.

25. Voice examples

Homepage

Good:

Notifications are easy to send and hard to explain. Chimeway gives every event, recipient, delivery, and attempt a place in your app’s database, so production debugging starts with a trace instead of a guess.

Avoid:

Supercharge your user engagement with next-generation omnichannel notification journeys.

Docs

Good:

Use an idempotency key when the same domain event may be retried. Chimeway uses the key to avoid creating duplicate events and deliveries.

Avoid:

Chimeway magically knows when not to duplicate messages.

Error message

Good:

Delivery suppressed: recipient disabled email for `invoice.paid`.

Avoid:

This chime did not ring.

Admin UI

Good:

Provider accepted the push notification. Device display is not guaranteed by the provider response.

Avoid:

Push delivered.

Release notes

Good:

Added `Chimeway.DeliveryAttempt` records for webhook retries. This makes provider failures visible in the admin trace.

Avoid:

Huge new webhook upgrades!

Social post

Good:

Chimeway is an open-source notification layer for Phoenix apps. The first vertical slice: in-app notifications, delayed email fallback, Oban dispatch, and a trace view that answers “why wasn’t this sent?”

Avoid:

We’re disrupting notifications for modern developers.

26. Brand-safe technical claims

Use these freely:

open-source notification library
embedded notification layer
local-first notifications
Phoenix/Ecto/Oban-friendly
adapter-based
traceable deliveries
durable notification records
app-owned notification data

Use these only if implemented:

Oban-backed dispatch
Swoosh adapter
LiveView admin UI
push adapter
SMS adapter
digest engine
quiet hours
multi-tenancy
frequency caps
webhook signing

Avoid unless proven by tests/docs:

production-ready
enterprise-grade
guaranteed delivery
drop-in
zero-config
fully automated
complete provider support

27. Brand architecture

Core package

chimeway

Meaning: core behaviours, structs, notifier definitions, policy, routing, rendering contracts.

Ecto package

chimeway_ecto

Meaning: schemas, migrations, query APIs.

Oban package

chimeway_oban

Meaning: workers, transactional enqueue, retries, scheduling.

Phoenix package

chimeway_phoenix

Meaning: router helpers, LiveView components, PubSub integration.

Admin package

chimeway_admin

Meaning: notification dashboard, trace view, simulator, requeue/cancel tooling.

Adapter packages

chimeway_swoosh
chimeway_pigeon
chimeway_web_push
chimeway_twilio
chimeway_slack
chimeway_webhook

Meaning: optional provider/channel integrations.

Batteries package

chimeway_batteries

Meaning: convenience package for common Phoenix/Ecto/Oban/Swoosh setup.

28. UI design tokens

Border radius

--cw-radius-sm: 4px;
--cw-radius-md: 8px;
--cw-radius-lg: 12px;
--cw-radius-xl: 16px;
--cw-radius-2xl: 24px;

Spacing

--cw-space-1: 4px;
--cw-space-2: 8px;
--cw-space-3: 12px;
--cw-space-4: 16px;
--cw-space-6: 24px;
--cw-space-8: 32px;
--cw-space-12: 48px;
--cw-space-16: 64px;
--cw-space-24: 96px;
--cw-space-32: 128px;

Shadows

--cw-shadow-sm: 0 1px 2px rgb(7 19 26 / 0.06);
--cw-shadow-md: 0 8px 24px rgb(7 19 26 / 0.08);
--cw-shadow-focus: 0 0 0 3px rgb(14 124 134 / 0.22);

Typography tokens

--cw-font-sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
--cw-font-mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
--cw-font-serif: "Source Serif 4", Georgia, serif;
--cw-text-xs: 0.75rem;
--cw-text-sm: 0.875rem;
--cw-text-md: 1rem;
--cw-text-lg: 1.125rem;
--cw-text-xl: 1.25rem;
--cw-text-2xl: 1.5rem;
--cw-text-3xl: 2rem;
--cw-text-4xl: 2.75rem;
--cw-text-5xl: 3.75rem;

29. Landing page visual recipe

Hero layout

Use a split hero:

Left:

Notifications that know the way.

Subhead:

Chimeway is an open-source notification library for Elixir apps. Define one event, fan out to many recipients and channels, persist every delivery, and trace exactly why something sent, failed, or was suppressed.

CTA:

Get started
View on GitHub

Right:

A diagram:

Domain Event
  -> Recipients
  -> Policy
  -> In-App
  -> Email if unread
  -> Delivery Attempt
  -> Trace

Hero visual style

Use:

* warm paper background
* dark ink text
* teal route lines
* brass waypoint
* violet trace highlight
* small code sample card
* small admin trace card

Avoid:

* full-screen gradient
* fake 3D dashboard
* huge bell illustration
* generic cloud mesh

30. Open Graph and social cards

OG card formula

Use:

Logo top-left
Headline large
Short descriptor
Subtle route diagram
Dark or warm paper background

Example OG headline

Notifications that know the way.

Example OG subhead

Open-source, local-first notifications for Elixir and Phoenix apps.

Social card sizes

Open Graph: 1200 × 630
X/Twitter: 1200 × 675
GitHub social preview: 1280 × 640

31. Stickers and swag

Chimeway is OSS, so swag should feel community-oriented, not corporate.

Good sticker ideas:

chimeway
notifications that know the way
one event / every route / full trace
why wasn’t this sent?
local-first notifications

Visual ideas:

* small route-bell mark
* trace timeline sticker
* brass-on-night badge
* “why wasn’t this sent?” laptop sticker
* Chimeway.trigger(...) code sticker

Avoid:

* “I got chimed”
* loud alarm/bell jokes
* salesy slogans
* mascot-heavy merch

32. Community and governance voice

Contributor tone

Use:

Thanks for opening this.
This is a good fit for the roadmap.
This is probably better as an adapter package.
Can you add a failing test?
Let’s keep core dependency-light.
This should remain explicit rather than magical.

Avoid:

RTFM.
This is obvious.
We don’t do that here.
Just use another library.

Issue templates

Issue categories:

Bug report
Adapter request
Provider behavior
Docs improvement
Admin UI issue
Migration issue
Feature proposal
Security concern

Maintainer stance

Chimeway should be opinionated but not dismissive.

Default response pattern:

1. Acknowledge the problem.
2. State the current design principle.
3. Explain tradeoffs.
4. Suggest a path: core, adapter, extension, docs, or non-goal.

33. LLM context guide

Use this section when asking AI agents to generate code, docs, UI, landing pages, or marketing material for Chimeway.

Mandatory context

Chimeway is:

An open-source, non-commercial, embedded notification library for Elixir/Phoenix apps.

It is not:

A SaaS, hosted product, open-core business, marketing automation tool, or customer engagement platform.

LLM brand instructions

When generating Chimeway materials:

1. Use Chimeway, not ChimeWay.
2. Use chimeway for package names.
3. Use Chimeway.* for modules.
4. Describe it as an “open-source notification library” or “embedded notification layer.”
5. Avoid calling it a “platform” unless clarifying that it is not hosted.
6. Avoid commercial SaaS language.
7. Emphasize local-first data ownership.
8. Emphasize explainability and traceability.
9. Use calm, practical, developer-native language.
10. Use Elixir/Phoenix/Ecto/Oban examples when possible.
11. Mention that adapters wrap existing channel/provider tools.
12. Prefer stable notification keys like "comment.created".
13. Include idempotency in serious examples.
14. Show failure/suppression states, not just happy paths.
15. Keep metaphors light and headlines clear.

LLM copy banlist

Do not generate copy using these phrases:

customer engagement platform
omnichannel campaign automation
growth engine
marketing journey
book a demo
start your free trial
pricing
sales team
AI-powered notifications
blast users
maximize engagement
proprietary platform
hosted control plane

LLM preferred phrases

Use these phrases:

notifications that know the way
one event, every route, full trace
local-first notifications
embedded notification layer
app-owned notification data
durable deliveries
explainable suppressions
why wasn’t this sent?
Phoenix apps
Elixir-native
adapter-based
policy-aware

LLM homepage prompt seed

Write homepage copy for Chimeway.
Brand context:
Chimeway is an open-source, non-commercial, embedded notification library for Elixir and Phoenix apps. It is not a SaaS and never will be. It helps developers define notification events, resolve recipients, route across channels, persist in-app records and delivery attempts, and debug why notifications sent, failed, or were suppressed.
Voice:
Calm, precise, developer-native, practical, transparent. Avoid SaaS/growth/marketing automation language.
Core tagline:
Notifications that know the way.
Must emphasize:
local-first, app-owned data, Phoenix/Ecto/Oban-friendly, durable delivery records, explainable traces, preferences, suppressions, delayed fallback, adapter-based channels.

LLM docs prompt seed

Write Chimeway documentation.
Use clear, practical Elixir examples. Explain the difference between Event, Notification, Delivery, and DeliveryAttempt. Use stable notification keys, idempotency keys, and policy checks. Avoid hidden magic. Include verification steps and common mistakes. Keep the tone calm and developer-to-developer.

LLM UI prompt seed

Design a Chimeway admin UI screen.
Visual style:
Warm paper background, dark ink text, teal route accents, brass highlights, violet trace accents, rounded cards, high contrast, no heavy gradients.
UX priorities:
Show current state, reason, timestamps, recipient, channel, route, policy decision, delivery attempts, provider response, and redacted payload. Make the screen answer: “why wasn’t this sent?”

34. Brand do/don’t summary

Do

* Use calm, precise language.
* Lead with the notification path.
* Show code.
* Show traces.
* Show suppressed states.
* Show admin/debug value.
* Use warm technical visuals.
* Respect accessibility.
* Treat recipients as people, not targets.
* Be honest about project maturity.
* Keep OSS values visible.

Don’t

* Sound like a SaaS company.
* Use sales CTAs.
* Use “omnichannel engagement.”
* Make the brand too musical.
* Overuse bells.
* Overpromise delivery guarantees.
* Hide failures behind vague language.
* Use thin low-contrast type.
* Use color-only status indicators.
* Turn Chimeway into a marketing/campaign product.

35. Final creative direction

Chimeway should feel like the notification library an experienced Phoenix developer wishes already existed:

* friendly enough to install in an afternoon
* explicit enough to trust in production
* durable enough to debug after the fact
* respectful enough not to spam people
* open enough to invite contributors
* designed enough to make docs, UI, and marketing feel intentional

The brand should not compete by shouting. It should compete by being clear.

Chimeway: notifications that know the way.