// display.hc — convert HiLisp values back to human-readable strings
import "./ast"
import "./types"

// Format a span prefix for error messages — empty string when no location is known
pub fun span_prefix(span: Span) : string =>
  match span {
    Span(l, c) => "[" + show(l) + ":" + show(c) + "] ",
    NoSpan     => ""
  }

// Convert any LVal to its printed representation (strings get quotes — Haskell-style show)
pub fun lval_show(v: LVal) : string =>
  match v {
    LNum(n)            => show(n),
    LSym(name)         => name,
    LStr(s)            => "\"" + s + "\"",
    LBool(b)           => if b { "true" } else { "false" },
    LNil               => "nil",
    LList(items)       => "(" + join(map(items, lval_show), " ") + ")",
    LBuiltin(name)     => "#<builtin:" + name + ">",
    LFun(fname, params, _, _) => if fname == "" { "#<fn(" + join(params, " ") + ")>" } else { "#<fn:" + fname + "(" + join(params, " ") + ")>" },
    LRecur(_)          => "#<recur>",
    LError(msg, span)        => span_prefix(span) + "Error: " + msg
  }

// Display a value for human output — strings printed without surrounding quotes
pub fun lval_display(v: LVal) : string =>
  match v {
    LStr(s) => s,
    _       => lval_show(v)
  }

test "show primitives" {
  assert_eq(lval_show(LNum(42)), "42")
  assert_eq(lval_show(LNil), "nil")
  assert_eq(lval_show(LBool(true)), "true")
  assert_eq(lval_show(LBool(false)), "false")
}

test "show string includes quotes" {
  assert_eq(lval_show(LStr("hello")), "\"hello\"")
}

test "show list" {
  assert_eq(lval_show(LList([LNum(1), LNum(2), LNum(3)])), "(1 2 3)")
  assert_eq(lval_show(LList([])), "()")
}
