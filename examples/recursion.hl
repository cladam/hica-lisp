; Recursive functions — self-reference works via fname injection
(defn factorial (n)
  (if (<= n 1) 1 (* n (factorial (- n 1)))))
(println (factorial 5))
(println (factorial 10))

(defn fib (n)
  (if (<= n 1) n (+ (fib (- n 1)) (fib (- n 2)))))
(println (fib 0))
(println (fib 1))
(println (fib 10))

(defn power (base exp)
  (if (= exp 0) 1 (* base (power base (- exp 1)))))
(println (power 2 10))
