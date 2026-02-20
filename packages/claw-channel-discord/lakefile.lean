import Lake

open Lake DSL
open System

package claw_channel_discord where
  version := v!"0.1.0"

require claw_channel from "../claw-channel"

target discord.o pkg : FilePath := do
  let oFile := pkg.buildDir / "discord.o"
  let srcJob ← inputTextFile <| pkg.dir / "ffi" / "discord.c"
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  buildO oFile srcJob weakArgs (traceArgs := #["-fPIC"]) (extraDepTrace := getLeanTrace)

extern_lib claw_discord pkg := do
  let obj ← discord.o.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "claw_discord") #[obj]

@[default_target]
lean_lib ClawChannelDiscord where
  roots := #[`Claw.Channel.Discord.FFI, `Claw.Channel.Discord.Adapter]
  globs := #[Lake.Glob.one `Claw.Channel.Discord.FFI, Lake.Glob.one `Claw.Channel.Discord.Adapter]
  needs := #[claw_discord]
