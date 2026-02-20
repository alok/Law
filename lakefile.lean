import Lake

open Lake DSL

package law where
  version := v!"0.1.0"
  license := "MIT OR Apache-2.0"

require claw_core from "packages/claw-core"
require claw_cache from "packages/claw-cache"
require claw_provider from "packages/claw-provider"
require claw_runtime from "packages/claw-runtime"
require claw_gateway from "packages/claw-gateway"
require claw_memory from "packages/claw-memory"
require claw_e2e from "packages/claw-e2e"
require clawctl from "apps/clawctl"

@[default_target]
lean_lib Law
