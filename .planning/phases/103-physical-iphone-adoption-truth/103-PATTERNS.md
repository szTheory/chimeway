# Phase 103: Physical iPhone & Adoption Truth - Pattern Map

**Mapped:** 2026-08-26  
**Files analyzed:** 15 planned create/modify surfaces (including the required CrossWake coordination seam)  
**Analogs found:** 14 / 15

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/mobile_proof/physical_bundle.ex` (new; exact name at planner discretion) | model / validator | transform | `lib/chimeway/mobile_proof/extension.ex` | role-match — must remain a separate v1 class |
| `lib/mix/tasks/verify.physical_proof_contract.ex` | config / verifier task | batch, file-I/O | same file | exact |
| `test/chimeway/mobile_physical_proof_test.exs` (new) | test | transform | `test/chimeway/mobile_proof_extension_test.exs` | role-match |
| `test/fixtures/alpha_twin_physical_proof/physical-valid.json` (new) | fixture | file-I/O | `test/fixtures/alpha_twin_physical_proof/valid.json` | role-match |
| `test/fixtures/alpha_twin_physical_proof/physical-negative-corpus.json` (new) | fixture | file-I/O | `test/fixtures/alpha_twin_physical_proof/negative-corpus.json` | exact |
| `test/chimeway/mobile_proof_extension_test.exs` | test | transform | same file | exact regression boundary |
| `test/chimeway/doc_contract_test.exs` | test | request-response (file-content contract) | adoption-selector/HexDocs blocks in same file | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | event-driven (CI topology contract) | Alpha-twin CI block in same file | exact |
| `mix.exs` | config | event-driven | aliases/extras in same file | exact |
| `.github/workflows/ci.yml` | config | event-driven | `verify_alpha_twin` job | exact |
| `guides/introduction/mobile-adoption-operations.md` (new) | documentation | request-response | `guides/introduction/adoption-paths.md` | role-match |
| `guides/introduction/adoption-paths.md` | documentation | request-response | same file | exact |
| `README.md` | documentation | request-response | guide link at line 100 | exact |
| `../crosswake/lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex` (new; selected-SHA compatibility seam) | model / validator | transform | `../crosswake/lib/crosswake/proof_lane/physical_iphone_contract.ex` | role-match — existing assertions are offline-study-only |
| `../crosswake/test/crosswake/proof_lane/chimeway_notification_physical_proof_test.exs` (new) | test | transform | CrossWake physical-contract tests | partial; exact test path to confirm at selected SHA |

`valid.json` and `negative-corpus.json` are immutable hermetic-v1 inputs. Do **not** repurpose, move, or alter their `proof_class: "hermetic"` records. The physical fixtures must be new files/a new root even if the exact names change.

## Pattern Assignments

### `lib/chimeway/mobile_proof/physical_bundle.ex` (model / validator, transform)

**Analog:** `lib/chimeway/mobile_proof/extension.ex`

**Closed schema and stable errors** (lines 4-38):

```elixir
@version 1
@keys ~w(extension_version owner proof_class ...)

with :ok <- exact_keys(proof),
     :ok <- equals(proof, "extension_version", @version, "MP-VERSION"),
     ... do
  {:ok, proof}
else
  {:error, _} = error -> error
end

defp exact_keys(proof) do
  if Map.keys(proof) |> Enum.sort() == Enum.sort(@keys), do: :ok, else: error("MP-SCHEMA", [])
end
```

**Digest and non-echoing error convention** (lines 40-60, 162):

```elixir
defp digest(proof, key, rule) do
  if is_binary(proof[key]) and Regex.match?(~r/\A[0-9a-f]{64}\z/, proof[key]),
    do: :ok,
    else: error(rule, [key])
end

defp error(rule_id, path), do: {:error, %{rule_id: rule_id, path: path}}
```

**Bounded string-to-existing-atom conversion and privacy recursion** (lines 113-161):

```elixir
defp string_report_to_atoms(report) when is_list(report) do
  Enum.map(report, fn
    %{"id" => id, "owner" => owner, "outcome" => outcome} = value when map_size(value) == 3 ->
      %{id: id, owner: safe_owner(owner), outcome: safe_outcome(outcome)}
    _ -> %{}
  end)
end

defp sensitive?(value) when is_map(value),
  do: Enum.any?(value, fn {key, nested} -> sensitive?(to_string(key)) or sensitive?(nested) end)
