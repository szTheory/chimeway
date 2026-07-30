# CI Hardening Backlog — CI-only lane failures (1 of 3 resolved; #2/#3 root causes pinned, quarantined pending push — see Phase 92 note)

_Filed 2026-07-09 after the milestone-boundary repo-hygiene sweep. Carried forward for a focused CI session (candidate for the next milestone)._

## Summary

After the hygiene sweep (clean tree, 340 commits pushed, all systemic CI issues fixed), `ci-gate` was at 11/15 lanes green. **The flaky `test` lane (#1) is now fixed (2026-07-09), so `pr-gate` is green and the merge pipeline is unblocked** — `ci-gate` is at **12/15**. Two lanes remain red (#2, #3); both reproduce **only on CI**.

Systemic fixes already landed on `main`: audit→advisory (`SECURITY.md`), uniform DB creds across lanes, CI Elixir 1.17→1.19, scoped migration-count query, `verify_gates` Postgres service.

**Green now (12):** Lint · Docs · Release gate contract · Runtime prefix · Mailglass · Inbox · Installer golden · Threadline · Sigra · Admin · **Test (OTP 26 + 27)**

---

## 1. Test lane — flaky isolation race ✅ RESOLVED 2026-07-09

**Fixed** (commits up to `28bee93`); `pr-gate` now green across 3 consecutive CI runs (was failing ~every 2nd–3rd run).

- **Symptom:** `Chimeway.GeneratedPrefixedRuntimeProofTest` intermittently `1 invalid` (setup_all raised) with `42P07 duplicate_table: relation "chimeway_events" already exists`; CI-only, never reproduced locally.
- **Actual root cause (proven by an added `current_database()` guard that flunked with `connected to chimeway_test, expected throwaway …`):** `prepare_generated_runtime_storage/1` starts a throwaway repo via `Repo.start_link/1`, which **merges the given opts over the app-env config**. On CI that config carries `url: DATABASE_URL` (`…/chimeway_test`); when both `:url` and `:database` are present, the URL's database wins — so the "throwaway" repo actually connected to `chimeway_test`, and its migrations collided with the `chimeway` schema the sibling `PrefixedRuntimeCase` clones there. Locally there is no `:url` in config, so it never reproduced. (The intermittency came from whether the sibling had already cloned the schema when this module's setup_all ran.)
- **Fix:** force `url: nil` in the throwaway repo config so the explicit `database` is authoritative (`test/support/generated_prefixed_runtime_case.ex`, `generated_repo_config/1`). Also kept as hardening: explicit `dynamic_repo:` on the migrator, a `current_database()` guard, a defensive `DROP SCHEMA` before migrating, and crash-safe cleanup.

## 2. Journeys + Example — `demo.up --check` hangs in CI

- **Symptom:** `Mix.Tasks.Demo.UpTest` "JOUR-05 mix demo.up --check exits 0" times out. Interim `@tag timeout: 300_000` confirmed a **hang** (>5 min), not slowness — runs ~2 s locally.
- **Cause:** the test runs `System.cmd("mix", ["demo.up", "--check"], env: [{"MIX_ENV", "dev"}, ...])`. In `:dev` the demo host needs its **dev database**, which CI never provisions (only the `test` DB is set up) → hangs on connection retry.
- **Suggested fix:** provision the demo-host dev DB (`ecto.create`/`ecto.migrate` in `MIX_ENV=dev` for `examples/chimeway_demo_host`) before the test, OR make `demo.up --check` DB-less / run it in test env. Reconsider the interim 300 s timeout tag afterward (`examples/chimeway_demo_host/test/mix/tasks/demo_up_test.exs`).
- **Root cause pinned (Phase 92/REL-02, `92-RESEARCH.md`):** the job-level `DATABASE_URL` env is inherited by the `System.cmd` subprocess, which routes the `:dev`-env task at whatever DB that URL names — combined with the `:dev` pre-warm compile step already on the demo lanes, `demo.up --check` no longer hits a cold-compile timeout or a missing DB. Both the job-level `DATABASE_URL` env and the `:dev` pre-warm step are load-bearing and must not be removed (Pitfall 5).
- **Phase 92 quarantine status:** mechanism above is pinned and a pre-phase run (`30558617430`) showed `verify_example`/`verify_journeys` green, but this plan requires the verified-fixed proof to be pinned to *this phase's own HEAD* push run — that run does not exist yet because the phase's commits have not been pushed to `origin/main` in this session (push is out of scope for this executor). **Quarantined, not silently gapped:** tracked in issue [#4](https://github.com/szTheory/chimeway/issues/4) pending a phase-HEAD-pinned push-run proof. The `@tag timeout: 300_000` tighten to `120_000` is deferred to that same push-verification pass so the tighten is never landed unguarded (Pitfall 5 / plan reversibility note).

## 3. Accrue — path dep not compiled in test env

- **Symptom:**
  ```
  Unchecked dependencies for environment test:
    could not find an app file at "_build/test/lib/accrue/ebin/accrue.app"
  ** (Mix) Can't continue due to errors on dependencies
  ```
- **Cause:** on CI, `accrue` is a **path dep** (`ACCRUE_PATH=.../accrue/accrue`, checked out from `szTheory/accrue`); locally it's the hex dep and compiles cleanly. An explicit `mix deps.compile accrue --force` step (added, runs under the job's `MIX_ENV=test`) still doesn't produce `accrue.app` — suggests the `szTheory/accrue` sibling fails to compile in this CI setup, or a nested-path / `app:` config mismatch.
- **Suggested fix:** compile the accrue sibling directly on CI and read the real error; verify `ACCRUE_PATH` points at the mix project root; compare against the passing `verify_sigra` lane's custom setup.
- **Root cause pinned (Phase 92/REL-02, `92-RESEARCH.md`):** full-tree `mix deps.compile` (via `obs-recompile.sh`) produces `accrue.app` in dependency order before the lane's own suite runs, plus the nested `ACCRUE_PATH` layout resolves correctly — the earlier standalone `mix deps.compile accrue --force` step was the incomplete fix; the full-tree compile step is what actually resolves it.
- **Phase 92 quarantine status:** mechanism above is pinned and a pre-phase run (`30558617430`) showed `verify_accrue` green, but — same as #2 — this plan requires proof pinned to this phase's own HEAD push run, which does not exist yet (commits not pushed in this session). **Quarantined, not silently gapped:** tracked in issue [#4](https://github.com/szTheory/chimeway/issues/4) pending a phase-HEAD-pinned push-run proof.

