// builtins.hc — the primitive layer of HiLisp
// Each builtin is a named function that operates on evaluated LVal arguments
import "std/io"
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
    _      => lerror("type/arity", "/ expects 2 args")
  }

// Comparison — numeric, 2 args; takes an operator lambda for reuse across <, >, <=, >=
pub fun builtin_cmp(args: list<LVal>, op: (int, int) -> bool) : LVal =>
  match args {
    [LNum(a), LNum(b)] => LBool(op(a, b)),
    _                  => lerror("type/not-a-number", "comparison expects 2 numbers")
  }

// Structural list equality — assumes both sides are LList items
pub fun list_eq(xs: list<LVal>, ys: list<LVal>) : bool =>
  match (xs, ys) {
    ([], []) => true,
    ([x, ..xr], [y, ..yr]) =>
      match builtin_eq([x, y]) {
        LBool(true) => list_eq(xr, yr),
        _           => false
      },
    _ => false
  }

// Structural hash equality — order-independent, so we look each key from a in b
// and require the same length. Missing keys or value mismatch → false.
pub fun hash_all_match(a: list<(string, LVal)>, b: list<(string, LVal)>) : bool =>
  match a {
    [] => true,
    [(k, v), ..rest] =>
      match map_get(b, k) {
        Some(v2) =>
          match builtin_eq([v, v2]) {
            LBool(true) => hash_all_match(rest, b),
            _           => false
          },
        None => false
      }
  }

pub fun hash_eq(a: list<(string, LVal)>, b: list<(string, LVal)>) : bool =>
  length(a) == length(b) && hash_all_match(a, b)

// Equality — structural, works across types. Symbol equality is name-based
// and ignores source spans, so `'save` from two files still compares equal.
pub fun builtin_eq(args: list<LVal>) : LVal =>
  match args {
    [LNum(a),  LNum(b)]     => LBool(a == b),
    [LBool(a), LBool(b)]    => LBool(a == b),
    [LStr(a),  LStr(b)]     => LBool(a == b),
    [LSym(a, _), LSym(b, _)] => LBool(a == b),
    [LNil,     LNil]        => LBool(true),
    [LList(a), LList(b)]    => LBool(list_eq(a, b)),
    [LHash(a), LHash(b)]    => LBool(hash_eq(a, b)),
    [_, _]                  => LBool(false),
    _                       => lerror("type/arity", "= expects 2 args")
  }

// Logic
pub fun builtin_not(args: list<LVal>) : LVal =>
  match args {
    [v] => if is_truthy(v) { LBool(false) } else { LBool(true) },
    _   => lerror("type/arity", "not expects 1 arg")
  }

pub fun builtin_and(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { b } else { LBool(false) },
    _      => lerror("type/arity", "and expects 2 args")
  }

pub fun builtin_or(args: list<LVal>) : LVal =>
  match args {
    [a, b] => if is_truthy(a) { a } else { b },
    _      => lerror("type/arity", "or expects 2 args")
  }

// Null/empty predicates
pub fun builtin_null(args: list<LVal>) : LVal =>
  match args {
    [LNil] => LBool(true),
    [_]    => LBool(false),
    _      => lerror("type/arity", "null? expects 1 arg")
  }

pub fun builtin_empty(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => LBool(length(items) == 0),
    [LStr(s)]      => LBool(str_length(s) == 0),
    _              => lerror("type/wrong-type", "empty? expects a list or string")
  }

// List primitives — the classic Lisp trio plus length
pub fun builtin_car(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [h, ..] => h, [] => LNil },
    _              => lerror("type/wrong-type", "car expects a list")
  }

pub fun builtin_cdr(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => match items { [_, ..rest] => LList(rest), [] => LList([]) },
    _              => lerror("type/wrong-type", "cdr expects a list")
  }

pub fun builtin_cons(args: list<LVal>) : LVal =>
  match args {
    [v, LList(items)] => LList([v] + items),
    _                 => lerror("type/wrong-type", "cons expects a value and a list")
  }

pub fun builtin_length(args: list<LVal>) : LVal =>
  match args {
    [LList(items)] => LNum(length(items)),
    _              => lerror("type/wrong-type", "length expects a list")
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
    [v] => LStr(lval_display(v)),
    _   => LStr(display_all(args))
  }

