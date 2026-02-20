import Lake

open Lake DSL

package claw_e2e where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require claw_cache from "../claw-cache"
require claw_provider from "../claw-provider"
require claw_runtime from "../claw-runtime"
require claw_gateway from "../claw-gateway"
require claw_memory from "../claw-memory"

@[default_target]
lean_lib ClawE2E where
  globs := #[.submodules `Claw.E2E]

@[default_target, test_driver]
lean_exe claw_e2e_tests where
  root := `Claw.E2E.Tests
