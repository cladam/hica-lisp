# Unreleased — v0.7.0

Config-oriented additions driven by the hedit design's HiLisp gap analysis
(§8). Two of the three gaps listed there were already resolved in main; this
release closes the remaining one (hash-maps) and polishes the string display
path so scripting output round-trips cleanly.

### ✨ Features

- **Hash-map value type (`LHash`) and eight operations.**
  `(hash-map k v …)`, `(hash-get m k [default])`, `(hash-set m k v)`,
  `(hash-del m k)`, `(hash-has? m k)`, `(hash-keys m)`, `(hash-vals m)`,
  `(hash? v)`. String keys, insertion-order preserving, structural (order-
  independent) equality.
- **`{k v k v …}` reader literal** — parser desugars braces into
  `(hash-map …)` so nested config maps read naturally.
- **String escapes round-trip through `lval_show`.** Real newlines, tabs,
  quotes and backslashes are re-escaped on display so `(println (str …))`
  produces readable output regardless of what's inside a string.
- **Structural equality for lists and hash-maps** — `=` now compares
  `LList`/`LList` and `LHash`/`LHash` structurally in addition to primitives.

### 📚 Docs

- README: new "Hash maps" and "String escapes" sections; `examples/hashmap.hl`
  listed in the examples table.
- `docs/hilisp-hica-guide.md`: hash-map subsection, escape-sequence limitation
  removed, built-in table extended.
- `examples/hashmap.hl`: runnable demo of the hash-map API.
- `lib/test-prelude.hl`: 15 new hash-map regression tests (116 total).

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
