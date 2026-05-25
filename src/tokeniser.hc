// Tokeniser — character-by-character scanner that correctly handles
// string literals containing spaces, parens, and other special chars.

// Flush accumulated token into acc list if non-empty
fun flush_tok(cur: string, acc: list<string>) : list<string> =>
  if str_length(cur) == 0 { acc } else { acc + [cur] }

// Scan src[i..] character by character.
// cur  = token being accumulated
// acc  = completed tokens so far
// in_str = true when inside a "..." literal
fun scan(src: string, i: int, cur: string, acc: list<string>, in_str: bool) : list<string> {
  if i >= str_length(src) {
    flush_tok(cur, acc)
  } else {
    let c = src[i:i+1]
    if in_str {
      if c == "\"" {
        // Closing quote — emit the complete string token
        scan(src, i + 1, "", acc + [cur + "\""], false)
      } else {
        scan(src, i + 1, cur + c, acc, true)
      }
    } else {
      if c == "\"" {
        // Opening quote — flush any current symbol, start a string token
        scan(src, i + 1, "\"", flush_tok(cur, acc), true)
      } else if c == "(" {
        scan(src, i + 1, "", flush_tok(cur, acc) + ["("], false)
      } else if c == ")" {
        scan(src, i + 1, "", flush_tok(cur, acc) + [")"], false)
      } else if c == "'" {
        scan(src, i + 1, "", flush_tok(cur, acc) + ["'"], false)
      } else if c == " " || c == "\n" || c == "\t" || c == "\r" {
        scan(src, i + 1, "", flush_tok(cur, acc), false)
      } else {
        scan(src, i + 1, cur + c, acc, false)
      }
    }
  }
}

pub fun tokenise(input: string) : list<string> {
  scan(input, 0, "", [], false)
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