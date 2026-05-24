// display.hc — convert HiLisp values back to human-readable strings
import "./ast"
import "./types"

// Render a list of values space-separated, for use inside (...)
fun show_items(items: list<LVal>) : string =>
  match items {
    []           => "",
    [x]          => lval_show(x),
    [x, ..rest]  => lval_show(x) + " " + show_items(rest)
  }

// Render a list of strings space-separated, used to show function params
fun show_params(params: list<string>) : string =>
  match params {
    []           => "",
    [p]          => p,
    [p, ..rest]  => p + " " + show_params(rest)
  }

// Convert any LVal to its printed representation
pub fun lval_show(v: LVal) : string =>
  match v {
    LNum(n)           => str(n),
    LSym(name)        => name,
    LStr(s)           => "\"" + s + "\"",
    LBool(b)          => if b { "true" } else { "false" },
    LNil              => "nil",
    LList(items)      => "(" + show_items(items) + ")",
    LBuiltin(name)    => "#<builtin:" + name + ">",
    LFun(params, _, _) => "#<fn(" + show_params(params) + ")>"
  }
