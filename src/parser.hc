import "./ast"
import "./types"

// Entry point for recursive-descent parsing — consumes one expression and returns the remainder
pub fun parse_tokens(tokens: list<string>) : (LVal, list<string>) =>
  match tokens {
    []              => (LNil, []),
    ["'", ..rest]   => parse_quote(rest),
    ["(", ..rest]   => parse_list(rest, []),
    [")", ..rest]   => (LNil, rest),
    [tok, ..rest]   => (parse_atom(tok), rest)
  }

// Reader macro: 'x => (quote x)
pub fun parse_quote(tokens: list<string>) : (LVal, list<string>) {
  let (val, rest) = parse_tokens(tokens)
  (LList([LSym("quote"), val]), rest)
}

// parse_list accumulates items until ")" then returns LList
pub fun parse_list(tokens: list<string>, acc: list<LVal>) : (LVal, list<string>) =>
  match tokens {
    []             => (LList(acc), []),          // unterminated list — return what we have
    [")", ..rest]  => (LList(acc), rest),         // closing paren — done
    _              => {
      let (item, rest) = parse_tokens(tokens)
      parse_list(rest, acc + [item])
    }
  }

// Classify a single token as a number, boolean, string literal, or symbol
pub fun parse_atom(tok: string) : LVal =>
  match parse_int(tok) {
    Some(n) => LNum(n),
    None    =>
      if tok == "true" { LBool(true) }
      else if tok == "false" { LBool(false) }
      else if starts_with(tok, "\"") { LStr(tok[1:str_length(tok) - 1]) }
      else { LSym(tok) }
  }

test "parse_atom: numbers and symbols" {
  let r1 = match parse_atom("42")  { LNum(n) => n == 42,   _ => false }
  let r2 = match parse_atom("foo") { LSym(s) => s == "foo", _ => false }
  assert(r1)
  assert(r2)
}

test "parse_atom: booleans" {
  let t = match parse_atom("true")  { LBool(b) => b == true,  _ => false }
  let f = match parse_atom("false") { LBool(b) => b == false, _ => false }
  assert(t)
  assert(f)
}

test "parse_tokens: parses a list and consumes closing paren" {
  let (v, rest) = parse_tokens(["(", "+", "1", "2", ")"])
  let is_list   = match v { LList(_) => true, _ => false }
  assert_eq(rest, [])
  assert(is_list)
}

test "parse_tokens: quote shorthand expands to (quote x)" {
  let (v, rest) = parse_tokens(["'", "x"])
  let is_quote  = match v { LList([LSym(q), LSym(_)]) => q == "quote", _ => false }
  assert_eq(rest, [])
  assert(is_quote)
}