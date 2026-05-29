# Phase 51: Journey & Admin Proof — Pattern Map

**Mapped:** 2026-05-29

## Files to Modify

| File | Role | Closest Analog |
|------|------|----------------|
| `examples/chimeway_demo_host/test/demo_host_web/journey_test.exs` | JOUR-06 journey proofs | Same file JOUR-03 (`:46-85`) |
| `examples/chimeway_demo_host/test/demo_host_web/admin_trace_live_test.exs` | JOUR-07/08 admin proofs | Same file JOUR-04 (`:9-36`) |

## Pattern: JOUR-03 → JOUR-06 read-cancel

**Source:** `journey_test.exs:46-85`

```elixir
assert {:ok, %{trace: %{delivery_ids: ids}}} = DemoHost.Seeds.escalation_waiting!()
# ... find in_app delivery, mark_read, drain_oban!(:chimeway_signals)
assert updated_run.state == :active
```

**Extension for JOUR-06:**

```elixir
# After mark_read + drain — ADD:
email_deliveries =
  from(d in Delivery, where: d.workflow_run_id == ^run.id and d.channel == "email")
  |> Repo.all()

assert email_deliveries == []

current_step = Chimeway.Workflows.get_current_step!(updated_run)
assert current_step.step_key == "initial_notice"
```

## Pattern: CR-01 time-fallback → JOUR-06 unread path

**Source:** `workflow_progression_test.exs:448-501`

```elixir
due_at = parse_iso8601!(waiting_run.status_context["due_at"])
past_due_now = DateTime.add(due_at, 1, :second)

assert {:ok, {:advanced, advanced_run, [next_delivery]}} =
         Progression.progress_run(workflow_run.id, now: past_due_now)

assert advanced_run.state == :active
assert next_delivery.channel == "email"
```

**Journey adaptation:** Use `DemoHost.Seeds.escalation_waiting!/0` instead of `trigger_workflow!/1`. Alias `Chimeway.Workflows.Progression`.

## Pattern: JOUR-04 → JOUR-07 admin suppression

**Source:** `admin_trace_live_test.exs:9-36`

```elixir
{:ok, view, _html} = live(conn)
html =
  view
  |> form("#trace-search-form", %{
    "mode" => "recipient",
    "query" => DemoHost.Seeds.alex_identity(),
    "notification_key" => ""
  })
  |> render_submit()

{:ok, detail_view, detail_html} = live(conn, "/admin/chimeway/deliveries/#{delivery_id}")
assert render(detail_view) =~ "teampulse.invite_sent"
```

**JOUR-07 swap:**

| JOUR-04 | JOUR-07 |
|---------|---------|
| `seed_invite/0` | `seed_password_reset/0` |
| `alex_identity()` | `sam_identity()` |
| `teampulse.invite_sent` | `teampulse.password_reset` |
| — | `suppressed`, `channel_disabled` |

## Pattern: JOUR-04 → JOUR-08 admin escalation

**JOUR-08 swap:**

| JOUR-04 | JOUR-08 |
|---------|---------|
| `seed_invite/0` | `escalation_waiting!/0` |
| `alex_identity()` | `morgan_identity()` |
| `teampulse.invite_sent` | `teampulse.payment_reminder` |
| `teampulse-seed-invite-corr` | `teampulse-seed-payment-corr` |
| — | timeline contains `workflow waiting` or `Workflow waiting` |

**Delivery pick:** Select in_app delivery from seed ids (escalation story).

## Tag Convention

```elixir
@tag :journey
@tag :jour_06  # or :jour_07, :jour_08
```

## PATTERN MAPPING COMPLETE
