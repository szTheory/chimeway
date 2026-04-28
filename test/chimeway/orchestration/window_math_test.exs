defmodule Chimeway.Orchestration.WindowMathTest do
  use ExUnit.Case, async: true

  alias Chimeway.Orchestration.WindowMath

  describe "next_eligible_at/2" do
    test "computes the next eligible UTC time from recipient-local quiet hours" do
      evaluation_time = ~U[2026-01-15 03:30:00Z]

      assert {:ok, next_eligible_at} =
               WindowMath.next_eligible_at(evaluation_time,
                 time_zone: "America/New_York",
                 quiet_hours_start_minute: 22 * 60,
                 quiet_hours_end_minute: 8 * 60
               )

      assert next_eligible_at == ~U[2026-01-15 13:00:00Z]
      assert next_eligible_at.time_zone == "Etc/UTC"
    end

    test "handles DST spring-forward gaps deterministically" do
      evaluation_time = ~U[2026-03-08 06:30:00Z]

      assert {:ok, next_eligible_at} =
               WindowMath.next_eligible_at(evaluation_time,
                 time_zone: "America/New_York",
                 quiet_hours_start_minute: 60,
                 quiet_hours_end_minute: 3 * 60 + 30
               )

      assert next_eligible_at == ~U[2026-03-08 07:00:00Z]
    end

    test "handles DST fall-back ambiguity deterministically" do
      evaluation_time = ~U[2026-11-01 05:30:00Z]

      assert {:ok, next_eligible_at} =
               WindowMath.next_eligible_at(evaluation_time,
                 time_zone: "America/New_York",
                 quiet_hours_start_minute: 60,
                 quiet_hours_end_minute: 90
               )

      assert next_eligible_at == ~U[2026-11-01 06:30:00Z]
    end
  end
end
