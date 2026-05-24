// hica-lisp – a small lisp in hica inspired by Carp
import "./ast"

type Env {
  Env(bindings: list<(string, LVal)>, parent: Env),
  EmptyEnv
}

fun assoc(pairs: list<(string, LVal)>, key: string) : maybe<LVal> =>
  match pairs {
    []             => None,
    [(k, v), ..rest] => if k == key { Some(v) } else { assoc(rest, key) }
  }

fun env_get(e: Env, key: string) : LVal => match e {
  EmptyEnv => LNil,
  Env(bindings, parent) => match assoc(bindings, key) {
    Some(v) => v,
    None    => env_get(parent, key)
  }
}

fun env_set(e: Env, key: string, v: LVal) : Env =>
  match e {
    EmptyEnv        => Env([(key, v)], EmptyEnv),
    // Env(bs, parent) => Env([(key, v)] + filter(bs, (p) => p.0 != key), parent)
    Env(bs, parent) => Env([(key, v)] + filter(bs, (p) => match p { (k, _) => k != key }), parent)
  }