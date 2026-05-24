// hica-lisp – a small lisp in hica inspired by Carp
import "./ast"

type Env {
  Env(bindings: list<(string, LVal)>, parent: Env),
  EmptyEnv
}

// assoc is a classic Lisp function, short for "association list lookup". 
// An association list (alist) is just a list of key-value pairs: [(string, LVal)].
// Walk the list head-to-tail. At each pair, destructure it into (k, v). 
// If k matches key, return Some(v). If not, recurse on rest. If the list empties out, return None.
// It returns maybe<LVal> so the caller (env_get) can distinguish "found" from "not found" and decide whether to walk up to the parent environment.

// Association list lookup — the simplest possible map: scan pairs for a matching key
fun assoc(pairs: list<(string, LVal)>, key: string) : maybe<LVal> =>
  match pairs {
    []             => None,
    [(k, v), ..rest] => if k == key { Some(v) } else { assoc(rest, key) }
  }

// Walk the environment chain — inner scopes shadow outer ones
fun env_get(e: Env, key: string) : LVal => match e {
  EmptyEnv => LNil,
  Env(bindings, parent) => match assoc(bindings, key) {
    Some(v) => v,
    None    => env_get(parent, key)
  }
}

// Bind a name in the current scope, shadowing any existing binding for that key
fun env_set(e: Env, key: string, v: LVal) : Env =>
  match e {
    EmptyEnv        => Env([(key, v)], EmptyEnv),
    // Env(bs, parent) => Env([(key, v)] + filter(bs, (p) => p.0 != key), parent)
    Env(bs, parent) => Env([(key, v)] + filter(bs, (p) => match p { (k, _) => k != key }), parent)
  }