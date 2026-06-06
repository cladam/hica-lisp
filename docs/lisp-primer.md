# Lisp Primer for HiLisp

New to Lisp? This short guide covers everything you need to read and write HiLisp
programs. No prior Lisp experience required.

## The one syntax rule

Every piece of code is either a **value** or a **call**:

```
value  →  42  |  true  |  "hello"  |  nil  |  my-name
call   →  (function arg1 arg2 …)
```

There are no operators, no statement keywords, no special punctuation
beyond parentheses. `(+ 1 2)` is a call to `+` with arguments `1` and `2`. The
function always comes first, inside the parens.

```lisp
(+ 1 2)          ; 3
(* 3 (+ 1 2))    ; 9  - calls nest naturally
(println "hi")   ; prints hi
```

The `;` starts a comment to end of line.

## Values

| Kind | Examples |
|------|----------|
| Number (integer) | `0` `42` `-7` |
| Boolean | `true` `false` |
| String | `"hello"` `"world"` |
| List | `(list 1 2 3)` |
| Nil | `nil` — the empty / absent value |
| Function | result of `fn` or `defn` |

## Defining names

```lisp
(def pi 3)
(def greeting "hello world")
```

`def` binds a name in the current environment. Use it at the top level for constants
and at the top of a file for configuration.

## Functions

### Named functions

```lisp
(defn square (x)
  (* x x))

(println (square 5))   ; 25
```

`defn` takes a name, a parameter list in parens, and a body expression.

### Anonymous functions (lambdas)

```lisp
(fn (x) (* x x))
```

Use `fn` when you want to pass a function as a value, for example to `map` or `filter`.

### Calling functions

```lisp
(square 4)            ; call by name → 16
((fn (x) (* x x)) 4)  ; call immediately → 16
```

## Conditionals

### `if`, two branches

```lisp
(if (> x 0) "positive" "non-positive")
```

All three parts are required: condition, then-expression, else-expression.

### `cond`, multiple branches

```lisp
(cond
  (= x 0) "zero"
  (< x 0) "negative"
  true    "positive")   ; true = catch-all default
```

`cond` tests each predicate in order and returns the matching expression.
Always include a `true` branch at the end as a default.

## Local bindings `let`

```lisp
(let (a 10
      b 20)
  (+ a b))   ; 30
```

`let` takes a flat list of `name value` pairs and a body. Bindings are visible only
inside the body.

## Lists

Lists are the core data structure in Lisp.

```lisp
(def xs (list 1 2 3 4 5))

(car xs)          ; 1 — first element
(cdr xs)          ; (2 3 4 5) — everything after the first
(cons 0 xs)       ; (0 1 2 3 4 5) — prepend an element
(length xs)       ; 5
```

`car` and `cdr` are historical names from the 50s, think of them as `head` and `tail`.

### Building lists with the prelude

Once you load `lib/prelude.hl`:

```lisp
(range 0 5)                               ; (0 1 2 3 4)
(map (fn (x) (* x x)) (list 1 2 3))       ; (1 4 9)
(filter (fn (x) (> x 2)) (list 1 2 3 4))  ; (3 4)
(fold + 0 (list 1 2 3 4 5))               ; 15
```

## Sequencing `do`

When you need more than one expression in a place that only accepts one:

```lisp
(do
  (println "step 1")
  (println "step 2")
  42)   ; value of the whole do-block
```

`do` evaluates each expression in order and returns the last one.

## Iteration with `loop`/`recur`

HiLisp has no `while` or `for`. The idiomatic replacement is `loop`/`recur`,
inspired by Clojure and Jank. `loop` establishes named bindings (like `let`);
`recur` restarts the loop with new values **without growing the call stack**.

```lisp
; Countdown — side effects per iteration
(loop [n 5]
  (if (= n 0)
    (println "done!")
    (do
      (println n)
      (recur (- n 1)))))
; 5 4 3 2 1 done!
```

The binding vector `[name init ...]` can hold multiple names — use this for
accumulator patterns:

```lisp
; Sum 1..100, O(1) stack
(loop [i 1 acc 0]
  (if (> i 100)
    acc
    (recur (+ i 1) (+ acc i))))
; 5050
```

`recur` must be in **tail position** — the very last thing evaluated in the
branch. A common mistake is placing `recur` before a `println`; swap them so
the print happens first.

### Recursion for naturally recursive problems

When the structure of the problem is recursive (trees, lists, divide-and-conquer)
use a named function instead:

```lisp
(defn sum-list (xs)
  (if (= (length xs) 0)
    0
    (+ (car xs) (sum-list (cdr xs)))))
```

For accumulating a result over a list, prefer `fold` from the prelude:

```lisp
(fold + 0 (list 1 2 3 4 5))   ; 15
```

## Quoting `'`

Normally `(foo 1 2)` calls `foo`. Sometimes you want the list itself, unevaluated.
Prefix with `'`:

```lisp
'(1 2 3)       ; the list (1 2 3), not a function call
'hello         ; the symbol hello, not a variable lookup
```

## Closures

Functions capture the environment where they were created:

```lisp
(defn make_adder (n)
  (fn (x) (+ x n)))   ; n is captured here

(def add10 (make_adder 10))
(println (add10 5))   ; 15
```

This lets you create specialised functions from general ones, a core Lisp pattern.

## Putting it together, a working example

```lisp
; Load the standard library first before running:
; ./hilisp lib/prelude.hl myscript.hl

(defn fizzbuzz (n)
  (cond
    (= (mod n 15) 0) "fizzbuzz"
    (= (mod n 3)  0) "fizz"
    (= (mod n 5)  0) "buzz"
    true             (str n)))

(loop [i 1]
  (if (> i 21)
    nil
    (do
      (println (fizzbuzz i))
      (recur (+ i 1)))))
```

## Next steps

- Browse the `examples/` directory, each file is a self-contained HiLisp program
- Read [hilisp-hica-guide.md](hilisp-hica-guide.md) for the full prelude
  function reference
- Open the REPL (`./hilisp`) and experiment interactively
