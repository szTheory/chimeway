---
phase: 72-admin-docs-and-verification-gate
plan: 02
subsystem: testing
tags: [playwright, chromium, admin, liveview, smoke]

requires: []
provides:
  - Root Playwright Chromium smoke harness for the mounted admin console
  - npm metadata and lockfile for @playwright/test 1.60.0
  - Demo-host HTTP/LiveView runtime support for real browser smoke
affects: [admin-console, demo-host, browser-smoke, verify-admin]

tech-stack:
  added: ["@playwright/test 1.60.0", "plug_cowboy 2.8.1 in demo host"]
  patterns: [Playwright webServer demo host startup, real-browser LiveView smoke, responsive overflow assertion]

key-files:
  created:
    - package.json
    - package-lock.json
    - playwright.config.ts
    - test/browser/admin_smoke.spec.ts
  modified:
    - chimeway_admin/priv/static/chimeway_admin.css
    - examples/chimeway_demo_host/config/test.exs
    - examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex
    - examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex
    - examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex
    - examples/chimeway_demo_host/mix.exs
    - examples/chimeway_demo_host/mix.lock

key-decisions:
  - "Browser smoke uses Playwright Chromium only, with desktop 1280x900 and mobile 390x844 projects."
  - "Demo-host smoke starts the test endpoint explicitly with server: true because config/test.exs keeps server false by default."
  - "Demo admin tenant defaults to DemoHost.Seeds.tenant_id/0 so mounted admin smoke sees seeded TeamPulse data."

patterns-established:
  - "Demo-host browser smoke serves Phoenix and LiveView static JS directly from deps without adding a frontend build pipeline."
  - "Responsive smoke rejects document-level overflow except intentional table-wrapper overflow."

requirements-completed: [SMOKE-01]

duration: 34min
completed: 2026-06-04
---

# Phase 72: Admin Browser Smoke Summary

**Playwright Chromium smoke proves the mounted admin console is nonblank, styled, navigable, form-usable, responsive, and redacted**

## Performance

- **Duration:** 34 min
- **Started:** 2026-06-04T21:21:00Z
- **Completed:** 2026-06-04T21:55:37Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added exact `@playwright/test` 1.60.0 dependency, npm lockfile, and a `smoke:admin` script.
- Added `playwright.config.ts` with demo-host webServer startup on `http://127.0.0.1:4002`, Chromium desktop/mobile projects, traces on failure, and screenshots on failure.
- Added `test/browser/admin_smoke.spec.ts` covering shell visibility, packaged CSS, nav routes, Trace Lookup, Trace Detail, Feed Debug, Recovery safety, privacy strings, and responsive overflow.
- Fixed demo-host browser runtime prerequisites: HTTP adapter, LiveView client assets, CSRF token, origin allowance, and seeded admin tenant alignment.
- Fixed a real mobile CSS cascade issue where `.cw-search-form` kept desktop grid columns under 390px.

## Task Commits

1. **Task 72-02-01: Add Playwright Chromium Project Metadata And Config** - `aa26e7b` (test)
2. **Task 72-02-02: Implement Mounted Admin Browser Smoke** - `8a9da03` (test)

## Files Created/Modified

- `package.json` - Root npm metadata with `smoke:admin` and exact `@playwright/test`.
- `package-lock.json` - npm-generated lockfile.
- `playwright.config.ts` - Chromium projects and demo-host webServer startup.
- `test/browser/admin_smoke.spec.ts` - Mounted admin browser smoke.
- `examples/chimeway_demo_host/mix.exs` / `mix.lock` - Added `plug_cowboy` so the demo endpoint can run as a real HTTP server.
- `examples/chimeway_demo_host/lib/demo_host_web/endpoint.ex` - Serves admin CSS plus Phoenix/LiveView JS.
- `examples/chimeway_demo_host/lib/demo_host_web/layouts/root.html.heex` - Loads CSS, CSRF token, Phoenix JS, LiveView JS, and connects `LiveSocket`.
- `examples/chimeway_demo_host/config/test.exs` - Allows the 127.0.0.1/localhost smoke origins.
- `examples/chimeway_demo_host/lib/demo_host_web/plugs/admin_actor.ex` - Uses seeded TeamPulse tenant by default with env override.
- `chimeway_admin/priv/static/chimeway_admin.css` - Adds late mobile override for `.cw-search-form`.

## Decisions Made

- Kept the smoke as one cross-project spec that runs once per Chromium viewport.
- Kept recovery non-mutating: verify eligible-work/confirm panels and disabled danger submit when a candidate exists, otherwise verify honest empty state.
- Used direct Phoenix/LiveView static assets instead of introducing a JS bundler.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Demo host could not start a real HTTP endpoint**
- **Found during:** Task 72-02-02 Playwright webServer startup.
- **Issue:** `config/test.exs` sets `server: false`, and the demo host lacked `plug_cowboy`, so the endpoint never listened on port 4002.
- **Fix:** Added `plug_cowboy`, changed Playwright webServer to set `server: true` before `Application.ensure_all_started/1`.
- **Verification:** `curl http://127.0.0.1:4002/admin/chimeway` returned 200 during manual probe; Playwright smoke passed.
- **Committed in:** `8a9da03`

**2. [Rule 3 - Blocking] Real-browser LiveView interactions were inert**
- **Found during:** Task 72-02-02 Trace Lookup form smoke.
- **Issue:** Demo host layout loaded CSS only; no LiveView client JS, CSRF token, or allowed origin for the 127.0.0.1 smoke host.
- **Fix:** Served Phoenix/LiveView static JS from deps, connected `LiveSocket` with CSRF token, and allowed test origins.
- **Verification:** Trace Lookup submit, row button `open_delivery`, and Feed Debug submit pass in Chromium.
- **Committed in:** `8a9da03`

**3. [Rule 3 - Blocking] Mobile `.cw-search-form` overflowed outside table wrappers**
- **Found during:** Task 72-02-02 mobile overflow assertion.
- **Issue:** Existing mobile grid override appeared before the base `.cw-search-form`, so cascade order restored desktop columns at 390px.
- **Fix:** Added a later max-width override for `.cw-search-form`.
- **Verification:** Mobile Playwright project passes document overflow assertion.
- **Committed in:** `8a9da03`

---

**Total deviations:** 3 auto-fixed (all blocking smoke/runtime issues).
**Impact on plan:** Fixes were required to make the planned real-browser smoke meaningful; no new operator capabilities were added.

## Issues Encountered

- Selector strictness required exact/scoped locators for duplicated labels like `Trace Lookup`, `Definitions`, and `Recovery`.
- Playwright webServer emits optional-dependency config warnings for skipped ecosystem packages; they are non-fatal in this smoke path.

## User Setup Required

None - browser installation is handled by `npx playwright install chromium` / later `mix verify.admin`.

## Verification

- `npm ci` - passed
- `npx playwright install chromium` - passed
- `npx playwright test test/browser/admin_smoke.spec.ts` - passed, 2 projects
- `npm ci && npx playwright install chromium && npx playwright test test/browser/admin_smoke.spec.ts` - passed, 2 projects

## Next Phase Readiness

Plan 72-03 can wire `mix verify.admin` to call `npm ci`, `npx playwright install --with-deps chromium`, and `npx playwright test test/browser/admin_smoke.spec.ts`.

---
*Phase: 72-admin-docs-and-verification-gate*
*Completed: 2026-06-04*
