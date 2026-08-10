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
