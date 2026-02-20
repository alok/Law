import Claw.Cache.Policy
import SQLite

namespace Claw.Cache
open Claw.Core

/-- Minimal cache index abstraction used across provider/runtime/gateway layers. -/
class PromptCacheIndexStore (m : Type → Type) where
  upsert : SessionId → PromptPrefixFingerprint → CacheMetrics → m Unit
  lookup : SessionId → m (Option PromptPrefixFingerprint)
  listRecentMisses : Nat → m (List CacheMissEvent)

/-- Concrete SQLite-backed cache store for M1. -/
structure SQLitePromptCacheStore where
  db : SQLite
  lineageRef : IO.Ref (Std.HashMap SessionId LineageId)

private def nowMs : IO Int64 :=
  return Int64.ofNat (← IO.monoMsNow)

private def ensureSchema (db : SQLite) : IO Unit := do
  let schema := String.intercalate "\n" [
    "CREATE TABLE IF NOT EXISTS prompt_prefix_index (",
    "  session_id TEXT PRIMARY KEY,",
    "  lineage_id TEXT NOT NULL,",
    "  model TEXT NOT NULL,",
    "  tool_schema_digest INTEGER NOT NULL,",
    "  system_prompt_digest INTEGER NOT NULL,",
    "  project_context_digest INTEGER NOT NULL,",
    "  static_prefix_digest INTEGER NOT NULL,",
    "  updated_at INTEGER NOT NULL",
    ");",
    "CREATE TABLE IF NOT EXISTS prompt_cache_events (",
    "  trace_id TEXT NOT NULL,",
    "  session_id TEXT NOT NULL,",
    "  event_kind TEXT NOT NULL,",
    "  reason TEXT NOT NULL,",
    "  prefix_digest INTEGER NOT NULL,",
    "  input_tokens INTEGER NOT NULL,",
    "  cache_read_tokens INTEGER NOT NULL,",
    "  cache_write_tokens INTEGER NOT NULL,",
    "  latency_ms INTEGER NOT NULL,",
    "  created_at INTEGER NOT NULL",
    ");",
    "CREATE TABLE IF NOT EXISTS cache_policy_violations (",
    "  session_id TEXT NOT NULL,",
    "  violation_kind TEXT NOT NULL,",
    "  details_json TEXT NOT NULL,",
    "  created_at INTEGER NOT NULL",
    ");",
    "CREATE INDEX IF NOT EXISTS idx_cache_events_created ON prompt_cache_events(created_at);",
    "CREATE INDEX IF NOT EXISTS idx_cache_events_kind ON prompt_cache_events(event_kind);"
  ]
  db.exec schema

/-- Opens a SQLite cache store and initializes schema on first use. -/
def openSQLitePromptCacheStore (path : System.FilePath) : IO SQLitePromptCacheStore := do
  match path.parent with
  | some parent =>
    if !parent.toString.isEmpty then
      IO.FS.createDirAll parent
  | none => pure ()
  let db ← SQLite.open path
  ensureSchema db
  let lineageRef ← IO.mkRef ({} : Std.HashMap SessionId LineageId)
  return { db, lineageRef }

/-- Session lineage override used to persist forks in the index table. -/
def setSessionLineage (store : SQLitePromptCacheStore) (sessionId : SessionId) (lineageId : LineageId) : IO Unit :=
  store.lineageRef.modify (fun m => m.insert sessionId lineageId)

private def getSessionLineage (store : SQLitePromptCacheStore) (sessionId : SessionId) : IO LineageId := do
  let m ← store.lineageRef.get
  return m.getD sessionId { raw := s!"root/{sessionId.raw}" }

