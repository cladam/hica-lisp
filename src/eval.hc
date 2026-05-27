import "./types"
import "./ast"
import "./builtins"
import "./display"
import "./parser"
import "./tokeniser"

pub fun eval(expr: LVal, env: Env) : (LVal, Env) => match expr {
  LNum(n)      => (LNum(n), env),
  LStr(s)      => (LStr(s), env),
  LBool(b)     => (LBool(b), env),
  LNil         => (LNil, env),
  LSym(name)   => (env_get(env, name), env),
  LList(items) => eval_list(items, env),
  _            => (LNil, env)
}

pub fun eval_list(items: list<LVal>, env: Env) : (LVal, Env) =>
  match items {
    // quote
    [LSym("quote"), arg] => (arg, env),

    // if
    [LSym("if"), cond_expr, then_expr, else_expr] =>
      eval_if(cond_expr, then_expr, else_expr, env),

    // cond  (Carp-inspired: alternating predicate/expr pairs, optional fallback)
    [LSym("cond"), ..clauses] => eval_cond(clauses, env),

    // do — sequence, return last value (Carp: do expr1 expr2 ...)
    [LSym("do"), ..exprs] => eval_do(exprs, env),

    // def
    [LSym("def"), LSym(name), val_expr] => eval_def(name, val_expr, env),

    // defn — sugar for (def name (fn [params] body))
    [LSym("defn"), LSym(name), LList(params), body] =>
      eval_def(name, LList([LSym("fn"), LList(params), body]), env),

    // fn (Carp: fn [args] body)
    [LSym("fn"), LList(params), body] =>
      eval_lambda(params, body, env),

    // let (Carp: let [x 1 y 2] body — vector of alternating name/val pairs)
    [LSym("let"), LList(bindings), body] =>
      eval_let(bindings, body, env),

    // use — pull names from an env-namespace into scope
    [LSym("use"), LSym(mod_name)] => eval_use(mod_name, env),

    // function call
    [func, ..args] => eval_call(func, args, env),
    _ => (LNil, env)
  }

pub fun eval_cond(clauses: list<LVal>, env: Env) : (LVal, Env) =>
  match clauses {
    [] => (LNil, env),
    // Two-element pair: (pred) (expr)
    [pred_expr, then_expr, ..rest] => {
      let (pred_val, env2) = eval(pred_expr, env)
      if is_truthy(pred_val) {
        eval(then_expr, env2)
      } else {
        eval_cond(rest, env2)
      }
    },
    // Single fallback expression
    [fallback] => eval(fallback, env)
  }

pub fun eval_do(exprs: list<LVal>, env: Env) : (LVal, Env) =>
  match exprs {
    []       => (LNil, env),
    [e]      => eval(e, env),
    [e, ..rest] => {
      let (_, env2) = eval(e, env)
      eval_do(rest, env2)
    }
  }

// (let [x 1 y 2] body) — bindings is [LSym("x"), LNum(1), LSym("y"), LNum(2)]
pub fun eval_let(bindings: list<LVal>, body: LVal, env: Env) : (LVal, Env) =>
  match bindings {
    [] => eval(body, env),
    [LSym(name), val_expr, ..rest] => {
      let (v, env2) = eval(val_expr, env)
      let env3 = env_set(env2, name, v)
      eval_let(rest, body, env3)
    },
    _ => (LNil, env)  // malformed let — skip
  }

pub fun eval_if(cond_expr: LVal, then_expr: LVal, else_expr: LVal, env: Env) : (LVal, Env) {
  let (cond_val, env2) = eval(cond_expr, env)
  if is_truthy(cond_val) {
    eval(then_expr, env2)
  } else {
    eval(else_expr, env2)
  }
}

// Bind a name in the current env and return the value
pub fun eval_def(name: string, val_expr: LVal, env: Env) : (LVal, Env) {
  let (v, env2) = eval(val_expr, env)
  // If defining a function, brand it with its name so apply can inject self-reference
  let v2 = match v {
    LFun(_, params, body, closure) => LFun(name, params, body, closure),
    _ => v
  }
  (v2, env_set(env2, name, v2))
}

// Extract symbol names from a parameter list — non-symbols are silently skipped
pub fun extract_params(params: list<LVal>) : list<string> =>
  match params {
    [] => [],
    [LSym(name), ..rest] => [name] + extract_params(rest),
    [_, ..rest] => extract_params(rest)
  }

// Capture the current env as a closure
pub fun eval_lambda(params: list<LVal>, body: LVal, env: Env) : (LVal, Env) {
  let param_names = extract_params(params)
  (LFun("", param_names, body, env), env)
}

