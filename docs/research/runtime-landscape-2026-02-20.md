# Runtime Landscape (2026-02-20)

This note tracks upstreams we are porting from and adjacent alternatives that influence Law design.

## Primary Porting Targets

### OpenClaw (TypeScript)
- Repository: https://github.com/openclaw/openclaw
- Relevant areas for Law parity:
  - multi-channel routing and gateway execution loops
  - provider fallback + operational CLI surfaces
  - cache-sensitive agent harness behavior
- Current Law mapping:
  - `packages/claw-channel*` for adapter boundaries
  - `packages/claw-gateway` + `packages/claw-provider` for turn execution and failover
  - `packages/claw-cache` + `packages/claw-memory` for cache index/event persistence
  - `apps/clawd` for daemon entrypoint

### ZeroClaw (Rust)
- Repository: https://github.com/zeroclaw-labs/zeroclaw
- Relevant areas for Law parity:
  - trait-driven modular architecture
  - explicit runtime contracts and strict policy boundaries
  - performance/benchmark discipline for hot paths
- Current Law mapping:
  - composable package boundaries mirror trait-style separation
  - strict cache-policy transitions in `Claw.Cache.Policy`
  - benchmark executable `claw_cache_bench` in `packages/claw-e2e`

## Alternatives Informing Architecture

These are not direct “port targets”, but they influence design choices:

- OpenHands docs: https://docs.all-hands.dev/
  - useful reference for autonomous coding-loop UX and deployment surface
- CrewAI docs: https://docs.crewai.com/
  - useful reference for multi-agent orchestration and role composition
- Microsoft AutoGen: https://microsoft.github.io/autogen/
  - useful reference for agent team abstractions and handoff patterns
- LangGraph docs: https://langchain-ai.github.io/langgraph/
  - useful reference for deterministic graph-based orchestration

## Near-Term Porting Priorities

1. Gateway auth/pairing model and node topology contracts.
2. Media pipeline primitives (inbound/outbound attachments).
3. Approval/sandbox surface for tool execution.
4. Expanded channel set beyond the current four adapter packages.
5. Compatibility loaders for upstream config formats (OpenClaw JSON / ZeroClaw TOML).

## Tracking in Code

Port status is modeled as code in `Claw.Core.Porting` and exposed in CLI:

```bash
lake exe clawctl port status --runtime openclaw
lake exe clawctl port status --runtime zeroclaw
```
