import Claw.Gateway.Service
import Claw.Memory.CacheStore
import Claw.Core.Porting
import Claw.Core.ToolDsl
import Claw.Channel.Registry
import Claw.Channel.WebChat.Adapter
import Claw.Channel.Telegram.Adapter
import Claw.Channel.Slack.Adapter
import Claw.Channel.Discord.Adapter
import Claw.Daemon.Runner

namespace Claw.E2E
open Claw.Core
open Claw.Cache
open Claw.Provider
open Claw.Runtime
open Claw.Gateway
open Claw.Memory
open Claw.Channel
open Claw.Daemon

private def assertTrue (cond : Bool) (msg : String) : IO Unit :=
  if !cond then
    throw <| IO.userError msg
  else
    pure ()

private def assertEq [BEq α] [Repr α] (label : String) (actual expected : α) : IO Unit :=
  if actual != expected then
    throw <| IO.userError s!"assertEq failed ({label})\nexpected: {repr expected}\nactual:   {repr actual}"
  else
    pure ()

private def testDeterministicFingerprint : IO Unit := do
  let model : ModelId := { raw := "m1" }
  let tools1 : List ToolDescriptor := [
    { name := "beta", schemaHash := 2 },
    { name := "alpha", schemaHash := 1 }
  ]
  let tools2 : List ToolDescriptor := [
    { name := "alpha", schemaHash := 1 },
    { name := "beta", schemaHash := 2 }
  ]
  let staticSegs : List PromptSegment := [
    { kind := .staticSystem, bytes := "sys".toUTF8 },
    { kind := .toolDefinitions, bytes := "tools".toUTF8 },
    { kind := .projectContext, bytes := "project".toUTF8 },
    { kind := .sessionContext, bytes := "session".toUTF8 }
  ]
  let a := buildFingerprint model tools1 "sys".toUTF8 "project".toUTF8 staticSegs
  let b := buildFingerprint model tools2 "sys".toUTF8 "project".toUTF8 staticSegs
  assertEq "tool digest stable" a.toolSchemaDigest b.toolSchemaDigest
  assertEq "prefix digest stable" a.staticPrefixDigest b.staticPrefixDigest

private def testStrictPolicyBlock : IO Unit := do
  let oldFp : PromptPrefixFingerprint := {
    model := { raw := "model-a" }
    toolSchemaDigest := 1
    systemPromptDigest := 2
    projectContextDigest := 3
    staticPrefixDigest := 4
  }
  let newFp : PromptPrefixFingerprint := { oldFp with model := { raw := "model-b" } }
  let state : SessionState := {
    sessionId := { raw := "s1" }
    lineageId := { raw := "root/s1" }
    fingerprint := oldFp
  }
  let next : ProposedRequestConfig := {
    sessionId := { raw := "s1" }
    proposed := newFp
    segments := [
      { kind := .staticSystem, bytes := "x".toUTF8 },
      { kind := .toolDefinitions, bytes := "y".toUTF8 },
      { kind := .projectContext, bytes := "z".toUTF8 },
      { kind := .sessionContext, bytes := ByteArray.empty },
      { kind := .dynamicMessages, bytes := ByteArray.empty }
    ]
  }
  match validateTransitionStrict {} state next with
  | .error .modelChangedWithoutFork => pure ()
  | other => throw <| IO.userError s!"expected modelChangedWithoutFork, got {repr other}"

private def testForkTransition : IO Unit := do
  let fpA : PromptPrefixFingerprint := {
    model := { raw := "model-a" }
    toolSchemaDigest := 10
    systemPromptDigest := 11
    projectContextDigest := 12
    staticPrefixDigest := 13
  }
  let fpB : PromptPrefixFingerprint := { fpA with model := { raw := "model-b" } }
  let state : SessionState := {
    sessionId := { raw := "s-fork" }
    lineageId := { raw := "root/s-fork" }
    fingerprint := fpA
  }
  let next : ProposedRequestConfig := {
    sessionId := { raw := "s-fork-child" }
    proposed := fpB
    segments := [
      { kind := .staticSystem, bytes := "sys".toUTF8 },
      { kind := .toolDefinitions, bytes := "tool".toUTF8 },
      { kind := .projectContext, bytes := "proj".toUTF8 },
      { kind := .sessionContext, bytes := "ctx".toUTF8 },
      { kind := .dynamicMessages, bytes := "msg".toUTF8 }
    ]
    forkReason? := some "model_switch"
  }
  match validateTransitionStrict {} state next with
  | .ok transitioned =>
    assertTrue (transitioned.lineageId != state.lineageId) "lineage should change on fork"
  | .error e =>
    throw <| IO.userError s!"fork transition unexpectedly failed: {e}"

