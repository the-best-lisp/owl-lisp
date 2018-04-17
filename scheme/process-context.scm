(define-library (scheme process-context)

   (import
      (owl defmac)
      (only (owl primop) halt)
      (only (owl syscall) error)
      (only (owl sys) getenv)
      (scheme base))

   (export
      command-line
      emergency-exit
      exit
      get-environment-variable
      get-environment-variables)

   (begin
      (define (command-line)
         (error "Implementation restriction:" 'command-line))

      (define (exit . x)
         (halt
            (if (pair? x)
               (let ((x (car x))) (if x (if (integer? x) x 0) 1))
               0)))

      (define emergency-exit exit)

      (define get-environment-variable getenv)

      (define (get-environment-variables)
         (sys-prim 14 #f #f #f))

))