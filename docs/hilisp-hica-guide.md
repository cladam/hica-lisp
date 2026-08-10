# HiLisp Scripting Guide for hica development

*For contributors to the hica ecosystem who want to use HiLisp for scaffolding,
automation, and dev scripts instead of bash.*

## Why HiLisp for hica work?

HiLisp is built in hica. Maintaining it IS hica development — every HiLisp script
you write exercises the compiler and gives you real-world feedback. Beyond that:

- **No second language to install**: the `./hilisp` binary is in this repo
- **Multi-file scripts**: load a library then your script, sharing one environment
- **File I/O and shell exec**: enough to drive `hica check`, generate source files,
  and wire up build steps
- **REPL for exploration**: `./hilisp` with no args drops you into an interactive
  session

## Setup

From the `hica-lisp` repo root:

```sh
./hilisp          # start REPL
./hilisp myscript.hl                         # run a single script
./hilisp lib/prelude.hl myscript.hl          # load stdlib, then run script
```

The `examples/` directory has ready-to-run programs that show the full range of the
language and prelude:

```sh
./hilisp lib/prelude.hl examples/sorting.hl       # merge sort + insertion sort
./hilisp lib/prelude.hl examples/statistics.hl    # mean, median, variance, stdev
./hilisp lib/prelude.hl examples/higher_order.hl  # scan, windows, flat_map, partition
./hilisp examples/fizzbuzz.hl                      # cond, loops (no prelude needed)
```

Use `hica build -o hilisp` to rebuild the interpreter from source after changing
interpreter code.

---

## Language in 2 minutes

HiLisp is dynamically typed. All syntax is s-expressions: `(function arg1 arg2)`.

### Define values and functions

```lisp
(def version 1)

(defn greet (name)
  (println (str "hello " name)))
```

### Conditionals

```lisp
(if condition then-expr else-expr)   ; all three required

(cond
  (= x 0) "zero"
  (< x 0) "negative"
  true    "positive")               ; true = default branch
```

### Lists

```lisp
(list 1 2 3)             ; create
(car (list 1 2 3))       ; → 1  (head)
(cdr (list 1 2 3))       ; → (2 3)  (tail)
(cons 0 (list 1 2 3))    ; → (0 1 2 3)
(length (list 1 2 3))    ; → 3
```

### Lambdas and closures

```lisp
(defn make_adder (n) (fn (x) (+ x n)))
(def add5 (make_adder 5))
(println (add5 10))   ; 15
```

### Sequencing

```lisp
(do
  (println "step 1")
  (println "step 2"))
```

### String building

Use `str` to concatenate any number of values into a string:

```lisp
(def path "/tmp/out.txt")
(println (str "writing to " path))
(println (str "hello" " " "world"))   ; → hello world
```

String literals **can** contain spaces — the tokenizer handles them correctly.
The usual escape sequences work too: `\n`, `\t`, `\r`, `\\`, `\"`.

### Hash maps

Key→value maps with string keys — the natural shape for config. There's a
constructor and a `{…}` reader literal that desugars to it:

```lisp
(def cfg (hash-map "tabsize" 4 "theme" "gruvbox"))
(def cfg2 {"tabsize" 4 "theme" "gruvbox"})   ; same thing

(hash-get cfg "theme")           ; → "gruvbox"
(hash-get cfg "missing" 99)      ; → 99  (default when absent)
(hash-set cfg "theme" "nord")    ; → new map, original untouched
(hash-keys cfg)                  ; → ("tabsize" "theme")
(hash-has? cfg "theme")          ; → true
(hash? cfg)                      ; → true
(= cfg cfg2)                     ; → true (order-independent)
```

Maps nest — useful for grouped config sections:

```lisp
(def config {"editor" {"tabsize" 4} "ui" {"theme" "gruvbox"}})
(hash-get (hash-get config "editor") "tabsize")   ; → 4
```

### Symbols

`'name` produces a symbol — distinct type from string, so hosts can dispatch on
`'save` without confusion with `"save"`.

```lisp
(symbol? 'save)          ; → true
(symbol-name 'save)      ; → "save"
(= 'save 'save)          ; → true   (name-based, ignores source span)
(= 'save "save")         ; → false
```

Useful pattern for command tables:

```lisp
(defn dispatch (action)
  (cond
    (= action 'save) (println "saving…")
    (= action 'quit) (println "goodbye")
    true             (println "unknown action")))
```

### Source-located runtime errors

Any error from a built-in call is annotated with the calling form's line and
column, so `init.hl` typos surface with a Rust-style caret snippet:

```
error[type/wrong-type]: hash-get expects (hash key) or (hash key default)
  --> init.hl:3:2
   |
 3 | (hash-get)
   |  ^
```

## Built-in functions

