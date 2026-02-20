import Claw.Core.Types

namespace Claw.Cache
open Claw.Core

/-- Prompt cache key material for a session prefix. -/
structure PromptPrefixFingerprint where
  model : ModelId
  toolSchemaDigest : UInt64
  systemPromptDigest : UInt64
  projectContextDigest : UInt64
  staticPrefixDigest : UInt64
  deriving Repr, Inhabited, BEq, DecidableEq

/-- Cache safety policy flags; strict mode by default. -/
structure CachePolicy where
  strictModelPinning : Bool := true
  strictToolsetPinning : Bool := true
  allowForkOnMutation : Bool := true
  strictOrdering : Bool := true
  deriving Repr, Inhabited, BEq, DecidableEq

/-- Ordered segment classes used to build a cacheable prompt prefix. -/
inductive PromptSegmentKind where
  | staticSystem
  | toolDefinitions
  | projectContext
  | sessionContext
  | dynamicMessages
  deriving Repr, Inhabited, BEq, DecidableEq, Ord, Hashable

/-- A single prompt segment; cache matching is prefix-based across ordered segments. -/
structure PromptSegment where
  kind : PromptSegmentKind
  bytes : ByteArray
  deriving Repr, Inhabited, BEq

/-- Provider usage metrics attached to cache events. -/
structure CacheMetrics where
  inputTokens : Nat := 0
  cacheReadTokens : Nat := 0
  cacheWriteTokens : Nat := 0
  latencyMs : Nat := 0
  deriving Repr, Inhabited, BEq

/-- Normalized cache event kinds for observability and SLOs. -/
inductive CacheEventKind where
  | hit
  | miss
  | blocked
  | forked
  | compacted
  deriving Repr, Inhabited, BEq, DecidableEq

instance : ToString CacheEventKind where
  toString
    | .hit => "hit"
    | .miss => "miss"
    | .blocked => "blocked"
    | .forked => "forked"
    | .compacted => "compacted"

/-- Parse event kind from persistence. -/
def CacheEventKind.ofString? (s : String) : Option CacheEventKind :=
  match s with
  | "hit" => some .hit
  | "miss" => some .miss
  | "blocked" => some .blocked
  | "forked" => some .forked
  | "compacted" => some .compacted
  | _ => none

/-- Persisted cache event row. -/
structure CacheEvent where
  traceId : TraceId
  sessionId : SessionId
  eventKind : CacheEventKind
  reason : String
  prefixDigest : UInt64
  metrics : CacheMetrics := {}
  createdAtMs : Int64
  deriving Repr, Inhabited, BEq

/-- Persisted policy violation row. -/
structure PolicyViolation where
  sessionId : SessionId
  violationKind : String
  detailsJson : String
  createdAtMs : Int64
  deriving Repr, Inhabited, BEq

/-- Returned cache miss view for CLI and diagnostics. -/
structure CacheMissEvent where
  traceId : TraceId
  sessionId : SessionId
  reason : String
  createdAtMs : Int64
  deriving Repr, Inhabited, BEq

/-- Aggregated cache/SLO counters. -/
structure CacheStats where
  totalEvents : Nat := 0
  hits : Nat := 0
  misses : Nat := 0
  blocked : Nat := 0
  forks : Nat := 0
  compactions : Nat := 0
  cacheHitRate : Float := 0
  cacheBreakRate : Float := 0
  policyBlockRate : Float := 0
  p95TurnLatencyMs : Nat := 0
  deriving Repr, Inhabited, BEq

end Claw.Cache
