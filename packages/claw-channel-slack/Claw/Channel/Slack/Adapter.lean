import Claw.Channel.Adapter
import Claw.Channel.Slack.FFI

namespace Claw.Channel.Slack
open Claw.Channel

/-- Canonical adapter name for Slack. -/
def adapterName : String := "slack"

private def toHandle (raw : UInt32) : AdapterHandle :=
  { channel := adapterName, handleId := UInt64.ofNat raw.toNat }

private def toRawHandle (h : AdapterHandle) : UInt32 :=
  UInt32.ofNat h.handleId.toNat

/-- Slack adapter with a narrow FFI boundary. -/
def adapter : ChannelAdapter where
  name := adapterName
  capability := {
    canReceive := true
    canSend := true
    supportsThreads := true
    supportsAttachments := false
  }
  start := do
    let raw := FFI.startRaw 0
    if raw == 0 then
      return .error (.transport adapterName "start failed")
    return .ok (toHandle raw)
  stop := fun h =>
    if h.channel == adapterName then
      let _ := FFI.stopRaw (toRawHandle h)
      pure ()
    else
      pure ()
  send := fun h msg => do
    if h.channel != adapterName then
      return .error (.invalidHandle adapterName)
    let rc := FFI.sendCountRaw msg.text.length.toUInt64
    if rc == 0 then
      return .ok ()
    return .error (.transport adapterName s!"send failed rc={rc.toNat}")

end Claw.Channel.Slack
