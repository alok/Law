import Lake

open Lake DSL

package claw_core where
  version := v!"0.1.0"

@[default_target]
lean_lib ClawCore where
  globs := #[.submodules `Claw.Core]
