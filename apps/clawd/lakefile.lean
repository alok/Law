import Lake

open Lake DSL

package clawd where
  version := v!"0.1.0"

require claw_daemon from "../../packages/claw-daemon"

@[default_target]
lean_exe clawd where
  root := `Claw.Daemon.Main