// println is side-effectful so needs a block body rather than an inline match arm
pub fun builtin_println(args: list<LVal>, env: Env) {
  println(display_all(args))
  (LNil, env)
}

// (write-file path content) — write a string to disk; returns nil or error string
pub fun builtin_write_file(args: list<LVal>, env: Env) =>
  match args {
    [LStr(path), LStr(content)] =>
      match write_file(path, content) {
        Ok(_)      => (LNil, env),
        Err(msg)   => (lerror("io/write-failed", msg), env)
      },
    _ => (lerror("type/arity", "write-file expects (path content)"), env)
  }

// (exec cmd) — run a shell command, return stdout trimmed; error string on failure
pub fun builtin_exec(args: list<LVal>, env: Env) =>
  match args {
    [LStr(cmd)] =>
      match exec(cmd) {
        Ok(out)  => (LStr(trim(out)), env),
        Err(msg) => (lerror("io/exec-failed", msg), env)
      },
    _ => (lerror("type/arity", "exec expects (cmd)"), env)
  }

// (starts-with str prefix) — true if str begins with prefix
pub fun builtin_starts_with(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LStr(pre)] => LBool(starts_with(s, pre)),
    _                    => lerror("type/wrong-type", "starts-with expects (str prefix)")
  }

// (lines str) — split str on newlines, return list of strings
pub fun builtin_lines(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] => LList(map(split(s, "\n"), (ln) => LStr(ln))),
    _         => lerror("type/wrong-type", "lines expects a string")
  }

// (contains str sub) — true if str contains the substring sub
// Uses a recursive helper to avoid the Koka 3.2.3 Perceus bug:
// split(s, sub) generates `if sub.is-empty then ... else s.split(sub)`,
// where Perceus drops `sub` after the condition, crashing the else branch.
// Passing s and sub as explicit function parameters avoids the issue.
pub fun str_has_sub(s: string, sub: string) : bool =>
  if str_length(sub) == 0 { true }
  else if str_length(s) < str_length(sub) { false }
  else if starts_with(s, sub) { true }
  else { str_has_sub(s[1:], sub) }

pub fun builtin_contains(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LStr(sub)] => LBool(str_has_sub(s, sub)),
    _                    => lerror("type/wrong-type", "contains expects (str sub)")
  }

// (assert condition) or (assert condition "message")
// Returns nil on success; LError on failure so run_forms prints it to stderr
// and continues, letting you see all failures in one run.
pub fun builtin_assert(args: list<LVal>) : LVal =>
  match args {
    [cond] =>
      if is_truthy(cond) { LNil }
      else { lerror("assert/failed", "assertion failed") },
    [cond, LStr(msg)] =>
      if is_truthy(cond) { LNil }
      else { lerror("assert/failed", "assertion failed: " + msg) },
    _ => lerror("type/arity", "assert expects 1 or 2 args")
  }

// (assert-eq a b) — structural equality check with auto-generated message
// Uses show_all([v]) rather than lval_show(v) directly so the div effect
// from lval_show stays within builtins.hc's local recursive group.
// No explicit return type — Koka infers the div effect from show_all.
pub fun builtin_assert_eq(args: list<LVal>) =>
  match args {
    [a, b] =>
      match builtin_eq([a, b]) {
        LBool(true) => LNil,
        _           => lerror("assert/failed", "expected " + show_all([b]) + ", got " + show_all([a]))
      },
    _ => lerror("type/arity", "assert-eq expects 2 args")
  }

// ── String extras ────────────────────────────────────────────────────────────

// (str-length s) — number of characters
pub fun builtin_str_length(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] => LNum(str_length(s)),
    _         => lerror("type/wrong-type", "str-length expects a string")
  }

// (str-slice s from to) or (str-slice s from) — extract a substring
pub fun builtin_str_slice(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LNum(i), ..rest] =>
      match rest {
        [LNum(j)] => LStr(s[i:j]),
        []        => LStr(s[i:]),
        _         => lerror("type/arity", "str-slice expects (str from) or (str from to)")
      },
    _ => lerror("type/wrong-type", "str-slice expects (str from) or (str from to)")
  }

