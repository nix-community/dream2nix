#lang racket

(require setup/dirs)

(let* ([config-rktd-path (cleanse-path (build-path (find-config-dir) "config.rktd"))]
       [old-config-ht (with-input-from-file config-rktd-path read)]
       [property-alist '((bin-search-dirs . "bin/")
                         (collects-search-dirs . "collects/")
                         (doc-search-dirs . "doc/")
                         (include-search-dirs . "include/")
                         (lib-search-dirs . "lib/")
                         (links-search-files . "links.rktd")
                         (man-search-dirs . "man/")
                         (pkgs-search-dirs . "pkgs/")
                         (share-search-dirs . "share/"))]
       [make-path-string (lambda (subpath)
                           (path->string (cleanse-path (build-path (find-config-dir) (version) subpath))))]
       [final-config-ht (foldl (match-lambda**
                                [((cons key subpath) accum)
                                 (hash-update accum
                                              key
                                              (curry cons (make-path-string subpath))
                                              '(#f))])
                               old-config-ht
                               property-alist)])
  (with-output-to-file config-rktd-path
    (lambda () (write final-config-ht))
    #:exists 'replace))
