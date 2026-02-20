namespace Claw.Channel.Discord.FFI

@[extern "claw_discord_start"]
opaque startRaw : UInt32 → UInt32

@[extern "claw_discord_send_count"]
opaque sendCountRaw : UInt64 → UInt32

@[extern "claw_discord_stop"]
opaque stopRaw : UInt32 → UInt32

end Claw.Channel.Discord.FFI
