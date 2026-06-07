// Tokeniser — character-by-character scanner that correctly handles
// string literals containing spaces, parens, and other special chars.
// Each token carries its source location (1-based line and column).
import "./ast"

// A lexed token with its text and source position
// (defined in ast.hc so it is universally accessible)

// Flush accumulated token into acc list if non-empty
pub fun flush_tok(cur: string, tok_line: int, tok_col: int, acc: list<Token>) : list<Token> =>
  if str_length(cur) == 0 { acc } else { acc + [Token(cur, tok_line, tok_col)] }

// skip_comment: advance past the rest of a ; line comment (up to and including the newline)
pub fun skip_comment(src: string, i: int) : int =>
  if i >= str_length(src) { i }
  else if src[i : i + 1] == "\n" { i + 1 }
  else { skip_comment(src, i + 1) }

// char_scan: walk src[i..] character by character.
// line, col       = current source position (1-based)
// cur             = token text being accumulated
// tok_line/col    = start position of the token in cur (valid when cur is non-empty)
// acc             = completed tokens so far
// in_str          = true when inside a "..." literal
// (named char_scan, not scan, to avoid clashing with Koka's built-in scan)
pub fun char_scan(src: string, i: int, line: int, col: int, cur: string, tok_line: int, tok_col: int, acc: list<Token>, in_str: bool) : list<Token> {
  if i >= str_length(src) {
    flush_tok(cur, tok_line, tok_col, acc)
  } else {
    let c = src[i:i+1]
    if in_str {
      if c == "\"" {
        // Closing quote — emit the complete string token
        let new_acc = flush_tok(cur + "\"", tok_line, tok_col, acc)
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == "\\" {
        // Escape sequence — peek at next character and translate
        let next = src[i+1:i+2]
        if next == "n" {
          char_scan(src, i + 2, line, col + 2, cur + "\n", tok_line, tok_col, acc, true)
        } else if next == "t" {
          char_scan(src, i + 2, line, col + 2, cur + "\t", tok_line, tok_col, acc, true)
        } else if next == "r" {
          char_scan(src, i + 2, line, col + 2, cur + "\r", tok_line, tok_col, acc, true)
        } else if next == "\\" {
          char_scan(src, i + 2, line, col + 2, cur + "\\", tok_line, tok_col, acc, true)
        } else if next == "\"" {
          char_scan(src, i + 2, line, col + 2, cur + "\"", tok_line, tok_col, acc, true)
        } else {
          // Unknown or dangling escape — keep as-is
          char_scan(src, i + 1, line, col + 1, cur + "\\", tok_line, tok_col, acc, true)
        }
      } else if c == "\n" {
        // Newline inside a string literal — update line tracking for later tokens
        char_scan(src, i + 1, line + 1, 1, cur + c, tok_line, tok_col, acc, true)
      } else {
        char_scan(src, i + 1, line, col + 1, cur + c, tok_line, tok_col, acc, true)
      }
    } else {
      if c == "\"" {
        // Opening quote — flush any current symbol, start a string token
        let new_acc = flush_tok(cur, tok_line, tok_col, acc)
        char_scan(src, i + 1, line, col + 1, "\"", line, col, new_acc, true)
      } else if c == "(" {
        let new_acc = flush_tok(cur, tok_line, tok_col, acc) + [Token("(", line, col)]
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == ")" {
        let new_acc = flush_tok(cur, tok_line, tok_col, acc) + [Token(")", line, col)]
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == "[" {
        // Square brackets are syntactic sugar for lists (binding vectors, param lists)
        let new_acc = flush_tok(cur, tok_line, tok_col, acc) + [Token("(", line, col)]
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == "]" {
        let new_acc = flush_tok(cur, tok_line, tok_col, acc) + [Token(")", line, col)]
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == "'" {
        let new_acc = flush_tok(cur, tok_line, tok_col, acc) + [Token("'", line, col)]
        char_scan(src, i + 1, line, col + 1, "", 0, 0, new_acc, false)
      } else if c == ";" {
        // Line comment — skip to end of line; next token is on the following line
        let new_acc = flush_tok(cur, tok_line, tok_col, acc)
        char_scan(src, skip_comment(src, i + 1), line + 1, 1, "", 0, 0, new_acc, false)
      } else if c == " " || c == "\n" || c == "\t" || c == "\r" {
        let new_acc  = flush_tok(cur, tok_line, tok_col, acc)
        let new_line = if c == "\n" { line + 1 } else { line }
        let new_col  = if c == "\n" { 1 } else { col + 1 }
        char_scan(src, i + 1, new_line, new_col, "", 0, 0, new_acc, false)
      } else {
        // Normal char — start a new token or continue accumulating
        let new_tok_line = if str_length(cur) == 0 { line } else { tok_line }
        let new_tok_col  = if str_length(cur) == 0 { col  } else { tok_col  }
        char_scan(src, i + 1, line, col + 1, cur + c, new_tok_line, new_tok_col, acc, false)
      }
    }
  }
}

pub fun tokenise(input: string) : list<Token> {
  char_scan(input, 0, 1, 1, "", 0, 0, [], false)
}

// Extract just the token texts — useful in tests and error display
pub fun tok_texts(toks: list<Token>) : list<string> => map(toks, (t) => tok_text(t))

test "tokenise basic expression" {
  assert_eq(tok_texts(tokenise("(+ 1 2)")), ["(", "+", "1", "2", ")"])
}

test "tokenise nested expression" {
  assert_eq(tok_texts(tokenise("(+ 1 (* 2 3))")), ["(", "+", "1", "(", "*", "2", "3", ")", ")"])
}

test "tokenise quote shorthand" {
  assert_eq(tok_texts(tokenise("'x")), ["'", "x"])
}

test "tokenise multi-line expression" {
  let src = "(defn foo (x)\n  (* x x))"
  assert_eq(tok_texts(tokenise(src)), ["(", "defn", "foo", "(", "x", ")", "(", "*", "x", "x", ")", ")"])
}

test "tokenise string literal with spaces" {
  assert_eq(tok_texts(tokenise("\"hello world\"")), ["\"hello world\""])
}

test "tokenise string literal with comma-space separator" {
  assert_eq(tok_texts(tokenise("(join \", \" xs)")), ["(", "join", "\", \"", "xs", ")"])
}

test "tokenise string literal with parens inside" {
  assert_eq(tok_texts(tokenise("\"a(b)c\"")), ["\"a(b)c\""])
}

test "tokenise string escape sequences" {
  // \n becomes an actual newline; \t becomes a tab; \\ becomes a backslash
  assert_eq(tok_texts(tokenise("\"a\\nb\"")), ["\"a\nb\""])
  assert_eq(tok_texts(tokenise("\"a\\tb\"")), ["\"a\tb\""])
  assert_eq(tok_texts(tokenise("\"a\\\\b\"")), ["\"a\\b\""])
}

test "tokenise tracks line and column" {
  let toks = tokenise("a\nb")
  let a_line = match toks { [a, _] => tok_line(a) == 1, _ => false }
  let a_col  = match toks { [a, _] => tok_col(a)  == 1, _ => false }
  let b_line = match toks { [_, b] => tok_line(b) == 2, _ => false }
  let b_col  = match toks { [_, b] => tok_col(b)  == 1, _ => false }
  assert(a_line)
  assert(a_col)
  assert(b_line)
  assert(b_col)
}