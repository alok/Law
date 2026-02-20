import Claw.Core.Types

namespace Claw.Daemon
open Claw.Core

private def trim (s : String) : String :=
  s.trimAscii.toString

/-- Stable built-in tool stubs that remain cache-safe across turns. -/
def defaultToolStubs : List ToolDescriptor := [
  { name := "EnterPlanMode", version := "v1", schemaHash := 1001, deferredLoading := false },
  { name := "ExitPlanMode", version := "v1", schemaHash := 1002, deferredLoading := false },
  { name := "ToolSearch", version := "v1", schemaHash := 1003, deferredLoading := false },
  { name := "ReadFile", version := "v1", schemaHash := 1101, deferredLoading := true },
  { name := "RunCommand", version := "v1", schemaHash := 1102, deferredLoading := true }
]

/-- Channels enabled by default in daemon mode. -/
def defaultChannels : List String := ["webchat", "telegram", "slack", "discord"]

/-- Runtime configuration for `clawd`. -/
structure DaemonConfig where
  dbPath : System.FilePath := ".law/cache.db"
  model : ModelId := { raw := "law-m1" }
  staticSystem : String := "You are Law, a cache-safe Lean runtime agent."
  projectContext : String := "project=law;mode=daemon"
  channels : List String := defaultChannels
  tools : List ToolDescriptor := defaultToolStubs
  once : Bool := false
  primaryTimeoutDemo : Bool := false
  deriving Repr, Inhabited

/-- User-facing CLI help text for daemon mode. -/
def usage : String :=
  String.intercalate "\n" [
    "clawd usage:",
    "  clawd [--db <path>] [--model <id>] [--system <text>] [--project <text>]",
    "        [--channels <csv>] [--channel <name>] [--once]",
    "        [--primary-timeout-demo] [--no-default-tools] [--tool <spec>]",
    "",
    "stdin wire format:",
    "  channel<TAB>session_id<TAB>sender<TAB>trace_id<TAB>text",
    "",
    "tool spec format:",
    "  name[:version]:schemaHash[:deferred]",
    "  examples: ToolSearch:1003, ReadFile:v1:1101:true"
  ]

private def parseDeferredFlag (raw : String) : Except String Bool :=
  match (trim raw).toLower with
  | "1" => .ok true
  | "true" => .ok true
  | "0" => .ok false
  | "false" => .ok false
  | other => .error s!"invalid deferred flag '{other}' (expected true/false/1/0)"

private def parseSchemaHash (raw : String) : Except String UInt64 :=
  match (trim raw).toNat? with
  | some n => .ok (UInt64.ofNat n)
  | none => .error s!"invalid schema hash '{raw}'"

private def parseToolSpec (raw : String) : Except String ToolDescriptor := do
  let parts := raw.splitOn ":"
  match parts with
  | [name, hash] =>
    if (trim name).isEmpty then
      throw s!"invalid tool spec '{raw}'"
    let parsedHash ← parseSchemaHash hash
    return {
      name := trim name
      version := "v1"
      schemaHash := parsedHash
      deferredLoading := false
    }
  | [name, version, hash] =>
    if (trim name).isEmpty || (trim version).isEmpty then
      throw s!"invalid tool spec '{raw}'"
    let parsedHash ← parseSchemaHash hash
    return {
      name := trim name
      version := trim version
      schemaHash := parsedHash
      deferredLoading := false
    }
  | [name, version, hash, deferred] =>
    if (trim name).isEmpty || (trim version).isEmpty then
      throw s!"invalid tool spec '{raw}'"
    let parsedHash ← parseSchemaHash hash
    let parsedDeferred ← parseDeferredFlag deferred
    return {
      name := trim name
      version := trim version
      schemaHash := parsedHash
      deferredLoading := parsedDeferred
    }
  | _ =>
    throw s!"invalid tool spec '{raw}'"

private def parseChannelsCsv (raw : String) : List String :=
  raw.splitOn ","
    |>.map trim
    |>.filter (fun c => !c.isEmpty)

private partial def parseArgsAux (cfg : DaemonConfig) : List String → Except String DaemonConfig
  | [] => .ok cfg
  | "--help" :: _ => .error usage
  | "--db" :: path :: rest => parseArgsAux { cfg with dbPath := path } rest
  | "--db" :: [] => .error "--db requires a value"
  | "--model" :: model :: rest => parseArgsAux { cfg with model := { raw := model } } rest
  | "--model" :: [] => .error "--model requires a value"
  | "--system" :: sys :: rest => parseArgsAux { cfg with staticSystem := sys } rest
  | "--system" :: [] => .error "--system requires a value"
  | "--project" :: ctx :: rest => parseArgsAux { cfg with projectContext := ctx } rest
  | "--project" :: [] => .error "--project requires a value"
  | "--channels" :: csv :: rest =>
    let channels := parseChannelsCsv csv
    if channels.isEmpty then
      .error "--channels must contain at least one channel"
    else
      parseArgsAux { cfg with channels := channels } rest
  | "--channels" :: [] => .error "--channels requires a csv value"
  | "--channel" :: ch :: rest => parseArgsAux { cfg with channels := [trim ch] } rest
  | "--channel" :: [] => .error "--channel requires a value"
  | "--once" :: rest => parseArgsAux { cfg with once := true } rest
  | "--primary-timeout-demo" :: rest => parseArgsAux { cfg with primaryTimeoutDemo := true } rest
  | "--no-default-tools" :: rest => parseArgsAux { cfg with tools := [] } rest
  | "--tool" :: spec :: rest => do
    let tool ← parseToolSpec spec
    parseArgsAux { cfg with tools := cfg.tools ++ [tool] } rest
  | "--tool" :: [] => .error "--tool requires a value"
  | flag :: _ => .error s!"unknown option '{flag}'\n\n{usage}"

/-- Parses daemon configuration from CLI args. -/
def parseArgs (args : List String) : Except String DaemonConfig :=
  parseArgsAux {} args

end Claw.Daemon
