(load-relative "loadtest.rktl")
(Section 'fixnum)
(require racket/fixnum
         racket/unsafe/ops
         "for-util.rkt")

(define (least-fixnum) (most-negative-fixnum))
(define (greatest-fixnum) (most-positive-fixnum))
(define (fixnum-width) (add1 (integer-length (most-positive-fixnum))))

(test #t fixnum? (least-fixnum))
(test #t fixnum? (greatest-fixnum))
(test #f fixnum? (sub1 (least-fixnum)))
(test #f fixnum? (add1 (greatest-fixnum)))

(test #t fixnum-for-every-system? 0)
(test #t fixnum-for-every-system? -100)
(test #t fixnum-for-every-system? 100)
(test #t fixnum-for-every-system? (- (expt 2 29)))
(test #t fixnum-for-every-system? (sub1 (expt 2 29)))
(test #t fixnum? (- (expt 2 29)))
(test #t fixnum? (sub1 (expt 2 29)))
(test #f fixnum-for-every-system? (sub1 (- (expt 2 29))))
(test #f fixnum-for-every-system? (expt 2 29))

(define (wraparound op)
  (lambda (x y)
    (unless (fixnum? x) (raise-argument-error 'wraparound "fixnum?" x))
    (unless (fixnum? y) (raise-argument-error 'wraparound "fixnum?" y))
    (define v (op x y))
    (if (zero? (bitwise-and v (add1 (greatext-fixnum))))
        (bitwise-ior v (- -1 (greatest-fixnum)))
        (bitwise-and v (greatest-fixnum)))))

(define (lshift x y)
  (unless (<= 0 y (integer-length (greatest-fixnum)))
    (error 'lshift "bad shift"))
  (arithmetic-shift x y))

(define unary-table 
  (list (list fxnot unsafe-fxnot)
        (list fxabs unsafe-fxabs)
        (list fx->fl unsafe-fx->fl)
        (list (lambda (v) (fl->fx (exact->inexact x)))
              (lambda (v) (unsafe-fl->fx (exact->inexact x))))))

(define 1nary-table
  (list (list fx- unsafe-fx-)

        (list fx>= unsafe-fx>=)
        (list fx> unsafe-fx>)
        (list fx= unsafe-fx=)
        (list fx<= unsafe-fx<=)
        (list fx< unsafe-fx<)
        (list fxmin unsafe-fxmin)
        (list fxmax unsafe-fxmax)))

(define 0nary-table
  (list (list fx+ unsafe-fx+)
        (list fx* unsafe-fx*)

        (list fxand unsafe-fxand)
        (list fxior unsafe-fxior)
        (list fxxor unsafe-fxxor)))

(define binary-table
  (list (list fxquotient unsafe-fxquotient)
        (list fxremainder unsafe-fxremainder)
        (list fxmodulo unsafe-fxmodulo)
        (list (wraparound +) fx+/wraparound)
        (list (wraparound -) fx-/wraparound)
        (list (wraparound *) fx*/wraparound)
        (list (wraparound lshift) fxlshift/wraparound)
        (list fx+/wraparound unsafe-fx+/wraparound)
        (list fx-/wraparound unsafe-fx-/wraparound)
        (list fx*/wraparound unsafe-fx*/wraparound)
        (list fxlshift/wraparound unsafe-fxlshift/wraparound)))

(define binary/small-second-arg-table
  (list (list fxlshift unsafe-fxlshift)
        (list fxrshift unsafe-fxrshift)))

(define table (append binary/small-second-arg-table binary-table unary-table 1nary-table 0nary-table))
  
(define (check-arity fx unsafe-fx)
  (let ([same-arities? (λ (x y) (equal? (procedure-arity x)
                                        (procedure-arity y)))])
    (test #t
          same-arities?
          fx
          unsafe-fx)))


;; same-results : (fixnum ... -> any) (fixnum ... -> any) (listof fixnum) -> #t
;; applies fx to args; if it raises an error, the function returns #t.
;;                     if it returns a result, the function applies args
;;                     to unsafe-fx and makes sure the results are either eq? or
;;                     (if the results are flonums), =
;; raises an exception when it finds a bug.
(define (same-results fx unsafe-fx args) 
  (let/ec k
    (let* ([fx-result (with-handlers ((exn:fail? (λ (x) (k #t))))
                        (apply fx args))]
           [unsafe-result (apply unsafe-fx args)]
           [ans
            (or (eq? fx-result unsafe-result)
                (and (flonum? fx-result)
                     (flonum? unsafe-result)
                     (= fx-result unsafe-result)))])
      (unless ans
        (newline)
        (error 'same-results (~a "better die now, rather than continue, what with unsafe ops around:\n"
                                 "     fx-result ~s\n"
                                 " unsafe-result ~s\n"
                                 "    op: ~s\n"
                                 "  args: ~s")
               fx-result
               unsafe-result
               fx
               args))
      #t)))

(define (flonum? x) (inexact-real? x))

(define (same-results/range/table)
  (for ([line (in-list unary-table)])
    (for ([i (in-range (- (expt 2 8)) (expt 2 8))])
      (test #t same-results (list-ref line 0) (list-ref line 1) (list i))))
  
  (for ([line (in-list (append binary/small-second-arg-table 
                               binary-table
                               1nary-table
                               0nary-table))])
    (for ([i (in-range (- (expt 2 4)) (expt 2 4))])
      (for ([j (in-range (- (expt 2 4)) (expt 2 4))])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i j))))))

(define (same-results/extremum)
  (let ([interesting-values (list (least-fixnum) -1 0 1 (greatest-fixnum))])
    (for ([line (in-list unary-table)])
      (for ([i (in-list interesting-values)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i))))
    
    (for ([line (in-list (append binary/small-second-arg-table
                                 binary-table
                                 1nary-table
                                 0nary-table))])
      (for ([i (in-list interesting-values)])
        (for ([j (in-list interesting-values)])
          (test #t same-results (list-ref line 0) (list-ref line 1) (list i j)))))))

(define (same-results/random/table)
  (for ([ignore (in-range 0 800)])
    (let ([i (random-fixnum)]
          [j (random-fixnum)]
          [k (inexact->exact (floor (* (random) (+ 1 (fixnum-width)))))]
          [more-fixnums (build-list (random 20) (λ (i) (random-fixnum)))])
      (for ([line (in-list unary-table)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i)))
      (for ([line (in-list binary-table)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i j)))
      (for ([line (in-list 0nary-table)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list))
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i))
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i j)))
      (for ([line (in-list 1nary-table)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i))
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i j)))
      (for ([line (in-list binary/small-second-arg-table)])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i k)))
      (for ([line (in-list (append 0nary-table 1nary-table))])
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i j k))
        (test #t same-results (list-ref line 0) (list-ref line 1) (list i k j))
        (test #t same-results (list-ref line 0) (list-ref line 1) (cons i more-fixnums))))))

(define (random-fixnum)
  (inexact->exact (floor (+ (least-fixnum) (* (random) (+ (- (greatest-fixnum) (least-fixnum)) 1))))))

;; check the arities
(for-each (λ (x) (apply check-arity x)) table)

;; check the extreme values (against themselves and few other values)
(same-results/extremum)

;; check randomly
(same-results/random/table)

;; check a small range
(same-results/range/table)

;; ----------------------------------------



;; ----------------------------------------

(err/rt-test (fxvector-ref (fxvector 4 5 6) 4) exn:fail:contract? #rx"[[]0, 2[]]")
(err/rt-test (fxvector-set! (fxvector 4 5 6) 4 0) exn:fail:contract? #rx"[[]0, 2[]]")

;; in-fxvector tests.
(let ((flv (fxvector 1 2 3)))
  (let ((flv-seq (in-fxvector flv)))
    (for ((x (in-fxvector flv))
          (xseq flv-seq)
          (i (in-naturals)))
      (test (+ i 1) 'in-fxvector-fast x)
      (test (+ i 1) 'in-fxvector-sequence xseq))))

;; for/fxvector test
(let ((flv (fxvector 1 2 3))
      (flv1 (for/fxvector ((i (in-range 3))) (+ i 1)))
      (flv2 (for/fxvector #:length 3 ((i (in-range 3))) (+ i 1))))
  (test flv 'for/fxvector flv1)
  (test flv 'for/fxvector-fast flv2))

;; for*/fxvector test
(let ((flv (fxvector 0 0 0 0 1 2 0 2 4))
      (flv1 (for*/fxvector ((i (in-range 3)) (j (in-range 3))) (* 1 i j)))
      (flv2 (for*/fxvector #:length 9 ((i (in-range 3)) (j (in-range 3))) (* 1 i j))))
  (test flv 'for*/fxvector flv1)
  (test flv 'for*/fxvector-fast flv2))

;; Test for both length too long and length too short
(let ((v (make-fxvector 3)))
  (fxvector-set! v 0 0)
  (fxvector-set! v 1 1)
  (let ((w (for/fxvector #:length 3 ((i (in-range 2))) i)))
    (test v 'for/fxvector-short-iter w)))

(let ((v (make-fxvector 10)))
  (for* ((i (in-range 3))
         (j (in-range 3)))
    (fxvector-set! v (+ j (* i 3)) (+ 1 i j)))
  (let ((w (for*/fxvector #:length 10 ((i (in-range 3)) (j (in-range 3))) (+ 1 i j))))
    (test v 'for*/fxvector-short-iter w)))

(test 2 'for/fxvector-long-iter
      (fxvector-length (for/fxvector #:length 2 ((i (in-range 10))) i)))
(test 5 'for*/fxvector-long-iter 
      (fxvector-length (for*/fxvector #:length 5 ((i (in-range 3)) (j (in-range 3))) (+ i j))))

;; Test for many body expressions
(let* ((flv (fxvector 1 2 3))
       (flv2 (for/fxvector ((i (in-range 3))) 
               (fxvector-set! flv i (+ (fxvector-ref flv i) 1))
               (fxvector-ref flv i)))
       (flv3 (for/fxvector #:length 3 ((i (in-range 3)))
               (fxvector-set! flv i (+ (fxvector-ref flv i) 1))
               (fxvector-ref flv i))))
  (test (fxvector 2 3 4) 'for/fxvector-many-body flv2)
  (test (fxvector 3 4 5) 'for/fxvector-length-many-body flv3))

;; fxvector-copy test
(let ((v (fxvector 0 1 2 3)))
  (let ((vc (fxvector-copy v)))
    (test (fxvector-length v) 'fxvector-copy (fxvector-length vc))
    (for ((vx (in-fxvector v))
          (vcx (in-fxvector vc)))
      (test vx 'fxvector-copy vcx))
    (fxvector-set! vc 2 -10)
    (test 2 'fxvector-copy (fxvector-ref v 2))
    (test -10 'fxvector-copy (fxvector-ref vc 2))
    (test '(2 3) 'fxvector-copy (for/list ([i (in-fxvector (fxvector-copy v 2))]) i))
    (test '(2) 'fxvector-copy (for/list ([i (in-fxvector (fxvector-copy v 2 3))]) i))))

;; ----------------------------------------

;; in-fxvector tests, copied from for.rktl

(test-sequence [(1 2 3)] (in-fxvector (fxvector 1 2 3)))
(test-sequence [(2 3 4)] (in-fxvector (fxvector 1 2 3 4) 1))
(test-sequence [(2 3 4)] (in-fxvector (fxvector 1 2 3 4 5) 1 4))
(test-sequence [(2 4 6)] (in-fxvector (fxvector 1 2 3 4 5 6 7 8) 1 7 2))
(test-sequence [(8 6 4)] (in-fxvector (fxvector 1 2 3 4 5 6 7 8) 7 1 -2))
(test-sequence [(2 4 6)] (in-fxvector (fxvector 1 2 3 4 5 6 7 8) 1 6 2))
(test-sequence [(8 6 4)] (in-fxvector (fxvector 1 2 3 4 5 6 7 8) 7 2 -2))

;; test malformed in-fxvector
(err/rt-test (for/list ([x (in-fxvector)]) x))
(err/rt-test (in-fxvector))

;; fxvector sequence tests
(test-sequence [(1 2 3)] (fxvector 1 2 3))
(test '() 'empty-fxvector-sequence (for/list ([i (fxvector)]) i))

;; Check safety:
(err/rt-test (for/fxvector ([i 5]) 8.0))
(err/rt-test (for/fxvector #:length 5 ([i 5]) 8.0))
(err/rt-test (for/fxvector #:length 5 #:fill 0 ([i 5]) 8.0))
(err/rt-test (for/fxvector #:length 5 #:fill 0.0 ([i 5]) 8))
(err/rt-test (for/fxvector #:length 10 #:fill 0.0 ([i 5]) 8))

;; ----------------------------------------
;; Make sure `fxvector` is not incorrectly constant-folded

(let ([v (fxvector 1 2 3)])
  (unsafe-fxvector-set! v 0 10)
  (test 10 'ref (unsafe-fxvector-ref v 0)))

;; ----------------------------------------

(test 2.0 fx->fl 2)
(test -2.0 fx->fl -2)

(test 2 fl->fx 2.0)
(test 2 fl->fx 2.2)
(test -2 fl->fx -2.0)
(test -2 fl->fx -2.2)

(test 0 fl->fx 0.0)
(test 0 fl->fx -0.0)

(err/rt-test (fl->fx +inf.0))
(err/rt-test (fl->fx -inf.0))
(err/rt-test (fl->fx +nan.0))

(if (fixnum? 536870911)
    (begin
      (test 536870911 fl->fx 536870911.0)
      (test 536870911 fl->fx 536870911.5))
    (begin
      (err/rt-test (fl->fx 536870911.0))
      (err/rt-test (fl->fx 536870911.5))))
(if (fixnum? -536870912)
    (begin
      (test -536870912 fl->fx -536870912.0)
      (test -536870912 fl->fx -536870912.5))
    (begin
      (err/rt-test (fl->fx -536870912.0))
      (err/rt-test (fl->fx -536870912.5))))

(if (fixnum? 1073741823)
    (begin
      (test 1073741823 fl->fx 1073741823.0)
      (test 1073741823 fl->fx 1073741823.5))
    (begin
      (err/rt-test (fl->fx 1073741823.0))
      (err/rt-test (fl->fx 1073741823.5))))
(if (fixnum? -1073741824)
    (begin
      (test -1073741824 fl->fx -1073741824.0)
      (test -1073741824 fl->fx -1073741824.5))
    (begin
      (err/rt-test (fl->fx -1073741824.0))
      (err/rt-test (fl->fx -1073741824.5))))

(if (fixnum? 1152921504606846975)
    (test 1152921504606846848 fl->fx 1152921504606846800.0)
    (err/rt-test (fl->fx 1152921504606846800.0)))
(if (fixnum? -1152921504606846976)
    (test -1152921504606846976 fl->fx -1152921504606847000.0)
    (err/rt-test (fl->fx -1152921504606847000.0)))

(if (fixnum? 1152921504606846976)
    (test 1152921504606846976 fl->fx 1152921504606847000.0)
    (err/rt-test (fl->fx 1152921504606847000.0)))
(if (fixnum? -1152921504606847232)
    (test -1152921504606847232 fl->fx -1152921504606847200.0)
    (err/rt-test (fl->fx -1152921504606847200.0)))

(if (fixnum? 4611686018427387903)
    ;; Note: 4611686018427387903 won't round-trip
    ;; if it's the biggest fixnum
    (test 4611686018427387392 fl->fx 4.6116860184273874e+18)
    (err/rt-test (fl->fx 4.6116860184273874e+18)))
(if (fixnum? -4611686018427387904)
    ;; Ditto (about round-trip)
    (test -4611686018427387904 fl->fx -4.611686018427388e+18)
    (err/rt-test (fl->fx -4.611686018427388e+18)))

;; Too big for all current fixnum ranges:
(err/rt-test (fl->fx 4.611686018427388e+18))
(err/rt-test (fl->fx -4.611686018427389e+18))

;; ----------------------------------------

(report-errs)
