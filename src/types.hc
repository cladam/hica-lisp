// hica-lisp – a small lisp in hica inspired by Carp
import "./ast"

type Env {
  Env(bindings: list<(string, LVal)>, parent: Env),
  EmptyEnv
}

// Walk the environment chain — inner scopes shadow outer ones
// Env bindings are a Hica map (list<(string, LVal)>), so map_get does the lookup
pub fun env_get(e: Env, key: string) : LVal => match e {
  EmptyEnv              => LNil,
  Env(bindings, parent) => match map_get(bindings, key) {
    Some(v) => v,
    None    => env_get(parent, key)
  }
}

// Bind a name in the current scope, shadowing any existing binding for that key
pub fun env_set(e: Env, key: string, v: LVal) : Env =>
  match e {
    EmptyEnv        => Env([(key, v)], EmptyEnv),
    Env(bs, parent) => Env(map_set(bs, key, v), parent)
  }