| Function | Description |
|---|---|
| `+` `-` `*` `/` | Arithmetic |
| `=` `<` `>` `<=` `>=` | Comparison (structural equality for lists and hashes) |
| `not` `and` `or` | Logic |
| `car` `cdr` `cons` `list` `length` | List primitives |
| `hash-map` `hash-get` `hash-set` `hash-del` | Hash-map ops (string keys) |
| `hash-has?` `hash-keys` `hash-vals` `hash?` | Hash-map inspection |
| `symbol?` `symbol-name` | Symbol test / name extraction |
| `str arg…` | Concatenate any values into a string |
| `println arg…` | Print without quotes, newline at end |
| `write-file path content` | Write string to file; returns `nil` or `error: …` |
| `exec cmd` | Run shell command; returns stdout (trimmed) or `error: …` |

---

## Standard library `lib/prelude.hl`

Load it as the first file argument:

```sh
./hilisp lib/prelude.hl yourscript.hl
```

### List functions

| Function | Example |
|---|---|
| `(range lo hi)` | `(range 0 5)` → `(0 1 2 3 4)` |
| `(take n xs)` | `(take 2 (list 10 20 30))` → `(10 20)` |
| `(drop n xs)` | `(drop 2 (list 10 20 30))` → `(30)` |
| `(take_while pred xs)` | elements from front while pred holds |
| `(drop_while pred xs)` | skip elements from front while pred holds |
| `(concat xs ys)` | append two lists |
| `(reverse xs)` | `(reverse (list 1 2 3))` → `(3 2 1)` |
| `(nth n xs)` | 0-based index |
| `(last xs)` | last element |
| `(flatten xs)` | one level of nesting removed |
| `(contains x xs)` | true if x is in xs |
| `(replicate n x)` | list of n copies of x |
| `(intersperse sep xs)` | insert sep between every element |
| `(windows n xs)` | sliding windows of size n |
| `(partition pred xs)` | `((matches) (non-matches))` |
| `(find pred xs)` | first matching element or nil |
| `(count_if pred xs)` | count of elements satisfying pred |
| `(enumerate xs)` | `((0 x0) (1 x1) …)` |

### Higher-order functions

| Function | Example |
|---|---|
| `(fold f acc xs)` | `(fold + 0 (list 1 2 3))` → `6` |
| `(map f xs)` | apply f to every element |
| `(filter pred xs)` | keep elements where pred is true |
| `(any pred xs)` | `(any (fn (x) (= x 0)) xs)` |
| `(all pred xs)` | all elements satisfy pred |
| `(zip xs ys)` | `(zip (list 1 2) (list 3 4))` → `((1 3) (2 4))` |
| `(zip_with f xs ys)` | apply f to paired elements |
| `(flat_map f xs)` | map then flatten one level |
| `(scan f acc xs)` | running fold — all intermediate accumulators |

### Math

`abs` `mod` `max2` `min2` `sum` `product` `clamp` `inc` `dec` `even` `odd` `square` `gcd` `lcm`

### String

`(repeat_str s n)`: repeat string n times  
`(join sep xs)`: concatenate a list of strings with a separator

### Tests

A 101-test regression suite lives at `lib/test-prelude.hl`:

```sh
./hilisp lib/prelude.hl lib/test-prelude.hl
```

This is also run in CI after building the interpreter.

## Scripting patterns

### Check a hica file and report

```lisp
(def result (exec "hica check src/parser.hc"))
(println result)
```

### Generate a file

```lisp
(def content (str "// generated\npub fun hello() => println(\"hello\")"))
(write-file "src/generated.hc" content)
(println "written")
```

`\n` becomes a real newline in the written file, as expected. `\t`, `\r`, `\\`,
and `\"` are supported likewise.

### Iterate a list and run a command per item

```lisp
(defn check_files (files)
  (if (= (length files) 0)
    (println "done")
    (do
      (println (exec (str "hica check " (car files))))
      (check_files (cdr files)))))

(check_files (list "src/ast.hc" "src/parser.hc" "src/eval.hc"))
```

### Multi-file scripts — share state across files

All files passed to `./hilisp` share one environment, in order:

```sh
./hilisp lib/prelude.hl lib/my-helpers.hl scripts/gen-tests.hl
```

Anything defined in an earlier file is visible to all later files.

## Known limitations

| Limitation | Workaround |
|---|---|
| `exec` command string can't contain spaces in parts | Build the command string with `str` |
| No tail-call optimisation for `defn` | Use `loop`/`recur` for iteration |
| No file-system listing | Use `exec "ls ..."` and parse the output |
| Hash-map keys are strings only | Coerce with `(str …)` on the way in |

## Workflow: scripting a hica build step

A realistic script that checks all source files and reports errors:

```lisp
; scripts/check-all.hl — run with ./hilisp lib/prelude.hl scripts/check-all.hl

(def sources (list "src/ast.hc"
                   "src/tokeniser.hc"
                   "src/parser.hc"
                   "src/display.hc"
                   "src/builtins.hc"
                   "src/eval.hc"
                   "src/main.hc"))

(defn check_one (path)
  (let (result (exec (str "hica check " path)))
    (println (str path ": " result))))

(defn check_all (files)
  (if (= (length files) 0)
    (println "all done")
    (do
      (check_one (car files))
      (check_all (cdr files)))))

(check_all sources)
```

Run it:

```sh
./hilisp lib/prelude.hl scripts/check-all.hl
```
