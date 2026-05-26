// Tokeniser — character-by-character scanner that correctly handles
// string literals containing spaces, parens, and other special chars.

// Flush accumulated token into acc list if non-empty
pub fun flush_tok(cur: string, acc: list<string>) : list<string> =>
  if str_length(cur) == 0 { acc } else { acc + [cur] }

// skip_comment: advance past the rest of a ; line comment (up to and including the newline)
pub fun skip_comment(src: string, i: int) : int =>
  if i >= str_length(src) { i }
  else if src[i : i + 1] == "\n" { i + 1 }
  else { skip_comment(src, i + 1) }

// char_scan: walk src[i..] character by character.
// cur  = token being accumulated
// acc  = completed tokens so far
// in_str = true when inside a "..." literal
// (named char_scan, not scan, to avoid clashing with Koka's built-in scan)
pub fun char_scan(src: string, i: int, cur: string, acc: list<string>, in_str: bool) : list<string> {
  if i >= str_length(src) {
    flush_tok(cur, acc)
  } else {
    let c = src[i:i+1]
    if in_str {
      if c == "\"" {
        // Closing quote — emit the complete string token
        char_scan(src, i + 1, "", acc + [cur + "\""], false)
      } else if c == "\\" {
        // Escape sequence — peek at next character and translate
        let next = src[i+1:i+2]
        if next == "n" {
          char_scan(src, i + 2, cur + "\n", acc, true)
        } else if next == "t" {
          char_scan(src, i + 2, cur + "\t", acc, true)
        } else if next == "r" {
          char_scan(src, i + 2, cur + "\r", acc, true)
        } else if next == "\\" {
          char_scan(src, i + 2, cur + "\\", acc, true)
        } else if next == "\"" {
          char_scan(src, i + 2, cur + "\"", acc, true)
        } else {
          // Unknown or dangling escape — keep as-is
          char_scan(src, i + 1, cur + "\\", acc, true)
        }
      } else {
        char_scan(src, i + 1, cur + c, acc, true)
      }
    } else {
      if c == "\"" {
        // Opening quote — flush any current symbol, start a string token
        char_scan(src, i + 1, "\"", flush_tok(cur, acc), true)
      } else if c == "(" {
        char_scan(src, i + 1, "", flush_tok(cur, acc) + ["("], false)
      } else if c == ")" {
        char_scan(src, i + 1, "", flush_tok(cur, acc) + [")"], false)
      } else if c == "'" {
        char_scan(src, i + 1, "", flush_tok(cur, acc) + ["'"], false)
      } else if c == ";" {
        // Line comment — skip to end of line via recursive helper
        char_scan(src, skip_comment(src, i + 1), "", flush_tok(cur, acc), false)
      } else if c == " " || c == "\n" || c == "\t" || c == "\r" {
        char_scan(src, i + 1, "", flush_tok(cur, acc), false)
      } else {
        char_scan(src, i + 1, cur + c, acc, false)
      }
    }
  }
}

pub fun tokenise(input: string) : list<string> {
  char_scan(input, 0, "", [], false)
}

test "tokenise basic expression" {
  assert_eq(tokenise("(+ 1 2)"), ["(", "+", "1", "2", ")"])
}

test "tokenise nested expression" {
  assert_eq(tokenise("(+ 1 (* 2 3))"), ["(", "+", "1", "(", "*", "2", "3", ")", ")"])
}

test "tokenise quote shorthand" {
  assert_eq(tokenise("'x"), ["'", "x"])
}

test "tokenise multi-line expression" {
  let src = "(defn foo (x)\n  (* x x))"
  assert_eq(tokenise(src), ["(", "defn", "foo", "(", "x", ")", "(", "*", "x", "x", ")", ")"])
}

test "tokenise string literal with spaces" {
  assert_eq(tokenise("\"hello world\""), ["\"hello world\""])
}

test "tokenise string literal with comma-space separator" {
  assert_eq(tokenise("(join \", \" xs)"), ["(", "join", "\", \"", "xs", ")"])
}

test "tokenise string literal with parens inside" {
  assert_eq(tokenise("\"a(b)c\""), ["\"a(b)c\""])
}

test "tokenise string escape sequences" {
  // \n becomes an actual newline; \t becomes a tab; \\ becomes a backslash
  assert_eq(tokenise("\"a\\nb\""), ["\"a\nb\""])
  assert_eq(tokenise("\"a\\tb\""), ["\"a\tb\""])
  assert_eq(tokenise("\"a\\\\b\""), ["\"a\\b\""])
}