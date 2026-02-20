import Claw.Core.Types
import Claw.Cache.Store
import Claw.Provider.Engine
import Claw.Runtime.Compaction
import Claw.Gateway.Service
import Claw.Memory.CacheStore
import Claw.Channel.Registry
import Claw.Channel.WebChat.Adapter
import Claw.Channel.Telegram.Adapter
import Claw.Channel.Slack.Adapter
import Claw.Channel.Discord.Adapter

namespace Law

/-- Workspace-level marker value for smoke imports. -/
def version : String := "0.1.0"

end Law
