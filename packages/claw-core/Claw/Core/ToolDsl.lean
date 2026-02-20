import Claw.Core.Types
import Lean

namespace Claw.Core
open Lean

private def requireNonEmptyStrLit (label : String) (stx : Syntax) : MacroM Unit := do
  match stx.isStrLit? with
  | none =>
    Macro.throwErrorAt stx s!"{label} must be a string literal"
  | some value =>
    if value.isEmpty then
      Macro.throwErrorAt stx s!"{label} must not be empty"
    else
      pure ()

/--
Compile-time DSL for tool stubs.

Example:
`toolStub% "ReadFile" @ "v1" # 1101`
-/
syntax "toolStub% " str " @ " str " # " num : term

macro_rules
  | `(toolStub% $name:str @ $version:str # $schemaHash:num) => do
    requireNonEmptyStrLit "tool name" name
    requireNonEmptyStrLit "tool version" version
    `(({ name := $name, version := $version, schemaHash := UInt64.ofNat $schemaHash, deferredLoading := false } : Claw.Core.ToolDescriptor))

end Claw.Core
