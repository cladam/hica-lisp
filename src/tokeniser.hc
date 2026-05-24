// Tokeniser — turns raw source text into a flat list of tokens.
// Pads parens and quote shorthand so a simple split works.
// Also normalise whitespace (tabs, newlines) to spaces so multi-line
// source files tokenise correctly.
pub fun tokenise(input: string) : list<string> {
  let step0 = replace(replace(input, "\n", " "), "\t", " ")
  let step1 = replace(replace(step0, "(", " ( "), ")", " ) ")
  let step2 = replace(step1, "'", " ' ")
  words(step2)
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