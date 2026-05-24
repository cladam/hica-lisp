// display.hc — convert HiLisp values back to human-readable strings
import "./ast"
import "./types"

// Convert any LVal to its printed representation
pub fun lval_show(v: LVal) : string =>
  match v {
    LNum(n)            => show(n),
    LSym(name)         => name,
    LStr(s)            => "\"" + s + "\"",
    LBool(b)           => if b { "true" } else { "false" },
    LNil               => "nil",
    LList(items)       => "(" + join(map(items, lval_show), " ") + ")",
    LBuiltin(name)     => "#<builtin:" + name + ">",
    LFun(params, _, _) => "#<fn(" + join(params, " ") + ")>"
  }
