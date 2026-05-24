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

// Eval all top-level forms in a token stream, threading env through
fun run_forms(tokens: list<string>, env: Env) {
  if length(tokens) > 0 {
    let (expr, rest) = parse_tokens(tokens)
    let (_, env2) = eval(expr, env)
    run_forms(rest, env2)
  }
}

// Interactive REPL loop
fun repl(env: Env) {
  let src = input("hilisp> ")
  if src == "(quit)" || src == ":quit" || src == "(exit)" {
    println("bye!")
  } else {
    let (out, env2) = eval_str(src, env)
    println(out)
    repl(env2)
  }
}

// Run a HiLisp source file
fun run_file(path: string) {
  match read_file(path) {
    Ok(content) => {
      let env = make_env()
      run_forms(tokenise(content), env)
    },
    Err(msg) => eprintln("error: could not read {path}: {msg}")
  }
}

// Dispatch: file argument → run file, no argument → REPL
fun run(r) {
  match get_positional(r, 0) {
    Some(path) => run_file(path),
    None => {
      println("HiLisp 0.1.0 — type (quit) to exit")
      let env = make_env()
      repl(env)
    }
  }
}

fun make_spec() =>
  cli("hilisp", "0.1.0", "a small Lisp interpreter in Hica")
    |> arg("file", "Lisp source file to run (omit for REPL)", false)

fun main() {
  let spec = make_spec()
  match cli_parse(spec) {
    Help          => println(cli_help(spec)),
    Version       => println(cli_version_str(spec)),
    CliError(msg) => eprintln("error: {msg}"),
    Parsed(r)     => run(r)
  }
}
