import Claw.Gateway.PromptBuilder

namespace Claw.Gateway
open Claw.Core
open Claw.Cache
open Claw.Provider
open Claw.Runtime

/-- Turn payload used by the gateway service. -/
structure GatewayTurn where
  sessionId : SessionId
  traceId : TraceId
  model : ModelId
  tools : List ToolDescriptor
  staticSystem : ByteArray
  projectContext : ByteArray
  userMessage : ByteArray
  forkReason? : Option String := none
  newLineage? : Option LineageId := none
  isCompaction : Bool := false
  deriving Repr, Inhabited

/-- High-level service that binds runtime session state to provider execution. -/
structure GatewayService where
  engine : ProviderEngine

/-- Execute one turn through canonical assembly, policy checks, and provider failover. -/
def runTurn
    (svc : GatewayService)
    (session : RuntimeSession)
    (turn : GatewayTurn) : IO (Except ProviderError (ProviderResponse × RuntimeSession)) := do
  let reminderText := String.intercalate "\n" session.systemReminders
  let req : ProviderRequest := {
    sessionId := turn.sessionId
    traceId := turn.traceId
    model := turn.model
    tools := turn.tools
    staticSystem := turn.staticSystem
    projectContext := turn.projectContext
    sessionContext := reminderText.toUTF8
    dynamicMessages := turn.userMessage
    forkReason? := turn.forkReason?
    newLineage? := turn.newLineage?
    isCompaction := turn.isCompaction
  }
  match (← Provider.runTurn svc.engine (some session.state) req) with
  | .error e => return .error e
  | .ok (resp, state') => return .ok (resp, { session with state := state' })

end Claw.Gateway
