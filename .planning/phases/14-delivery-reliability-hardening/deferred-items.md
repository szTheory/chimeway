# Phase 14 Deferred Items

Items discovered during execution that are out of scope for the current task and are
deferred for explicit handling later. Per executor scope-boundary rule: only auto-fix
issues directly caused by the current task's changes; pre-existing failures in
unrelated files are logged here.

## Pre-existing `mix format --check-formatted` violations

Discovered while running `mix ci` for Plan 14-01. These files are not touched by
Phase 14 Wave 0 (test scaffolding only) and the violations exist on `main` prior to
this plan. They block `mix ci.lint` for everyone, not just this plan.

| File                                | Discovered in | Notes                                                                     |
| ----------------------------------- | ------------- | ------------------------------------------------------------------------- |
| `lib/chimeway/policy.ex`            | 14-01, 14-02  | Pre-existing format violation, unrelated to Phase 14 scope                |
| `lib/chimeway/policy/settings.ex`   | 14-01, 14-02  | Pre-existing format violation, unrelated to Phase 14 scope                |
| `test/chimeway/policy_test.exs`     | 14-01, 14-02  | Long-line `assert ==` not wrapped; pre-existing                            |

**Recommended disposition:** Have a Phase 14 closeout plan (or a one-off chore commit)
run `mix format` on these three files. Touching them inside 14-01 or 14-02 would expand
scope beyond their documented boundaries (Wave 0 test scaffolding for 14-01; additive
schema/migration for 14-02). 14-02 confirms `mix ci` is still blocked by the same three
files.
