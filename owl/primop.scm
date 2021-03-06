;; vm rimops

;; todo: convert tuple to variable arity
;; todo: convert arity checks 17 -> 25

(define-library (owl primop)
   (export
      primops
      primop-name ;; primop → symbol | primop
      multiple-return-variable-primops
      variable-input-arity?
      special-bind-primop?
      ;; primop wrapper functions
      run
      set-ticker
      clock
      sys-prim
      bind
      ff-bind
      mkt
      halt
      wait
      ;; extra ops
      set-memory-limit get-word-size get-memory-limit
      eq?

      apply apply-cont ;; apply post- and pre-cps
      call/cc call-with-current-continuation
      lets/cc

      _poll2
      ;; vm interface
      vm bytes->bytecode
      )

   (import
      (owl defmac))

   (begin

      (define bytes->bytecode
         (C raw type-bytecode))

      (define eq?
         (bytes->bytecode
            '(25 3 0 6 54 4 5 6 24 6 17)))

      (define (app a b)
         (if (eq? a '())
            b
            (cons (car a) (app (cdr a) b))))

      ;; l -> fixnum | #false if too long
      (define (len l)
         (let loop ((l l) (n 0))
            (if (eq? l '())
               n
               (lets ((n o (fx+ n 1)))
                  (if o #false (loop (cdr l) n))))))

      (define (func lst) 
         (lets 
            ((arity (car lst))
             (lst (cdr lst))
             (len (len lst)))
            (bytes->bytecode
               (cons 25 (cons arity (cons 0 (cons len 
                  (app lst (list 17))))))))) ;; fail if arity mismatch

      ;; changing any of the below 3 primops is tricky. they have to be recognized by the primop-of of 
      ;; the repl which builds the one in which the new ones will be used, so any change usually takes 
      ;; 2 rebuilds. 

      ; these 2 primops require special handling, mainly in cps
      (define ff-bind ;; turn to badinst soon, possibly return later 
         ; (func '(2 49))
         '__ff-bind__

         )
      (define bind
         ; (func '(2 32 4 5 24 5))
         '__bind__
         )
      ; this primop is the only one with variable input arity
      (define mkt 
         '__mkt__
         ;(func '(4 23 3 4 5 6 7 24 7))
         )

      ;; these rest are easy
      (define car         (func '(2 52 4 5 24 5))) 
      (define cdr         (func '(2 53 4 5 24 5))) 
      (define cons        (func '(3 51 4 5 6 24 6)))
      (define run         (func '(3 50 4 5 6 24 6)))
      (define set-ticker  (func '(2 62 4 5 24 5)))
      (define sys-prim    (func '(5 63 4 5 6 7 8 24 8)))
      (define clock       (func '(1 9 3 5 61 3 4 2 5 2)))
      (define sys         (func '(4 27 4 5 6 7 24 7)))
      (define sizeb       (func '(2 28 4 5 24 5)))
      (define raw         (func '(3 37 4 5 6 24 6)))
      (define _poll2      (func '(4 9 3 11 11 4 5 6 3 4 2 11 2))) 
      (define fxband      (func '(3 55 4 5 6 24 6)))
      (define fxbor       (func '(3 56 4 5 6 24 6)))
      (define fxbxor      (func '(3 57 4 5 6 24 6)))

      (define type        type-byte)
      (define size        (func '(2 36 4 5 24 5)))
      (define cast        (func '(3 22 4 5 6 24 6)))
      (define ref         (func '(3 47 4 5 6 24 6)))
      (define refb        (func '(3 48 4 5 6 24 6)))
      (define ff-toggle   (func '(2 46 4 5 24 5)))

      ;; make thread sleep for a few thread scheduler rounds
      (define (wait n) 
         (if (eq? n 0)
            n
            (lets ((n _ (fx- n 1)))
               (set-ticker 0) ;; allow other threads to run
               (wait n))))

      ;; from cps
      (define (special-bind-primop? op)
         (or (eq? op 32) (eq? op 49)))

      ;; fixme: handle multiple return value primops sanely (now a list)
      (define multiple-return-variable-primops
         '(49 11 26 38 39 40 58 59 37 61))

      (define variable-input-arity? (C eq? 23)) ;; mkt

      (define primops-1
         (list
            ;;; input arity includes a continuation
            (tuple 'sys          27 4 1 sys)
            (tuple 'sizeb        28 1 1 sizeb)   ;; raw-obj -> numbe of bytes (fixnum)
            (tuple 'raw          37 2 1 raw)   ;; make raw object, and *add padding byte count to type variant*
            (tuple 'cons         51 2 1 cons)
            (tuple 'car          52 1 1 car)
            (tuple 'cdr          53 1 1 cdr)
            (tuple 'eq?          54 2 1 eq?)
            (tuple 'fxband       55 2 1 fxband)
            (tuple 'fxbor        56 2 1 fxbor)
            (tuple 'fxbxor       57 2 1 fxbxor)
            (tuple '_poll2       11 3 2 _poll2) ;; poll rfdlist wfdlist timeout/false → fd/false/null type
            (tuple 'type-byte    15 1 1 type-byte) ;; get just the type bits (new)
            (tuple 'type         15 1 1 type)
            (tuple 'size         36 1 1 size)  ;;  get object size (- 1)
            (tuple 'cast         22 2 1 cast)  ;; cast object type (works for immediates and allocated)
            (tuple 'ref          47 2 1 ref)   ;;
            (tuple 'refb         48 2 1 refb)      ;;
            (tuple 'mkt          23 'any 1 mkt)   ;; mkt type v0 .. vn t
            (tuple 'ff-toggle    46 1 1 ff-toggle)))  ;; (fftoggle node) -> node', toggle redness

      (define set (func '(4 45 4 5 6 7 24 7)))
      (define lesser? (func '(3 44 4 5 6 24 6)))
      (define listuple (func '(4 35 4 5 6 7 24 7)))
      (define mkblack (func '(5 42 4 5 6 7 8 24 8)))
      (define mkred (func '(5 43 4 5 6 7 8 24 8)))
      (define red? (func '(2 41 4 5 24 5)))
      (define fxqr (func '(4 26))) ;; <- placeholder 
      (define fx+ (func '(4 38 4 5 6 7 24 7)))
      (define fx- (func '(4 40 4 5 6 7 24 7)))
      (define fx>> (func '(4 58 4 5 6 7 24 7)))
      (define fx<< (func '(4 59 4 5 6 7 24 7)))

      (define apply (bytes->bytecode '(20))) ;; <- no arity, just call 20
      (define apply-cont (bytes->bytecode (list (fxbor 20 64))))

      (define primops-2
         (list
            (tuple 'bind         32 1 #false bind)  ;; (bind thing (lambda (name ...) body)), fn is at CONT so arity is really 1
            (tuple 'set          45 3 1 set)   ;; (set tuple pos val) -> tuple'
            (tuple 'lesser?      44 2 1 lesser?)  ;; (lesser? a b)
            (tuple 'listuple     35 3 1 listuple)  ;; (listuple type size lst)
            (tuple 'mkblack      42 4 1 mkblack)   ; (mkblack l k v r)
            (tuple 'mkred        43 4 1 mkred)   ; ditto
            (tuple 'ff-bind      49 1 #false ff-bind)  ;; SPECIAL ** (ffbind thing (lambda (name ...) body)) 
            (tuple 'red?         41 1 #false red?)  ;; (red? node) -> bool
            (tuple 'fxqr         26 3 3 'fxqr)   ;; (fxdiv ah al b) -> qh ql r
            (tuple 'fx+          38 2 2 fx+)   ;; (fx+ a b)      ;; 2 out 
            (tuple 'fx*          39 2 2 fx*)   ;; (fx* a b)      ;; 2 out
            (tuple 'ncons        29 2 1 ncons)   ;;
            (tuple 'ncar         30 1 1 ncar)   ;;
            (tuple 'ncdr         31 1 1 ncdr)   ;;
            (tuple 'fx-          40 2 2 fx-)   ;; (fx- a b)       ;; 2 out
            (tuple 'fx>>         58 2 2 fx>>)   ;; (fx>> a b) -> hi lo, lo are the lost bits
            (tuple 'fx<<         59 2 2 fx<<)   ;; (fx<< a b) -> hi lo, hi is the overflow
            (tuple 'clock        61 0 2 clock) ; (clock) → posix-time x ms
            (tuple 'set-ticker   62 1 1 set-ticker)
            (tuple 'sys-prim     63 4 1 sys-prim)))

      (define primops 
         (app primops-1
              primops-2))

      ;; special things exposed by the vm
      (define (set-memory-limit n) (sys-prim 7 n #f #f))
      (define (get-word-size) (sys-prim 8 1 #f #f))
      (define (get-memory-limit) (sys-prim 9 #f #f #f))

      ;; todo: add get-heap-metrics

      ;; stop the vm *immediately* without flushing input or anything else with return value n
      (define (halt n) (sys-prim 6 n #f #f))

      (define call/cc
         ('_sans_cps
            (λ (k f)
               (f k
                  (case-lambda
                     ((c a) (k a))
                     ((c a b) (k a b))
                     ((c . x) (apply-cont k x)))))))

      (define call-with-current-continuation call/cc)

      (define-syntax lets/cc 
         (syntax-rules (call/cc)
            ((lets/cc (om . nom) . fail) 
               (syntax-error "let/cc: continuation name cannot be " (quote (om . nom)))) 
            ((lets/cc var . body) 
               (call/cc (λ (var) (lets . body))))))

      ;; non-primop instructions that can report errors
      (define (instruction-name op)
         (cond
            ((eq? op 17) 'arity-error)
            ((eq? op 32) 'bind)
            ((eq? op 50) 'run)
            (else #false)))

      (define (primop-name pop)
         (let ((pop (fxband pop 63))) ; ignore top bits which sometimes have further data
            (or (instruction-name pop)
               (let loop ((primops primops))
                  (cond
                     ((null? primops) pop)
                     ((eq? pop (ref (car primops) 2))
                        (ref (car primops) 1))
                     (else
                        (loop (cdr primops))))))))

      ;; silly runtime exception, error not defined yet here
      (define (check-equal a b)
         (if (eq? a b)
            'ok
            (car 'assert-fail)))

      ;; exit by returning to r3
      (define (vm . bytes)
         ((bytes->bytecode bytes)))

      '(check-equal 42 ;; load 42:
         (vm 14 42 4  ;;   r4 = fixnum(42)
             24 4))   ;;   return r4 = call r3 with it

      '(check-equal 0         ;; count down to zero:
         ((bytes->bytecode   ;;   r4 arg
               '(14 0 5      ;;   r5 = 0
                 14 1 6      ;;   r6 = 1
                 16 4 7 0    ;;   jump forward x if r4 is imm[0] == 0, starting from next instruction
                 40 4 6 4 7  ;;   r4 - r6 = r4 / r7
                 12 10       ;;   jump back by 9
                 24 4))      ;;   return r4
            100))

))
