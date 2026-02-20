import Lake

open Lake DSL
open System

package claw_channel_slack where
  version := v!"0.1.0"

require claw_channel from "../claw-channel"

target slack.o pkg : FilePath := do
  let oFile := pkg.buildDir / "slack.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "slack.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs (traceArgs := #["-fPIC"]) (extraDepTrace := getLeanTrace)

extern_lib claw_slack pkg := do
  let obj ← slack.o.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "claw_slack") #[obj]

@[default_target]
lean_lib ClawChannelSlack where
  roots := #[`Claw.Channel.Slack.FFI, `Claw.Channel.Slack.Adapter]
  globs := #[Lake.Glob.one `Claw.Channel.Slack.FFI, Lake.Glob.one `Claw.Channel.Slack.Adapter]
  needs := #[claw_slack]