def upsertFingerprint
    (store : SQLitePromptCacheStore)
    (sessionId : SessionId)
    (fingerprint : PromptPrefixFingerprint)
    (metrics : CacheMetrics) : IO Unit := do
  let lineage ← getSessionLineage store sessionId
  let updatedAt ← nowMs
  let stmt ← store.db.prepare "INSERT INTO prompt_prefix_index (session_id, lineage_id, model, tool_schema_digest, system_prompt_digest, project_context_digest, static_prefix_digest, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(session_id) DO UPDATE SET lineage_id = excluded.lineage_id, model = excluded.model, tool_schema_digest = excluded.tool_schema_digest, system_prompt_digest = excluded.system_prompt_digest, project_context_digest = excluded.project_context_digest, static_prefix_digest = excluded.static_prefix_digest, updated_at = excluded.updated_at"
  stmt.bindText 1 sessionId.raw
  stmt.bindText 2 lineage.raw
  stmt.bindText 3 fingerprint.model.raw
  stmt.bindInt64 4 fingerprint.toolSchemaDigest.toInt64
  stmt.bindInt64 5 fingerprint.systemPromptDigest.toInt64
  stmt.bindInt64 6 fingerprint.projectContextDigest.toInt64
  stmt.bindInt64 7 fingerprint.staticPrefixDigest.toInt64
  stmt.bindInt64 8 updatedAt
  stmt.exec
  if metrics != {} then
    pure ()

def lookupFingerprint (store : SQLitePromptCacheStore) (sessionId : SessionId) : IO (Option PromptPrefixFingerprint) := do
  let stmt ← store.db.prepare "SELECT model, tool_schema_digest, system_prompt_digest, project_context_digest, static_prefix_digest FROM prompt_prefix_index WHERE session_id = ? LIMIT 1"
  stmt.bindText 1 sessionId.raw
  if (← stmt.step) then
    return some {
      model := { raw := (← stmt.columnText 0) }
      toolSchemaDigest := (← stmt.columnInt64 1).toUInt64
      systemPromptDigest := (← stmt.columnInt64 2).toUInt64
      projectContextDigest := (← stmt.columnInt64 3).toUInt64
      staticPrefixDigest := (← stmt.columnInt64 4).toUInt64
    }
  return none

def listRecentMisses (store : SQLitePromptCacheStore) (recent : Nat) : IO (List CacheMissEvent) := do
  let stmt ← store.db.prepare "SELECT trace_id, session_id, reason, created_at FROM prompt_cache_events WHERE event_kind = 'miss' ORDER BY created_at DESC LIMIT ?"
  stmt.bindInt64 1 (Int64.ofNat recent)
  let mut rows : Array CacheMissEvent := #[]
  while (← stmt.step) do
    rows := rows.push {
      traceId := { raw := (← stmt.columnText 0) }
      sessionId := { raw := (← stmt.columnText 1) }
      reason := (← stmt.columnText 2)
      createdAtMs := (← stmt.columnInt64 3)
    }
  return rows.toList

abbrev SQLiteCacheM := ReaderT SQLitePromptCacheStore IO

instance : PromptCacheIndexStore SQLiteCacheM where
  upsert sessionId fingerprint metrics := do
    upsertFingerprint (← read) sessionId fingerprint metrics
  lookup sessionId := do
    lookupFingerprint (← read) sessionId
  listRecentMisses recent := do
    listRecentMisses (← read) recent

/-- Records a cache event row for observability and SLO computations. -/
def recordCacheEvent (store : SQLitePromptCacheStore) (event : CacheEvent) : IO Unit := do
  let stmt ← store.db.prepare "INSERT INTO prompt_cache_events (trace_id, session_id, event_kind, reason, prefix_digest, input_tokens, cache_read_tokens, cache_write_tokens, latency_ms, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  stmt.bindText 1 event.traceId.raw
  stmt.bindText 2 event.sessionId.raw
  stmt.bindText 3 (toString event.eventKind)
  stmt.bindText 4 event.reason
  stmt.bindInt64 5 event.prefixDigest.toInt64
  stmt.bindInt64 6 (Int64.ofNat event.metrics.inputTokens)
  stmt.bindInt64 7 (Int64.ofNat event.metrics.cacheReadTokens)
  stmt.bindInt64 8 (Int64.ofNat event.metrics.cacheWriteTokens)
  stmt.bindInt64 9 (Int64.ofNat event.metrics.latencyMs)
  stmt.bindInt64 10 event.createdAtMs
  stmt.exec

