import Claw.Cache.Store

namespace Claw.Provider
open Claw.Core
open Claw.Cache

/-- Provider request material after gateway assembly. -/
structure ProviderRequest where
  sessionId : SessionId
  traceId : TraceId
  model : ModelId
  tools : List ToolDescriptor
  staticSystem : ByteArray
  projectContext : ByteArray
  sessionContext : ByteArray
  dynamicMessages : ByteArray
  forkReason? : Option String := none
  newLineage? : Option LineageId := none
  isCompaction : Bool := false
  deriving Repr, Inhabited

/-- Provider usage metadata returned by backend calls. -/
structure ProviderUsage where
  inputTokens : Nat := 0
  cacheReadTokens : Nat := 0
  cacheWriteTokens : Nat := 0
  latencyMs : Nat := 0
  deriving Repr, Inhabited, BEq

/-- Successful provider response. -/
structure ProviderResponse where
  providerName : String
  outputText : String
  usage : ProviderUsage := {}
  cacheHit : Bool := false
  deriving Repr, Inhabited, BEq

/-- Failure modes used by provider failover logic. -/
inductive ProviderError where
  | timeout (provider : String)
  | upstream (provider : String) (message : String)
  | policy (err : PolicyError)
  | ordering (message : String)
  deriving Repr, Inhabited, BEq

instance : ToString ProviderError where
  toString
    | .timeout provider => s!"provider timeout: {provider}"
    | .upstream provider message => s!"provider error ({provider}): {message}"
    | .policy err => s!"policy violation: {err}"
    | .ordering message => s!"ordering error: {message}"

/-- A provider implementation. -/
structure ProviderClient where
  name : String
  run : ProviderRequest → IO (Except ProviderError ProviderResponse)

/-- Policy for attempting fallback providers after failures. -/
structure FailoverPolicy where
  timeoutMs : Nat := 60_000
  maxRetries : Nat := 0
  fallbackOrder : List String := []
  deriving Repr, Inhabited

end Claw.Provider
