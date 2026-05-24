; Closures — functions that capture their environment
(defn make_multiplier (factor)
  (fn (x) (* x factor)))
(def double (make_multiplier 2))
(def triple (make_multiplier 3))
(println (double 7))
(println (triple 7))

(defn compose (f g) (fn (x) (f (g x))))
(defn inc (x) (+ x 1))
(defn square (x) (* x x))
(def square_then_inc (compose inc square))
(println (square_then_inc 4))
(println (square_then_inc 9))

; Accumulator factory
(defn make_counter (start)
  (fn (step) (+ start step)))
(def from5 (make_counter 5))
(println (from5 10))
(println (from5 100))
