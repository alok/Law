import Claw.Gateway.Service
import Claw.Memory.CacheStore
import Claw.Runtime.Session

namespace Claw.E2E
open Claw.Core
open Claw.Cache
open Claw.Provider
open Claw.Runtime
open Claw.Gateway
open Claw.Memory

/-- Summary of one cache benchmark run. -/
structure CacheBenchSummary where
  runs : Nat
  hits : Nat
  misses : Nat
  medianMs : Nat
  p95Ms : Nat
  cacheHitRate : Float
  deriving Repr, Inhabited

private def median (samples : Array Nat) : Nat :=
  if samples.size == 0 then
    0
  else
    let sorted := samples.qsort (· <= ·)
    let mid := sorted.size / 2
    if sorted.size % 2 == 0 then
      (sorted[mid - 1]! + sorted[mid]!) / 2
    else
      sorted[mid]!

private def p95 (samples : Array Nat) : Nat :=
  if samples.size == 0 then
    0
  else
    let sorted := samples.qsort (· <= ·)
    let idx := (95 * (sorted.size - 1)) / 100
    sorted[idx]!

/-- Runs a deterministic cache benchmark over repeated equivalent turns. -/
def runCacheBench (runs : Nat := 20) : IO CacheBenchSummary := do
  let dbPath : System.FilePath := ".lake/build/cache-bench.db"
  try
    IO.FS.removeFile dbPath
  catch _ =>
    pure ()

  let store ← openCacheStore dbPath
  let provider : ProviderClient := {
    name := "bench"
    run := fun req =>
      pure <| .ok {
        providerName := "bench"
        outputText := s!"ok:{(String.fromUTF8? req.dynamicMessages).getD "invalid"}"
        usage := { inputTokens := 32, cacheReadTokens := 0, cacheWriteTokens := 4, latencyMs := 7 }
      }
  }
  let engine : ProviderEngine := {
    store := store
    policy := {}
    providers := [provider]
    failover := {}
  }
  let service : GatewayService := { engine := engine }
  let sid : SessionId := { raw := "bench-session" }
  let mut session := mkInitialSession sid { raw := "bench-model" }

  let turn : GatewayTurn := {
    sessionId := sid
    traceId := { raw := "bench-trace" }
    model := { raw := "bench-model" }
    tools := [{ name := "ToolSearch", schemaHash := 1003 }]
    staticSystem := "system".toUTF8
    projectContext := "project".toUTF8
    userMessage := "one-word response".toUTF8
  }

  let mut hits := 0
  let mut misses := 0
  let mut durations : Array Nat := #[]

  for _ in List.range runs do
    let start ← IO.monoMsNow
    match (← runTurn service session turn) with
    | .error e => throw <| IO.userError s!"cache bench failed: {e}"
    | .ok (resp, nextSession) =>
      let stop ← IO.monoMsNow
      durations := durations.push (stop - start)
      if resp.cacheHit then
        hits := hits + 1
      else
        misses := misses + 1
      session := nextSession

  let total := hits + misses
  let hitRate := if total == 0 then 0.0 else Float.ofNat hits / Float.ofNat total
  return {
    runs := runs
    hits := hits
    misses := misses
    medianMs := median durations
    p95Ms := p95 durations
    cacheHitRate := hitRate
  }

def runMain (argv : List String) : IO UInt32 := do
  let runs :=
    match argv with
    | "--runs" :: n :: _ => n.toNat!
    | _ => 20
  let summary ← runCacheBench runs
  IO.println s!"runs={summary.runs}"
  IO.println s!"hits={summary.hits} misses={summary.misses}"
  IO.println s!"cache_hit_rate={(summary.cacheHitRate * 100.0)}%"
  IO.println s!"median_ms={summary.medianMs} p95_ms={summary.p95Ms}"
  pure 0

end Claw.E2E

def main (argv : List String) : IO UInt32 :=
  Claw.E2E.runMain argv
