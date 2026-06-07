import "./ast"
import "./types"
import "./tokeniser"

// Helper for tests — creates a Token with a dummy source position
fun mk_tok(text: string) : Token => Token(text, 0, 0)

// Entry point for recursive-descent parsing — consumes one expression and returns the remainder
pub fun parse_tokens(tokens: list<Token>) : (LVal, list<Token>) =>
  match tokens {
    []           => (LNil, []),
    [t, ..rest]  =>
      if tok_text(t) == "'" { parse_quote(rest) }
      else if tok_text(t) == "(" { parse_list(rest, []) }
      else if tok_text(t) == ")" { (LNil, rest) }
      else { (parse_atom(t), rest) }
  }

// Reader macro: 'x => (quote x)
pub fun parse_quote(tokens: list<Token>) : (LVal, list<Token>) {
  let (v, rest) = parse_tokens(tokens)
  (LList([LSym("quote"), v]), rest)
}

// parse_list accumulates items until ")" then returns LList
pub fun parse_list(tokens: list<Token>, acc: list<LVal>) : (LVal, list<Token>) =>
  match tokens {
    []           => (LList(acc), []),            // unterminated list — return what we have
    [t, ..rest]  =>
      if tok_text(t) == ")" { (LList(acc), rest) }    // closing paren — done
      else {
        let (item, rest2) = parse_tokens(tokens)
        parse_list(rest2, acc + [item])
      }
  }

// Classify a single token as a number, boolean, string literal, or symbol
pub fun parse_atom(t: Token) : LVal =>
  match parse_int(tok_text(t)) {
    Some(n) => LNum(n),
    None    =>
      if tok_text(t) == "true" { LBool(true) }
      else if tok_text(t) == "false" { LBool(false) }
      else if starts_with(tok_text(t), "\"") { LStr(tok_text(t)[1:str_length(tok_text(t)) - 1]) }
      else { LSym(tok_text(t)) }
  }

test "parse_atom: numbers and symbols" {
  let r1 = match parse_atom(mk_tok("42"))  { LNum(n) => n == 42,   _ => false }
  let r2 = match parse_atom(mk_tok("foo")) { LSym(s) => s == "foo", _ => false }
  assert(r1)
  assert(r2)
}

test "parse_atom: booleans" {
  let t = match parse_atom(mk_tok("true"))  { LBool(b) => b == true,  _ => false }
  let f = match parse_atom(mk_tok("false")) { LBool(b) => b == false, _ => false }
  assert(t)
  assert(f)
}

test "parse_tokens: parses a list and consumes closing paren" {
  let (v, rest) = parse_tokens([mk_tok("("), mk_tok("+"), mk_tok("1"), mk_tok("2"), mk_tok(")")])
  let is_list   = match v { LList(_) => true, _ => false }
  assert_eq(rest, [])
  assert(is_list)
}

test "parse_tokens: quote shorthand expands to (quote x)" {
  let (v, rest) = parse_tokens([mk_tok("'"), mk_tok("x")])
  let is_quote  = match v { LList([LSym(q), LSym(_)]) => q == "quote", _ => false }
  assert_eq(rest, [])
  assert(is_quote)
}