// (str-at s i) — single character at index i returned as a one-char string
pub fun builtin_str_at(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LNum(i)] => LStr(s[i:i+1]),
    _ => lerror("type/wrong-type", "str-at expects (str index)")
  }

// (str-split s sep) — split string on separator, return list of strings
pub fun builtin_str_split(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LStr(sep)] => LList(map(split(s, sep), (part) => LStr(part))),
    _ => lerror("type/wrong-type", "str-split expects (str sep)")
  }

// (trim s) — strip leading and trailing whitespace
pub fun builtin_trim(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] => LStr(trim(s)),
    _         => lerror("type/wrong-type", "trim expects a string")
  }

// (to-upper s) / (to-lower s) — case conversion
pub fun builtin_to_upper(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] => LStr(to_upper(s)),
    _         => lerror("type/wrong-type", "to-upper expects a string")
  }

pub fun builtin_to_lower(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] => LStr(to_lower(s)),
    _         => lerror("type/wrong-type", "to-lower expects a string")
  }

// (ends-with s suffix) — true if s ends with suffix
pub fun builtin_ends_with(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LStr(suf)] => LBool(ends_with(s, suf)),
    _ => lerror("type/wrong-type", "ends-with expects (str suffix)")
  }

// (replace s old new) — replace all occurrences of old in s with new
pub fun builtin_replace(args: list<LVal>) : LVal =>
  match args {
    [LStr(s), LStr(old), LStr(new_str)] => LStr(replace(s, old, new_str)),
    _ => lerror("type/wrong-type", "replace expects (str old new)")
  }

// Helper: convert a list of LVals to a list of their display strings
pub fun lvals_to_strings(items: list<LVal>) : list<string> =>
  match items {
    []            => [],
    [v, ..rest]   => [lval_display(v)] + lvals_to_strings(rest)
  }

// (join sep list) — join list of values with separator
pub fun builtin_join(args: list<LVal>) : LVal =>
  match args {
    [LStr(sep), LList(items)] => LStr(join(lvals_to_strings(items), sep)),
    _ => lerror("type/wrong-type", "join expects (sep list)")
  }

// ── Symbols ──────────────────────────────────────────────────────────────────

// (symbol? v) — true iff v is a quoted/name symbol (LSym), not a string
pub fun builtin_symbol_pred(args: list<LVal>) : LVal =>
  match args {
    [LSym(_, _)] => LBool(true),
    [_]          => LBool(false),
    _            => lerror("type/arity", "symbol? expects 1 arg")
  }

// (symbol-name sym) — extract the name of a symbol as a plain string
pub fun builtin_symbol_name(args: list<LVal>) : LVal =>
  match args {
    [LSym(name, _)] => LStr(name),
    _               => lerror("type/wrong-type", "symbol-name expects a symbol")
  }

// ── Hash-maps ────────────────────────────────────────────────────────────────

// Fold args into an alist of (string, LVal); non-string keys or odd arity
// produce an LError which the outer builtin returns as-is.
pub fun collect_hash_pairs(args: list<LVal>, acc: list<(string, LVal)>) : LVal =>
  match args {
    []                    => LHash(acc),
    [LStr(k), v, ..rest]  => collect_hash_pairs(rest, map_set(acc, k, v)),
    [_, _, ..]            => lerror("type/wrong-type", "hash-map keys must be strings"),
    [_]                   => lerror("type/arity", "hash-map expects an even number of args")
  }

// (hash-map k1 v1 k2 v2 …) — build a hash-map; keys must be strings.
// Later keys shadow earlier ones (last-write-wins).
pub fun builtin_hash_map(args: list<LVal>) : LVal => collect_hash_pairs(args, [])

// (hash-get m k)         — value or nil
// (hash-get m k default) — value or default
pub fun builtin_hash_get(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries), LStr(k)] =>
      match map_get(entries, k) { Some(v) => v, None => LNil },
    [LHash(entries), LStr(k), default] =>
      match map_get(entries, k) { Some(v) => v, None => default },
    _ => lerror("type/wrong-type", "hash-get expects (hash key) or (hash key default)")
  }

