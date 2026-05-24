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
