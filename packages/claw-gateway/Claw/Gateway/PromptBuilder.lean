import Claw.Runtime.Compaction

namespace Claw.Gateway
open Claw.Core
open Claw.Cache

/-- Input model for canonical prompt assembly. -/
structure PromptBuildInput where
  staticSystem : ByteArray
  toolDefinitions : ByteArray
  projectContext : ByteArray
  sessionContext : ByteArray
  dynamicMessages : ByteArray
  deriving Repr, Inhabited

/-- Build prompt segments in static-first order. -/
def buildSegments (input : PromptBuildInput) : List PromptSegment :=
  [
    { kind := .staticSystem, bytes := input.staticSystem },
    { kind := .toolDefinitions, bytes := input.toolDefinitions },
    { kind := .projectContext, bytes := input.projectContext },
    { kind := .sessionContext, bytes := input.sessionContext },
    { kind := .dynamicMessages, bytes := input.dynamicMessages }
  ]

/-- Validate canonical ordering and return ordered segments. -/
def buildAndValidate (input : PromptBuildInput) : Except String (List PromptSegment) :=
  validateCanonical (buildSegments input)

end Claw.Gateway
