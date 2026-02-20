import Lake

open Lake DSL
open System

package claw_channel_webchat where
  version := v!"0.1.0"

require claw_channel from "../claw-channel"

target webchat.o pkg : FilePath := do
  let oFile := pkg.buildDir / "webchat.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "webchat.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs (traceArgs := #["-fPIC"]) (extraDepTrace := getLeanTrace)

extern_lib claw_webchat pkg := do
  let obj ← webchat.o.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "claw_webchat") #[obj]

@[default_target]
lean_lib ClawChannelWebChat where
  roots := #[`Claw.Channel.WebChat.FFI, `Claw.Channel.WebChat.Adapter]
  globs := #[Lake.Glob.one `Claw.Channel.WebChat.FFI, Lake.Glob.one `Claw.Channel.WebChat.Adapter]
  needs := #[claw_webchat]
