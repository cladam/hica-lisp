// Tokeniser — turns raw source text into a flat list of tokens.
// Parens and the quote shorthand (') get padded with spaces so a simple split works.
pub fun tokenise(input: string) : list<string> {
  let step1 = replace(replace(input, "(", " ( "), ")", " ) ")
  let step2 = replace(step1, "'", " ' ")
  words(step2)
}