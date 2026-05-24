// builtins.hc — the primitive layer of HiLisp
// Each builtin is a named function that operates on evaluated LVal arguments
import "./ast"
import "./types"
import "./display"

// Unwrap a numeric LVal to an int (0 on type mismatch)
fun lval_int(v: LVal) : int => match v { LNum(n) => n, _ => 0 }

// Arithmetic — + and * fold over all args; - and / are binary
fun builtin_add(args: list<LVal>) : LVal => LNum(fold(args, 0, (acc, v) => acc + lval_int(v)))
fun builtin_mul(args: list<LVal>) : LVal => LNum(fold(args, 1, (acc, v) => acc * lval_int(v)))

fun builtin_sub(args: list<LVal>) : LVal =>
  match args {
    []          => LNum(0),
    [x]         => LNum(0 - lval_int(x)),
    [x, ..rest] => LNum(fold(rest, lval_int(x), (acc, v) => acc - lval_int(v)))
  }

fun builtin_div(args: list<LVal>) : LVal =>
  match args {
    [x, y] => LNum(lval_int(x) / lval_int(y)),
    _      => LStr("error: / expects 2 args")
  }

// Comparison — numeric, 2 args; takes an operator lambda for reuse across <, >, <=, >=
fun builtin_cmp(args: list<LVal>, op: (int, int) -> bool) : LVal =>
  match args {
    [LNum(a), LNum(b)] => LBool(op(a, b)),
    _                  => LStr("error: comparison expects 2 numbers")
  }

// Equality — structural, works across types
fun builtin_eq(args: list<LVal>) : LVal =>
  match args {
    [LNum(a),  LNum(b)]  => LBool(a == b),
    [LBool(a), LBool(b)] => LBool(a == b),
    [LStr(a),  LStr(b)]  => LBool(a == b),
    [LNil,     LNil]     => LBool(true),
    [_, _]               => LBool(false),
    _                    => LStr("error: = expects 2 args")
  }

// Logic
fun builtin_not(args: list<LVal>) : LVal =>
  match args {
    [v] => if is_truthy(v) { LBool(false) } else { LBool(true) },
    _   => LStr("error: not expects 1 arg")
  }

fun builtin_and(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { b } else { LBool(false) },
    _      => LStr("error: and expects 2 args")
  }

fun builtin_or(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { a } else { b },
    _      => LStr("error: or expects 2 args")
  }

// List primitives — the classic Lisp trio plus length
fun builtin_car(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [h, ..] => h, [] => LNil },
    _              => LStr("error: car expects a list")
  }

fun builtin_cdr(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [_, ..rest] => LList(rest), [] => LList([]) },
    _              => LStr("error: cdr expects a list")
  }

fun builtin_cons(args: list<LVal>) : LVal =>
  match args {
    [v, LList(items)] => LList([v] + items),
    _                 => LStr("error: cons expects a value and a list")
  }

fun builtin_length(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => LNum(length(items)),
    _              => LStr("error: length expects a list")
  }

fun builtin_str(args: list<LVal>) : LVal =>
  match args {
    [v] => LStr(lval_show(v)),
    _   => LStr(join(map(args, lval_show), ""))
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
    "println" => { println(join(map(args, lval_show), " ")); (LNil, env) },
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
