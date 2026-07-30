# 89-02 Summary — Fan-out: 9 async flips (inbox/digests/workflows)

**Status:** COMPLETE (commit `b597489`) · **Requirements:** CONC-01

Flipped to `async: true` (each a one-line `use Chimeway.DataCase` edit, research-audited D-02 flip-safe):
`inbox_state_transition`, `inbox_pagination`, `inbox_query`, `inbox_integration`,
`digests/digest_rule`, `digests/emission`, `digests/accumulation`,
`workflows_inspection`, `workflows`.

Verified together with 89-03/89-04 in the combined suite run (see 89-06): 1229 tests, 0 failures, 0 invalid, no non-Threadline ownership errors, on both a random seed and `--seed 0`.
