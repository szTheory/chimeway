# Phase 96: Adoption Front Door & Proof Gate - Pattern Map

**Mapped:** 2026-08-10  
**Files analyzed:** 8 planned create/modify targets  
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/introduction/adoption-paths.md` | documentation | request-response | `guides/introduction/mailglass-integration.md` | role-match |
| `README.md` | documentation | request-response | current Quick Start / Documentation blocks in `README.md` | exact |
| `mix.exs` | config | transform | current package whitelist and ExDoc extras in `mix.exs` | exact |
| `lib/mix/tasks/verify.adoption_paths.ex` | task | request-response | `lib/mix/tasks/verify_published.ex` | role-match |
| `scripts/prove-adoption-paths.exs` | utility/runner | batch | `scripts/prove-accrue-consumer.exs` | role-match |
| `.github/workflows/ci.yml` | config | event-driven | `install_golden_contract` + `ci-gate` | exact |
| `test/chimeway/doc_contract_test.exs` | test | transform | existing README / ExDoc / integration-guide contracts | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | batch | existing artifact proof and CI-gate contracts | exact |

## Pattern Assignments

### `guides/introduction/adoption-paths.md` (documentation, request-response)

**Analog:** `guides/introduction/mailglass-integration.md`

Keep the selector static and use the guide's established literal proof-boundary structure. It must route to, rather than repeat, detailed guide setup.

**Proof narrative and limitation pattern** ([`guides/introduction/mailglass-integration.md:193`](/Users/jon/projects/chimeway/guides/introduction/mailglass-integration.md:193)):

```markdown
**What happened:** In the unpacked-artifact clean-consumer proof, Fake recorded exactly one host-composed message and Chimeway recorded a successful `Chimeway.Adapters.Mailglass` attempt.

**Why it matters:** ... This is local composition evidence, not a claim that an email reached a live provider or inbox.

**Next step:** Follow the focused [Mailglass integration blueprint](../recipes/mailglass-integration-blueprint.md) for your host application's wiring.

The proof does not cover real provider acceptance, sender/domain verification, inbox placement/display, production credentials, provider callbacks, or live webhook feedback.
```

**Accrue evidence and non-terminal wording** ([`guides/introduction/accrue-dunning-integration.md:115`](/Users/jon/projects/chimeway/guides/introduction/accrue-dunning-integration.md:115)):

```markdown
CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.3.0 chimeway_version=1.0.0 workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received
```

Use each canonical guide as the source of truth for Core, Mailglass, and Accrue limitation wording. Do not name `mix verify.mailglass` or `mix verify.accrue` as proof commands: the guides explicitly reserve those for maintainers ([`mailglass-integration.md:203`](/Users/jon/projects/chimeway/guides/introduction/mailglass-integration.md:203), [`accrue-dunning-integration.md:139`](/Users/jon/projects/chimeway/guides/introduction/accrue-dunning-integration.md:139)).

---

### `README.md` (documentation, request-response)

**Analog:** current Quick Start and Documentation routing blocks in `README.md`

Add one concise link to the selector; preserve README's role as a short entry surface.

**Quick Start link pattern** ([`README.md:98`](/Users/jon/projects/chimeway/README.md:98)):

```markdown
## Quick Start

Follow the [Golden Path guide](guides/introduction/golden-path.md) for install, notifier setup, and your first explainable trace.
```

**Documentation-list pattern** ([`README.md:154`](/Users/jon/projects/chimeway/README.md:154)):

```markdown
## Documentation

- [Golden Path Guide](guides/introduction/golden-path.md)
- [Mailglass Integration Guide](guides/introduction/mailglass-integration.md)
- [Accrue Dunning Integration Guide](guides/introduction/accrue-dunning-integration.md)
```

---

### `mix.exs` (config, transform)

**Analog:** package whitelist and ExDoc extras configuration in the same file.

**Package-membership pattern** ([`mix.exs:229`](/Users/jon/projects/chimeway/mix.exs:229)):

```elixir
defp package do
  [
    files:
      ~w(lib priv guides scripts/prove-accrue-consumer.exs CHANGELOG.md LICENSE.md README.md mix.exs .formatter.exs),
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/szTheory/chimeway"}
  ]
end
```

Extend this explicit whitelist with the new package-owned runner; do not replace it with a broad `scripts` directory inclusion.

**ExDoc ordered-extras pattern** ([`mix.exs:238`](/Users/jon/projects/chimeway/mix.exs:238)):

```elixir
docs: [
  ...,
  extras: [
    "guides/introduction/getting-started.md",
    "guides/introduction/installation.md",
    "guides/introduction/golden-path.md",
    ...
  ],
  groups_extras: [Introduction: ~r/guides\/introduction\//, ...]
]
```

Place the new selector first in `extras`, while keeping its path under `guides/introduction/` so the existing group regex includes it automatically.

---

### `lib/mix/tasks/verify.adoption_paths.ex` (task, request-response)

**Analog:** `lib/mix/tasks/verify_published.ex`

Follow the small purpose-built Mix task shape: module documentation, `use Mix.Task`, shortdoc, a narrow `run/1`, and deterministic nonzero failure. Unlike the curl task, this task must parse `--only` strictly and delegate without doing proof work.

**Task façade/error pattern** ([`lib/mix/tasks/verify_published.ex:1`](/Users/jon/projects/chimeway/lib/mix/tasks/verify_published.ex:1)):

```elixir
use Mix.Task

@shortdoc "Verify chimeway is published and accessible at the given version on hex.pm"

@impl Mix.Task
def run([]) do
  Mix.shell().error("Usage: mix verify.published <version>")
  exit({:shutdown, 1})
end
```

Use `OptionParser.parse(argv, strict: [only: :string])`, accept exactly zero options or one allowlisted value, and reject duplicate, positional, malformed, and unknown values before loading/building an artifact. Delegate the selected `core | mailglass | accrue` list to the runner.

---

### `scripts/prove-adoption-paths.exs` (utility/runner, batch)

**Analog:** `scripts/prove-accrue-consumer.exs`

Mirror the script-module boundary and `System.halt/1` executable entrypoint. Replace its archive-specific CLI parsing with a runner API used by the Mix task. This runner owns one build/unpack, serial dispatch, fixed safe framing, and no raw exception/output rendering.

**Package-owned fixture invocation and cleanup pattern** ([`scripts/prove-accrue-consumer.exs:10`](/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:10)):

```elixir
with {:ok, archive, digest} <- arguments(argv),
     {:ok, root} <- unpack_and_validate(archive, digest) do
  try do
    Code.require_file(Path.join(root, @fixture))
    proof = Chimeway.Test.ArtifactConsumerFixture.prove_accrue!(root, opts)
    IO.puts(proof.output)
    0
  rescue
    _ -> diagnostic("proof failed", @proof)
  after
    File.rm_rf!(root)
  end
end
```

**Safe fixed diagnostic pattern** ([`scripts/prove-accrue-consumer.exs:185`](/Users/jon/projects/chimeway/scripts/prove-accrue-consumer.exs:185)):

```elixir
defp diagnostic(message, status) do
  IO.binwrite(:stderr, "Accrue package proof: #{message}\n")
  status
end
```

For the new runner, print only `[adoption:<path>] START`, the fixture's already-validated `proof.output`, `[adoption:<path>] PASS`, or one redacted `FAIL stage=<enum> status=<integer>` plus `mix verify.adoption_paths --only <path>`. Never use `inspect/1`, `Exception.message/1`, paths, database names, archives, or generated-host output.

---

### `.github/workflows/ci.yml` (config, event-driven)

**Analog:** `install_golden_contract` job and `ci-gate` aggregation.

**PostgreSQL root lane pattern** ([`.github/workflows/ci.yml:1043`](/Users/jon/projects/chimeway/.github/workflows/ci.yml:1043)):

```yaml
install_golden_contract:
  runs-on: ubuntu-latest
  permissions:
    contents: read
    actions: read
  if: github.event_name != 'pull_request'
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: postgres
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5
```

Copy checkout, setup-beam, root deps/cache/compile, and database preparation from this root-lane family; name the job `verify_adoption_paths`; final behavior step must be `mix verify.adoption_paths`; no partner checkout or matrix, and run the lane on every CI event.

**Gate wiring pattern** ([`.github/workflows/ci.yml:1277`](/Users/jon/projects/chimeway/.github/workflows/ci.yml:1277)):

```yaml
ci-gate:
  name: ci-gate
  needs: [lint, test, ..., test_floor_1_17]
  if: always() && github.event_name != 'pull_request'
  ...
  env:
    VERIFY_ACCRUE: ${{ needs.verify_accrue.result }}
  run: scripts/ci/aggregate-gate.sh ... VERIFY_ACCRUE ...
```

Add the job to all three coupled locations in both gates: `needs`, upper-case environment result, and `aggregate-gate.sh` argument list.

---

### `test/chimeway/doc_contract_test.exs` (test, transform)

**Analog:** README, integration-guide, and ExDoc extras contracts.

Keep concise positive/negative textual assertions in the existing file; use `setup` to read a file once and `for` loops for marker allowlists.

**README-contract pattern** ([`test/chimeway/doc_contract_test.exs:1593`](/Users/jon/projects/chimeway/test/chimeway/doc_contract_test.exs:1593)):

```elixir
describe "README install doc contract (GATE-01)" do
  setup do
    content = File.read!("README.md")
    %{content: content}
  end

  for required <- @required do
    test "requires #{required} in README", %{content: content} do
      assert String.contains?(content, unquote(required))
    end
  end
end
```

**Extras order-test pattern** ([`test/chimeway/doc_contract_test.exs:1787`](/Users/jon/projects/chimeway/test/chimeway/doc_contract_test.exs:1787)):

```elixir
golden_path_index = :binary.match(content, "guides/introduction/golden-path.md")
selector_index = :binary.match(content, "guides/introduction/adoption-paths.md")
assert selector_index < golden_path_index
```

Add selector all-and-only Core/Mailglass/Accrue rows, canonical guide paths, responsibility/limitation anchors, exact focused commands, one safe proof record per row, README link, first-extra ordering, and forbidden maintainer-suite/unsafe tokens.

---

### `test/chimeway/release_gate_contract_test.exs` (test, batch)

**Analog:** artifact-consumer proof, parser-negatives, and CI-gate contracts in this file.

Extend the existing serialized release-gate contract rather than introducing a shell checker. It already aliases the fixture and centralizes workflow constants/lane lists.

**Shared fixture / lane-list pattern** ([`test/chimeway/release_gate_contract_test.exs:1`](/Users/jon/projects/chimeway/test/chimeway/release_gate_contract_test.exs:1)):

```elixir
alias Chimeway.Test.ArtifactConsumerFixture

@ci_yml ".github/workflows/ci.yml"
@ci_gate_lanes ~w(lint test verify_gates ... test_floor_1_17)
@pr_gate_lanes ~w(lint test verify_gates verify_docs)
```

**CI topology assertion pattern** ([`test/chimeway/release_gate_contract_test.exs:238`](/Users/jon/projects/chimeway/test/chimeway/release_gate_contract_test.exs:238)):

```elixir
needs = extract_ci_gate_needs(ci_yml)
assert length(needs) == length(@ci_gate_lanes)

for lane <- @ci_gate_lanes do
  assert lane in needs, "ci-gate must need #{lane}"
end
```

**Strict negative proof pattern** ([`test/chimeway/release_gate_contract_test.exs:1664`](/Users/jon/projects/chimeway/test/chimeway/release_gate_contract_test.exs:1664)):

```elixir
for unsafe_key <- ~w[... payload ... credential raw_struct inspect sql ...] do
  assert_raise RuntimeError, ~r/unknown evidence key/, fn ->
    ArtifactConsumerFixture.parse_accrue_evidence!(line <> " #{unsafe_key}=private")
  end
end
```

Add direct runner/task tests (or structural source assertions plus controlled invocation) for invalid and duplicate `--only` failing before proof output; aggregate dispatching every path once; focused dispatching only one; single safe proof record and framing; no partner-suite commands. Also bind `verify_adoption_paths`, PostgreSQL 15, aggregate command, every-event execution, and presence in both `pr-gate` and `ci-gate`.

## Shared Patterns

### Artifact consumer ownership and cleanup

**Source:** `priv/adoption_proof/artifact_consumer_fixture.ex:79-126`, `:134-183`, `:191-225`, `:986-1012`  
**Apply to:** the new runner only (call it; do not recreate or move it).

```elixir
result =
  try do
    File.rm_rf!(root)
    scaffold!(root, unpacked_root, db_config)
    validate_artifact_dependency!(...)
    ...
    output = run_mix!(root, ["run", "priv/prove_core.exs"])
    safe_output = proof_line!(output)
    %{output: safe_output, evidence: parse_evidence!(safe_output)}
  rescue
    error ->
      cleanup!(identity, opts)
      reraise error, __STACKTRACE__
  end

Map.put(result, :cleanup, cleanup!(identity, opts))
```

The runner must build/unpack once and call `prove_core!/2`, `prove_mailglass!/2`, and `prove_accrue!/2` serially. The fixture remains the only owner of scaffold/provenance/lifecycle/parser/cleanup behavior.

### Safe proof evidence

**Source:** `priv/adoption_proof/artifact_consumer_fixture.ex:758-854`, `:963-983`  
**Apply to:** runner framing, docs examples, and release contracts.

```elixir
case lines do
  [line] -> line
  [] -> raise "artifact consumer proof did not emit CHIMEWAY_MAILGLASS_PROOF"
  _ -> raise "artifact consumer proof emitted multiple CHIMEWAY_MAILGLASS_PROOF lines"
end
```

Retain original fixture `proof.output` as the authoritative evidence line. The existing parsers reject unknown fields, duplicate fields, malformed pairs, and schema drift; never parse-and-inspect/re-emit a map.

### CI aggregation parity

**Source:** `.github/workflows/ci.yml:1277-1300`; `scripts/ci/aggregate-gate.sh:14-28`  
**Apply to:** dedicated adoption job and its `pr-gate`/`ci-gate` membership.

```bash
for lane in "$@"; do
  result="${!lane}"
  if [[ "$result" != "success" ]]; then
    echo "Required lane $lane: $result"
    failed=1
  fi
done
```

Every gate dependency requires aligned `needs`, environment variable, and aggregate-script argument entries. A non-success (including skipped) must fail the aggregate.

## No Analog Found

None. The exact selector and aggregate adoption runner are new compositions, but all constituent conventions have direct repository analogs.

## Metadata

**Analog search scope:** `guides/introduction`, root docs/config, `lib/mix/tasks`, `scripts`, `priv/adoption_proof`, `test/chimeway`, `.github/workflows`  
**Files scanned:** 12 primary analog/source files  
**Pattern extraction date:** 2026-08-10
