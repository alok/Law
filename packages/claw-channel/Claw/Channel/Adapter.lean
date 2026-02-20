import Claw.Channel.Types

namespace Claw.Channel

/-- Concrete adapter contract; each channel package provides one value of this shape. -/
structure ChannelAdapter where
  name : String
  capability : ChannelCapability
  start : IO (Except ChannelError AdapterHandle)
  stop : AdapterHandle → IO Unit
  send : AdapterHandle → OutboundMessage → IO (Except ChannelError Unit)

/-- Convenience send helper when caller only has plain text. -/
def sendText
    (adapter : ChannelAdapter)
    (handle : AdapterHandle)
    (recipient : String)
    (text : String)
    (traceId : String) : IO (Except ChannelError Unit) :=
  adapter.send handle {
    channel := adapter.name
    recipient := recipient
    text := text
    traceId := { raw := traceId }
  }

end Claw.Channel
