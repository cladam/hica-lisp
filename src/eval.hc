import "./types"
import "./ast"
import "./builtins"
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
  (v, env_set(env2, name, v))
}

// Extract symbol names from a parameter list — non-symbols are silently skipped
pub fun extract_params(params: list<LVal>) : list<string> =>
  flat_map(params, (p) => match p { LSym(name) => [name], _ => [] })

// Capture the current env as a closure
pub fun eval_lambda(params: list<LVal>, body: LVal, env: Env) : (LVal, Env) {
  let param_names = extract_params(params)
  (LFun(param_names, body, env), env)
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
pub fun bind_params(params: list<string>, args: list<LVal>, env: Env) : Env =>
  fold(zip(params, args), env, (e, pair) => match pair { (p, a) => env_set(e, p, a) })

// Apply a callable to evaluated arguments
pub fun apply(f: LVal, args: list<LVal>, env: Env) : (LVal, Env) =>
  match f {
    LFun(params, body, closure_env) => {
      let call_env    = bind_params(params, args, Env([], closure_env))
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