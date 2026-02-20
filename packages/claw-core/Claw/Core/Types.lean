import Std

namespace Claw.Core

instance : Repr ByteArray where
  reprPrec bytes _ := repr bytes.toList

/-- Logical model identifier. -/
structure ModelId where
  raw : String
  deriving Repr, Inhabited, BEq, DecidableEq, Hashable, Ord

/-- Logical session identifier. -/
structure SessionId where
  raw : String
  deriving Repr, Inhabited, BEq, DecidableEq, Hashable, Ord

/-- Session lineage identifier, used for cache-safe forks. -/
structure LineageId where
  raw : String
  deriving Repr, Inhabited, BEq, DecidableEq, Hashable, Ord

/-- Trace identifier for observability records. -/
structure TraceId where
  raw : String
  deriving Repr, Inhabited, BEq, DecidableEq, Hashable, Ord

/-- Stable tool descriptor used for deterministic tool-set hashing. -/
structure ToolDescriptor where
  name : String
  version : String := "v1"
  schemaHash : UInt64
  deferredLoading : Bool := false
  deriving Repr, Inhabited, BEq, DecidableEq

/-- Deterministic key used to canonicalize tool ordering before hashing. -/
def ToolDescriptor.sortKey (t : ToolDescriptor) : String :=
  s!"{t.name}:{t.version}:{t.schemaHash.toNat}:{if t.deferredLoading then "1" else "0"}"

instance : Ord ToolDescriptor where
  compare a b := compare a.sortKey b.sortKey

private def insertSortedTool (x : ToolDescriptor) : List ToolDescriptor → List ToolDescriptor
  | [] => [x]
  | y :: ys =>
      match compare x y with
      | .lt | .eq => x :: y :: ys
      | .gt => y :: insertSortedTool x ys

/-- Canonicalized tool order for cache-stable prefix hashing. -/
def normalizeTools (tools : List ToolDescriptor) : List ToolDescriptor :=
  tools.foldl (fun acc t => insertSortedTool t acc) []

/-- Creates a child lineage id from a parent and reason. -/
def LineageId.childFrom (parent : LineageId) (reason : String) : LineageId :=
  { raw := s!"{parent.raw}/{reason}" }

end Claw.Core
