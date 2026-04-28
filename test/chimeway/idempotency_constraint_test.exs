defmodule Chimeway.IdempotencyConstraintTest do
  use Chimeway.DataCase, async: false

  import Ecto.Query, only: [from: 2]

  alias Chimeway.Events.Event
  alias Chimeway.Notifications.Notification
  alias Chimeway.Repo
  alias Chimeway.Trigger

  defmodule IdempotentNotifier do
    @behaviour Chimeway.Notifier

    @impl true
    def notification_key, do: "comment.created"

    @impl true
    def version, do: 2

    @impl true
    def recipients(_params) do
      {:ok, [%{recipient_identity: "user-1", recipient_type: "member"}]}
    end

    @impl true
    def build(_params, _recipient) do
      {:ok, %{"topic" => "mentions", "token" => "drop-me"}}
    end
  end

  test "serial duplicate triggers return duplicate tuple and preserve one canonical event row" do
    assert {:ok, first} =
             Trigger.trigger(
               IdempotentNotifier,
               %{"body" => "hello", "password" => "drop-this"},
               idempotency_key: "serial-dup-key"
             )

    assert {:duplicate, existing_event} =
             Trigger.trigger(
               IdempotentNotifier,
               %{"body" => "hello", "password" => "drop-this"},
               idempotency_key: "serial-dup-key"
             )

    assert existing_event.id == first.event.id

    assert Repo.aggregate(
             from(e in Event, where: e.idempotency_key == "serial-dup-key"),
             :count,
             :id
           ) == 1

    assert Repo.aggregate(
             from(n in Notification, where: n.event_id == ^first.event.id),
             :count,
             :id
           ) == 1
  end

  test "concurrent duplicate triggers still produce one canonical event row" do
    parent = self()

    results =
      1..10
      |> Task.async_stream(
        fn _attempt ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          Trigger.trigger(
            IdempotentNotifier,
            %{"body" => "hello", "secret" => "drop-this"},
            idempotency_key: "concurrent-dup-key"
          )
        end,
        ordered: false,
        max_concurrency: 10,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _payload}, &1)) == 1
    assert Enum.count(results, &match?({:duplicate, %Event{}}, &1)) == 9

    assert Repo.aggregate(
             from(e in Event, where: e.idempotency_key == "concurrent-dup-key"),
             :count,
             :id
           ) == 1

    event =
      Repo.one!(from(e in Event, where: e.idempotency_key == "concurrent-dup-key", limit: 1))

    assert Repo.aggregate(
             from(n in Notification, where: n.event_id == ^event.id),
             :count,
             :id
           ) == 1
  end
end
