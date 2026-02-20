import Claw.Channel.Adapter
import Std

namespace Claw.Channel

/-- In-memory adapter registry keyed by adapter name. -/
structure ChannelRegistry where
  adapters : Std.HashMap String ChannelAdapter

/-- Empty channel registry. -/
def ChannelRegistry.empty : ChannelRegistry :=
  { adapters := {} }

/-- Register or replace a named channel adapter. -/
def ChannelRegistry.register (reg : ChannelRegistry) (adapter : ChannelAdapter) : ChannelRegistry :=
  { adapters := reg.adapters.insert adapter.name adapter }

/-- Finds a channel adapter by name. -/
def ChannelRegistry.get? (reg : ChannelRegistry) (name : String) : Option ChannelAdapter :=
  reg.adapters.get? name

/-- List registered adapter names. -/
def ChannelRegistry.names (reg : ChannelRegistry) : List String :=
  reg.adapters.toList.map (fun (n, _) => n)

end Claw.Channel