```

Create a **new** module/versioned proof class rather than adding fields to this module. Apply exact-key checks recursively to the bundle records: Chimeway envelope, CrossWake digest reference, visible-alert attestation, and completion marker. Only retain specified opaque refs/digests and Chimeway-owned facts. Return rule ID plus bounded path only; never return rejected values or canonical CrossWake bytes.

### `lib/mix/tasks/verify.physical_proof_contract.ex` (Mix verifier, batch/file-I/O)

**Analog:** same file.

**Artifact-binding workflow** (lines 10-31):

```elixir
load_crosswake!()
corpus = read!("negative-corpus.json")

with {:ok, artifact} <- build_artifact!(),
     artifact_sha256 <- sha256!(artifact),
     {:ok, _} <- validate_built_artifact!(artifact, artifact_sha256),
     ...,
     :ok <- verify_cases(corpus, validator) do
  Mix.shell().info("physical proof contract OK")
else
  _ -> exit({:shutdown, 70})
end
```

**Strict corpus dispatch** (lines 35-53) and **ephemeral archive cleanup** (lines 55-93) are the required shape. Extend it to select physical-v1 fixtures separately from hermetic-v1, validate both independently, and invoke only a CrossWake source-bound checker at the declared full SHA. Do not load/copy its report into retained Chimeway evidence.

### `test/chimeway/mobile_physical_proof_test.exs` and physical fixtures (test / file-I/O)

**Analogs:** `test/chimeway/mobile_proof_extension_test.exs`, `test/fixtures/alpha_twin_physical_proof/{valid,negative-corpus}.json`.

**Fixture decode plus boundary assertion** (`mobile_proof_extension_test.exs`, lines 8-13):

```elixir
fixture = @fixture |> File.read!() |> Jason.decode!()
assert {:ok, proof} = Extension.validate(fixture, canonical_validator: &valid_report/1)
assert proof["subjective_observation"] == %{"visible_alert" => "not_asserted"}
```

**Rule/path-only negative assertion** (lines 15-24):

```elixir
assert {:error, %{rule_id: "MP-ARTIFACT-DIGEST", path: ["chimeway_artifact_sha256"]}} =
         Extension.validate(...)
```

**Negative corpus format** (`negative-corpus.json`, lines 1-13): use a closed `cases` list with stable `id`, expected `rule_id`, bounded `path`, and a full malformed proof. Include missing/unknown/duplicate/reordered keys, owner/revision/digest mismatch, marker mismatch, recursive sensitive keys/values, fabricated CrossWake/device claims, no-replace collision, and each invalid attestation state. The attestation tests must prove that input can validate `observed`, but no automatic producer/promotion path can create or infer it.

### CrossWake source-bound notification seam (model/test, transform)

**Analog:** `../crosswake/lib/crosswake/proof_lane/physical_iphone_contract.ex`.

**Ordered fixed owner-qualified facts** (lines 8-23, 45-70):

```elixir
@owners [:device_local, :backend_authority, :evidence_promotion]
@outcomes [:passed, :blocked, :unavailable]
@assertions [
  %{id: "PI-PACK-INSTALL-AUDIO", owner: :device_local},
  ...
]

if Enum.all?(report, &exact_report_entry_shape?/1) do
  ...
  supplied_ids != expected_ids -> {:error, "PI-ASSERTIONS-ORDER"}
  not Enum.all?(report, &valid_report_entry?/1) -> {:error, "PI-ASSERTIONS-OWNER"}
end
```

The current contract is explicitly an offline-study vocabulary, so it is **not** semantic authority for notification permission, authenticated registration, and protected activation. At the selected immutable CrossWake SHA, add/expose a distinct CrossWake-owned notification extension with its own closed ordered assertions and public `validate_report`/source-bound evidence entrypoint. Chimeway consumes the result and digests only.

**No-replace publication pattern:** `../crosswake/lib/crosswake/proof_lane/native_promotion.ex` lines 11-30 and 55-67 digest immutable bytes then map collision to a stable rule. Reuse that behavior in CrossWake-owned publication; do not reimplement overwrite-capable publication in Chimeway.

### CI, alias, and gate contracts (config / event-driven)

**Analogs:** `mix.exs`, `.github/workflows/ci.yml`, `test/chimeway/release_gate_contract_test.exs`.

**Alias grouping** (`mix.exs`, lines 125-130):

```elixir
"ci.verify_gates": [
  "cmd scripts/test-db env CHIMEWAY_SKIP_PARTNER_TEST_REPOS=1 MIX_ENV=test mix test test/chimeway/doc_contract_test.exs test/chimeway/release_gate_contract_test.exs --exclude adoption_paths_e2e --warnings-as-errors"
],
"ci.alpha_twin": ["verify.alpha_twin", "verify.physical_proof_contract"],
```

**Credential-free pinned-repository job** (`.github/workflows/ci.yml`, lines 299-346): it pins `CROSSWAKE_PATH`, does a detached full-SHA checkout, asserts remote/HEAD/clean state, then runs `mix verify.alpha_twin` and `mix verify.physical_proof_contract`. Replace the old hermetic pin only after selecting a compatible source-bound revision; retain the job as Linux/credential-free and do not add Apple/Xcode/APNS secrets.

**Topology contract** (`release_gate_contract_test.exs`, lines 25-26 and 2683-2718): update the lane lists, required strings, aggregate `needs`, and result tokens together if a distinct physical lane is introduced. Existing physical-contract validation can remain inside `verify_alpha_twin` only if tests lock the replacement selected SHA and both aggregate gates.

### Documentation and doc-contracts (documentation / request-response)

**Guide analog:** `guides/introduction/adoption-paths.md`.

**Progressive-disclosure/ownership/boundary format** (lines 3, 7-23):

```markdown
**Choose this when:** ...

