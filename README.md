# HiLisp - a small Lisp interpreter written in Hica

HiLisp is a tree-walking Lisp interpreter built entirely in
[hica](https://github.com/cladam/hica), a language that compiles to
[Koka](https://koka-lang.github.io). It serves as a proof of concept that hica is
expressive enough to implement a real language, including closures, recursion, and
higher-order functions.

Inspiration: **[Carp](https://carp-lang.github.io/Carp/LanguageGuide.html)** (special form vocabulary) and **[Jank](https://jank-lang.org/)** (`loop`/`recur` tail-recursive iteration).

## Quick start

```sh
# Run the REPL
./hilisp

# Run a .hl file
./hilisp examples/recursion.hl

# Build from source (requires hica ≥ 0.29.3 and Koka 3.2.3)
hica build -o hilisp
```

New to Lisp? Start with [docs/lisp-primer.md](docs/lisp-primer.md).

## Language overview

HiLisp is dynamically typed. Values are numbers, booleans, strings, lists, functions,
or nil. All code is an s-expression.

### Special forms

| Form | Description |
|------|-------------|
| `(def name val)` | Bind a value |
| `(defn name (p1 p2) body)` | Define a named function (supports recursion) |
| `(fn (p1 p2) body)` | Anonymous lambda |
| `(if cond then else)` | Conditional — all three branches required |
| `(cond p1 e1 p2 e2 …)` | Multi-branch; use `true` as final predicate for default |
| `(let (x 1 y 2) body)` | Local bindings |
| `(do e1 e2 …)` | Sequence; returns last value |
| `(quote x)` / `'x` | Quote — return unevaluated |
| `(loop [x init …] body)` | Tail-recursive loop with named bindings |
| `(recur v1 v2 …)` | Restart the enclosing `loop` with new values — no stack growth |

### Built-in functions

`+` `-` `*` `/` `=` `<` `>` `<=` `>=` `not` `and` `or` `null?` `empty?`  
`car` `cdr` `cons` `list` `length`  
`println` `str`  
`hash-map` `hash-get` `hash-set` `hash-del` `hash-has?` `hash-keys` `hash-vals` `hash?`

### Hash maps

Config-friendly key→value maps with string keys. Two constructors:

```lisp
(def a (hash-map "tabsize" 4 "theme" "gruvbox"))
(def b {"tabsize" 4 "theme" "gruvbox"})   ; reader literal, desugars to (hash-map …)

(hash-get a "theme")           ; → "gruvbox"
(hash-get a "missing" 99)      ; → 99  (default when key absent)
(hash-set a "theme" "nord")    ; → new map, original unchanged
(hash-keys a)                  ; → ("tabsize" "theme")
(= a b)                        ; → true (order-independent)
```

Maps nest freely:

```lisp
(def config {"editor" {"tabsize" 4} "ui" {"theme" "gruvbox"}})
(hash-get (hash-get config "editor") "tabsize")   ; → 4
```

See `examples/hashmap.hl` for the full API.

### String escapes

String literals support the usual escapes: `\n`, `\t`, `\r`, `\\`, `\"`.
Values round-trip through `lval_show`, so `(str …)` and `(println (str …))`
produce readable output regardless of embedded newlines or quotes.


### Example — recursion

```lisp
(defn factorial (n)
  (if (<= n 1) 1 (* n (factorial (- n 1)))))

(println (factorial 10))   ; 3628800
```

### Example — higher-order functions

```lisp
(defn make_adder (n) (fn (x) (+ x n)))
(def add10 (make_adder 10))
(println (add10 32))   ; 42
```

### Example — FizzBuzz with `loop`/`recur`

```lisp
(defn mod (a b) (- a (* b (/ a b))))

(defn fizzbuzz (n)
  (cond
    (= (mod n 15) 0) "fizzbuzz"
    (= (mod n 3)  0) "fizz"
    (= (mod n 5)  0) "buzz"
    true             n))

(loop [i 1]
  (if (<= i 20)
    (do (println (fizzbuzz i)) (recur (+ i 1)))
    nil))
```

### Example — accumulator with `loop`/`recur`

```lisp
; Sum 1..100 without recursion or stack growth
(def total
  (loop [i 1 acc 0]
    (if (> i 100)
      acc
      (recur (+ i 1) (+ acc i)))))

(println total)   ; 5050
```

## Examples

The `examples/` directory contains runnable `.hl` files:

| File | What it shows |
|------|---------------|
| `arithmetic.hl` | Basic operators, `def`, expressions |
| `functions.hl` | Higher-order functions, closures |
| `recursion.hl` | Factorial, Fibonacci, power |
| `lists.hl` | `car`/`cdr`/`cons`, `map`, `filter` |
| `closures.hl` | Closure factories, `compose` |
| `fizzbuzz.hl` | `cond`, loops, custom `mod` |
| `sorting.hl` | Merge sort and insertion sort |
| `statistics.hl` | Mean, median, variance, standard deviation |
| `higher_order.hl` | `scan`, `windows`, `flat_map`, `partition`, `enumerate` |
| `loop.hl` | `loop`/`recur` — countdown, accumulator sum, O(n) Fibonacci |
| `hashmap.hl` | Hash-map constructor, `{k v …}` reader literal, nested maps |

## Source layout

```
src/
  ast.hc        - LVal and Env types
  types.hc      - env_get / env_set
  tokeniser.hc  - source text → token list
  parser.hc     - token list → LVal AST
  display.hc    - lval_show
  builtins.hc   - built-in functions + make_env()
  eval.hc       - tree-walking evaluator
  lisp.hc       - barrel re-export
  main.hc       - CLI, REPL, file runner
```

## Standard library

Load `lib/prelude.hl` as the first argument to get a full set of list, math, and
string utilities:

```sh
./hilisp lib/prelude.hl examples/sorting.hl
```

See [docs/hilisp-hica-guide.md](docs/hilisp-hica-guide.md) for the full function reference.

## Known limitations

- `println` uses `lval_show`, so strings display with quotes.
- Recursive `defn` functions without `loop`/`recur` will stack-overflow on deep input — use `loop`/`recur` for iteration.

