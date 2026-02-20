import Lake

open Lake DSL

package claw_channel where
  version := v!"0.1.0"

require claw_core from "../claw-core"

@[default_target]
lean_lib ClawChannel where
  roots := #[`Claw.Channel.Types, `Claw.Channel.Adapter, `Claw.Channel.Registry]
  globs := #[
    Lake.Glob.one `Claw.Channel.Types,
    Lake.Glob.one `Claw.Channel.Adapter,
    Lake.Glob.one `Claw.Channel.Registry
  ]
