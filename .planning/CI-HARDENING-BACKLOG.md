# CI Hardening Backlog — 3 CI-only lane failures blocking `ci-gate`

_Filed 2026-07-09 after the milestone-boundary repo-hygiene sweep. Carried forward for a focused CI session (candidate for the next milestone)._

## Summary

After the hygiene sweep (clean tree, 340 commits pushed, all systemic CI issues fixed), `ci-gate` is at **11/15 lanes green**. Three lanes remain red. All three **pass locally** (full core suite = `1176 tests, 0 failures`) and reproduce **only on CI**, so they need CI-environment debugging rather than code fixes verifiable locally.

Systemic fixes already landed on `main`: audit→advisory (`SECURITY.md`), uniform DB creds across lanes, CI Elixir 1.17→1.19, scoped migration-count query, `verify_gates` Postgres service.

**Green now (11):** Lint · Docs · Release gate contract · Runtime prefix · Mailglass · Inbox · Installer golden · Threadline · Sigra · Admin · (Test OTP-26 intermittently)

---

## 1. Test lane — flaky isolation race (⚠️ blocks `pr-gate`)

**Highest priority:** `pr-gate` needs `[lint, test, verify_gates, verify_docs]`; three are green, so fixing this lane restores the merge pipeline and unblocks the release PR — independent of #2/#3.

- **Symptom:** `Chimeway.GeneratedPrefixedRuntimeProofTest` reported `1 invalid` (setup_all raised):
  ```
  ** (Postgrex.Error) ERROR 42P07 (duplicate_table) relation "chimeway_events" already exists
  ```
- **Flaky, CI-only:** on a single-commit re-run, **OTP 26 passed while OTP 27 failed**. Local full core suite passes 1176/0 every time.
- **Where:** `prepare_generated_runtime_storage/1` in `test/support/generated_prefixed_runtime_case.ex` — creates a throwaway DB `chimeway_generated_prefixed_runtime_#{unique}` via `Ecto.Adapters.Postgres.storage_up/1`, treats `{:error, :already_up}` as `:ok`, then runs 31 fixture migrations. "Already exists" = migrations ran against a non-clean DB/schema.
- **Likely cause:** the `already_up`-as-`:ok` path migrating a pre-existing DB, or a race with a prior module's `on_exit` cleanup (`storage_down` + `File.rm_rf`). Global `Application.put_env(:chimeway, :prefix, ...)` adds shared-state fragility.
- **Suggested fix:** force a clean slate before migrating (`storage_down` then `storage_up`, or drop the `chimeway` prefix schema) so `already_up` never migrates dirty state; guard the global `:prefix` env.

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
