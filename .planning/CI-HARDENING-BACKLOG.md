# CI Hardening Backlog — CI-only lane failures (1 of 3 resolved)

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

## 3. Accrue — path dep not compiled in test env

- **Symptom:**
  ```
  Unchecked dependencies for environment test:
    could not find an app file at "_build/test/lib/accrue/ebin/accrue.app"
  ** (Mix) Can't continue due to errors on dependencies
  ```
- **Cause:** on CI, `accrue` is a **path dep** (`ACCRUE_PATH=.../accrue/accrue`, checked out from `szTheory/accrue`); locally it's the hex dep and compiles cleanly. An explicit `mix deps.compile accrue --force` step (added, runs under the job's `MIX_ENV=test`) still doesn't produce `accrue.app` — suggests the `szTheory/accrue` sibling fails to compile in this CI setup, or a nested-path / `app:` config mismatch.
- **Suggested fix:** compile the accrue sibling directly on CI and read the real error; verify `ACCRUE_PATH` points at the mix project root; compare against the passing `verify_sigra` lane's custom setup.

---

**Interim commits already on `main` (see `2c2cb2a`):** the scoped migration-count fix (real fix — keep), plus the `demo_up_test` timeout tag and the accrue `deps.compile` step (both interim/partial — revisit per above).

**To promote to a GitHub issue:**
```
gh issue create --title "CI hardening: 3 CI-only lane failures blocking ci-gate" \
  --body-file .planning/CI-HARDENING-BACKLOG.md
```
