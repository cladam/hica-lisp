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
  // Symbol resolution:
  //   1. explicit binding in scope wins,
  //   2. names of the shape `host/…` resolve to the registered host
  //      dispatch callback (as an LBuiltin sentinel so `(host/set …)`
  //      still goes through eval_call → apply_builtin → apply_host_dispatch),
  //   3. otherwise it's an undefined-symbol error.
  LSym(name, span) => match env_has(env, name) {
    true  => (env_get(env, name), env),
    false =>
      if starts_with(name, "host/") { (LBuiltin(name), env) }
      else { (lerror_at("eval/undefined-symbol", "'" + name + "' is not defined", span), env) }
  },
  LList(items) => eval_list(items, env),
  _            => (LNil, env)
}

pub fun eval_list(items: list<LVal>, env: Env) : (LVal, Env) =>
  match items {
    // quote
    [LSym("quote", _), arg] => (arg, env),

    // if
    [LSym("if", _), cond_expr, then_expr, else_expr] =>
      eval_if(cond_expr, then_expr, else_expr, env),

    // cond  (Carp-inspired: alternating predicate/expr pairs, optional fallback)
    [LSym("cond", _), ..clauses] => eval_cond(clauses, env),

    // do — sequence, return last value (Carp: do expr1 expr2 ...)
    [LSym("do", _), ..exprs] => eval_do(exprs, env),

    // def
    [LSym("def", _), LSym(name, _), val_expr] => eval_def(name, val_expr, env),

    // defn — sugar for (def name (fn [params] body))
    [LSym("defn", _), LSym(name, _), LList(params), body] =>
      eval_def(name, LList([lsym("fn"), LList(params), body]), env),

    // fn (Carp: fn [args] body)
    [LSym("fn", _), LList(params), body] =>
      eval_lambda(params, body, env),

    // let (Carp: let [x 1 y 2] body — vector of alternating name/val pairs)
    [LSym("let", _), LList(bindings), body] =>
      eval_let(bindings, body, env),

    // use — pull names from an env-namespace into scope
    [LSym("use", _), LSym(mod_name, _)] => eval_use(mod_name, env),

    // eval — parse and evaluate a string as HiLisp code in the current env
    [LSym("eval", _), src_expr] => eval_eval(src_expr, env),

    // recur — package new binding values for the enclosing loop
    [LSym("recur", _), ..args] => eval_recur(args, env),

    // loop — Jank-inspired tail-recursive iteration without stack growth
    // Only fires as a special form when the user has not defined a function named loop;
    // otherwise (e.g. fizzbuzz defines its own loop), defer to the function call path.
    [LSym("loop", _), LList(bindings), body] => eval_loop_or_call(bindings, body, env),

    // function call — when the head is a symbol, capture its source span so any
    // runtime error (arity/type/etc) surfaces with the calling form's location
    // rather than pointing at nothing.
    [LSym(name, span), ..args] =>
      eval_call_with_span(LSym(name, span), args, span, env),
    [func, ..args] => eval_call(func, args, env),
    _ => (LNil, env)
  }

