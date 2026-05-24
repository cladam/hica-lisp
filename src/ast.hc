

// LVal is the single recursive type that represents every value in HiLisp —
// numbers, symbols, strings, booleans, lists, functions, and nil
pub type LVal {
  LNum(n: int),
  LSym(name: string),
  LStr(s: string),
  LBool(b: bool),
  LList(items: list<LVal>),
  LFun(fname: string, params: list<string>, body: LVal, env: Env),
  LBuiltin(name: string),
  LNil
}

// Env and LVal are mutually recursive — LFun captures an Env, Env holds LVals
// Bindings are a Hica map (list<(string, LVal)>); parent chains implement lexical scope
pub type Env {
  Env(bindings: list<(string, LVal)>, parent: Env),
  EmptyEnv
}

// Everything is truthy except false and nil
pub fun is_truthy(v: LVal) : bool =>
  match v {
    LBool(b) => b,
    LNil     => false,
    _        => true
  }

test "truthy: non-false, non-nil values are truthy" {
  assert(is_truthy(LNum(1)))
  assert(is_truthy(LStr("hi")))
  assert(is_truthy(LBool(true)))
  assert(is_truthy(LList([])))
}

test "falsy: only false and nil" {
  assert_false(is_truthy(LBool(false)))
  assert_false(is_truthy(LNil))
}