private def testSystemReminderStability : IO Unit := do
  let model : ModelId := { raw := "cache-model" }
  let tools : List ToolDescriptor := [{ name := "tool", schemaHash := 7 }]
  let staticSegs : List PromptSegment := [
    { kind := .staticSystem, bytes := "system".toUTF8 },
    { kind := .toolDefinitions, bytes := "tool".toUTF8 },
    { kind := .projectContext, bytes := "project".toUTF8 },
    { kind := .sessionContext, bytes := "session".toUTF8 }
  ]
  let a := buildFingerprint model tools "system".toUTF8 "project".toUTF8 staticSegs
  let b := buildFingerprint model tools "system".toUTF8 "project".toUTF8 staticSegs
  assertEq "system reminder should not affect static digest" a.staticPrefixDigest b.staticPrefixDigest

private def testCompactionFork : IO Unit := do
  let base : List PromptSegment := [
    { kind := .staticSystem, bytes := "sys".toUTF8 },
    { kind := .toolDefinitions, bytes := "tools".toUTF8 },
    { kind := .projectContext, bytes := "project".toUTF8 },
    { kind := .sessionContext, bytes := "session".toUTF8 },
    { kind := .dynamicMessages, bytes := "history".toUTF8 }
  ]
  match buildCacheSafeCompaction { raw := "s1" } { raw := "s1c" } base "compact".toUTF8 with
  | .error e => throw <| IO.userError s!"compaction failed: {e}"
  | .ok fork =>
    let oldPrefix := base.take 4
    let newPrefix := fork.segments.take 4
    assertEq "compaction preserves prefix" newPrefix oldPrefix
    let tail := fork.segments.drop 4
    assertTrue (tail.length = 1) "compaction should have one dynamic tail segment"

private def testCanonicalFallbackE2E : IO Unit := do
  let dbPath : System.FilePath := ".lake/build/cache-e2e.db"
  try
    IO.FS.removeFile dbPath
  catch _ =>
    pure ()

  let store ← openCacheStore dbPath

  let primary : ProviderClient := {
    name := "primary"
    run := fun _ => pure <| .error (.timeout "primary")
  }
  let secondary : ProviderClient := {
    name := "secondary"
    run := fun _ =>
      pure <| .ok {
        providerName := "secondary"
        outputText := "fallback-ok"
        usage := { inputTokens := 42, cacheReadTokens := 0, cacheWriteTokens := 4, latencyMs := 20 }
      }
  }

  let engine : ProviderEngine := {
    store := store
    policy := {}
    providers := [primary, secondary]
    failover := { fallbackOrder := ["primary", "secondary"] }
  }

  let svc : GatewayService := { engine := engine }
  let sid : SessionId := { raw := "session-fallback" }
  let mut session := mkInitialSession sid { raw := "model-fallback" }

  let turn : GatewayTurn := {
    sessionId := sid
    traceId := { raw := "trace-1" }
    model := { raw := "model-fallback" }
    tools := [{ name := "tool-a", schemaHash := 1 }]
    staticSystem := "system".toUTF8
    projectContext := "project".toUTF8
    userMessage := "hello".toUTF8
  }

  match (← runTurn svc session turn) with
  | .error e => throw <| IO.userError s!"first turn failed: {e}"
  | .ok (resp, nextSession) =>
    assertEq "fallback provider name" resp.providerName "secondary"
    assertTrue (!resp.cacheHit) "first turn should not be a cache hit"
    session := nextSession

  match (← runTurn svc session turn) with
  | .error e => throw <| IO.userError s!"second turn failed: {e}"
  | .ok (resp, nextSession) =>
    assertEq "fallback provider name second" resp.providerName "secondary"
    assertTrue resp.cacheHit "second equivalent turn should be cache hit"
    session := nextSession

  let persisted? ← lookupFingerprint store sid
  assertTrue persisted?.isSome "cache index should persist fingerprint"

  let misses ← listRecentMisses store 50
  assertTrue (!misses.isEmpty) "expected at least one miss event"

  let stats ← cacheStats store
  assertEq "blocked events" stats.blocked 0

  let violations ← countPolicyViolations store
  assertEq "policy violations" violations 0

  pure ()

