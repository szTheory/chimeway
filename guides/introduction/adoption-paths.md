# Adoption Paths

Choose one proof path, run its focused command, and then follow the linked guide for detailed setup. Each proof builds and checks a clean consumer from a Chimeway artifact; it is compatibility evidence for the listed boundary, not a substitute for your host's policy or provider validation.

For the iPhone-first delivery boundary, follow the canonical [Mobile Adoption and Operations guide](mobile-adoption-operations.md).

## Core

**Choose this when:** You want to prove a durable notification lifecycle and public trace before adding a delivery partner.

**Host responsibility:** The host owns recipients, tenancy, notification policy, and the application database.

**Chimeway responsibility:** Chimeway records the durable `event -> notification -> delivery -> attempt` lifecycle and exposes the explainable trace.

**Partner responsibility:** No delivery partner is involved in this Core proof.

```bash
mix verify.adoption_paths --only core
```

**Representative proof record:** `CHIMEWAY_CORE_PROOF notification_key=artifact_consumer.core_trace notification_version=1 delivery_id=2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e status=succeeded last_attempt_outcome=succeeded timeline_events=event_created,notification_created,delivery_planned,attempt_recorded`

**Does not cover:** external delivery or a provider accepting a message. The proof shows a host-owned durable lifecycle and trace.

**Next step:** Follow the [Golden Path](golden-path.md) for installation and trace detail.

## Mailglass

**Choose this when:** You want to prove host-owned email composition and a successful Chimeway Mailglass adapter attempt.

**Host responsibility:** The host owns the mailable, rendering inputs, Mailglass configuration, sender identity, and provider credentials.

**Chimeway responsibility:** Chimeway routes the notification to the adapter, records the attempt, and keeps the trace explainable.

**Partner responsibility:** Mailglass composes the host mailable and the provider accepts or rejects live delivery outside this proof.

```bash
mix verify.adoption_paths --only mailglass
```

**Representative proof record:** `CHIMEWAY_MAILGLASS_PROOF transport=fake notification_key=artifact_consumer.mailglass_proof notification_version=1 delivery_id=2f1c8b94-3a5e-4d70-8c16-2e3a4b5c6d7e channel=email render_key=artifact_consumer.mailglass_proof.email render_version=1 status=succeeded last_attempt_outcome=succeeded last_attempt_number=1 adapter_module=Chimeway.Adapters.Mailglass timeline_events=event_created,notification_created,delivery_planned,attempt_recorded,webhook_received`

**Does not cover:** real provider acceptance, sender/domain verification, inbox placement/display, production credentials, provider callbacks, or live webhook feedback. Fake proves local host composition and Chimeway adapter orchestration.

**Next step:** Follow the [Mailglass integration guide](mailglass-integration.md) for host wiring and the detailed proof boundary.

## Accrue

**Choose this when:** You want to prove an Accrue billing event reaches a Chimeway workflow signal through the integration.

**Host responsibility:** The host owns billing facts, Accrue configuration, and the business decision to start or stop a campaign.

**Chimeway responsibility:** Chimeway records the notification lifecycle, workflow trace, and outcome signal handling.

**Partner responsibility:** Accrue owns the `invoice.payment_failed` event boundary and the `invoice.paid` outcome signal through its integration.

```bash
mix verify.adoption_paths --only accrue
```

**Representative proof record:** `CHIMEWAY_ACCRUE_PROOF provenance=released_package accrue_version=1.5.0 chimeway_version=1.0.0 workflow_key=accrue.dunning workflow_version=1 waiting_state=waiting waiting_reason=waiting_for_step_progression outcome_event=invoice.paid outcome_state=active outcome_reason=signal_received timeline_reasons=waiting_for_step_progression,signal_received`

**Does not cover:** workflow completion or a terminal workflow state: `active / signal_received` only proves the outcome signal ended the waiting escalation path. A `released_package` record requires resolved package metadata; a SHA-qualified ref is compatibility evidence only, not released-package proof. Live providers, credentials, and webhooks remain outside this deterministic proof.

**Next step:** Follow the [Accrue dunning integration guide](accrue-dunning-integration.md) for setup, provenance, and workflow detail.
