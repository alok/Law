import Lake

open Lake DSL

package claw_gateway where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require claw_cache from "../claw-cache"
require claw_provider from "../claw-provider"
require claw_runtime from "../claw-runtime"

@[default_target]
lean_lib ClawGateway where
  globs := #[.submodules `Claw.Gateway]