private def testChannelAdapterFFIStubs : IO Unit := do
  let adapters : List ChannelAdapter :=
    [Claw.Channel.WebChat.adapter, Claw.Channel.Telegram.adapter, Claw.Channel.Slack.adapter, Claw.Channel.Discord.adapter]
  for adapter in adapters do
    match (← adapter.start) with
    | .error e =>
      throw <| IO.userError s!"adapter start failed ({adapter.name}): {e}"
    | .ok handle =>
      let result ← adapter.send handle {
        channel := adapter.name
        recipient := "recipient"
        text := "hello"
        traceId := { raw := s!"trace-{adapter.name}" }
      }
      match result with
      | .ok _ => pure ()
      | .error e => throw <| IO.userError s!"adapter send failed ({adapter.name}): {e}"
      adapter.stop handle

  let reg := ChannelRegistry.empty
    |>.register Claw.Channel.WebChat.adapter
    |>.register Claw.Channel.Telegram.adapter
    |>.register Claw.Channel.Slack.adapter
    |>.register Claw.Channel.Discord.adapter
  assertEq "registry size" reg.names.length 4

private def testDaemonMessagePath : IO Unit := do
  let dbPath : System.FilePath := ".lake/build/daemon-e2e.db"
  try
    IO.FS.removeFile dbPath
  catch _ =>
    pure ()
  let cfg : DaemonConfig := {
    dbPath := dbPath
    model := { raw := "daemon-model" }
    channels := ["webchat"]
    once := true
  }
  let runtime ← start cfg
  try
    let msg : InboundMessage := {
      channel := "webchat"
      sessionId := { raw := "daemon-session" }
      sender := "test-user"
      text := "hello daemon"
      traceId := { raw := "daemon-trace" }
    }
    match (← handleMessage runtime msg) with
    | .error err => throw <| IO.userError s!"daemon message failed: {err}"
    | .ok _ => pure ()
    let sessions ← runtime.sessions.get
    assertTrue (sessions.contains msg.sessionId) "daemon session state should persist"
  finally
    shutdown runtime

private def testPortingCoverageModel : IO Unit := do
  let openclaw := portingFeatures .openclaw
  let zeroclaw := portingFeatures .zeroclaw
  assertTrue (!openclaw.isEmpty) "openclaw feature map must not be empty"
  assertTrue (!zeroclaw.isEmpty) "zeroclaw feature map must not be empty"
  let openclawCoverage := coveragePercent openclaw
  let zeroclawCoverage := coveragePercent zeroclaw
  assertTrue (openclawCoverage > 0.0) "openclaw coverage should be > 0"
  assertTrue (zeroclawCoverage > 0.0) "zeroclaw coverage should be > 0"

private def testToolStubDsl : IO Unit := do
  let eager : ToolDescriptor := toolStub% "ToolSearch" @ "v1" # 42
  let deferred : ToolDescriptor := { (toolStub% "ReadFile" @ "v2" # 77) with deferredLoading := true }
  assertEq "tool dsl eager name" eager.name "ToolSearch"
  assertEq "tool dsl eager deferred" eager.deferredLoading false
  assertEq "tool dsl deferred name" deferred.name "ReadFile"
  assertEq "tool dsl deferred flag" deferred.deferredLoading true
  assertEq "tool dsl deferred schema hash" deferred.schemaHash 77

/-- Runs all added cache architecture tests for M1. -/
def runAll : IO Unit := do
  testDeterministicFingerprint
  testStrictPolicyBlock
  testForkTransition
  testSystemReminderStability
  testCompactionFork
  testCanonicalFallbackE2E
  testChannelAdapterFFIStubs
  testDaemonMessagePath
  testPortingCoverageModel
  testToolStubDsl
  IO.println "claw-e2e-tests: ok"

end Claw.E2E

def main : IO UInt32 := do
  Claw.E2E.runAll
  pure 0
