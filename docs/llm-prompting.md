# Prompting LLMs with HiLisp

HiLisp is a natural fit for structured LLM interaction. S-expressions are unambiguously
nested, easy to validate, and LLMs already know Lisp from training data. This guide
shows how to use HiLisp's `exec` and `eval` builtins to call an LLM API and execute
its response as live code.

---

## The idea

Instead of asking an LLM to return JSON and then parsing it, ask it to return an
s-expression. HiLisp can evaluate that string directly — the grammar *is* the schema.

```
Prompt: "Respond only with a HiLisp s-expression."

LLM response: "(do (println \"London\") (println \"rainy\"))"
```

```lisp
(eval llm-response)   ; executes: prints "London", then "rainy"
```

No JSON parser. No schema validation. If the parens balance, it runs.

---

## The `eval` special form

```lisp
(eval src)
```

- `src` must evaluate to a string
- The string is parsed as a HiLisp expression and evaluated in the **current env**
- Bindings created inside the eval'd code (`def`, `defn`) persist into the calling env

```lisp
(eval "(+ 10 32)")                  ; → 42
(eval "(def greeting \"hello\")")   ; defines greeting in scope
(println greeting)                   ; → hello
```

---

## Environment variables in `exec`

`exec` inherits the full environment of the parent process, so any variable exported
in your shell is visible inside the command string:

```lisp
(exec "echo $GEMINI_API_KEY")   ; returns the key value as a string
```

Set the key before running HiLisp:

```sh
export GEMINI_API_KEY="your-key-here"
./hilisp lib/prelude.hl examples/llm-eval.hl
```

---

## Calling Gemini with `exec`

`exec` shells out and returns stdout as a string. The Gemini REST API takes a JSON
body and returns candidates:

```lisp
(defn ask (prompt)
  (exec (str
    "curl -s https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY "
    "-H \"Content-Type: application/json\" "
    "-d \"{\\\"contents\\\":[{\\\"parts\\\":[{\\\"text\\\":\\\""
    prompt
    "\\\"}]}]}\" "
    "| jq -r '.candidates[0].content.parts[0].text'")))
```

Usage:

```lisp
(def response (ask "Reply with a HiLisp expression that prints the answer to life."))
(println response)   ; inspect before eval-ing
(eval response)      ; execute it
```

> **Safety note**: Only `eval` a response you trust or have validated. An untrusted
> response can call `exec` or `write-file`. See the sandboxing section below.

---

## Structured tool calls

Define a vocabulary of functions in HiLisp, then ask the LLM to compose them:

```lisp
(defn search (query)
  (exec (str "curl -s 'https://search.example.com/api?q=" query "'")))

(defn summarise (text)
  (exec (str "echo '" text "' | llm summarise")))

; ask Gemini to compose a program from the available tools
(defn ask-gemini (system-prompt task)
  (exec (str
    "curl -s https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY "
    "-H \"Content-Type: application/json\" "
    "-d \"{\\\"system_instruction\\\":{\\\"parts\\\":[{\\\"text\\\":\\\""
    system-prompt
    "\\\"}]},\\\"contents\\\":[{\\\"parts\\\":[{\\\"text\\\":\\\""
    task
    "\\\"}]}]}\" "
    "| jq -r '.candidates[0].content.parts[0].text'")))

(defn save (path content)
  (write-file path content))
```

Prompt the LLM:

```
You have access to these HiLisp functions:
  (search query)        — web search, returns result string
  (summarise text)      — summarise a block of text
  (save path content)   — write content to a file

Respond ONLY with a (do ...) s-expression using these functions.
Task: research "Koka language" and save a summary to summary.txt
```

Expected LLM output:

```lisp
(do
  (def result (search "Koka language"))
  (def short  (summarise result))
  (save "summary.txt" short))
```

HiLisp evaluates this directly — the LLM has composed a real program.

---

## Extracting s-expressions from prose

If the LLM wraps the expression in prose, extract the s-expression with a helper:

```lisp
; (extract-sexp text) — return the first balanced s-expression found in text
(defn find-open (s i)
  (if (>= i (length-str s))
    -1
    (if (= (char-at s i) "(")
      i
      (find-open s (+ i 1)))))
```

Or simply prompt with a system instruction: *"Your response must start with `(` and
end with `)` and contain no other text."*

---

## Sandboxing

`eval` runs in the full HiLisp environment, which includes `exec` and `write-file`.
Until HiLisp has a capability/permission system, apply prompt-level controls:

- Inspect the response string with `contains` before eval-ing
- Run untrusted code in a subprocess: `(exec (str "./hilisp -e '" response "'"))`
- Define a restricted env by omitting `exec`/`write-file` from `make_env` and passing
  it explicitly to your eval loop

---

## Minimal end-to-end example

Save as `examples/llm-eval.hl` and run with `./hilisp lib/prelude.hl examples/llm-eval.hl`:

```sh
export GEMINI_API_KEY="your-key-here"
./hilisp lib/prelude.hl examples/llm-eval.hl
```

```lisp
; llm-eval.hl — call Gemini and execute its HiLisp response

(defn ask-lisp (task)
  (exec (str
    "curl -s https://generativelanguage.googleapis.com/v1beta/models/"
    "gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY "
    "-H \"Content-Type: application/json\" "
    "-d \"{\\\"system_instruction\\\":{\\\"parts\\\":[{\\\"text\\\":"
    "\\\"Reply ONLY with a single HiLisp s-expression. "
    "No prose, no markdown, no backticks.\\\"}]},"
    "\\\"contents\\\":[{\\\"parts\\\":[{\\\"text\\\":\\\""
    task
    "\\\"}]}]}\" "
    "| jq -r '.candidates[0].content.parts[0].text'")))

(def task "Print the first 5 fibonacci numbers using println.")
(def code (ask-lisp task))

(println "--- Gemini returned ---")
(println code)
(println "--- executing ---")
(eval code)
```