// (hash-set m k v) — return a new hash with k bound to v
pub fun builtin_hash_set(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries), LStr(k), v] => LHash(map_set(entries, k, v)),
    _ => lerror("type/wrong-type", "hash-set expects (hash key value)")
  }

// Remove key k from an alist, preserving insertion order for the rest
pub fun alist_del(entries: list<(string, LVal)>, k: string) : list<(string, LVal)> =>
  match entries {
    []               => [],
    [(kk, v), ..rest] =>
      if kk == k { alist_del(rest, k) }
      else       { [(kk, v)] + alist_del(rest, k) }
  }

// (hash-del m k) — return a new hash without k (no-op if k is absent)
pub fun builtin_hash_del(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries), LStr(k)] => LHash(alist_del(entries, k)),
    _ => lerror("type/wrong-type", "hash-del expects (hash key)")
  }

// (hash-has? m k) — boolean
pub fun builtin_hash_has(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries), LStr(k)] =>
      match map_get(entries, k) { Some(_) => LBool(true), None => LBool(false) },
    _ => lerror("type/wrong-type", "hash-has? expects (hash key)")
  }

// Extract the key or value from a hash entry. Kept as top-level functions so
// Koka codegen doesn't end up with a nested match inside a lambda literal,
// which produced an indentation-sensitive parse error in the emitted .kk.
pub fun hash_key_of(kv: (string, LVal)) : LVal => match kv { (k, _) => LStr(k) }
pub fun hash_val_of(kv: (string, LVal)) : LVal => match kv { (_, v) => v }

// (hash-keys m) — list of string keys in insertion order
pub fun builtin_hash_keys(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries)] => LList(map(entries, hash_key_of)),
    _ => lerror("type/wrong-type", "hash-keys expects a hash")
  }

// (hash-vals m) — list of values in insertion order
pub fun builtin_hash_vals(args: list<LVal>) : LVal =>
  match args {
    [LHash(entries)] => LList(map(entries, hash_val_of)),
    _ => lerror("type/wrong-type", "hash-vals expects a hash")
  }

// (hash? v) — type predicate
pub fun builtin_hash_pred(args: list<LVal>) : LVal =>
  match args {
    [LHash(_)] => LBool(true),
    [_]        => LBool(false),
    _          => lerror("type/arity", "hash? expects 1 arg")
  }

// ── Parsing ───────────────────────────────────────────────────────────────────

// (parse-int s) — convert string to integer; returns nil on failure (not an error)
pub fun builtin_parse_int(args: list<LVal>) : LVal =>
  match args {
    [LStr(s)] =>
      match parse_int(s) {
        Some(n) => LNum(n),
        None    => LNil
      },
    _ => lerror("type/wrong-type", "parse-int expects a string")
  }

// ── IO ────────────────────────────────────────────────────────────────────────

// (read-file path) — read file contents as a string; returns LError on failure
pub fun builtin_read_file(args: list<LVal>, env: Env) =>
  match args {
    [LStr(path)] =>
      match read_file(path) {
        Ok(content) => (LStr(content), env),
        Err(msg)    => (lerror("io/read-failed", msg), env)
      },
    _ => (lerror("type/wrong-type", "read-file expects a path string"), env)
  }

// (input) or (input "prompt") — read a line from stdin; prompt is printed first.
// hica's input() now emits hica-readline-prompt() which flushes stdout and
// returns empty string on EOF instead of throwing an exception.
pub fun builtin_input(args: list<LVal>, env: Env) =>
  match args {
    []        => (LStr(input("")), env),
    [LStr(p)] => (LStr(input(p)), env),
    _ => (lerror("type/wrong-type", "input expects 0 or 1 string arg"), env)
  }

// (random lo hi) — random integer in [lo, hi] inclusive; no annotation so Koka
// infers the ndet effect
pub fun builtin_random(args: list<LVal>) =>
  match args {
    [LNum(lo), LNum(hi)] => LNum(random(lo, hi)),
    _ => lerror("type/arity", "random expects (lo hi)")
  }

