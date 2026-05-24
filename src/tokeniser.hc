// Tokeniser — turns raw source text into a flat list of tokens.
// Parens and the quote shorthand (') get padded with spaces so a simple split works.
pub fun tokenise(input: string) : list<string> {
  let step1 = replace(replace(input, "(", " ( "), ")", " ) ")
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