**Host responsibility:** ...

**Chimeway responsibility:** ...

**Partner responsibility:** ...

**Does not cover:** ...

**Next step:** ...
```

The new guide is the canonical authority: organize its opening by the four jobs, then link to detailed installation, storage-prefix upgrade, Oban, tracing, adapter, Golden Path, and proof material. State on every relevant support/proof section that **physical evidence is pending** at Threshold A; provider acceptance is handoff only, not device receipt/display/protected open/inbox/engagement.

**ExDoc registration:** `mix.exs` lines 245-280 shows literal extras paths grouped by regex. Add the guide under Introduction, then link it shallowly from README and Adoption Paths; do not duplicate the runbook.

**Doc contract pattern:** `test/chimeway/doc_contract_test.exs` lines 1821-1870 uses an explicit `@integration_guides` list plus ordering assertion; lines 1968-2057 read the three affected surfaces and assert required/forbidden exact strings. Add one dedicated Phase-103 describe block that checks guide existence, role entry points, headings/order, executable commands, stable terminology, links, pending wording, and forbidden overclaims/sensitive examples.

**README linking pattern:** `README.md` line 100 links to the detailed Golden Path rather than repeating it. Add one equivalent sentence/link to `guides/introduction/mobile-adoption-operations.md`.

## Shared Patterns

### Exact schemas, privacy, and error projection

**Sources:** `lib/chimeway/mobile_proof/extension.ex` lines 14-46, 113-162; CrossWake `evidence.ex` lines 40-43, 441-479.

Apply to the new Chimeway envelope, attestation, fixture corpus, and CrossWake boundary: exact allowlists; full lower-case SHA-256 strings; closed state enums; stable ordering; recursive scans for tokens/credentials/payloads/identities/device references/logs/paths/media; bounded atom conversion; only rule ID and path in failure results.

### Immutable/source-bound ownership

**Sources:** `lib/mix/tasks/verify.physical_proof_contract.ex` lines 10-24 and 95-98; `.github/workflows/ci.yml` lines 327-346.

The verifier resolves an exact remote and detached SHA, hashes canonical CrossWake bytes inside the source-bound validation scope, and retains digests/revision/result only. Do not adapt the old `Extension.canonical_report/2` copying strategy for physical evidence.

### Append-only completion

**Sources:** CrossWake `native_promotion.ex` lines 15-25, 55-67; `evidence.ex` lines 441-459.

Use a fresh opaque run reference and bundle destination for every retry. Publish bytes plus digest atomically/no-replace; validate completion-marker digest before accepting a bundle; collision is a stable rejection, never an overwrite.

### CI/local parity and executable docs

**Sources:** `mix.exs` lines 125-130; `release_gate_contract_test.exs` lines 244-262 and 2683-2718; `doc_contract_test.exs` lines 1968-2057.

All deterministic Phase-103 assertions belong in the named Mix verifier plus committed contract tests and the same credential-free CI job. Only the selected iPhone's visible alert is subjective; do not create a human UAT gate for machine-checkable proof work.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `../crosswake/lib/crosswake/proof_lane/chimeway_notification_physical_proof.ex` | model / validator | transform | Current physical contract validates an offline-study assertion list, not the Phase-103 notification facts. A new CrossWake-owned semantic authority is required at a deliberately selected SHA. |

## Metadata

**Analog search scope:** `lib/chimeway/mobile_proof`, `lib/mix/tasks`, `test/chimeway`, fixtures, ExDoc guides, README, Mix aliases, CI workflow, and the adjacent CrossWake proof lane.  
**Files scanned:** 16 primary Chimeway/CrossWake analogs and fixtures.  
**Pattern extraction date:** 2026-08-26