/-- Records a cache policy violation row. -/
def recordPolicyViolation (store : SQLitePromptCacheStore) (v : PolicyViolation) : IO Unit := do
  let stmt ← store.db.prepare
    "INSERT INTO cache_policy_violations (session_id, violation_kind, details_json, created_at) VALUES (?, ?, ?, ?)"
  stmt.bindText 1 v.sessionId.raw
  stmt.bindText 2 v.violationKind
  stmt.bindText 3 v.detailsJson
  stmt.bindInt64 4 v.createdAtMs
  stmt.exec

private def ratio (n d : Nat) : Float :=
  if d == 0 then 0.0 else Float.ofNat n / Float.ofNat d

private def loadLatencies (store : SQLitePromptCacheStore) : IO (Array Nat) := do
  let stmt ← store.db.prepare
    "SELECT latency_ms FROM prompt_cache_events ORDER BY latency_ms ASC"
  let mut rows : Array Nat := #[]
  while (← stmt.step) do
    rows := rows.push (Int.toNat (← stmt.columnInt64 0).toInt)
  return rows

/-- Computes aggregate cache statistics for CLI and monitoring. -/
def cacheStats (store : SQLitePromptCacheStore) : IO CacheStats := do
  let stmt ← store.db.prepare "SELECT COUNT(*), SUM(CASE WHEN event_kind = 'hit' THEN 1 ELSE 0 END), SUM(CASE WHEN event_kind = 'miss' THEN 1 ELSE 0 END), SUM(CASE WHEN event_kind = 'blocked' THEN 1 ELSE 0 END), SUM(CASE WHEN event_kind = 'forked' THEN 1 ELSE 0 END), SUM(CASE WHEN event_kind = 'compacted' THEN 1 ELSE 0 END) FROM prompt_cache_events"
  let mut total := 0
  let mut hits := 0
  let mut misses := 0
  let mut blocked := 0
  let mut forks := 0
  let mut compactions := 0
  if (← stmt.step) then
    total := Int.toNat (← stmt.columnInt64 0).toInt
    hits := Int.toNat (← stmt.columnInt64 1).toInt
    misses := Int.toNat (← stmt.columnInt64 2).toInt
    blocked := Int.toNat (← stmt.columnInt64 3).toInt
    forks := Int.toNat (← stmt.columnInt64 4).toInt
    compactions := Int.toNat (← stmt.columnInt64 5).toInt

  let latencies ← loadLatencies store
  let p95 :=
    if latencies.size = 0 then
      0
    else
      let idx := ((95 * (latencies.size - 1)) / 100)
      latencies[idx]!

  return {
    totalEvents := total
    hits := hits
    misses := misses
    blocked := blocked
    forks := forks
    compactions := compactions
    cacheHitRate := ratio hits total
    cacheBreakRate := ratio misses total
    policyBlockRate := ratio blocked total
    p95TurnLatencyMs := p95
  }

/-- Counts persisted policy violations. -/
def countPolicyViolations (store : SQLitePromptCacheStore) : IO Nat := do
  let stmt ← store.db.prepare "SELECT COUNT(*) FROM cache_policy_violations"
  if (← stmt.step) then
    return Int.toNat (← stmt.columnInt64 0).toInt
  return 0

/-- Creates a forked session lineage record in the cache index mapping. -/
def forkSession (store : SQLitePromptCacheStore)
    (parentSession : SessionId)
    (childSession : SessionId)
    (reason : String) : IO LineageId := do
  let parentLineage ← getSessionLineage store parentSession
  let childLineage := LineageId.childFrom parentLineage reason
  setSessionLineage store childSession childLineage
  return childLineage

/-- Reads cache hit/miss thresholds used for operational SLO checks. -/
def defaultSloThresholds : Nat × Nat := (70, 55)

/-- Helper that snapshots monotonic time for event timestamps. -/
def mkEventTime : IO Int64 := nowMs

end Claw.Cache
