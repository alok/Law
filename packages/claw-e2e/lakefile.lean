import Lake

open Lake DSL

package claw_e2e where
  version := v!"0.1.0"

require claw_core from "../claw-core"
require claw_cache from "../claw-cache"
require claw_provider from "../claw-provider"
require claw_runtime from "../claw-runtime"
require claw_gateway from "../claw-gateway"
require claw_memory from "../claw-memory"
require claw_channel from "../claw-channel"
require claw_channel_webchat from "../claw-channel-webchat"
require claw_channel_telegram from "../claw-channel-telegram"
require claw_channel_slack from "../claw-channel-slack"
require claw_channel_discord from "../claw-channel-discord"

@[default_target]
lean_lib ClawE2E where
  globs := #[.submodules `Claw.E2E]

@[default_target, test_driver]
lean_exe claw_e2e_tests where
  root := `Claw.E2E.Tests
