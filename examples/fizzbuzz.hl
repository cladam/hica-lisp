; FizzBuzz — using cond for multi-branch dispatch
; (no modulo builtin, so we implement it as integer division trick)
(defn mod (a b) (- a (* b (/ a b))))

(defn fizzbuzz (n)
  (cond
    (= (mod n 15) 0) 15
    (= (mod n 3)  0) 3
    (= (mod n 5)  0) 5
    true n))

(defn loop (i max)
  (if (<= i max)
    (do (println (fizzbuzz i))
        (loop (+ i 1) max))
    0))

(loop 1 20)
