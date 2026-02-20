import Claw.Daemon.Config
import Claw.Daemon.Input
import Claw.Gateway.ChannelRuntime
import Claw.Memory.CacheStore
import Claw.Channel.Registry
import Claw.Channel.WebChat.Adapter
import Claw.Channel.Telegram.Adapter
import Claw.Channel.Slack.Adapter
import Claw.Channel.Discord.Adapter

namespace Claw.Daemon
open Claw.Core
open Claw.Channel
open Claw.Cache
open Claw.Provider
open Claw.Runtime
open Claw.Gateway
open Claw.Memory

/-- Running daemon state with initialized gateway/channel/provider components. -/
structure DaemonRuntime where
  config : DaemonConfig
  channelRuntime : GatewayChannelRuntime
  sessions : IO.Ref (Std.HashMap SessionId RuntimeSession)

private def allAdapters : List ChannelAdapter := [
  Claw.Channel.WebChat.adapter,
  Claw.Channel.Telegram.adapter,
  Claw.Channel.Slack.adapter,
  Claw.Channel.Discord.adapter
]

private def makeRegistry (channels : List String) : ChannelRegistry :=
  allAdapters.foldl
    (fun reg adapter =>
      if channels.contains adapter.name then
        reg.register adapter
      else
        reg)
    ChannelRegistry.empty

private def requestText (req : ProviderRequest) : String :=
  (String.fromUTF8? req.dynamicMessages).getD "<invalid-utf8>"

private def mkPrimaryProvider (timeoutDemo : Bool) : ProviderClient := {
  name := "primary"
  run := fun req =>
    if timeoutDemo then
      pure <| .error (.timeout "primary")
    else
      pure <| .ok {
        providerName := "primary"
        outputText := s!"primary:{requestText req}"
        usage := { inputTokens := 24, cacheReadTokens := 0, cacheWriteTokens := 3, latencyMs := 12 }
      }
}

private def mkFallbackProvider : ProviderClient := {
  name := "fallback"
  run := fun req =>
    pure <| .ok {
      providerName := "fallback"
      outputText := s!"fallback:{requestText req}"
      usage := { inputTokens := 18, cacheReadTokens := 0, cacheWriteTokens := 1, latencyMs := 9 }
    }
}

private def makeEngine (store : CacheStore) (cfg : DaemonConfig) : ProviderEngine := {
  store := store
  policy := {}
  providers := [mkPrimaryProvider cfg.primaryTimeoutDemo, mkFallbackProvider]
  failover := {
    fallbackOrder := ["primary", "fallback"]
  }
}

/-- Initializes daemon runtime dependencies and starts selected channel adapters. -/
def start (cfg : DaemonConfig) : IO DaemonRuntime := do
  let registry := makeRegistry cfg.channels
  if registry.names.isEmpty then
    throw <| IO.userError "clawd: no known channels enabled (use --channels)"
  let store ← openCacheStore cfg.dbPath
  let engine := makeEngine store cfg
  let service : GatewayService := { engine := engine }
  let channelRuntime ← Claw.Gateway.start service registry
  let sessions ← IO.mkRef ({} : Std.HashMap SessionId RuntimeSession)
  return { config := cfg, channelRuntime, sessions }

/-- Stops all live adapters for this daemon runtime. -/
def shutdown (rt : DaemonRuntime) : IO Unit :=
  Claw.Gateway.shutdown rt.channelRuntime

private def lookupOrInitSession (rt : DaemonRuntime) (sid : SessionId) : IO RuntimeSession := do
  let sessions ← rt.sessions.get
  match sessions.get? sid with
  | some session => pure session
  | none =>
    let session := mkInitialSession sid rt.config.model
    rt.sessions.modify (fun m => m.insert sid session)
    pure session

/-- Processes one inbound message through gateway runtime and persists next session state. -/
def handleMessage (rt : DaemonRuntime) (msg : InboundMessage) : IO (Except ProviderError Unit) := do
  let session ← lookupOrInitSession rt msg.sessionId
  let result ← Claw.Gateway.handleInbound
    rt.channelRuntime
    session
    msg
    rt.config.model
    rt.config.tools
    rt.config.staticSystem.toUTF8
    rt.config.projectContext.toUTF8
  match result with
  | .error err => pure <| .error err
  | .ok nextSession =>
    rt.sessions.modify (fun m => m.insert msg.sessionId nextSession)
    pure <| .ok ()

private partial def loopStdin (rt : DaemonRuntime) (stdin : IO.FS.Stream) (processed : Nat) : IO Nat := do
  if rt.config.once && processed > 0 then
    return processed
  let line ← stdin.getLine
  if line.isEmpty then
    return processed
  match parseInboundLine line with
  | .error parseErr =>
    IO.eprintln s!"clawd parse error: {parseErr}"
    loopStdin rt stdin processed
  | .ok none =>
    loopStdin rt stdin processed
  | .ok (some msg) =>
    match (← handleMessage rt msg) with
    | .error providerErr =>
      IO.eprintln s!"clawd provider error (trace={msg.traceId.raw}): {providerErr}"
      loopStdin rt stdin processed
    | .ok _ =>
      IO.println s!"clawd processed trace={msg.traceId.raw} session={msg.sessionId.raw} channel={msg.channel}"
      loopStdin rt stdin (processed + 1)

/-- Runs daemon stdin loop from an initialized runtime. -/
def runStdinLoop (rt : DaemonRuntime) : IO Nat := do
  let stdin ← IO.getStdin
  loopStdin rt stdin 0

/-- Starts the daemon from parsed config and runs until EOF (or one message with `--once`). -/
def run (cfg : DaemonConfig) : IO UInt32 := do
  let runtime ← start cfg
  try
    let processed ← runStdinLoop runtime
    if processed == 0 then
      IO.eprintln "clawd: no inbound messages processed"
    pure 0
  finally
    shutdown runtime

end Claw.Daemon
