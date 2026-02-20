import Claw.Daemon.Runner

namespace Claw.Daemon

def runMain (argv : List String) : IO UInt32 := do
  match parseArgs argv with
  | .error msg =>
    IO.eprintln msg
    pure 2
  | .ok cfg =>
    run cfg

end Claw.Daemon

def main (argv : List String) : IO UInt32 :=
  Claw.Daemon.runMain argv
