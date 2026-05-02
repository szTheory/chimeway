# Active Requirements

## CHANNELS (Outbound Channel Contracts)
- **CHAN-01**: System supports generic outbound channel adapters (SMS, Push, Chat) without hard-coupling to specific vendor SDKs.
- **CHAN-02**: Channel-specific rendering contracts exist to format payloads appropriately for different channels (e.g., `text_body` for SMS vs `html_body` for email).

## FEEDBACK (Inbound Feedback Normalization)
- **FEED-01**: System provides a webhook ingestion layer to receive asynchronous provider callbacks (receipts, bounces).
- **FEED-02**: Provider-specific callback payloads are normalized into canonical Chimeway delivery outcomes (delivered, bounced, failed).

## WORKFLOW (Feedback-Driven Progression)
- **FLOW-01**: Normalized delivery outcomes are emitted as signals to the workflow engine.
- **FLOW-02**: Workflow journeys can define outcome-based progression rules (e.g., escalate to SMS if email bounces, or stop if push is delivered) driven by asynchronous feedback.

## AUDIT (Operator Traces & Audit)
- **TRAC-01**: Operator timeline traces include asynchronous provider callbacks and the resulting outcome state updates.
- **TRAC-02**: Trace visibility connects the inbound webhook event back to the specific journey progression step it triggered.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CHAN-01     | Phase 29 | Complete |
| CHAN-02     | Phase 29 | Complete |
| FEED-01     | Phase 33 | Complete |
| FEED-02     | Phase 33 | Complete |
| FLOW-01     | Phase 34 | Pending |
| FLOW-02     | Phase 34 | Pending |
| TRAC-01     | Phase 32 | Complete |
| TRAC-02     | Phase 32 | Complete |
