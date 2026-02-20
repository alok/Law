import Claw.Cache.Ordering

namespace Claw.Cache
open Claw.Core

private def fnvOffset : UInt64 := 14695981039346656037
private def fnvPrime : UInt64 := 1099511628211

private def hashStep (h : UInt64) (b : UInt8) : UInt64 :=
  (h ^^^ UInt64.ofNat b.toNat) * fnvPrime

/-- Hashes a byte array with FNV-1a 64-bit. -/
def hashBytes (bytes : ByteArray) (seed : UInt64 := fnvOffset) : UInt64 :=
  bytes.foldl hashStep seed

/-- Hashes a UTF-8 string with FNV-1a 64-bit. -/
def hashString (s : String) (seed : UInt64 := fnvOffset) : UInt64 :=
  hashBytes s.toUTF8 seed

private def mixHash (h : UInt64) (n : UInt64) : UInt64 :=
  hashBytes (toString n).toUTF8 h

/-- Deterministic digest of normalized tool descriptors. -/
def digestTools (tools : List ToolDescriptor) : UInt64 :=
  let normalized := normalizeTools tools
  normalized.foldl
    (fun acc t =>
      let acc := hashString t.name acc
      let acc := hashString t.version acc
      let acc := mixHash acc t.schemaHash
      let acc := hashString (if t.deferredLoading then "1" else "0") acc
      acc)
    fnvOffset

/-- Digest over static prefix segments. -/
def digestStaticPrefix (segments : List PromptSegment) : UInt64 :=
  segments.foldl
    (fun acc seg =>
      let acc := hashString (toString seg.kind.rank) acc
      hashBytes seg.bytes acc)
    fnvOffset

/-- Build fingerprint from canonical static prompt data. -/
def buildFingerprint
    (model : ModelId)
    (tools : List ToolDescriptor)
    (systemPrompt : ByteArray)
    (projectContext : ByteArray)
    (staticSegments : List PromptSegment) : PromptPrefixFingerprint :=
  {
    model := model
    toolSchemaDigest := digestTools tools
    systemPromptDigest := hashBytes systemPrompt
    projectContextDigest := hashBytes projectContext
    staticPrefixDigest := digestStaticPrefix staticSegments
  }

/-- Prefix equality check used to classify hits/misses. -/
def isPrefixMatch (a b : PromptPrefixFingerprint) : Bool :=
  a.model == b.model &&
  a.toolSchemaDigest == b.toolSchemaDigest &&
  a.systemPromptDigest == b.systemPromptDigest &&
  a.projectContextDigest == b.projectContextDigest &&
  a.staticPrefixDigest == b.staticPrefixDigest

end Claw.Cache
