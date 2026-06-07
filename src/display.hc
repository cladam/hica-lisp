// display.hc — convert HiLisp values back to human-readable strings
import "./ast"
import "./types"

// Format a span prefix for error messages — used in the REPL where source is not available
pub fun span_prefix(span: Span) : string =>
  match span {
    Span(l, c) => "[" + show(l) + ":" + show(c) + "] ",
    NoSpan     => ""
  }

// Get the Nth line (1-based) from a pre-split list of lines
pub fun nth_line(lines: list<string>, n: int) : string =>
  match lines {
    []          => "",
    [h, ..rest] => if n == 1 { h } else { nth_line(rest, n - 1) }
  }

// Repeat a string n times (used to build caret padding)
pub fun str_repeat(s: string, n: int) : string =>
  if n <= 0 { "" } else { s + str_repeat(s, n - 1) }

// Render a Rust-style source snippet with a caret pointing at the error location.
//
//   --> path:3:5
//    |
//  3 | (+ foo 1)
//    |    ^
//
// Returns an empty string when no span is available.
pub fun render_snippet(source: string, path: string, span: Span) : string =>
  match span {
    NoSpan     => "",
    Span(l, c) => {
      let src_line = nth_line(split(source, "\n"), l)
      let ln_str   = show(l)
      let pad      = str_repeat(" ", str_length(ln_str) + 2)
      "  --> " + path + ":" + ln_str + ":" + show(c) + "\n" +
      pad + "|\n" +
      " " + ln_str + " | " + src_line + "\n" +
      pad + "| " + str_repeat(" ", c - 1) + "^"
    }
  }

// Convert any LVal to its printed representation (strings get quotes — Haskell-style show)
pub fun lval_show(v: LVal) : string =>
  match v {
    LNum(n)            => show(n),
    LSym(name, _)      => name,
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
