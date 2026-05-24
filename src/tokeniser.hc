// tokeniser, should it be living on its own?

pub fun tokenise(input: string) : list<string> {
  let step1 = replace(replace(input, "(", " ( "), ")", " ) ")
  let step2 = replace(step1, "'", " ' ")
  split(trim(step2), " ") |> filter((s) => str_length(s) > 0)
}