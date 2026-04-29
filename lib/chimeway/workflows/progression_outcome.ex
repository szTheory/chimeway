defmodule Chimeway.Workflows.ProgressionOutcome do
  @moduledoc """
  Pure mapper from canonical delivery facts to a curated workflow-facing outcome
  vocabulary used by Phase 25 progression rules.

  The mapper has no IO and no Repo access. Callers preload the prior
  `Chimeway.Delivery` row (and optionally the latest `Chimeway.DeliveryAttempt`)
  inside the same progression transaction and pass them in. This keeps branch
  semantics deterministic, replay-safe, and explainable from durable rows alone
  per D-12.

  ## Curated vocabulary (D-04)

  `from_delivery/2` returns either `:not_branchable_yet` or a three-tuple
  `{:branchable, outcome, evidence}` where `outcome` is one of:

    * `:delivered`           — `delivery.status == :succeeded`
    * `:suppressed`          — `delivery.status == :suppressed`
    * `:temporary_failure`   — `delivery.status == :failed`
    * `:retries_exhausted`   — `delivery.status == :cancelled` and
                                `suppression_reason == "retries_exhausted"`
    * `:permanent_failure`   — `delivery.status == :cancelled` and
                                `suppression_reason == "permanent_failure"`
    * `:bounced`             — `delivery.status == :cancelled` and
                                `suppression_reason == "bounced"`

  ## Early-fire warning for `temporary_failure` (WR-02)

  `temporary_failure` resolves from a `delivery.status == :failed` row, which
  is **NOT** terminal: `Chimeway.Deliveries`'s `@allowed_transitions` permits
  `failed: [:dispatched]`, the path Oban uses while a delivery is being
  retried. A workflow authoring:

      %{"kind" => "on_outcome", "outcome" => "temporary_failure", "to_step" => "email"}

  fires `to_step` on the **FIRST** transient `:failed` write — before any
  retry has been attempted. The original delivery may still succeed on a
  later attempt, leaving the host with BOTH a successful primary delivery
  AND the destination-step delivery for the same notification.

  If the intent is "fire after retries are exhausted", use
  `retries_exhausted` (which resolves only from a guaranteed-terminal
  `:cancelled` row with `suppression_reason == "retries_exhausted"`). If the
  intent IS "fire immediately on the first failure so we can try a
  different channel while the original retries", pair the destination
  step's notifier with an idempotency key so the host can collapse a
  primary success + an early-fire escalation to one user-visible delivery.

  See `Chimeway.Notifier` moduledoc near `@progress_outcomes` for the
  authoring-time version of this warning.

  Per D-05, `:pending`, `:dispatched`, and `:digested` deliveries always return
  `:not_branchable_yet`. Cancelled rows whose `suppression_reason` is not in the
  curated set also return `:not_branchable_yet` so workflow rules never advance
  on a meaning the contract did not explicitly assign.

  ## Evidence

  The third tuple element carries replay-safe primitive evidence so workflow
  transitions can persist a sufficient explanation of *why* the outcome was
  chosen without any callback re-entry:

    * `:delivery_status`     — string copy of `delivery.status`
    * `:suppression_reason`  — string copy of `delivery.suppression_reason`
                                (may be `nil`)
    * `:attempt_outcome`     — string copy of latest attempt outcome (or `nil`)
    * `:attempt_error_class` — string copy of latest attempt error class
                                (or `nil`)
  """

  alias Chimeway.Delivery
  alias Chimeway.DeliveryAttempt

  @type outcome ::
          :delivered
          | :suppressed
          | :temporary_failure
          | :retries_exhausted
          | :permanent_failure
          | :bounced

  @type evidence :: %{
          delivery_status: String.t(),
          suppression_reason: String.t() | nil,
          attempt_outcome: String.t() | nil,
          attempt_error_class: String.t() | nil
        }

  @type result :: {:branchable, outcome(), evidence()} | :not_branchable_yet

  @spec from_delivery(Delivery.t(), DeliveryAttempt.t() | nil) :: result()
  def from_delivery(%Delivery{status: :succeeded} = delivery, attempt) do
    {:branchable, :delivered, evidence_for(delivery, attempt)}
  end

  def from_delivery(%Delivery{status: :suppressed} = delivery, attempt) do
    {:branchable, :suppressed, evidence_for(delivery, attempt)}
  end

  # `:failed` is non-terminal (Chimeway.Deliveries permits `failed: [:dispatched]`),
  # so this branch may fire BEFORE retries are exhausted. See the
  # "Early-fire warning for `temporary_failure` (WR-02)" section in this
  # module's @moduledoc for the operator-facing consequence and the
  # recommended pairing with idempotency keys at the destination step.
  def from_delivery(%Delivery{status: :failed} = delivery, attempt) do
    {:branchable, :temporary_failure, evidence_for(delivery, attempt)}
  end

  def from_delivery(
        %Delivery{status: :cancelled, suppression_reason: "retries_exhausted"} = delivery,
        attempt
      ) do
    {:branchable, :retries_exhausted, evidence_for(delivery, attempt)}
  end

  def from_delivery(
        %Delivery{status: :cancelled, suppression_reason: "permanent_failure"} = delivery,
        attempt
      ) do
    {:branchable, :permanent_failure, evidence_for(delivery, attempt)}
  end

  def from_delivery(
        %Delivery{status: :cancelled, suppression_reason: "bounced"} = delivery,
        attempt
      ) do
    {:branchable, :bounced, evidence_for(delivery, attempt)}
  end

  # Pending, dispatched, digested, and any cancelled row whose suppression
  # reason is not in the curated vocabulary stay unbranchable so workflow rules
  # never advance on a meaning the contract did not assign (D-05/D-12).
  def from_delivery(%Delivery{}, _attempt), do: :not_branchable_yet

  @spec evidence_for(Delivery.t(), DeliveryAttempt.t() | nil) :: evidence()
  defp evidence_for(%Delivery{} = delivery, attempt) do
    %{
      delivery_status: status_to_string(delivery.status),
      suppression_reason: delivery.suppression_reason,
      attempt_outcome: attempt_outcome_to_string(attempt),
      attempt_error_class: attempt_error_class(attempt)
    }
  end

  defp status_to_string(status) when is_atom(status) and not is_nil(status),
    do: Atom.to_string(status)

  defp status_to_string(nil), do: nil

  defp attempt_outcome_to_string(%DeliveryAttempt{outcome: outcome}) when is_atom(outcome) and not is_nil(outcome),
    do: Atom.to_string(outcome)

  defp attempt_outcome_to_string(_), do: nil

  defp attempt_error_class(%DeliveryAttempt{error_class: error_class}), do: error_class
  defp attempt_error_class(_), do: nil
end
