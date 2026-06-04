---
phase: 67-close-ecos-09-repin-sigra-ci-sha-harden-verify-lanes-against
plan: 02
subsystem: docs
tags:
  - doc-contract
  - doc-fixes
  - validation
requires:
  - 67-01
provides:
  - 67-03
affects:
  - guides/introduction/sigra-auth-integration.md
  - guides/introduction/threadline-integration.md
  - test/chimeway/doc_contract_test.exs
tech-stack: []
key-files:
  modified:
    - guides/introduction/sigra-auth-integration.md
    - guides/introduction/threadline-integration.md
    - test/chimeway/doc_contract_test.exs
decisions:
  - "Doc Contract Enforcement: added positive assertion and negative exclusions to enforce the valid shape of `Chimeway.trigger/3` calls in guides to guarantee accurate copy-paste code snippets for adopters."
metrics:
  duration: 2m
  completed_date: "2026-06-03"
---

# Phase 67 Plan 02: Sigra guide invalid trigger example fix and doc-contract hardening Summary

This plan corrected the `Chimeway.trigger/3` call in the Sigra auth integration guide to align with the real module-first valid shape (removing the invalid string identity first arg and non-existent `params:` option). We also removed bare arity-1 notation inside Elixir fences which raised on copy-paste.

Finally, we enhanced the `doc_contract_test.exs` module to forbid invalid legacy trigger shapes and enforce passing a Notifier module as the first argument, locking down guide accuracy.

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED
