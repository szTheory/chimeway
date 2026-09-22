# Phase 107: Operator Timeline, Guidance & Gate Parity - Pattern Map

**Mapped:** 2026-09-12
**Files analyzed:** 12 new/modified files
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/chimeway/traces.ex` | service | request-response / transform | `lib/chimeway/traces.ex` timeline builders | exact |
| `lib/chimeway/safe_evidence.ex` | utility | transform | `lib/chimeway/safe_evidence.ex` closed timeline projection | exact |
| `test/chimeway/traces_test.exs` | test | request-response | existing `explain_delivery/1` timeline/privacy describes in same file | exact |
| `test/chimeway/safe_evidence_test.exs` | test | transform | existing closed-vocabulary test in same file | exact |
| `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` | component | transform / request-response | existing timeline renderer in same file | exact |
| `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` | test | transform | `chimeway_admin/test/chimeway_admin/redaction_test.exs` | role-match |
| `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` | test | event-driven / request-response | existing mounted inbox journey in same file | exact |
| `guides/introduction/inbox-integration.md` | config/documentation | transform | existing golden-path sections in same guide plus live demo config/auth | exact |
| `test/chimeway/doc_contract_test.exs` | test | file-I/O / transform | existing inbox guide contract in same file | exact |
| `mix.exs` | config | batch | neighboring `verify.*` aliases in same file | exact |
| `MAINTAINING.md` | config/documentation | batch | existing pre-ship verification inventory in same file | exact |
| `test/chimeway/release_gate_contract_test.exs` | test | file-I/O / batch | existing gate topology and archive-safety contracts in same file | exact |

All analogs above were checked with `git ls-files`; none is a runtime/plugin mirror. `.github/workflows/ci.yml` is supporting read-only topology evidence, not an expected Phase 107 edit.

## Pattern Assignments

### `lib/chimeway/traces.ex` (service, request-response / transform)

**Analog:** `lib/chimeway/traces.ex`

**Tenant-scoped parent preload pattern** (lines 190-227):

```elixir
def explain_delivery(delivery_id, opts \\ []) do
  with {:ok, tenant_id} <- TenantScope.resolve(opts) do
    repo_opts = repo_opts(opts, [:tenant_id])
    delivery =
      Repo.one(
        from(d in Delivery,
          join: n in Notification,
          on: n.id == d.notification_id,
          join: e in Event,
          on: e.id == n.event_id,
          where: d.id == ^delivery_id and d.tenant_id == ^tenant_id and
                   n.tenant_id == ^tenant_id and e.tenant_id == ^tenant_id,
          preload: [notification: :event, attempts: []]
        ),
        repo_opts
      )

    case delivery && Repo.preload(delivery, target_history_preload(tenant_id), repo_opts) do
      %Delivery{notification: notification, attempts: attempts} = loaded_delivery ->
        timeline = build_timeline(notification.event, notification, loaded_delivery,
          attempts, digest_context(loaded_delivery, repo_opts), repo_opts)
```

Project the new entries only from `notification.seen_at` and `notification.read_at` passed through this existing boundary. Do not query signals, PubSub, attempts, or delivery state.

**Conditional entry and composition pattern** (lines 428-545):

```elixir
entries =
  if authoritative_timestamp do
    [%{at: authoritative_timestamp, event: event, detail: SafeEvidence.timeline_detail(%{})}]
  else
    []
  end

(base ++ other_entries ++ entries)
|> Enum.sort_by(&timeline_sort_key/1)
```

Add independent seen and read lists; a non-nil `read_at` must not create a seen event.

**Ordering pattern to replace** (lines 610-632): current `{timeline_rank(event), at}` is rank-first. Use a timestamp-first scalar key and the closed rank second:

```elixir
defp timeline_sort_key(%{event: event, at: at}) do
  {DateTime.to_unix(at, :microsecond), timeline_rank(event)}
end
```

Add explicit ranks for `:notification_seen` and `:notification_read`, with seen lower than read. Preserve existing relative tie order.

---

### `lib/chimeway/safe_evidence.ex` (utility, transform)

**Analog:** `lib/chimeway/safe_evidence.ex`

**Closed event admission** (lines 33-37, 355-366):

```elixir
@timeline_events ~w(
  event_created notification_created delivery_planned deferred resumed recovered suppressed cancelled
  digested digest_skipped emitted_immediately digest_emitted attempt_recorded webhook_received
  workflow_progressed workflow_waiting workflow_stopped workflow_completed
)a

defp trace_timeline_entry(%{at: %DateTime{} = at, event: event, detail: detail})
     when event in @timeline_events and is_map(detail) do
  [%{at: at, event: event, detail: timeline_detail(detail)}]
end

defp trace_timeline_entry(_entry), do: []
```

Add exactly the two event atoms to `@timeline_events`. Do not add any new `@timeline_fields` entry.

**Defense-in-depth detail projection** (lines 482-501):

```elixir
def timeline_detail(value) when is_map(value) do
  value
  |> then(fn detail -> if is_struct(detail), do: Map.from_struct(detail), else: detail end)
  |> then(fn detail ->
    detail
    |> Privacy.redact()
    |> Enum.reduce(%{}, fn {key, value}, safe ->
      case Map.get(@timeline_fields, key |> to_string() |> String.downcase()) do
        nil -> safe
        field -> if safe_timeline_value?(field, value), do: Map.put(safe, field, value), else: safe
      end
    end)
  end)
end
```

The new lifecycle entries must emerge with `detail == %{}`.

---

### `test/chimeway/traces_test.exs` and `test/chimeway/safe_evidence_test.exs` (tests)

**Analogs:** existing timeline and closed-vocabulary tests in the same files.

**Trace fixture/assertion pattern** (`test/chimeway/traces_test.exs`, lines 383-440, 462-486):

```elixir
assert {:ok, explanation} = Traces.explain_delivery(delivery.id)
encoded = :erlang.term_to_binary(explanation)

for sentinel <- ["raw-correlation-sentinel", "raw-recipient-sentinel"] do
  assert :binary.match(encoded, sentinel) == :nomatch, "leaked #{sentinel}"
end

assert Enum.all?(explanation.timeline, fn entry ->
  Enum.sort(Map.keys(entry)) == [:at, :detail, :event]
end)
```

Extend this style with four independent states (neither, seen-only, read-only, both), two sibling deliveries, exact persisted timestamps, exact empty details, and hostile sentinels. Chronology must use deliberately cross-ranked timestamps so the assertion cannot pass vacuously; add a separate equal-microsecond seen-before-read assertion.

**SafeEvidence closed-vocabulary pattern** (`test/chimeway/safe_evidence_test.exs`, lines 6-37): build one valid map containing an extra hostile field, assert the exact safe result, then loop over invalid/unknown inputs and assert they are rejected/dropped. Test both new atoms positively and an unknown timeline atom negatively.

---

### `chimeway_admin/lib/chimeway_admin/components/timeline_event.ex` (component, transform)

**Analog:** same component, lines 14-46.

```elixir
attr(:timeline, :list, required: true)

def timeline(assigns) do
  ~H"""
  <ol class="cw-timeline">
    <%= for entry <- @timeline do %>
      <li class="cw-timeline__item">
        <time datetime={DateTime.to_iso8601(entry.at)}>{format_at(entry.at)}</time>
        <strong>{humanize_event(entry.event)}</strong>
        <dl class="cw-timeline__details">
          <%= for {key, value} <- Redaction.safe_timeline_detail(entry.detail) do %>
            <dt>{key}</dt><dd>{format_detail_value(value)}</dd>
          <% end %>
        </dl>
      </li>
    <% end %>
  </ol>
  """
end
```

Preserve `<time>`, `<dl>`, and redaction. Add one general hook such as `data-cw-timeline-event={Atom.to_string(entry.event)}` and explicit clauses returning the locked labels `Notification seen` and `Notification read`; retain generic humanization for other atoms.

---

### `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs` (test, transform)

**Analog:** `chimeway_admin/test/chimeway_admin/redaction_test.exs`, lines 1-4 and 33-56.

```elixir
defmodule ChimewayAdmin.RedactionTest do
  use ExUnit.Case, async: true
  alias ChimewayAdmin.Redaction

  test "safe_timeline_detail drops sensitive keys" do
    detail = %{"reason" => "channel_disabled", "password" => "secret"}
    assert Redaction.safe_timeline_detail(detail) == %{"reason" => "channel_disabled"}
  end
end
```

Use `ExUnit.Case, async: true`, import `Phoenix.LiveViewTest`, and render directly:

```elixir
html = render_component(&ChimewayAdmin.Components.TimelineEvent.timeline/1,
  timeline: [
    %{at: timestamp, event: :notification_seen, detail: %{}},
    %{at: timestamp, event: :notification_read, detail: %{}}
  ])
```

Assert both exact labels, both hook values, ISO `<time datetime>`, retained empty `<dl>`, and absence of hostile detail. Do not create a browser harness.

---

### `examples/chimeway_demo_host/test/demo_host_web/inbox_bell_proof_test.exs` (test, event-driven / request-response)

**Analog:** same file, lines 7-18 and 62-82.

```elixir
use DemoHostWeb.ConnCase, async: false
import Phoenix.LiveViewTest
use Oban.Testing, repo: Chimeway.Repo, prefix: "chimeway"
@moduletag :inbox

{:ok, view, _html} = live(conn, "/inbox")
view |> element("button[data-cw-inbox-bell]") |> render_click()
drain_signal_queue!()
assert Repo.get!(WorkflowRun, run.id).state == :active
assert signal_transition_count(run.id) == 1
```

Extend the real sequence: seed durable arrival, open the mounted bell (visible rows become seen), drain the workflow queue, click explicit read, repeat actions to prove once-only progression, then mount `/admin/chimeway/deliveries/:delivery_id` with the same authorized session and assert both labels/hooks and privacy negatives.

---

### `guides/introduction/inbox-integration.md` and `test/chimeway/doc_contract_test.exs`

**Analog:** inbox guide contract at `test/chimeway/doc_contract_test.exs:1096-1227`.

```elixir
setup do
  content = File.read!(@inbox_integration_guide)
  %{content: content}
end

for required <- @required do
  test "requires #{required} in inbox integration guide", %{content: content} do
    assert String.contains?(content, unquote(required))
  end
end

refute String.contains?(content, stale_or_unsafe_text)
```

Tag the new focused contracts `:inbox_gate_parity`. Require the exact configuration keys (`:inbox_change_publisher`, `:pubsub_server`, `:topic_secret`, auth module), both auth callbacks, opaque `cw_*` examples, ownership statements, authoritative reload/reconnect semantics, and the lifecycle comparison table. Add negative assertions for raw email examples and stale deferred-seen wording. Preserve the current ordered golden-path sections (lines 1145-1166) and current path-package truth assertions (lines 1184-1225).

The guide should copy executable configuration/auth shapes from tracked demo-host files (`examples/chimeway_demo_host/config/config.exs` and `examples/chimeway_demo_host/lib/demo_host/inbox_auth.ex`) and link the existing mobile operations guide for provider-handoff/protected-activation distinctions.

---

### `mix.exs` and `MAINTAINING.md` (config/documentation, batch)

**Analog:** neighboring ordered aliases and the current inbox alias (`mix.exs:147-164`).

```elixir
"verify.inbox": [
  "cmd --shell cd chimeway_inbox && mix deps.get && mix test --warnings-as-errors",
  "cmd --shell cd examples/chimeway_demo_host && mix deps.get && mix test --only inbox --warnings-as-errors"
]
```

Expand this single alias in cheapest-to-broadest order: focused root lifecycle/timeline/privacy/Phoenix-optional files under `scripts/test-db`; full inbox package; focused admin component/redaction; tagged guide and release contracts under `scripts/test-db`; demo `--only inbox` last. Keep warnings-as-errors and nested `mix deps.get`. Do not add a new alias or CI job and do not include `verify.admin`/Playwright.

Update the existing `MAINTAINING.md` pre-ship inventory around lines 60-74 to enumerate these evidence classes and state that both aggregates consume `verify_inbox`.

---

### `test/chimeway/release_gate_contract_test.exs` (test, file-I/O / batch)

**Analog:** same file's topology setup and mutation-style assertions (`:24-64`, `:263-320`).

```elixir
@ci_gate_lanes ~w(... verify_inbox ...)
@pr_gate_lanes ~w(... verify_inbox ...)

test "verify_inbox is an unfiltered required PR lane", %{ci_yml: ci_yml} do
  needs = extract_pr_gate_needs(ci_yml)
  inbox_block = extract_ci_job_block(ci_yml, "verify_inbox")
  assert "verify_inbox" in needs
  refute String.contains?(inbox_block, "if: github.event_name != 'pull_request'")
end
```

Add `:inbox_gate_parity` contracts that extract the `verify.inbox` alias and require each exact evidence command, assert the CI job invokes only `mix verify.inbox`, assert both `pr-gate` and `ci-gate` carry the `needs.verify_inbox.result` token into their aggregate script, and assert nightly-only admin/browser jobs remain excluded. Prefer mutation-negative tests that remove each required command/edge and prove the helper rejects the mutation.

**Safe test-owned temporary-directory pattern** (replaces direct cleanup visible at lines 1840, 2825, and 3302):

```elixir
@owned_temp_prefixes ~w(
  chimeway_release_gate_
  chimeway_release_archive_
  chimeway_adoption_security_
  chimeway_adoption_run_
)

defp remove_owned_temp_dir!(directory) do
  temp_root = Path.expand(System.tmp_dir!())
  directory = Path.expand(directory)
  basename = Path.basename(directory)

  owned_prefix? = Enum.any?(@owned_temp_prefixes, &String.starts_with?(basename, &1))

  if directory != temp_root and Path.dirname(directory) == temp_root and owned_prefix? do
    File.rm_rf!(directory)
  else
    raise ArgumentError, "refusing recursive cleanup outside an owned temp directory"
  end
end
```

Route every recursive cleanup exercised by this release test through the guard, passing the owned directory itself (for an archive, `Path.dirname(archive)` once, before calling the helper). Remove the unnecessary pre-clean of the fresh unique `build_unpacked_package!` output or guard it. Add refusal tests for `System.tmp_dir!()`, nested/arbitrary directories, and unowned sibling names, plus an acceptance test for every closed prefix. Never call `File.rm_rf*` directly on `Path.dirname(...)` or caller-controlled paths.

## Shared Patterns

### Durable authority and tenant scope

**Source:** `lib/chimeway/traces.ex:190-227`  
**Apply to:** core projection and mounted demo proof.

Load the parent notification through the existing tenant-constrained delivery query. Seen/read are independent persisted columns, not inferred signals.

### Closed evidence and dual redaction

**Sources:** `lib/chimeway/safe_evidence.ex:33-78,355-366,482-501`; `chimeway_admin/lib/chimeway_admin/redaction.ex:6-11,82-96`  
**Apply to:** core timeline, component, component tests, demo assertions.

Only closed event atoms survive core projection; details pass through `Privacy.redact` plus an allowlist. The admin applies a second redaction layer. New event details remain exactly `%{}` and require no new allowed detail key.

### Executable documentation contracts

**Source:** `test/chimeway/doc_contract_test.exs:1096-1227`  
**Apply to:** guide and maintainer documentation.

Use positive required-string/section-order assertions together with negative stale/unsafe assertions. Tag the Phase 107 subset so the expanded inbox lane runs only the focused contract.

### Single verification owner

**Sources:** `mix.exs:160-164`; `.github/workflows/ci.yml:450-469,846-910,1540-1568`  
**Apply to:** alias, release contract, maintainer instructions.

`mix verify.inbox` remains the only local composition point; the existing `verify_inbox` job runs it, and both aggregate gates consume that job result. The workflow is evidence for contracts and should not need editing.

## No Analog Found

None. The only new file, `chimeway_admin/test/chimeway_admin/components/timeline_event_test.exs`, has a strong project-local ExUnit/redaction analog and an established `Phoenix.LiveViewTest.render_component/3` convention.

## Metadata

**Analog search scope:** root core/test/config/docs, `chimeway_admin`, `chimeway_inbox`, demo host, and CI workflow  
**Tracked-source gate:** passed for every named analog  
**Pattern extraction date:** 2026-09-12
