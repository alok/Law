namespace Claw.Channel.Telegram.FFI

@[extern "claw_telegram_start"]
opaque startRaw : UInt32 → UInt32

@[extern "claw_telegram_send_count"]
opaque sendCountRaw : UInt64 → UInt32

@[extern "claw_telegram_stop"]
opaque stopRaw : UInt32 → UInt32

end Claw.Channel.Telegram.FFI
