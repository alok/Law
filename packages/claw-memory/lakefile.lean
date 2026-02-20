import Lake

open Lake DSL

package claw_memory where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require claw_cache from "../claw-cache"

@[default_target]
lean_lib ClawMemory where
  globs := #[.submodules `Claw.Memory]
