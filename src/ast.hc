

// Source location for error reporting — 1-based line and column numbers
pub type Span {
  Span(line: int, col: int),
  NoSpan
}

// A lexed token with its text and source position
pub type Token {
  Token(text: string, line: int, col: int)
}

// Field accessors for Token (dot notation only works for struct, not type)
pub fun tok_text(t: Token) : string => match t { Token(s, _, _) => s }
pub fun tok_line(t: Token) : int    => match t { Token(_, l, _) => l }
pub fun tok_col(t: Token) : int     => match t { Token(_, _, c) => c }

// LVal is the single recursive type that represents every value in HiLisp —
// numbers, symbols, strings, booleans, lists, hash-maps, functions, and nil.
// Hash-map entries are keyed by string; insertion order is preserved by the
// alist backing store.
pub type LVal {
  LNum(n: int),
  LSym(name: string, span: Span),
  LStr(s: string),
  LBool(b: bool),
  LList(items: list<LVal>),
  LHash(entries: list<(string, LVal)>),
  LFun(fname: string, params: list<string>, body: LVal, env: Env),
  LBuiltin(name: string),
  LRecur(args: list<LVal>),
  LError(id: string, msg: string, note: string, span: Span),
  LNil
}

// Convenience constructors
pub fun lsym(name: string) : LVal => LSym(name, NoSpan)
pub fun lhash(entries: list<(string, LVal)>) : LVal => LHash(entries)
pub fun lerror_full(id: string, msg: string, note: string, span: Span) : LVal => LError(id, msg, note, span)
pub fun lerror_at(id: string, msg: string, span: Span) : LVal => LError(id, msg, "", span)
pub fun lerror(id: string, msg: string) : LVal => LError(id, msg, "", NoSpan)

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