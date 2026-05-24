; Higher-order functions and closures
(defn square (x) (* x x))
(defn cube (x) (* x (* x x)))
(println (square 5))
(println (cube 3))

(defn make_adder (n) (fn (x) (+ x n)))
(def add10 (make_adder 10))
(println (add10 5))
(println (add10 32))

(defn apply_twice (f x) (f (f x)))
(println (apply_twice square 2))
(println (apply_twice (make_adder 3) 0))
