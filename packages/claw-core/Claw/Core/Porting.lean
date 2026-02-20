namespace Claw.Core

/-- Upstream runtime target for comparative porting status. -/
inductive UpstreamRuntime where
  | openclaw
  | zeroclaw
  deriving Repr, Inhabited, BEq, DecidableEq

instance : ToString UpstreamRuntime where
  toString
    | .openclaw => "openclaw"
    | .zeroclaw => "zeroclaw"

/-- One tracked capability from an upstream runtime and its Law coverage status. -/
structure PortingFeature where
  category : String
  name : String
  inLawM1 : Bool
  notes : String
  deriving Repr, Inhabited, BEq

/-- Static feature map for OpenClaw-style runtime capabilities. -/
def openclawFeatures : List PortingFeature := [
  { category := "runtime", name := "strict prompt-cache policy", inLawM1 := true, notes := "implemented in ProviderEngine + CachePolicy" },
  { category := "runtime", name := "provider failover", inLawM1 := true, notes := "ordered fallback with timeout/upstream handling" },
  { category := "runtime", name := "sqlite cache index/events", inLawM1 := true, notes := "prompt_prefix_index + event/violation tables" },
  { category := "runtime", name := "daemon entrypoint", inLawM1 := true, notes := "new clawd stdin-driven daemon" },
  { category := "runtime", name := "channel adapter registry", inLawM1 := true, notes := "webchat/telegram/slack/discord packages" },
  { category := "runtime", name := "cache benchmark harness", inLawM1 := true, notes := "claw_cache_bench executable in claw-e2e" },
  { category := "gateway", name := "auth/pairing and node topology", inLawM1 := false, notes := "not yet implemented" },
  { category := "media", name := "media pipeline + attachment storage", inLawM1 := false, notes := "not yet implemented" },
  { category := "ui", name := "desktop/mobile shells", inLawM1 := false, notes := "not yet implemented" },
  { category := "ops", name := "doctor/onboarding workflows", inLawM1 := false, notes := "not yet implemented" }
]

/-- Static feature map for ZeroClaw-style runtime capabilities. -/
def zeroclawFeatures : List PortingFeature := [
  { category := "core", name := "trait-like composable interfaces", inLawM1 := true, notes := "Lean structures/class boundaries by package" },
  { category := "core", name := "provider/channel modularity", inLawM1 := true, notes := "provider engine + channel adapter boundaries" },
  { category := "core", name := "policy-first runtime transitions", inLawM1 := true, notes := "strict SessionPolicy checks in cache layer" },
  { category := "bench", name := "agent/cache benchmark", inLawM1 := true, notes := "cache hit benchmark + e2e assertions" },
  { category := "daemon", name := "long-running daemon process", inLawM1 := true, notes := "clawd entrypoint with persistent sqlite store" },
  { category := "security", name := "approval/security surface", inLawM1 := false, notes := "not yet implemented" },
  { category := "tools", name := "tool execution sandbox", inLawM1 := false, notes := "not yet implemented" },
  { category := "hardware", name := "peripheral adapters", inLawM1 := false, notes := "not yet implemented" },
  { category := "channels", name := "full long-tail channel set", inLawM1 := false, notes := "currently 4 channels" },
  { category := "python", name := "python sdk integrations", inLawM1 := false, notes := "not yet implemented" }
]

/-- Returns tracked features for a target upstream runtime. -/
def portingFeatures : UpstreamRuntime → List PortingFeature
  | .openclaw => openclawFeatures
  | .zeroclaw => zeroclawFeatures

/-- Count implemented features in a feature set. -/
def implementedCount (features : List PortingFeature) : Nat :=
  features.foldl (fun acc feature => if feature.inLawM1 then acc + 1 else acc) 0

/-- Coverage percentage of implemented features for status reporting. -/
def coveragePercent (features : List PortingFeature) : Float :=
  let total := features.length
  if total == 0 then
    0.0
  else
    (Float.ofNat (implementedCount features) / Float.ofNat total) * 100.0

end Claw.Core
