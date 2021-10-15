#lang info

(define collection "1d6")

(define version "0.0.1")

(define deps
  '("base"
    "brag"
    "beautiful-racket-lib"))

(define build-deps
  '("scribble-lib"
    "rackunit-lib"
    "racket-doc"
    "beautiful-racket-lib"))

(define pkg-desc "1d6 is a Racket implementation of the Troll dice-rolling language.")

(define pkg-authors '("jesse@lisp.sh"))
