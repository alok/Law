import Lake

open Lake DSL

package claw_cache where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require leansqlite from git "https://github.com/leanprover/leansqlite" @ "main"

@[default_target]
lean_lib ClawCache where
  globs := #[.submodules `Claw.Cache]