// Dispatch — maps a builtin name to its implementation
pub fun apply_builtin(name: string, args: list<LVal>, env: Env) =>
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
    "null?"   => (builtin_null(args), env),
    "empty?"  => (builtin_empty(args), env),
    "car"     => (builtin_car(args), env),
    "cdr"     => (builtin_cdr(args), env),
    "cons"    => (builtin_cons(args), env),
    "list"    => (LList(args), env),
    "length"  => (builtin_length(args), env),
    "str"     => (builtin_str(args), env),
    "println"    => builtin_println(args, env),
    "write-file"   => builtin_write_file(args, env),
    "exec"         => builtin_exec(args, env),
    "starts-with"  => (builtin_starts_with(args), env),
    "lines"        => (builtin_lines(args), env),
    "contains"     => (builtin_contains(args), env),
    "assert"       => (builtin_assert(args), env),
    "assert-eq"    => (builtin_assert_eq(args), env),
    // string extras
    "str-length"  => (builtin_str_length(args), env),
    "str-slice"   => (builtin_str_slice(args), env),
    "str-at"      => (builtin_str_at(args), env),
    "str-split"   => (builtin_str_split(args), env),
    "trim"        => (builtin_trim(args), env),
    "to-upper"    => (builtin_to_upper(args), env),
    "to-lower"    => (builtin_to_lower(args), env),
    "ends-with"   => (builtin_ends_with(args), env),
    "replace"     => (builtin_replace(args), env),
    "join"        => (builtin_join(args), env),
    // symbols
    "symbol?"     => (builtin_symbol_pred(args), env),
    "symbol-name" => (builtin_symbol_name(args), env),
    // hash-maps
    "hash-map"    => (builtin_hash_map(args), env),
    "hash-get"    => (builtin_hash_get(args), env),
    "hash-set"    => (builtin_hash_set(args), env),
    "hash-del"    => (builtin_hash_del(args), env),
    "hash-has?"   => (builtin_hash_has(args), env),
    "hash-keys"   => (builtin_hash_keys(args), env),
    "hash-vals"   => (builtin_hash_vals(args), env),
    "hash?"       => (builtin_hash_pred(args), env),
    // parsing
    "parse-int"   => (builtin_parse_int(args), env),
    // IO
    "read-file"   => builtin_read_file(args, env),
    "input"       => builtin_input(args, env),
    "random"      => (builtin_random(args), env),
    _              => (lerror("eval/unknown-builtin", "unknown builtin: " + name), env)
  }