## 4. Compile-once spike — warm `_build` restore still recompiles (CACHE-05, deferred from Phase 88)

_Filed 2026-07-29. Phase 88 fixed cache correctness (keys/collision/HITs) but the warm `ci-gate` **regressed** ~373 s → ~648 s; the compile-once target was not met. See `CI-PERF-BASELINE.md` "Phase 88 outcome"._

**✅ REGRESSION RECOVERED 2026-07-29** (commit `bbee487`): deleted the serial `build` producer and converted the 9 default lanes to per-lane self-caching, which also re-warms the demo lanes' `:dev` build (236s/297s → 6s). Warm `ci-gate` **648 s → 362 s** (at/below baseline; run `30480960879`). **What remains open below is now LOW-VALUE:** cost analysis proved the slow lanes are test-execution-bound (`mix ci.test` 280s, `verify.install_golden` 183s), not compile — so the <3 min target needs **Phase 89 async**, and eliminating the residual per-lane recompile (ex_cldr/rebar) would shave compile but not reach <3 min. Keep the notes below only if a future pass wants the last compile-seconds.

- **Symptom:** on warm runs every lane's `build-test` cache HITs and the restored `_build` is complete (app manifest + 98 beams present), yet compilation still costs ~86 s+ per lane, and the serial `build` producer (`needs: [build]`) adds ~140 s in front of consumers that don't get faster.
- **Three proven causes (on-runner producer probe, run `30474102629`):**
  1. **`ex_cldr` / `ex_cldr_numbers` rebuild ~86 s exactly once after each cache restore** (then stable) — via `ex_money` → `mailglass`. Signature of the D-01 split of `deps` and `_build` into two independently-restored caches: the dep source can land newer than its compiled artifact, so `mix` rebuilds it once. Top hypothesis to test first: **re-unify `deps`+`_build` into a single cache** so their relative mtimes are preserved.
  2. **8 rebar/Erlang deps (hackney, telemetry, idna, certifi, mimerl, parse_trans, metrics, unicode_util_compat) recompile on every `mix` invocation** regardless of cache — the known `mix`-invokes-`rebar3` quirk. Needs its own investigation (rebar `_build`/`.rebar3` caching).
  3. **Consumers recompile the app (~93 files) though the producer does not** — cause still unprobed (consumer-specific; would need a second probe on e.g. `install_golden`).
- **Ruled out:** mtime staleness (mix's content-hash check ignores it — confirmed on CI and locally, and a `restore-mtimes.sh` experiment changed nothing); cache incompleteness (restored `_build` is complete); an `ex_cldr → app` cascade (producer app stayed clean after ex_cldr rebuilt).
- **Suggested approach:** spike the unified-cache hypothesis first (cheapest, addresses the ~86 s ex_cldr cost); if the producer split still doesn't pay off after that, consider reverting the `build` producer + `needs: [build]` wiring to baseline timing and keeping only the pure key-correctness. Each hypothesis costs an ~11-min live CI run — batch changes.

---

**Interim commits already on `main` (see `2c2cb2a`):** the scoped migration-count fix (real fix — keep), plus the `demo_up_test` timeout tag and the accrue `deps.compile` step (both interim/partial — revisit per above).

**To promote to a GitHub issue:**
```
gh issue create --title "CI hardening: 3 CI-only lane failures blocking ci-gate" \
  --body-file .planning/CI-HARDENING-BACKLOG.md
```
