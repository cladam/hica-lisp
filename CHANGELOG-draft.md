# Unreleased — v0.9.2

Bug-fix release: makes the host-dispatch carve-out symmetric so plain-Lisp
wrappers around `host/…` builtins can be called multiple times without
losing state.

### 🐛 Bug Fixes

- **Host wrappers now see fresh host state on every call.** `apply` already
  merged the callee's `__`-prefixed bindings *back* into the caller's env
  after a body that touches `host/…`. It now also *pre-merges* the caller's
  latest `__`-prefixed keys **into** the callee's topmost frame before
  evaluating the body. Without this, a wrapper like
  `(def bind (fn (k v) (host/bind k v)))` would run against its captured
  closure's snapshot of `__hedit_bindings` — so the second `(bind …)`
  overwrote the first instead of accumulating. Symptom: hedit M4b's
  end-to-end test bound `Ctrl-x` then `Ctrl-q`, and `Ctrl-x` resolved to
  `Ignore` instead of `Quit`. New regression test
  `host wrapper: two sequential bind calls accumulate` in `src/eval.hc`
  covers this precisely.

### 🔨 Compatibility

- No API changes; embedders using `register_host_dispatch` need no code
  changes. Version bump `0.9.1 → 0.9.2`.

# Unreleased — v0.9.0

Embedding-oriented release: HiLisp now has a first-class extension point for
host applications. Drives hedit's design §7.5 out of its "ugly form"
workaround and closes the last piece of the hedit-side HiLisp gap analysis.

### ✨ Features

- **Host builtins hook (`host/…` dispatch).** A single, focused extension
  point for embedders. Any call to a symbol prefixed with `host/`
  (`(host/set …)`, `(host/get …)`, `(host/bind …)`) is routed to a native
  Hica callback the embedder registers once at env-creation time. HiLisp
  itself stays a closed match over its own builtins — no plugin registries,
  no dynamic dispatch table — and hosts can mutate their own state without
  ever leaking into the interpreter.
  - New Env field `host: HostDispatch` (variant `HostFn(cb) | NoHostFn`),
    preserved across `env_set` so the registration is visible to every
    inner scope.
  - New `register_host_dispatch(env, cb) : Env` — installs the callback.
  - `host/…` symbols resolve automatically in `eval` (as an `LBuiltin`
    sentinel), so users don't need to explicitly `def` them; unresolved
    `host/foo` with no dispatch registered produces a source-located
    `LError` with id `host/not-registered`.
  - `apply_builtin` guards the core dispatch: `host/…` names go through
    `apply_host_dispatch`; everything else falls through to
    `apply_core_builtin` unchanged.
- **Env helpers `env_host` / `env_set_host`** for reading and installing
  the callback without touching bindings. Used by
  `register_host_dispatch`; also useful for host-side testing.

### 🧪 Tests

- +5 host-dispatch tests in `src/builtins.hc` (22 total in that module):
  not-registered error, echo callback, arg + env mutation, persistence
  across `env_set`, and non-`host/` routing still hitting the core arm.
- All 123 prelude regression tests still pass.

### 🔨 Compatibility

- **Requires hica ≥ 0.49.2** — the compiler now auto-detects the need for
  Koka's `div type` in codegen, which is what allows the `HostDispatch`
  callback (a function whose parameter list mentions `Env`) to compile
  cleanly. Older Hica versions will refuse the generated `.kk`.
- No changes to existing builtins, special forms, or the `LVal` public
  variants. Scripts that don't touch `host/…` are unaffected.
- Env constructor changed from `Env(bindings, parent)` to
  `Env(bindings, host, parent)`. The three internal call sites in `eval`
  (fn apply, loop, recur) were updated; user code never constructs `Env`
  directly, so this is source-compatible for scripts.
- Version bump `0.8.0 → 0.9.0`.

### 📚 Docs

- `docs/hica-issue-div-type.md`: write-up of the compiler support we
  needed and got (upstreamed as `hica` v0.49.2). Kept in the repo as a
  design-note reference.
- CHANGELOG updated (this file).

# Unreleased — v0.8.0

Config-oriented release driven by the hedit design's HiLisp gap analysis (§8).
Closes all four items and polishes the runtime error path so `init.hl` typos
surface at the offending source form.

### ✨ Features

- **Hash-map value type (`LHash`) and eight operations.**
  `(hash-map k v …)`, `(hash-get m k [default])`, `(hash-set m k v)`,
  `(hash-del m k)`, `(hash-has? m k)`, `(hash-keys m)`, `(hash-vals m)`,
  `(hash? v)`. String keys, insertion-order preserving, structural (order-
  independent) equality.
- **`{k v k v …}` reader literal** — parser desugars braces into
  `(hash-map …)` so nested config maps read naturally.
- **Symbol API for hosts.** New builtins `(symbol? v)` and `(symbol-name sym)`
  so host programs (e.g. hedit's `(bind …)`) can test/extract symbols without
  matching on the raw `LVal` ADT.
- **Symbol equality.** `=` now compares two `LSym` values by name (span-
  independent). Symbols and strings of the same text compare unequal.
- **String escapes round-trip through `lval_show`.** Real newlines, tabs,
  quotes and backslashes are re-escaped on display so `(println (str …))`
  produces readable output regardless of what's inside a string.
- **Structural equality for lists and hash-maps** — `=` now compares
  `LList`/`LList` and `LHash`/`LHash` structurally in addition to primitives.
- **Source-located runtime errors.** `eval_call` now captures the head-symbol
  span of every call form and stamps it onto any span-less `LError` returned
  by the builtin, so `(hash-get)` (wrong arity) prints a caret snippet
  pointing at that exact form. Deeper spans (e.g. `undefined-symbol`) are
  preserved.

### 📚 Docs

- README: new "Hash maps", "String escapes", "Symbols" and "Source-located
  errors" sections; `examples/hashmap.hl` and `examples/symbols.hl` listed.
- `docs/hilisp-hica-guide.md`: hash-map + symbols subsections, escape-sequence
  limitation removed, built-in table extended.
- `examples/hashmap.hl`, `examples/symbols.hl`: runnable demos.
- `lib/test-prelude.hl`: +22 regression tests (123 total).

### 🔨 Compatibility

- No changes to existing built-ins or special forms; existing scripts continue
  to run unchanged.
- Version bump `0.6.0 → 0.7.0`.

# Previously unreleased since v0.3.2 (2026-05-27)

### ✨ Features

- [c707974](https://github.com/cladam/hica-lisp/commit/c707974) feat: add null? and empty? builtins and update prelude.hl

### 🐛 Bug Fixes

- [a093a20](https://github.com/cladam/hica-lisp/commit/a093a20) fix: update comments in changelog.hl
- [5c441ed](https://github.com/cladam/hica-lisp/commit/5c441ed) fix: renamed script
- [e78192f](https://github.com/cladam/hica-lisp/commit/e78192f) fix: remove unneeded comment
- [5edc4cf](https://github.com/cladam/hica-lisp/commit/5edc4cf) fix: strip .git from links in the changelog script

### ⚙️ Maintenance

- [7b2ead2](https://github.com/cladam/hica-lisp/commit/7b2ead2) chore: mapped hl files to clojure in VSCode for hinglighting
