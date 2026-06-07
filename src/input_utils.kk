// input_utils.kk — historical workaround; no longer imported by builtins.hc.
//
// The hica compiler (v0.30+) now emits hica-fflush() + hica-readline-prompt()
// directly into any generated .kk file that uses input(). Both fixes are now
// baked into hica's codegen:
//   - stdout flushed before blocking on stdin (macOS buffering fix)
//   - empty string returned on EOF instead of throwing an exception
//
// This file is kept for reference only.
module input_utils

import std/os/readline

// Flush stdout so any buffered prompt text appears before blocking on stdin.
extern fflush-stdout() : io ()
  c inline "(fflush(stdout),kk_Unit)"

// Display prompt, flush stdout, read a line.
// Returns empty string on EOF or read error instead of throwing.
pub fun readline-prompt(prompt: string) : io string
  print(prompt)
  fflush-stdout()
  match try(readline)
    Ok(s)    -> s
    Error(_) -> ""
