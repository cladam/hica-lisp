// hica-lisp – a small lisp in hica inspired by Carp
import "./ast"

// Walk the environment chain — inner scopes shadow outer ones
// Env bindings are a Hica map (list<(string, LVal)>), so map_get does the lookup
pub fun env_get(e: Env, key: string) : LVal => match e {
  EmptyEnv                 => LNil,
  Env(bindings, _, parent) => match map_get(bindings, key) {
    Some(v) => v,
    None    => env_get(parent, key)
  }
}

// Bind a name in the current scope, shadowing any existing binding for that key.
// The host callback (if any) is preserved so registrations persist across
// scopes; new EmptyEnv extensions start with NoHostFn.
pub fun env_set(e: Env, key: string, v: LVal) : Env =>
  match e {
    EmptyEnv            => Env([(key, v)], NoHostFn, EmptyEnv),
    Env(bs, host, parent) => Env(map_set(bs, key, v), host, parent)
  }

// Check whether a name is bound anywhere in the environment chain
pub fun env_has(e: Env, key: string) : bool => match e {
  EmptyEnv                 => false,
  Env(bindings, _, parent) => match map_get(bindings, key) {
    Some(_) => true,
    None    => env_has(parent, key)
  }
}

// Read the host dispatch callback, walking the parent chain until one is
// found. Returns NoHostFn if no embedder ever registered one.
pub fun env_host(e: Env) : HostDispatch => match e {
  EmptyEnv                => NoHostFn,
  Env(_, HostFn(cb), _)   => HostFn(cb),
  Env(_, NoHostFn, parent) => env_host(parent)
}

// Install the host callback on the *current* scope. Existing bindings and
// parent chain are preserved; if `e` is EmptyEnv we create a fresh Env
// so downstream env_get lookups still work.
pub fun env_set_host(e: Env, host: HostDispatch) : Env =>
  match e {
    EmptyEnv              => Env([], host, EmptyEnv),
    Env(bs, _, parent)    => Env(bs, host, parent)
  }

test "env_get returns LNil for missing key" {
  let r      = env_get(EmptyEnv, "x")
  let is_nil = match r { LNil => true, _ => false }
  assert(is_nil)
}

test "env_set and env_get roundtrip" {
  let e  = env_set(EmptyEnv, "x", LNum(42))
  let r  = env_get(e, "x")
  let ok = match r { LNum(n) => n == 42, _ => false }
  assert(ok)
}

test "inner scope shadows outer" {
  let outer    = env_set(EmptyEnv, "x", LNum(1))
  let inner    = env_set(Env([], NoHostFn, outer), "x", LNum(2))
  let r_inner  = match env_get(inner, "x") { LNum(n) => n == 2, _ => false }
  let r_outer  = match env_get(outer, "x") { LNum(n) => n == 1, _ => false }
  assert(r_inner)
  assert(r_outer)
}
