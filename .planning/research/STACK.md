# Technology Stack

**Project:** Chimeway v1.4 - Channel Feedback Loops
**Researched:** 2026-04-30

## Recommended Stack

### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Elixir / Phoenix | current LTS | Webhook Ingestion Seams | Host apps run Phoenix/Plug; Chimeway needs an integration seam for router ingestion. |

### Supporting Libraries (Host-App Side)
*Chimeway will define behaviors, and host apps will implement them using these standard community libraries.*

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `twilio_elixir` | ~> 0.1 | SMS Outbound | Host apps wanting Twilio integration. Modern and fully featured. |
| `pigeon` | ~> 2.0 | Push Notifications | Standard Elixir library for APNS and FCM. |
| `slack_elixir` | ~> 1.2 | Chat | Connecting to Slack workspaces via Socket Mode or Web API. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| SMS | Adapter Seam | Native `ex_twilio` integration | Chimeway strictly avoids vendor lock-in. An adapter behavior is superior to a hardcoded dependency. |
| Webhooks | `Plug` integration seam | Built-in Phoenix Controller | Chimeway is embedded infrastructure. It should provide a generic seam that host apps mount in their router to receive webhooks seamlessly without dictating the web layer's entire shape. |

## Installation

\`\`\`elixir
# No new core dependencies for Chimeway itself.
# Host apps will install the relevant adapter libraries if they want to expand channels.
\`\`\`

## Sources
- HexDocs for `pigeon`, `twilio_elixir`, `slack_elixir` (HIGH confidence)
- WebSearch for Elixir SMS and Push ecosystem (MEDIUM confidence)
- Chimeway `.planning/PROJECT.md` Architecture Constraints (HIGH confidence)