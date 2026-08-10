---
status: testing
phase: 96-adoption-front-door-proof-gate
source: [96-VERIFICATION.md]
started: 2026-08-10T23:27:19Z
updated: 2026-08-10T23:27:19Z
---

## Current Test

number: 1
name: Concurrent archive pathname replacement
expected: |
  Only the originally read immutable archive bytes are hashed, parsed, and materialized.
awaiting: user response

## Tests

### 1. Concurrent archive pathname replacement
expected: Only the originally read immutable archive bytes are hashed, parsed, and materialized.
result: pending

### 2. Live verify_adoption_paths GitHub Actions lane
expected: The PostgreSQL 15 lane succeeds and ci-gate consumes its result.
result: pending

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
