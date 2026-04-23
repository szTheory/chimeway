# Chimeway Agent Guide

## Project

Chimeway is an open-source, embedded notification layer for Elixir and Phoenix apps. It is local-first: host applications own their data, policies, and delivery history.

Core value: every notification decision must be explainable ("why was this sent, failed, or suppressed?").

## Technology Stack

- Elixir 1.17+ / OTP 26+
- Ecto 3.x + PostgreSQL 15+
- Phoenix 1.7/1.8 (optional integration surfaces)
- Oban 2.x (optional but recommended async dispatch)
- Swoosh 1.x (email adapter seam)

## Build Principles

- Persist stable `notification_key` + version (never module names as durable identity).
- Keep a durable lifecycle spine: event -> notification -> delivery -> attempt.
- Treat idempotency and suppression reasons as first-class product behavior.
- Keep adapters replaceable with explicit behaviours and contract tests.
- Preserve host ownership boundaries (auth, tenancy, URL generation, correlation IDs).

## Quality Gates

- Provide and maintain `mix verify.*` and `mix ci.*` entrypoints.
- Keep CI and local scripts in parity.
- Avoid leaking sensitive payload fields in telemetry and operator surfaces.

## Planning Source of Truth

- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

Current roadmap has 5 phases, with Phase 1 (`Durable Core Spine`) as the immediate focus.