// Evaluate each argument left-to-right, threading env through
pub fun eval_args(args: list<LVal>, env: Env) : (list<LVal>, Env) =>
  match args {
    []          => ([], env),
    [a, ..rest] => {
      let (v, env2)   = eval(a, env)
      let (vs, env3)  = eval_args(rest, env2)
      ([v] + vs, env3)
    }
  }

// Bind params to evaluated args — zip pairs them up, fold threads them into the env
pub fun bind_one(e: Env, pair: (string, LVal)) : Env =>
  match pair { (p, a) => env_set(e, p, a) }

pub fun bind_params(params: list<string>, args: list<LVal>, env: Env) : Env =>
  fold(zip(params, args), env, bind_one)

// Apply a callable to evaluated arguments
pub fun apply(f: LVal, args: list<LVal>, env: Env) : (LVal, Env) =>
  match f {
    LFun(fname, params, body, closure_env) => {
      // Inject self-reference so named functions can call themselves recursively
      let base_env    = if fname == "" { closure_env } else { env_set(closure_env, fname, f) }
      let call_env    = bind_params(params, args, Env([], base_env))
      let (result, _) = eval(body, call_env)
      (result, env)  // discard inner scope, return calling env
    },
    LBuiltin(name) => apply_builtin(name, args, env),
    _              => (LStr("error: not a function"), env)
  }

pub fun eval_call(func: LVal, args: list<LVal>, env: Env) : (LVal, Env) {
  let (f, env2)       = eval(func, env)
  let (arg_vals, env3) = eval_args(args, env2)
  apply(f, arg_vals, env3)
}

// use is stubbed until we have a module registry
pub fun eval_use(mod_name: string, env: Env) : (LVal, Env) => (LNil, env)

test "eval self-evaluating forms" {
  let env = make_env()
  let (n, _) = eval(LNum(42), env)
  let (s, _) = eval(LStr("hi"), env)
  assert_eq(lval_show(n), "42")
  assert_eq(lval_show(s), "\"hi\"")
}

test "eval arithmetic via builtins" {
  let env = make_env()
  let (r, _) = eval(LList([LSym("+"), LNum(2), LNum(3)]), env)
  assert_eq(lval_show(r), "5")
}

test "eval if branches" {
  let env = make_env()
  let (r1, _) = eval(LList([LSym("if"), LBool(true),  LNum(1), LNum(2)]), env)
  let (r2, _) = eval(LList([LSym("if"), LBool(false), LNum(1), LNum(2)]), env)
  assert_eq(lval_show(r1), "1")
  assert_eq(lval_show(r2), "2")
}

test "eval null? and empty? builtins" {
  let env = make_env()
  let (r1, _) = eval(LList([LSym("null?"), LSym("nil")]), env)
  let (r2, _) = eval(LList([LSym("empty?"), LList([LSym("list")])]), env)
  let (r3, _) = eval(LList([LSym("empty?"), LStr("")]), env)
  assert_eq(lval_show(r1), "true")
  assert_eq(lval_show(r2), "true")
  assert_eq(lval_show(r3), "true")
}

test "eval def and symbol lookup" {
  let env = make_env()
  let (_, env2) = eval(LList([LSym("def"), LSym("x"), LNum(10)]), env)
  let (r, _)    = eval(LSym("x"), env2)
  assert_eq(lval_show(r), "10")
}

test "eval lambda definition and call" {
  let env = make_env()
  let fn_expr  = LList([LSym("fn"), LList([LSym("x")]), LList([LSym("*"), LSym("x"), LNum(2)])])
  let (_, env2) = eval(LList([LSym("def"), LSym("double"), fn_expr]), env)
  let (r, _)    = eval(LList([LSym("double"), LNum(5)]), env2)
  assert_eq(lval_show(r), "10")
}

test "eval recursive defn" {
  // factorial: (defn fact (n) (if (<= n 1) 1 (* n (fact (- n 1)))))
  let env0 = make_env()
  let body = LList([LSym("if"),
    LList([LSym("<="), LSym("n"), LNum(1)]),
    LNum(1),
    LList([LSym("*"), LSym("n"), LList([LSym("fact"), LList([LSym("-"), LSym("n"), LNum(1)])])])])
  let defn_expr = LList([LSym("defn"), LSym("fact"), LList([LSym("n")]), body])
  let (_, env1) = eval(defn_expr, env0)
  let (r5, _)   = eval(LList([LSym("fact"), LNum(5)]), env1)
  let (r1, _)   = eval(LList([LSym("fact"), LNum(1)]), env1)
  assert_eq(lval_show(r5), "120")
  assert_eq(lval_show(r1), "1")
}