namespace Claw.Channel.Slack.FFI

@[extern "claw_slack_start"]
opaque startRaw : UInt32 → UInt32

@[extern "claw_slack_send_count"]
opaque sendCountRaw : UInt64 → UInt32

@[extern "claw_slack_stop"]
opaque stopRaw : UInt32 → UInt32

end Claw.Channel.Slack.FFI