// If the user has bound a function named "loop" in scope, call it.
// Otherwise treat (loop [bindings] body) as the tail-recursion special form.
pub fun eval_loop_or_call(bindings: list<LVal>, body: LVal, env: Env) : (LVal, Env) =>
  match env_get(env, "loop") {
    LFun(_, _, _, _) => eval_call(lsym("loop"), [LList(bindings), body], env),
    _                => eval_loop(bindings, body, env)
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
    [LSym(name, _), val_expr, ..rest] => {
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
    [LSym(name, _), ..rest] => [name] + extract_params(rest),
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

// Return the first LError found in an argument list, or LNil if none
pub fun first_error(args: list<LVal>) : LVal =>
  match args {
    []                          => LNil,
    [LError(i, m, n, s), ..]   => LError(i, m, n, s),
    [_, ..rest]                 => first_error(rest)
  }

// Detect whether a function body ultimately routes to a `host/…`
// builtin. Used by `apply` to decide whether to propagate env
// mutations from an LFun call — normally we discard the callee's env
// (proper Lisp scope), but when the callee's whole purpose is to
// dispatch to the embedder's host we need those mutations to reach
// the caller so `(def foo (fn (…) (host/set …)))` wrappers work.
//
// We only look at the *shape* of the body, not evaluate it, so this
// stays total and cheap. Only three shapes matter:
//
//   1. `(host/whatever …)`            — direct dispatch
//   2. `(some-fn (host/whatever …))`  — dispatch nested in a call
//   3. everything else                — standard scope semantics
//
// Case (1) is what `hedit`'s preamble emits (`(def set (fn (k v)
// (host/set k v)))`). Case (2) covers convenience wrappers like
// `(fn (k v) (println (host/set k v)))` should any host add them.
pub fun body_touches_host(body: LVal) : bool =>
  match body {
    LList([LSym(name, _), .._]) => starts_with(name, "host/") || contains_host_call([body]),
    LList(items)                => contains_host_call(items),
    _                           => false
  }

pub fun contains_host_call(items: list<LVal>) : bool =>
  match items {
    [] => false,
    [x, ..rest] =>
      match x {
        LList([LSym(name, _), .._]) =>
          if starts_with(name, "host/") { true } else { contains_host_call(rest) },
        _ => contains_host_call(rest)
      }
  }

// Copy every `__`-prefixed binding from `donor`'s topmost frame into
// `receiver`. The `__` prefix is the convention embedders use for
// host-visible state (see hedit's `__hedit_bindings` /
// `__hedit_values`). Bindings *without* the prefix — the callee's
// user-visible `def`s and lambda params — stay inside the callee's
// scope, preserving normal Lisp semantics.
//
// We deliberately look at *only* the topmost frame. `env_set` on the
// callee (see `types.hc::env_set`) always mutates the current scope,
// so a `host/…` callback's writes land there. Walking deeper into the
// chain would re-visit the caller's *original* pre-call snapshot of
// those same keys and overwrite our fresh values with the stale ones
// (parent envs live *after* the caller's mutations in insertion
// order).
pub fun merge_host_bindings(receiver: Env, donor: Env) : Env =>
  match donor {
    EmptyEnv                 => receiver,
    Env(bindings, _, _) => copy_host_pairs(receiver, bindings)
  }

pub fun copy_host_pairs(receiver: Env, pairs: list<(string, LVal)>) : Env =>
  match pairs {
    [] => receiver,
    [(k, v), ..rest] =>
      if starts_with(k, "__") { copy_host_pairs(env_set(receiver, k, v), rest) }
      else { copy_host_pairs(receiver, rest) }
  }

// Apply a callable to evaluated arguments, propagating any error values.
//
// LFun calls normally discard the callee's env (standard Lisp: `def`
// inside a function body doesn't leak into the caller). We make one
// carve-out: if the function body ultimately dispatches to a `host/…`
// builtin, we salvage the host-visible mutations from the callee's
// env and layer them onto the caller's env via `merge_host_bindings`.
// That way host dispatches routed through a plain-Lisp wrapper
// (`(def set (fn (k v) (host/set k v)))`) persist their state without
// leaking the callee's local `def`s / lambda params into the caller.
// Without this carve-out, embedders can only mutate host state from
// bare `(host/xxx …)` calls, which forces every user file to spell out
// the ugly `host/` prefix.
pub fun apply(f: LVal, args: list<LVal>, env: Env) : (LVal, Env) {
  let err     = first_error(args)
  let has_err = match err { LError(_, _, _, _) => true, _ => false }
  if has_err {
    (err, env)
  } else {
    match f {
      LFun(fname, params, body, closure_env) => {
        // Inject self-reference so named functions can call themselves recursively
        let base_env       = if fname == "" { closure_env } else { env_set(closure_env, fname, f) }
        let call_env       = bind_params(params, args, Env([], NoHostFn, base_env))
        // Pre-merge: pull the caller's latest `__`-prefixed host state
        // into the callee's topmost frame *before* eval. Closures snapshot
        // their defining env, so without this a wrapper like
        // `(def set (fn (k v) (host/set k v)))` would see stale host
        // state on the second and later calls — the first `(set …)`
        // mutation lives in the caller's env, but the closure_env still
        // holds the pre-call snapshot. Symmetric with the outbound merge
        // below; together they make host state behave as if shared
        // across the boundary while user-visible bindings stay scoped.
        let call_env2      =
          if body_touches_host(body) { merge_host_bindings(call_env, env) }
          else { call_env }
        let (result, inner_env) = eval(body, call_env2)
        // Merge host-visible mutations back into the caller's env
        // when the body dispatched through a `host/…` builtin; otherwise
        // preserve normal Lisp scope semantics by returning `env` intact.
        let out_env =
          if body_touches_host(body) { merge_host_bindings(env, inner_env) }
          else { env }
        (result, out_env)
      },
      LBuiltin(name) => apply_builtin(name, args, env),
      _              => (lerror("eval/not-a-function", "not a function"), env)
    }
  }
}

pub fun eval_call(func: LVal, args: list<LVal>, env: Env) : (LVal, Env) {
  let (f, env2) = eval(func, env)
  // Short-circuit: if function lookup itself produced an error, skip arg eval
  let is_err = match f { LError(_, _, _, _) => true, _ => false }
  if is_err {
    (f, env2)
  } else {
    let (arg_vals, env3) = eval_args(args, env2)
    apply(f, arg_vals, env3)
  }
}

// Same as eval_call, but attaches `span` to any span-less LError coming out of
// the callee — so `(hash-get)` with wrong arity points at the source `(hash-get …)`.
pub fun eval_call_with_span(func: LVal, args: list<LVal>, span: Span, env: Env) : (LVal, Env) {
  let (result, env2) = eval_call(func, args, env)
  (with_span(result, span), env2)
}

// use is stubbed until we have a module registry
pub fun eval_use(mod_name: string, env: Env) : (LVal, Env) => (LNil, env)

// (eval src) — evaluate src (a string) as HiLisp code in the current env
pub fun eval_eval(src_expr: LVal, env: Env) : (LVal, Env) {
  let (src_val, env2) = eval(src_expr, env)
  match src_val {
    LStr(src) => {
      let tokens = tokenise(src)
      let (expr, _) = parse_tokens(tokens)
      eval(expr, env2)
    },
    _ => (lerror("eval/type-error", "eval expects a string"), env2)
  }
}

// Extract the binding names from a loop binding vector [name val name val ...]
pub fun extract_loop_names(bindings: list<LVal>) : list<string> =>
  match bindings {
    []                          => [],
    [LSym(name, _), _, ..rest]  => [name] + extract_loop_names(rest),
    [_, _, ..rest]              => extract_loop_names(rest)
  }

// Evaluate the initial values from a loop binding vector (skip the names)
pub fun eval_loop_init(bindings: list<LVal>, env: Env) : (list<LVal>, Env) =>
  match bindings {
    []                    => ([], env),
    [_, val_expr, ..rest] => {
      let (v, env2)   = eval(val_expr, env)
      let (vs, env3)  = eval_loop_init(rest, env2)
      ([v] + vs, env3)
    },
    _ => ([], env)
  }

// Run body repeatedly; restart with new bindings whenever (recur ...) is returned
pub fun run_loop(names: list<string>, body: LVal, loop_env: Env, outer_env: Env) : (LVal, Env) {
  let (result, _) = eval(body, loop_env)
  match result {
    LRecur(new_args) => {
      let new_env = bind_params(names, new_args, Env([], NoHostFn, outer_env))
      run_loop(names, body, new_env, outer_env)
    },
    _ => (result, outer_env)
  }
}

// (loop [x init ...] body) — establish bindings, iterate via (recur new-x ...)
pub fun eval_loop(bindings: list<LVal>, body: LVal, env: Env) : (LVal, Env) {
  let names          = extract_loop_names(bindings)
  let (init_vals, env2) = eval_loop_init(bindings, env)
  let loop_env       = bind_params(names, init_vals, Env([], NoHostFn, env2))
  run_loop(names, body, loop_env, env2)
}

// (recur arg ...) — evaluate args and wrap in LRecur for run_loop to catch
pub fun eval_recur(arg_exprs: list<LVal>, env: Env) : (LVal, Env) {
  let (arg_vals, env2) = eval_args(arg_exprs, env)
  (LRecur(arg_vals), env2)
}

test "loop/recur: sum 1 to 10" {
  let env = make_env()
  let (r, _) = eval(LList([lsym("eval"), LStr("(loop [i 1 acc 0] (if (> i 10) acc (recur (+ i 1) (+ acc i)))))")]), env)
  assert_eq(lval_show(r), "55")
}

test "loop/recur: countdown to done" {
  let env = make_env()
  let (r, _) = eval(LList([lsym("eval"), LStr("(loop [n 3] (if (= n 0) \"done\" (recur (- n 1))))")]), env)
  assert_eq(lval_show(r), "\"done\"")
}

test "eval string as code" {
  let env = make_env()
  let (r, _) = eval(LList([lsym("eval"), LStr("(+ 1 2)")]), env)
  assert_eq(lval_show(r), "3")
}

test "eval string defines binding" {
  let env = make_env()
  let (_, env2) = eval(LList([lsym("eval"), LStr("(def x 42)")]), env)
  let (r, _)    = eval(lsym("x"), env2)
  assert_eq(lval_show(r), "42")
}

test "eval self-evaluating forms" {
  let env = make_env()
  let (n, _) = eval(LNum(42), env)
  let (s, _) = eval(LStr("hi"), env)
  assert_eq(lval_show(n), "42")
  assert_eq(lval_show(s), "\"hi\"")
}

test "eval arithmetic via builtins" {
  let env = make_env()
  let (r, _) = eval(LList([lsym("+"), LNum(2), LNum(3)]), env)
  assert_eq(lval_show(r), "5")
}

test "eval if branches" {
  let env = make_env()
  let (r1, _) = eval(LList([lsym("if"), LBool(true),  LNum(1), LNum(2)]), env)
  let (r2, _) = eval(LList([lsym("if"), LBool(false), LNum(1), LNum(2)]), env)
  assert_eq(lval_show(r1), "1")
  assert_eq(lval_show(r2), "2")
}

test "eval null? and empty? builtins" {
  let env = make_env()
  let (r1, _) = eval(LList([lsym("null?"), lsym("nil")]), env)
  let (r2, _) = eval(LList([lsym("empty?"), LList([lsym("list")])]), env)
  let (r3, _) = eval(LList([lsym("empty?"), LStr("")]), env)
  assert_eq(lval_show(r1), "true")
  assert_eq(lval_show(r2), "true")
  assert_eq(lval_show(r3), "true")
}

test "eval def and symbol lookup" {
  let env = make_env()
  let (_, env2) = eval(LList([lsym("def"), lsym("x"), LNum(10)]), env)
  let (r, _)    = eval(lsym("x"), env2)
  assert_eq(lval_show(r), "10")
}

test "eval lambda definition and call" {
  let env = make_env()
  let fn_expr  = LList([lsym("fn"), LList([lsym("x")]), LList([lsym("*"), lsym("x"), LNum(2)])])
  let (_, env2) = eval(LList([lsym("def"), lsym("double"), fn_expr]), env)
  let (r, _)    = eval(LList([lsym("double"), LNum(5)]), env2)
  assert_eq(lval_show(r), "10")
}

test "eval recursive defn" {
  // factorial: (defn fact (n) (if (<= n 1) 1 (* n (fact (- n 1)))))
  let env0 = make_env()
  let body = LList([lsym("if"),
    LList([lsym("<="), lsym("n"), LNum(1)]),
    LNum(1),
    LList([lsym("*"), lsym("n"), LList([lsym("fact"), LList([lsym("-"), lsym("n"), LNum(1)])])])])
  let defn_expr = LList([lsym("defn"), lsym("fact"), LList([lsym("n")]), body])
  let (_, env1) = eval(defn_expr, env0)
  let (r5, _)   = eval(LList([lsym("fact"), LNum(5)]), env1)
  let (r1, _)   = eval(LList([lsym("fact"), LNum(1)]), env1)
  assert_eq(lval_show(r5), "120")
  assert_eq(lval_show(r1), "1")
}

// Regression test for the "second host call sees stale state" bug that
// hedit's M4 hit. Simulates a hedit-like `bind` handler that stores the
// key→cmd pair into `__hedit_bindings` (a hash-map) on the env. We wrap
// `host/bind` in a plain-Lisp lambda (as hedit's preamble does), then
// call it twice through that wrapper. Before the pre-merge fix, the
// second call's closure_env still held the pre-first-call snapshot of
// `__hedit_bindings`, so the second bind overwrote the first instead of
// accumulating.
pub fun probe_bind_cb(name: string, args: list<LVal>, e: Env) : (LVal, Env) =>
  match (name, args) {
    ("host/bind", [LStr(k), v]) => {
      let cur   = env_get(e, "__probe_bindings")
      let m     = match cur { LHash(_) => cur, _ => LHash([]) }
      let m2    = builtin_hash_set([m, LStr(k), v])
      (LNil, env_set(e, "__probe_bindings", m2))
    },
    _ => (lerror("host/bad-args", "unexpected call"), e)
  }

test "host wrapper: two sequential bind calls accumulate" {
  let env  = make_env()
  let env2 = register_host_dispatch(env, probe_bind_cb)
  // Seed the shared slot so it exists on the env before any wrapper
  // captures its closure.
  let env3 = env_set(env2, "__probe_bindings", LHash([]))
  // (def bind (fn (k v) (host/bind k v)))
  let wrapper = LList([lsym("fn"),
    LList([lsym("k"), lsym("v")]),
    LList([lsym("host/bind"), lsym("k"), lsym("v")])])
  let (_, env4) = eval(LList([lsym("def"), lsym("bind"), wrapper]), env3)
  // Values must be self-evaluating (or explicitly quoted) — bare `quit`
  // would be treated as a symbol lookup and fail with undefined-symbol,
  // short-circuiting apply before the wrapper body runs.
  let q_quit   = LList([lsym("quote"), lsym("quit")])
  let q_ignore = LList([lsym("quote"), lsym("ignore")])
  let (_, env5) = eval(LList([lsym("bind"), LStr("Ctrl-x"), q_quit]),   env4)
  let (_, env6) = eval(LList([lsym("bind"), LStr("Ctrl-q"), q_ignore]), env5)
  let m = env_get(env6, "__probe_bindings")
  assert_eq(lval_show(builtin_hash_get([m, LStr("Ctrl-x")])), "quit")
  assert_eq(lval_show(builtin_hash_get([m, LStr("Ctrl-q")])), "ignore")
}
