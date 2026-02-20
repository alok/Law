import Lake

open Lake DSL
open System

package claw_channel_telegram where
  version := v!"0.1.0"

require claw_channel from "../claw-channel"

target telegram.o pkg : FilePath := do
  let oFile := pkg.buildDir / "telegram.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "telegram.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs (traceArgs := #["-fPIC"]) (extraDepTrace := getLeanTrace)

extern_lib claw_telegram pkg := do
  let obj ← telegram.o.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "claw_telegram") #[obj]

@[default_target]
lean_lib ClawChannelTelegram where
  roots := #[`Claw.Channel.Telegram.FFI, `Claw.Channel.Telegram.Adapter]
  globs := #[Lake.Glob.one `Claw.Channel.Telegram.FFI, Lake.Glob.one `Claw.Channel.Telegram.Adapter]
  needs := #[claw_telegram]
