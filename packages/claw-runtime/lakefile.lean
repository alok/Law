import Lake

open Lake DSL

package claw_runtime where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require claw_cache from "../claw-cache"
require claw_provider from "../claw-provider"

@[default_target]
lean_lib ClawRuntime where
  globs := #[.submodules `Claw.Runtime]
