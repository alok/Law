namespace Claw.Channel.WebChat.FFI

@[extern "claw_webchat_start"]
opaque startRaw : UInt32 → UInt32

@[extern "claw_webchat_send_count"]
opaque sendCountRaw : UInt64 → UInt32

@[extern "claw_webchat_stop"]
opaque stopRaw : UInt32 → UInt32

end Claw.Channel.WebChat.FFI
