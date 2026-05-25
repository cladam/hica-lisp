// main.hc — HiLisp entry point: REPL and file runner

import "std/cli"
import "std/io"
import "./lisp"

// Parse and eval one expression, return display string + new env
fun eval_str(src: string, env: Env) {
  let tokens = tokenise(src)
  let (expr, _) = parse_tokens(tokens)
  let (result, env2) = eval(expr, env)
  (lval_show(result), env2)
}

// Eval all top-level forms in a token stream; returns the final env
fun run_forms(tokens: list<string>, env: Env) : Env {
  if length(tokens) > 0 {
    let (expr, rest) = parse_tokens(tokens)
    let (_, env2) = eval(expr, env)
    run_forms(rest, env2)
  } else {
    env
  }
}

// Interactive REPL loop
fun repl(env: Env) {
  let src = input("hilisp=> ")
  if src == "(quit)" || src == ":quit" || src == "(exit)" {
    println("bye!")
  } else {
    let (out, env2) = eval_str(src, env)
    println(out)
    repl(env2)
  }
}

// Load one file into an existing env; returns the updated env
fun load_file(path: string, env: Env) : Env {
  match read_file(path) {
    Ok(content) => run_forms(tokenise(content), env),
    Err(msg)    => { eprintln("error: {path}: {msg}"); env }
  }
}

// Run a list of files sequentially, sharing the same env
fun run_files(files: list<string>, env: Env) {
  match files {
    []             => {},
    [path, ..rest] => run_files(rest, load_file(path, env))
  }
}

// Dispatch: one or more files → run them (shared env); no files → REPL
fun run(r) {
  let files = get_positionals(r)
  if length(files) > 0 {
    let env = make_env()
    run_files(files, env)
  } else {
    println("HiLisp 0.3.0 — type (quit) to exit")
    let env = make_env()
    repl(env)
  }
}

fun make_spec() =>
  cli("hilisp", "0.3.0", "a small Lisp interpreter in Hica")
    |> arg("file", "source file(s) to run — multiple files share one env (omit for REPL)", false)

fun main() {
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: {msg}"),
    Parsed(r)     => run(r)
  }
}
