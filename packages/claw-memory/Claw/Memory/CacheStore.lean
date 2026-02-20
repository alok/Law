import Claw.Cache.Store

namespace Claw.Memory
open Claw.Cache

abbrev CacheStore := SQLitePromptCacheStore

/-- Opens the persisted prompt cache SQLite store for this workspace. -/
def openCacheStore (path : System.FilePath := ".law/cache.db") : IO CacheStore :=
  openSQLitePromptCacheStore path

end Claw.Memory
