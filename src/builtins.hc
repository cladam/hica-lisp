// builtins.hc — the primitive layer of HiLisp
// Each builtin is a named function that operates on evaluated LVal arguments
import "./ast"
import "./types"
import "./display"

// Unwrap a numeric LVal to an int (0 on type mismatch)
pub fun lval_int(v: LVal) : int => match v { LNum(n) => n, _ => 0 }

// Arithmetic — + and * fold over all args; - and / are binary
pub fun builtin_add(args: list<LVal>) : LVal => LNum(fold(args, 0, (acc, v) => acc + lval_int(v)))
pub fun builtin_mul(args: list<LVal>) : LVal => LNum(fold(args, 1, (acc, v) => acc * lval_int(v)))

pub fun builtin_sub(args: list<LVal>) : LVal =>
  match args {
    []          => LNum(0),
    [x]         => LNum(0 - lval_int(x)),
    [x, ..rest] => LNum(fold(rest, lval_int(x), (acc, v) => acc - lval_int(v)))
  }

pub fun builtin_div(args: list<LVal>) : LVal =>
  match args {
    [x, y] => LNum(lval_int(x) / lval_int(y)),
    _      => LStr("error: / expects 2 args")
  }

// Comparison — numeric, 2 args; takes an operator lambda for reuse across <, >, <=, >=
pub fun builtin_cmp(args: list<LVal>, op: (int, int) -> bool) : LVal =>
  match args {
    [LNum(a), LNum(b)] => LBool(op(a, b)),
    _                  => LStr("error: comparison expects 2 numbers")
  }

// Equality — structural, works across types
pub fun builtin_eq(args: list<LVal>) : LVal =>
  match args {
    [LNum(a),  LNum(b)]  => LBool(a == b),
    [LBool(a), LBool(b)] => LBool(a == b),
    [LStr(a),  LStr(b)]  => LBool(a == b),
    [LNil,     LNil]     => LBool(true),
    [_, _]               => LBool(false),
    _                    => LStr("error: = expects 2 args")
  }

// Logic
pub fun builtin_not(args: list<LVal>) : LVal =>
  match args {
    [v] => if is_truthy(v) { LBool(false) } else { LBool(true) },
    _   => LStr("error: not expects 1 arg")
  }

pub fun builtin_and(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { b } else { LBool(false) },
    _      => LStr("error: and expects 2 args")
  }

pub fun builtin_or(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { a } else { b },
    _      => LStr("error: or expects 2 args")
  }

// List primitives — the classic Lisp trio plus length
pub fun builtin_car(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [h, ..] => h, [] => LNil },
    _              => LStr("error: car expects a list")
  }

pub fun builtin_cdr(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [_, ..rest] => LList(rest), [] => LList([]) },
    _              => LStr("error: cdr expects a list")
  }

pub fun builtin_cons(args: list<LVal>) : LVal =>
  match args {
    [v, LList(items)] => LList([v] + items),
    _                 => LStr("error: cons expects a value and a list")
  }

pub fun builtin_length(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => LNum(length(items)),
    _              => LStr("error: length expects a list")
  }

// Local recursive helpers — avoids passing functions as higher-order values cross-file,
// which breaks Hica's div-effect propagation
pub fun show_all(args: list<LVal>) : string =>
  match args {
    []          => "",
    [v, ..rest] => lval_show(v) + show_all(rest)
  }

pub fun display_all(args: list<LVal>) : string =>
  match args {
    []          => "",
    [v, ..rest] => lval_display(v) + display_all(rest)
  }

pub fun builtin_str(args: list<LVal>) : LVal =>
  match args {
    [v] => LStr(lval_show(v)),
    _   => LStr(show_all(args))
  }

// println is side-effectful so needs a block body rather than an inline match arm
pub fun builtin_println(args: list<LVal>, env: Env) : (LVal, Env) {
  println(display_all(args))
  (LNil, env)
}

// Dispatch — maps a builtin name to its implementation
pub fun apply_builtin(name: string, args: list<LVal>, env: Env) : (LVal, Env) =>
  match name {
    "+"       => (builtin_add(args), env),
    "-"       => (builtin_sub(args), env),
    "*"       => (builtin_mul(args), env),
    "/"       => (builtin_div(args), env),
    "="       => (builtin_eq(args), env),
    "<"       => (builtin_cmp(args, (a, b) => a < b), env),
    ">"       => (builtin_cmp(args, (a, b) => a > b), env),
    "<="      => (builtin_cmp(args, (a, b) => a <= b), env),
    ">="      => (builtin_cmp(args, (a, b) => a >= b), env),
    "not"     => (builtin_not(args), env),
    "and"     => (builtin_and(args), env),
    "or"      => (builtin_or(args), env),
    "car"     => (builtin_car(args), env),
    "cdr"     => (builtin_cdr(args), env),
    "cons"    => (builtin_cons(args), env),
    "list"    => (LList(args), env),
    "length"  => (builtin_length(args), env),
    "str"     => (builtin_str(args), env),
    "println" => builtin_println(args, env),
    _         => (LStr("error: unknown builtin " + name), env)
  }

// Build the initial environment with all builtins pre-registered
pub fun make_env() : Env {
  let names = ["+", "-", "*", "/", "=", "<", ">", "<=", ">=",
               "not", "and", "or",
               "car", "cdr", "cons", "list", "length",
               "println", "str"]
  fold(names, EmptyEnv, (e, name) => env_set(e, name, LBuiltin(name)))
}

test "arithmetic" {
  assert_eq(lval_show(builtin_add([LNum(2), LNum(3)])), "5")
  assert_eq(lval_show(builtin_sub([LNum(10), LNum(3)])), "7")
  assert_eq(lval_show(builtin_sub([LNum(5)])), "-5")
  assert_eq(lval_show(builtin_mul([LNum(4), LNum(3)])), "12")
}

test "equality and comparison" {
  assert_eq(lval_show(builtin_eq([LNum(1), LNum(1)])), "true")
  assert_eq(lval_show(builtin_eq([LNum(1), LNum(2)])), "false")
  assert_eq(lval_show(builtin_eq([LStr("a"), LStr("a")])), "true")
  let cmp = builtin_cmp([LNum(3), LNum(5)], (a, b) => a < b)
  assert_eq(lval_show(cmp), "true")
}

test "list primitives" {
  let lst = LList([LNum(1), LNum(2), LNum(3)])
  assert_eq(lval_show(builtin_car([lst])), "1")
  assert_eq(lval_show(builtin_cdr([lst])), "(2 3)")
  assert_eq(lval_show(builtin_cons([LNum(0), lst])), "(0 1 2 3)")
}

test "make_env registers builtins" {
  let e        = make_env()
  let has_plus = match env_get(e, "+")   { LBuiltin(_) => true, _ => false }
  let has_car  = match env_get(e, "car") { LBuiltin(_) => true, _ => false }
  assert(has_plus)
  assert(has_car)
}