// Build the initial environment with all builtins pre-registered
pub fun make_env() : Env {
  let names = ["+", "-", "*", "/", "=", "<", ">", "<=", ">=",
               "not", "and", "or", "null?", "empty?",
               "car", "cdr", "cons", "list", "length",
               "println", "str",
               "write-file", "exec",
               "starts-with", "lines", "contains",
               "assert", "assert-eq",
               "str-length", "str-slice", "str-at", "str-split",
               "trim", "to-upper", "to-lower", "ends-with", "replace", "join",
               "symbol?", "symbol-name",
               "hash-map", "hash-get", "hash-set", "hash-del",
               "hash-has?", "hash-keys", "hash-vals", "hash?",
               "parse-int",
               "read-file", "input", "random"]
  let base = fold(names, EmptyEnv, (e, name) => env_set(e, name, LBuiltin(name)))
  env_set(base, "nil", LNil)
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

test "null? and empty? predicates" {
  assert_eq(lval_show(builtin_null([LNil])), "true")
  assert_eq(lval_show(builtin_null([LList([])])), "false")
  assert_eq(lval_show(builtin_empty([LList([])])), "true")
  assert_eq(lval_show(builtin_empty([LList([LNum(1)])])), "false")
  assert_eq(lval_show(builtin_empty([LStr("")])), "true")
  assert_eq(lval_show(builtin_empty([LStr("x")])), "false")
}

test "make_env registers builtins" {
  let e        = make_env()
  let has_plus = match env_get(e, "+")   { LBuiltin(_) => true, _ => false }
  let has_car  = match env_get(e, "car") { LBuiltin(_) => true, _ => false }
  let has_null = match env_get(e, "null?") { LBuiltin(_) => true, _ => false }
  let has_empty = match env_get(e, "empty?") { LBuiltin(_) => true, _ => false }
  let has_hash = match env_get(e, "hash-map") { LBuiltin(_) => true, _ => false }
  assert(has_plus)
  assert(has_car)
  assert(has_null)
  assert(has_empty)
  assert(has_hash)
}

test "hash-map build and get" {
  let m = builtin_hash_map([LStr("k"), LNum(1), LStr("j"), LStr("v")])
  assert_eq(lval_show(builtin_hash_get([m, LStr("k")])), "1")
  assert_eq(lval_show(builtin_hash_get([m, LStr("j")])), "\"v\"")
  assert_eq(lval_show(builtin_hash_get([m, LStr("missing")])), "nil")
  assert_eq(lval_show(builtin_hash_get([m, LStr("missing"), LNum(99)])), "99")
}

test "hash-map odd arity errors" {
  let r = builtin_hash_map([LStr("k")])
  let is_err = match r { LError(_, _, _, _) => true, _ => false }
  assert(is_err)
}

test "hash-map non-string key errors" {
  let r = builtin_hash_map([LNum(1), LNum(2)])
  let is_err = match r { LError(_, _, _, _) => true, _ => false }
  assert(is_err)
}

test "hash-map set overwrites" {
  let m  = builtin_hash_map([LStr("k"), LNum(1)])
  let m2 = builtin_hash_set([m, LStr("k"), LNum(9)])
  assert_eq(lval_show(builtin_hash_get([m2, LStr("k")])), "9")
}

test "hash-map del removes key" {
  let m  = builtin_hash_map([LStr("k"), LNum(1), LStr("j"), LNum(2)])
  let m2 = builtin_hash_del([m, LStr("k")])
  assert_eq(lval_show(builtin_hash_has([m2, LStr("k")])), "false")
  assert_eq(lval_show(builtin_hash_has([m2, LStr("j")])), "true")
}

test "hash-map keys and vals preserve order" {
  let m = builtin_hash_map([LStr("a"), LNum(1), LStr("b"), LNum(2)])
  assert_eq(lval_show(builtin_hash_keys([m])), "(\"a\" \"b\")")
  assert_eq(lval_show(builtin_hash_vals([m])), "(1 2)")
}

test "hash? predicate" {
  assert_eq(lval_show(builtin_hash_pred([LHash([])])), "true")
  assert_eq(lval_show(builtin_hash_pred([LList([])])), "false")
  assert_eq(lval_show(builtin_hash_pred([LNum(1)])),   "false")
}

test "hash equality is order-independent" {
  let m1 = builtin_hash_map([LStr("a"), LNum(1), LStr("b"), LNum(2)])
  let m2 = builtin_hash_map([LStr("b"), LNum(2), LStr("a"), LNum(1)])
  let m3 = builtin_hash_map([LStr("a"), LNum(1)])
  assert_eq(lval_show(builtin_eq([m1, m2])), "true")
  assert_eq(lval_show(builtin_eq([m1, m3])), "false")
}

test "list equality is structural" {
  let a = LList([LNum(1), LNum(2), LNum(3)])
  let b = LList([LNum(1), LNum(2), LNum(3)])
  let c = LList([LNum(1), LNum(2)])
  assert_eq(lval_show(builtin_eq([a, b])), "true")
  assert_eq(lval_show(builtin_eq([a, c])), "false")
}

test "symbol equality ignores span" {
  let s1 = LSym("save", Span(1, 1))
  let s2 = LSym("save", Span(9, 3))
  let s3 = LSym("quit", NoSpan)
  assert_eq(lval_show(builtin_eq([s1, s2])), "true")
  assert_eq(lval_show(builtin_eq([s1, s3])), "false")
  // symbol vs same-named string is NOT equal
  assert_eq(lval_show(builtin_eq([s1, LStr("save")])), "false")
}

test "symbol? predicate" {
  assert_eq(lval_show(builtin_symbol_pred([lsym("save")])),   "true")
  assert_eq(lval_show(builtin_symbol_pred([LStr("save")])),   "false")
  assert_eq(lval_show(builtin_symbol_pred([LNum(1)])),        "false")
}

test "symbol-name extracts the name" {
  assert_eq(lval_show(builtin_symbol_name([lsym("save")])), "\"save\"")
  let err = builtin_symbol_name([LStr("save")])
  let is_err = match err { LError(_, _, _, _) => true, _ => false }
  assert(is_err)
}
