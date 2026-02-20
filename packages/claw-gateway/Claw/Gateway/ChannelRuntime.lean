import Claw.Gateway.Service
import Claw.Channel.Registry

namespace Claw.Gateway
open Claw.Core
open Claw.Channel
open Claw.Runtime
open Claw.Provider

/-- Runtime wiring for executing gateway turns through registered channel adapters. -/
structure GatewayChannelRuntime where
  service : GatewayService
  registry : ChannelRegistry
  handles : IO.Ref (Std.HashMap String AdapterHandle)

/-- Starts all registered channel adapters and returns runtime wiring. -/
def start (service : GatewayService) (registry : ChannelRegistry) : IO GatewayChannelRuntime := do
  let mut handles : Std.HashMap String AdapterHandle := {}
  for (name, adapter) in registry.adapters.toList do
    match (← adapter.start) with
    | .ok handle =>
      handles := handles.insert name handle
    | .error _ =>
      pure ()
  let ref ← IO.mkRef handles
  return { service, registry, handles := ref }

/-- Stop all active adapters. -/
def shutdown (rt : GatewayChannelRuntime) : IO Unit := do
  let handles ← rt.handles.get
  for (name, handle) in handles.toList do
    match rt.registry.get? name with
    | some adapter =>
      adapter.stop handle
    | none =>
      pure ()

/-- Route an inbound channel message through the gateway and send a reply to the same channel. -/
def handleInbound
    (rt : GatewayChannelRuntime)
    (session : RuntimeSession)
    (msg : InboundMessage)
    (model : ModelId)
    (tools : List ToolDescriptor)
    (staticSystem : ByteArray)
    (projectContext : ByteArray) : IO (Except ProviderError RuntimeSession) := do
  let turn : GatewayTurn := {
    sessionId := msg.sessionId
    traceId := msg.traceId
    model := model
    tools := tools
    staticSystem := staticSystem
    projectContext := projectContext
    userMessage := msg.text.toUTF8
  }
  match (← runTurn rt.service session turn) with
  | .error e => return .error e
  | .ok (response, nextSession) =>
    let handles ← rt.handles.get
    match handles.get? msg.channel, rt.registry.get? msg.channel with
    | some handle, some adapter =>
      let _ ← adapter.send handle {
        channel := msg.channel
        recipient := msg.sender
        text := response.outputText
        traceId := msg.traceId
      }
      return .ok nextSession
    | _, _ =>
      return .ok nextSession

end Claw.Gateway
