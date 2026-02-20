import Claw.Provider.Types

namespace Claw.Provider
open Claw.Core
open Claw.Cache

/-- Runtime provider engine configuration. -/
structure ProviderEngine where
  store : SQLitePromptCacheStore
  policy : CachePolicy := {}
  providers : List ProviderClient
  failover : FailoverPolicy := {}

private def encodeToolset (tools : List ToolDescriptor) : ByteArray :=
  let payload :=
    String.intercalate "\n"
      ((normalizeTools tools).map fun t =>
        s!"{t.name}|{t.version}|{t.schemaHash.toNat}|{if t.deferredLoading then "1" else "0"}")
  payload.toUTF8

private def estimateTokens (segments : List PromptSegment) : Nat :=
  segments.foldl (fun acc seg => acc + seg.bytes.size / 4 + 1) 0

private def requestSegments (req : ProviderRequest) : List PromptSegment :=
  [
    { kind := .staticSystem, bytes := req.staticSystem },
    { kind := .toolDefinitions, bytes := encodeToolset req.tools },
    { kind := .projectContext, bytes := req.projectContext },
    { kind := .sessionContext, bytes := req.sessionContext },
    { kind := .dynamicMessages, bytes := req.dynamicMessages }
  ]

private def reorderProviders (providers : List ProviderClient) (order : List String) : List ProviderClient :=
  let rec pick (remaining : List ProviderClient) (names : List String) (acc : List ProviderClient) :=
    match names with
    | [] => acc.reverse ++ remaining
    | n :: ns =>
      let selected := remaining.filter (fun p => p.name == n)
      let rest := remaining.filter (fun p => p.name != n)
      pick rest ns (selected.reverse ++ acc)
  pick providers order []

private def runWithFallback (providers : List ProviderClient) (req : ProviderRequest) : IO (Except ProviderError ProviderResponse) := do
  let rec loop (pending : List ProviderClient) (lastErr : Option ProviderError) := do
    match pending with
    | [] =>
      return .error (lastErr.getD (.upstream "none" "no providers configured"))
    | p :: rest =>
      match (← p.run req) with
      | .ok r => return .ok { r with providerName := p.name }
      | .error (.timeout _) => loop rest (some (.timeout p.name))
      | .error (.upstream _ msg) => loop rest (some (.upstream p.name msg))
      | .error err => return .error err
  loop providers none

private def toSessionState (sessionId : SessionId) (fingerprint : PromptPrefixFingerprint) : SessionState :=
  { sessionId := sessionId, lineageId := { raw := s!"root/{sessionId.raw}" }, fingerprint := fingerprint }

/-- Executes a request through strict cache policy and provider failover. -/
def runTurn
    (engine : ProviderEngine)
    (state? : Option SessionState)
    (req : ProviderRequest) : IO (Except ProviderError (ProviderResponse × SessionState)) := do
  let segments := requestSegments req
  if engine.policy.strictOrdering then
    match validateCanonical segments with
    | .error msg =>
      return .error (.ordering msg)
    | .ok _ => pure ()

  let staticSegments := segments.take 4
  let fingerprint := buildFingerprint req.model req.tools req.staticSystem req.projectContext staticSegments

  let priorFingerprint? ← lookupFingerprint engine.store req.sessionId
  let currentState :=
    match state?, priorFingerprint? with
    | some s, some _ => s
    | some s, none => { s with fingerprint := fingerprint }
    | none, some fp => toSessionState req.sessionId fp
    | none, none => toSessionState req.sessionId fingerprint

  let proposed : ProposedRequestConfig := {
    sessionId := req.sessionId
    proposed := fingerprint
    segments := segments
    forkReason? := req.forkReason?
    newLineage? := req.newLineage?
  }

  match validateTransitionStrict engine.policy currentState proposed with
  | .error err =>
    let t ← mkEventTime
    recordCacheEvent engine.store {
      traceId := req.traceId
      sessionId := req.sessionId
      eventKind := .blocked
      reason := toString err
      prefixDigest := fingerprint.staticPrefixDigest
      createdAtMs := t
    }
    recordPolicyViolation engine.store {
      sessionId := req.sessionId
      violationKind := toString err
      detailsJson := s!"session={req.sessionId.raw};trace={req.traceId.raw}"
      createdAtMs := t
    }
    return .error (.policy err)
  | .ok nextState =>
    if req.forkReason?.isSome then
      setSessionLineage engine.store req.sessionId nextState.lineageId

    let orderedProviders := reorderProviders engine.providers engine.failover.fallbackOrder
    let response ← runWithFallback orderedProviders req
    match response with
    | .error err => return .error err
    | .ok providerResponse =>
      let cacheHit :=
        match priorFingerprint? with
        | some fp => isPrefixMatch fp fingerprint
        | none => false
      let eventKind := if cacheHit then CacheEventKind.hit else CacheEventKind.miss
      let metrics : CacheMetrics := {
        inputTokens := providerResponse.usage.inputTokens + estimateTokens segments
        cacheReadTokens := providerResponse.usage.cacheReadTokens
        cacheWriteTokens := providerResponse.usage.cacheWriteTokens
        latencyMs := providerResponse.usage.latencyMs
      }
      upsertFingerprint engine.store req.sessionId fingerprint metrics
      let t ← mkEventTime
      recordCacheEvent engine.store {
        traceId := req.traceId
        sessionId := req.sessionId
        eventKind := eventKind
        reason := s!"provider={providerResponse.providerName}"
        prefixDigest := fingerprint.staticPrefixDigest
        metrics := metrics
        createdAtMs := t
      }
      if req.forkReason?.isSome then
        recordCacheEvent engine.store {
          traceId := req.traceId
          sessionId := req.sessionId
          eventKind := .forked
          reason := req.forkReason?.getD "fork"
          prefixDigest := fingerprint.staticPrefixDigest
          createdAtMs := t
        }
      if req.isCompaction then
        recordCacheEvent engine.store {
          traceId := req.traceId
          sessionId := req.sessionId
          eventKind := .compacted
          reason := "cache-safe compaction"
          prefixDigest := fingerprint.staticPrefixDigest
          createdAtMs := t
        }
      return .ok ({ providerResponse with cacheHit := cacheHit }, nextState)

end Claw.Provider
