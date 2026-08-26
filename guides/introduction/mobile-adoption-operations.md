# Mobile Adoption and Operations

This is the canonical guide for Chimeway's iPhone-first mobile delivery path. It is deliberately literal: the current public state is **physical evidence pending**. A green package, Git revision, Hex artifact, or CI run establishes provenance only; none establishes physical-device behavior.

## Start with your job

- **[Integrate mobile push](#readiness-and-roles)** — host integrator: prepare the host-owned prerequisites and wiring.
- **[Explain an outcome](#outcome-vocabulary)** — operator/on-call: distinguish the durable facts recorded by Chimeway.
- **[Review the security boundary](#ownership-boundaries)** — security reviewer: confirm which party owns each trust decision.
- **[Run or promote proof](#proof-ladder)** — maintainer: use the Threshold-A contract today and the signed-device process only when external gates are ready.

## Readiness and roles

Chimeway is embedded in the host application. The host integrator owns tenant eligibility and application wiring; the operator explains a recorded outcome; the security reviewer checks the boundary; and the maintainer runs release and proof commands. Begin with the [Installation Guide](installation.md) and the [Golden Path](golden-path.md); this guide does not repeat their procedures.

## Ownership boundaries

The host owns recipients, tenancy, authentication, authorization, URL generation, token custody, APNs credentials, and the decision to activate an intent. Chimeway owns its durable `event -> notification -> delivery -> attempt` lifecycle and explainable trace. CrossWake owns native permission observation, authenticated registration authority, offline protected-open handling, and one-time protected activation. Apple/APNs accepts or rejects a provider request.

Provider acceptance is provider handoff only. It does not prove device receipt or display, protected activation, inbox seen/read, or engagement.

## Compatible installation and upgrade

Install and configure Chimeway using the [Installation Guide](installation.md). New installations use the isolated `chimeway` schema; an existing public-schema installation follows the explicit compatibility steps in the [Storage Prefix Upgrade Guide](storage-prefix-upgrade.md). Do not silently move host data or infer a tenant from a device.

## Tenant, APNs, and host wiring

Keep tenant resolution, recipient eligibility, APNs configuration, and host registration/activation authority in the host. Wire async dispatch through the [Oban integration recipe](../recipes/oban-integration.md) when the host uses Oban. Use the [custom adapter recipe](../recipes/custom-adapter.md) for adapter seams and the [Golden Path](golden-path.md) for notifier and trace setup.

Provider acceptance is provider handoff only. It does not prove device receipt or display, protected activation, inbox seen/read, or engagement.

## Outcome vocabulary

Use these facts without collapsing them: a **logical delivery** is Chimeway's durable delivery decision; a **target** is one eligible destination; an **attempt** is one adapter attempt; **provider acceptance** is APNs handoff; **visible presentation** is the separate alert observation; a **protected open** is CrossWake's authorized one-time activation; **inbox seen/read** are separate inbox lifecycle facts; and **engagement** is not inferred by Chimeway.

For a durable explanation, follow [Tracing a notification](../recipes/tracing-a-notification.md). Provider acceptance is provider handoff only. It does not prove device receipt or display, protected activation, inbox seen/read, or engagement.

## Offline protected opens

An offline protected open is queued by CrossWake and re-authorized after reconnect. It remains route-scoped and server-authoritative: tenant, binding revision, expiry, session, manifest, and RouteGate authorization are checked again before one-time consumption. It is not generic background sync, and provider acceptance is provider handoff only—not proof of receipt, display, protected activation, inbox seen/read, or engagement.

## Proof ladder

**Threshold A — `release_ready_physical_pending`.** This credential-free release gate validates schemas, fixtures, source-bound CrossWake proof, and package integrity. Run:

```bash
mix ci.verify_gates
mix verify.alpha_twin
mix verify.physical_proof_contract
mix chimeway.mobile_physical_proof --preflight --json
```

The result remains physical evidence pending. It is not physical behavior evidence.

**Threshold B — `physical_support_promoted`.** After Apple signing/provisioning, APNs sandbox, the selected iPhone, host authority, and the CrossWake Phase 162 reconciliation are ready, run the signed-device process. The runner asks exactly: “Did the expected Chimeway alert appear on the selected iPhone?” Choose **Observed**, **Did not appear**, or **Cannot verify**. That observation confirms visible presentation only; it does not establish APNs acceptance, protected activation, inbox state, or engagement. A promotion requires an explicit `Observed` answer and an append-only validated bundle.

## Troubleshooting and operator actions

### A provider attempt was accepted but no alert was reported

**What happened:** Chimeway has a provider-acceptance attempt but no visible-presentation fact.

**Why it matters:** Provider acceptance is provider handoff only. It does not prove device receipt or display, protected activation, inbox seen/read, or engagement.

**How to fix:** Inspect the Chimeway trace, then have the host and CrossWake owners check authorization, registration, selected-device state, and the bounded visible-alert attestation. Do not backfill or infer `Observed`.

### A protected open is unavailable after reconnect

**What happened:** CrossWake did not authorize one-time activation.

**Why it matters:** Reauthorization prevents stale, replayed, expired, revoked, logged-out, or tenant-switched intents from activating a fallback route.

**How to fix:** Resolve the host session, tenant, binding revision, and route authorization, then create a fresh intent. Use a new proof run; never overwrite retained evidence.

### The release gate is green but physical support is still pending

**What happened:** Threshold A completed.

**Why it matters:** Package/CI provenance is not APNs receipt, display, or protected-open evidence.

**How to fix:** Keep public support wording at physical evidence pending until the signed-device Threshold-B bundle is validated and promoted.

## Non-goals

This guide does not deliver Android or FCM transport, generic offline/background sync, broad device support, device management, a general attestation platform, push analytics, raw-token storage, screenshots/video, rich-media campaigns, or arbitrary notification actions. Chimeway does not claim that APNs acceptance establishes receipt, display, protected activation, inbox read/seen, or engagement.
