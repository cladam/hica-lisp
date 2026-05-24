# Building a Lisp in hica – HiLisp, or just hica-lisp

## Premise

What if hica could be used to build external DSLs, or even languages like a Lisp?

Inspiration: **[Carp](https://carp-lang.github.io/Carp/LanguageGuide.html)**, a Lisp
with ML/Rust-like semantics: statically typed, ownership-aware, pattern matching,
sumtypes, modules, and interfaces. 

hica compiles to Koka but will borrow Carp's rich set of *special forms* and its vocabulary of `defn`, `def`, `let`, `do`, `cond`, `fn`, `match`, `quote`, and `use`.

## Usage

```sh
hica build   # compile to binary
hica run     # compile and run
hica fmt     # format according to hica style guide
hica check   # type-check without emitting
hica clean   # remove generated files
```
