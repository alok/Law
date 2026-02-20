import Claw.Cache.Types

namespace Claw.Cache

/-- Canonical rank for prompt segments; lower ranks must appear earlier. -/
def PromptSegmentKind.rank : PromptSegmentKind → Nat
  | .staticSystem => 0
  | .toolDefinitions => 1
  | .projectContext => 2
  | .sessionContext => 3
  | .dynamicMessages => 4

/-- Returns true when segments are already in canonical static-first order. -/
def isCanonicalOrder (segments : List PromptSegment) : Bool :=
  let rec go (prev : Nat) : List PromptSegment → Bool
    | [] => true
    | seg :: rest =>
        let current := seg.kind.rank
        prev <= current && go current rest
  go 0 segments

/-- Sort segments into canonical order. -/
private def insertSegment (x : PromptSegment) : List PromptSegment → List PromptSegment
  | [] => [x]
  | y :: ys =>
    if x.kind.rank <= y.kind.rank then
      x :: y :: ys
    else
      y :: insertSegment x ys

/-- Sort segments into canonical order. -/
def canonicalize (segments : List PromptSegment) : List PromptSegment :=
  segments.foldl (fun acc seg => insertSegment seg acc) []

/-- Validates canonical order with a stable error string. -/
def validateCanonical (segments : List PromptSegment) : Except String (List PromptSegment) :=
  if isCanonicalOrder segments then
    .ok segments
  else
    .error "non-canonical prompt segment order"

end Claw.Cache
