import Claw.Runtime.Session

namespace Claw.Runtime
open Claw.Core
open Claw.Cache

/-- Cache-safe compaction request preserving parent static/session prefix. -/
structure CompactionFork where
  parentSession : SessionId
  childSession : SessionId
  segments : List PromptSegment
  deriving Repr, Inhabited, BEq

/-- Builds a compaction request by preserving first four prefix segments and changing only dynamic tail. -/
def buildCacheSafeCompaction
    (parentSession childSession : SessionId)
    (baseSegments : List PromptSegment)
    (compactionPrompt : ByteArray) : Except String CompactionFork := do
  let canonical ← validateCanonical baseSegments
  let staticPrefix := canonical.take 4
  let mergedDynamic : ByteArray :=
    (canonical.filter (fun s => s.kind == .dynamicMessages)).foldl
      (fun acc seg => acc ++ seg.bytes)
      ByteArray.empty
  let dynamic := { kind := .dynamicMessages, bytes := mergedDynamic ++ compactionPrompt }
  return {
    parentSession := parentSession
    childSession := childSession
    segments := staticPrefix ++ [dynamic]
  }

end Claw.Runtime
