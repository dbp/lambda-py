#lang racket

(require redex)
(require redex/tut-subst)
(require "lambdapy-core.rkt")

(define red
  (reduction-relation
   λπ
   #:domain p
   (--> (in-hole P (str string))
        (in-hole P (obj-val str (meta-str string) ()))
        "string")
   (--> (in-hole P none)
        (in-hole P vnone)
        "none")
   (--> (in-hole P undefined)
        (in-hole P (undefined-val))
        "undefined")
   (--> (in-hole P (list (val ...)))
        (in-hole P (obj-val list (meta-list (val ...)) ()))
        "list")
   (--> (in-hole P (tuple (val ...)))
        (in-hole P (obj-val tuple (meta-tuple (val ...)) ()))
        "tuple")
   (--> ((in-hole E (fun (x ...) e)) εs Σ)
        ((in-hole E (fun-val εs (λ (x ...) e))) εs Σ)
        "fun-novararg")
   (--> ((in-hole E (fun (x ...) x_1 e)) εs Σ)
        ((in-hole E (fun-val εs (λ (x ...) (x_1) e))) εs Σ)
        "fun-vararg")
   (--> (in-hole P (if val e_1 e_2))
        (in-hole P e_1)
        (side-condition (term (truthy? val)))
        "if-true")
   (--> (in-hole P (if val e_1 e_2))
        (in-hole P e_2)
        (side-condition (not (term (truthy? val))))
        "if-false")
   (--> (in-hole P (seq val e))
        (in-hole P e)
        "seq")
   (--> ((in-hole E (let (x_1 val) e))
         (ε_1 ε ...)
         Σ)
        ((in-hole E (subst (x_1) (x_new) e))
         ((extend-env ε_1 x_new ref_new) ε ...)
         (override-store Σ ref_new val))
        (fresh x_new)
        (where ref_new ,(new-loc))
        "let")
   (--> ((in-hole E (id x_1 local))
         (name env (((x_2 ref_2) ... (x_1 ref_1) (x_3 ref_3) ...) ε ...))
         (name store ((ref_4 val_4) ... (ref_1 val_1) (ref_5 val_5) ...)))
        ((in-hole E val_1)
         env
         store)
        (side-condition (not (member (term x_1) (term (x_2 ... x_3 ...)))))
        (side-condition (not (member (term ref_1) (term (ref_4 ... ref_5 ...)))))
        (side-condition (not (redex-match? λπ (undefined-val) (term val_1)))) ;; TODO: exception for undefined
        "id-local")
   (--> ((in-hole E (assign (id x_1 local) val_1))
         ((name scope ((x_2 ref_2) ...)) ε ...)
         Σ)
        ((in-hole E vnone)
         ((extend-env scope x_1 ref_1) ε ...)
         (override-store Σ ref_1 val_1))
        (side-condition (not (member (term x_1) (term (x_2 ...)))))
        (where ref_1 ,(new-loc))
        "assign-local-free")
   (--> ((in-hole E (assign (id x_1 local) val_1))
         (name env (((x_2 ref_2) ... (x_1 ref_1) (x_3 ref_3) ...) ε ...))
         Σ)
        ((in-hole E vnone)
         env
         (override-store Σ ref_1 val_1))
        (side-condition (not (member (term x_1) (term (x_2 ... x_3 ...)))))
        "assign-local-bound")
   ))

(define-metafunction λπ
  truthy? : val -> #t or #f
  [(truthy? (fun-val any ...)) #t]
  [(truthy? (obj-val any ...)) #t] ;; simply return #t for now
  [(truthy? (undefined-val)) #f])

(define new-loc
  (let ([n 0])
    (lambda () (begin (set! n (add1 n)) n))))

(define-metafunction λπ
  extend-env : ε x ref -> ε
  [(extend-env ((x_2 ref_2) ...) x_1 ref_1) ((x_2 ref_2) ... (x_1 ref_1))])

(define-metafunction λπ
  override-store : Σ ref val -> Σ
  [(override-store ((ref_2 val_2) ...) ref_1 val_1)
   ((ref_2 val_2) ... (ref_1 val_1))
   (side-condition (not (member (term ref_1) (term (ref_2 ...)))))]
  [(override-store ((ref_2 val_2) ... (ref_1 val_0) (ref_3 val_3) ...) ref_1 val_1)
   ((ref_2 val_2) ... (ref_1 val_1) (ref_3 val_3) ...)
   (side-condition (not (member (term ref_1) (term (ref_2 ...)))))])

;; simply use this subst function for now
(define-metafunction λπ
  subst : (x ..._1) (any ..._1) e -> e
  [(subst (x ..._1) (any ..._1) e)
   ,(subst/proc (redex-match? λπ x) (term (x ...)) (term (any ...)) (term e))])

(define-term vnone (obj-val none (meta-none) ()))

(define-metafunction λπ
  cascade : (e ...) εs Σ -> ((val ...) εs Σ)
  [(cascade () εs Σ)
   (() εs Σ)]
  [(cascade (e_1 e_2 ...) εs Σ)
   ((val_1 val_2 ...) εs_2 Σ_2)
   (where (val_1 εs_1 Σ_1) ,(apply-reduction-relation* red (term (e_1 εs Σ))))
   (where ((val_2 ...) εs_2 Σ_2) (cascade (e_2 ...) εs_1 Σ_1))])