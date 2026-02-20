import Claw.Memory.CacheStore
import Claw.Core.Porting

namespace Claw.Cli
open Claw.Core
open Claw.Cache
open Claw.Memory

private def usage : String :=
  "clawctl usage:\n" ++
  "  clawctl cache stats [--db <path>]\n" ++
  "  clawctl cache misses --recent <n> [--db <path>]\n" ++
  "  clawctl session fork --session <id> --reason <reason> [--db <path>]\n" ++
  "  clawctl port status [--runtime <openclaw|zeroclaw>]"

private def parseDbPath : List String → System.FilePath × List String
  | "--db" :: p :: rest => (p, rest)
  | x :: xs =>
    let (db, rest) := parseDbPath xs
    (db, x :: rest)
  | [] => (".law/cache.db", [])

private def parseRecent : List String → Nat
  | "--recent" :: n :: _ => n.toNat!
  | _ => 20

private def lookupFlagValue (flag : String) : List String → Option String
  | [] => none
  | f :: v :: rest => if f == flag then some v else lookupFlagValue flag (v :: rest)
  | [_] => none

private def parseRuntime (args : List String) : Except String UpstreamRuntime := do
  let raw := (lookupFlagValue "--runtime" args).getD "openclaw"
  match raw.trimAscii.toString.toLower with
  | "openclaw" => .ok .openclaw
  | "zeroclaw" => .ok .zeroclaw
  | other => .error s!"unknown runtime '{other}' (expected openclaw|zeroclaw)"

private def printStats (stats : CacheStats) : IO Unit := do
  IO.println s!"total_events={stats.totalEvents}"
  IO.println s!"hits={stats.hits} misses={stats.misses} blocked={stats.blocked} forks={stats.forks} compactions={stats.compactions}"
  IO.println s!"cache_hit_rate={stats.cacheHitRate * 100.0}%"
  IO.println s!"cache_break_rate={stats.cacheBreakRate * 100.0}%"
  IO.println s!"policy_block_rate={stats.policyBlockRate * 100.0}%"
  IO.println s!"p95_turn_latency_ms={stats.p95TurnLatencyMs}"
  let (warnThresh, incidentThresh) := defaultSloThresholds
  if stats.cacheHitRate * 100.0 < Float.ofNat incidentThresh then
    IO.println "status=incident cache_hit_rate_below_incident_threshold"
  else if stats.cacheHitRate * 100.0 < Float.ofNat warnThresh then
    IO.println "status=warn cache_hit_rate_below_warn_threshold"
  else
    IO.println "status=healthy"

private def runCacheStats (args : List String) : IO Unit := do
  let (dbPath, _) := parseDbPath args
  let store ← openCacheStore dbPath
  let stats ← cacheStats store
  printStats stats

private def runCacheMisses (args : List String) : IO Unit := do
  let (dbPath, rest) := parseDbPath args
  let recent := parseRecent rest
  let store ← openCacheStore dbPath
  let misses ← listRecentMisses store recent
  for miss in misses do
    IO.println s!"{miss.createdAtMs.toInt}\t{miss.sessionId.raw}\t{miss.traceId.raw}\t{miss.reason}"

private def runSessionFork (args : List String) : IO Unit := do
  let (dbPath, rest) := parseDbPath args
  let sessionId := (lookupFlagValue "--session" rest).getD "default"
  let reason := (lookupFlagValue "--reason" rest).getD "model_switch"
  let ts ← IO.monoMsNow
  let childId := s!"{sessionId}-fork-{ts}"
  let store ← openCacheStore dbPath
  let lineage ← forkSession store { raw := sessionId } { raw := childId } reason
  IO.println s!"forked parent={sessionId} child={childId} lineage={lineage.raw}"

private def runPortStatus (args : List String) : IO UInt32 := do
  match parseRuntime args with
  | .error err =>
    IO.eprintln err
    pure 2
  | .ok runtime =>
    let features := portingFeatures runtime
    let implemented := implementedCount features
    let total := features.length
    IO.println s!"runtime={runtime}"
    for feature in features do
      let status := if feature.inLawM1 then "implemented" else "pending"
      IO.println s!"[{status}] {feature.category}/{feature.name} - {feature.notes}"
    IO.println s!"coverage={coveragePercent features}% ({implemented}/{total})"
    pure 0

/-- CLI entry point for cache and session operations. -/
def run (argv : List String) : IO UInt32 := do
  match argv with
  | "cache" :: "stats" :: rest =>
    runCacheStats rest
    pure 0
  | "cache" :: "misses" :: rest =>
    runCacheMisses rest
    pure 0
  | "session" :: "fork" :: rest =>
    runSessionFork rest
    pure 0
  | "port" :: "status" :: rest =>
    runPortStatus rest
  | _ =>
    IO.eprintln usage
    pure 2

end Claw.Cli

def main (argv : List String) : IO UInt32 :=
  Claw.Cli.run argv
