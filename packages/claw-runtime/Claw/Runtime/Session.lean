import Claw.Provider.Engine

namespace Claw.Runtime
open Claw.Core
open Claw.Cache

/-- Runtime session model for gateway turns. -/
structure RuntimeSession where
  state : SessionState
  systemReminders : List String := []
  deriving Repr, Inhabited

/-- Create initial runtime session state for a model and session. -/
def mkInitialSession (sessionId : SessionId) (model : ModelId) : RuntimeSession :=
  let fp : PromptPrefixFingerprint := {
    model := model
    toolSchemaDigest := 0
    systemPromptDigest := 0
    projectContextDigest := 0
    staticPrefixDigest := 0
  }
  { state := { sessionId := sessionId, lineageId := { raw := s!"root/{sessionId.raw}" }, fingerprint := fp } }

/-- Cache-safe dynamic reminder insertion. -/
def addSystemReminder (session : RuntimeSession) (reminder : String) : RuntimeSession :=
  { session with systemReminders := session.systemReminders ++ [s!"<system-reminder>{reminder}</system-reminder>"] }

/-- Fork session lineage for model/tool transitions that must preserve parent prefix history. -/
def forkForReason
    (session : RuntimeSession)
    (childSession : SessionId)
    (reason : String) : RuntimeSession :=
  let child := {
    session.state with
    sessionId := childSession
    lineageId := LineageId.childFrom session.state.lineageId reason
  }
  { state := child, systemReminders := session.systemReminders }

end Claw.Runtime
