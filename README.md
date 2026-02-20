# Law

Lean-first, composable implementation of OpenClaw-style agent runtime and gateway semantics.

## Workspace goals

- Prompt caching is mandatory and policy-enforced.
- Cache metadata is persisted in SQLite.
- Session policy is strict by default.
- Channel adapters are isolated via small boundaries.

## Build

```bash
lake update
lake build
```

## Run tests

```bash
lake build @claw_e2e
lake exe claw_e2e_tests
```

## CLI

```bash
lake exe clawctl cache stats
lake exe clawctl cache misses --recent 20
lake exe clawctl session fork --session default --reason model_switch
```
