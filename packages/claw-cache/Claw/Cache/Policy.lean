import Claw.Cache.Fingerprint

namespace Claw.Cache
open Claw.Core

/-- Session state used to validate cache-safe transitions. -/
structure SessionState where
  sessionId : SessionId
  lineageId : LineageId
  fingerprint : PromptPrefixFingerprint
  deriving Repr, Inhabited, BEq

/-- Proposed request transition for policy validation. -/
structure ProposedRequestConfig where
  sessionId : SessionId
  proposed : PromptPrefixFingerprint
  segments : List PromptSegment
  forkReason? : Option String := none
  newLineage? : Option LineageId := none
  deriving Repr, Inhabited, BEq

/-- Policy violations that should block or fork transitions. -/
inductive PolicyError where
  | nonCanonicalOrdering
  | modelChangedWithoutFork
  | toolsetChangedWithoutFork
  | staticSystemChangedWithoutFork
  | projectContextChangedWithoutFork
  | staticPrefixChangedWithoutFork
  | forkDisallowed (reason : String)
  deriving Repr, Inhabited, BEq

instance : ToString PolicyError where
  toString
    | .nonCanonicalOrdering => "non-canonical prompt segment order"
    | .modelChangedWithoutFork => "model changed inside session without fork"
    | .toolsetChangedWithoutFork => "tool set changed inside session without fork"
    | .staticSystemChangedWithoutFork => "static system prompt changed without fork"
    | .projectContextChangedWithoutFork => "project context changed without fork"
    | .staticPrefixChangedWithoutFork => "static prefix changed without fork"
    | .forkDisallowed reason => s!"fork requested but disabled: {reason}"

/-- Session policy hook used by provider/runtime/gateway. -/
class SessionPolicy (m : Type → Type) where
  validateTransition : SessionState → ProposedRequestConfig → m (Except PolicyError SessionState)

private def requireForkIf (changed : Bool) (canFork : Bool) (err : PolicyError) : Except PolicyError Unit :=
  if !changed || canFork then .ok () else .error err

/-- Strict policy implementation matching prompt-cache invariants. -/
def validateTransitionStrict (policy : CachePolicy)
    (state : SessionState)
    (next : ProposedRequestConfig) : Except PolicyError SessionState := do
  if policy.strictOrdering then
    match validateCanonical next.segments with
    | .ok _ => pure ()
    | .error _ => throw .nonCanonicalOrdering

  let hasFork := next.forkReason?.isSome

  if hasFork && !policy.allowForkOnMutation then
    throw (.forkDisallowed (next.forkReason?.getD "unspecified"))

  if policy.strictModelPinning then
    requireForkIf (state.fingerprint.model != next.proposed.model) hasFork .modelChangedWithoutFork

  if policy.strictToolsetPinning then
    requireForkIf
      (state.fingerprint.toolSchemaDigest != next.proposed.toolSchemaDigest)
      hasFork
      .toolsetChangedWithoutFork

  requireForkIf
    (state.fingerprint.systemPromptDigest != next.proposed.systemPromptDigest)
    hasFork
    .staticSystemChangedWithoutFork

  requireForkIf
    (state.fingerprint.projectContextDigest != next.proposed.projectContextDigest)
    hasFork
    .projectContextChangedWithoutFork

  requireForkIf
    (state.fingerprint.staticPrefixDigest != next.proposed.staticPrefixDigest)
    hasFork
    .staticPrefixChangedWithoutFork

  let lineage :=
    match next.newLineage?, next.forkReason? with
    | some id, _ => id
    | none, some reason => LineageId.childFrom state.lineageId reason
    | none, none => state.lineageId

  return {
    sessionId := next.sessionId
    lineageId := lineage
    fingerprint := next.proposed
  }

abbrev StrictPolicyM := ReaderT CachePolicy IO

instance : SessionPolicy StrictPolicyM where
  validateTransition state next := do
    let policy ← read
    return validateTransitionStrict policy state next

end Claw.Cache
