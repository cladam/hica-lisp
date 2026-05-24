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