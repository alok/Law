import Claw.Channel.Types

namespace Claw.Daemon
open Claw.Core
open Claw.Channel

private def trim (s : String) : String :=
  s.trimAscii.toString

private def dropEndChars (s : String) (n : Nat) : String :=
  (s.dropEnd n).toString

/-- Removes a trailing line break, preserving all other text bytes. -/
def stripLineBreak (line : String) : String :=
  let noLf := if line.endsWith "\n" then dropEndChars line 1 else line
  if noLf.endsWith "\r" then dropEndChars noLf 1 else noLf

/--
Splits a line into exactly five TSV columns by scanning with `String.Pos`.
Only the first four tabs are separators; remaining tabs stay in the text field.
-/
def splitInboundColumns (line : String) : Array String :=
  let rec go
      (fuel : Nat)
      (pos start : line.Pos)
      (splits : Nat)
      (acc : Array String) : Array String :=
    match fuel with
    | 0 => acc.push (line.extract start line.endPos)
    | fuel + 1 =>
      if pos = line.endPos then
        acc.push (line.extract start line.endPos)
      else
        match pos.get?, pos.next? with
        | some ch, some nextPos =>
          if ch == '\t' && splits < 4 then
            go fuel nextPos nextPos (splits + 1) (acc.push (line.extract start pos))
          else
            go fuel nextPos start splits acc
        | _, _ =>
          acc.push (line.extract start line.endPos)
  go (line.length + 1) line.startPos line.startPos 0 #[]

/-- Parse one stdin line into an inbound message envelope. -/
def parseInboundLine (line : String) : Except String (Option InboundMessage) := do
  let cleaned := stripLineBreak line
  if (trim cleaned).isEmpty then
    return none
  let cols := splitInboundColumns cleaned
  if cols.size != 5 then
    throw s!"invalid inbound line; expected 5 TSV fields, got {cols.size}"
  let channel := cols[0]!
  let session := cols[1]!
  let sender := cols[2]!
  let trace := cols[3]!
  let text := cols[4]!
  if (trim channel).isEmpty then
    throw "invalid inbound line: channel is empty"
  if (trim session).isEmpty then
    throw "invalid inbound line: session_id is empty"
  if (trim sender).isEmpty then
    throw "invalid inbound line: sender is empty"
  if (trim trace).isEmpty then
    throw "invalid inbound line: trace_id is empty"
  return some {
    channel := trim channel
    sessionId := { raw := trim session }
    sender := sender
    text := text
    traceId := { raw := trim trace }
  }

end Claw.Daemon
