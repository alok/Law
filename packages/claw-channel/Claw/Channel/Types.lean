import Claw.Core.Types

namespace Claw.Channel
open Claw.Core

/-- Handle for an active channel adapter instance. -/
structure AdapterHandle where
  channel : String
  handleId : UInt64
  deriving Repr, Inhabited, BEq, DecidableEq

/-- Capabilities exposed by a channel adapter. -/
structure ChannelCapability where
  canReceive : Bool := true
  canSend : Bool := true
  supportsThreads : Bool := false
  supportsAttachments : Bool := false
  deriving Repr, Inhabited, BEq

/-- Incoming normalized message envelope from an external channel. -/
structure InboundMessage where
  channel : String
  sessionId : SessionId
  sender : String
  text : String
  traceId : TraceId
  deriving Repr, Inhabited, BEq

/-- Outgoing normalized message envelope to an external channel. -/
structure OutboundMessage where
  channel : String
  recipient : String
  text : String
  traceId : TraceId
  deriving Repr, Inhabited, BEq

/-- Adapter-level error model. -/
inductive ChannelError where
  | disabled (channel : String)
  | transport (channel : String) (reason : String)
  | invalidHandle (channel : String)
  deriving Repr, Inhabited, BEq

instance : ToString ChannelError where
  toString
    | .disabled c => s!"channel disabled: {c}"
    | .transport c r => s!"channel transport error ({c}): {r}"
    | .invalidHandle c => s!"invalid channel handle: {c}"

end Claw.Channel
