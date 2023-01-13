#lang racket/base

(require json)
(require pkg/name)
(require racket/file)
(require racket/function)
(require racket/match)
(require racket/list)
(require racket/set)
(require racket/string)
(require setup/getinfo)

(provide generate-dream-lock)

;; XXX: We presently end up doing multiple DFSes in the course of
;; generating multiple dream-lock.json files for foo, foo-lib,
;; foo-test: the issue is that generating the foo dream-lock requires
;; that we traverse foo-lib, and that subsequently generating the
;; foo-lib dream-lock requires repeating the same traversal of foo-lib. How can this be avoided?

(define-logger dream2nix)

;; TODO: no effort is made to handle cycles right now
(define (dfs graph u dependency-subgraph)
  (if (hash-has-key? dependency-subgraph u)
      dependency-subgraph
      (let ([destinations (hash-ref graph u)])
        (foldl (curry dfs graph)
               (hash-set dependency-subgraph u destinations)
               destinations))))

(define (dependencies dir)
  (let ([info-procedure (get-info/full dir)]
        [ignore-error (lambda (_) '())])
    (append (with-handlers ([exn:fail? ignore-error])
              (info-procedure 'deps))
            (with-handlers ([exn:fail? ignore-error])
              (info-procedure 'build-deps)))))

(define dependency->name+type
  (match-lambda [(or (cons pkg-name _) pkg-name) (package-source->name+type pkg-name #f)]))

(define (dependency->name dep)
  (let-values ([(name _) (dependency->name+type dep)]) name))

(define (remote-pkg->source name url rev)

  (define (url->source url)
    (let* ([source-with-removed-http-or-git-double-slash (regexp-replace #rx"^(?:git|http)://" url "https://")]
           [left-trimmed-source (string-trim source-with-removed-http-or-git-double-slash "git+" #:right? #f)]
           [maybe-match-path (regexp-match #rx"\\?path=([^#]+)" left-trimmed-source)]
           [trimmed-source (regexp-replace #rx"(?:/tree/.+)?(?:\\?path=.+)?$" left-trimmed-source "")])
      (cons `(url . ,trimmed-source)
            (match maybe-match-path
              [(list _match dir)
               `((dir . ,(regexp-replace* #rx"%2F" dir "/")))]
              [_ '()]))))

  (cons (string->symbol name)
        (make-immutable-hash
         `((0.0.0 . ,(make-immutable-hash
                      (append
                       (url->source url)
                       `((rev . ,rev)
                         (type . "git")
                         ;; TODO: sha256?
                         ))))))))

(define (local-pkg->source name path)
  (list (cons (string->symbol name)
              (make-immutable-hash
               `((0.0.0 . ,(make-immutable-hash
                            `((type . "path")
                              (path . ,path)))))))))

(define (generate-dream-lock pkgs-all-path)
  (log-dream2nix-info "Generating dream lock.")
  (let* ([src-path (getenv "RACKET_SOURCE")]
         [rel-path (getenv "RACKET_RELPATH")]
         [package-path (simplify-path (cleanse-path (build-path src-path (if (string=? rel-path "")
                                                                             'same
                                                                             rel-path))))]
         [parent-path (simplify-path (cleanse-path (build-path package-path 'up)))]
         [package-name (if (string=? rel-path "")
                           (getenv "RACKET_PKG_MAYBE_NAME")
                           (path->string
                            (match/values (split-path package-path)
                              ((_base subdir _must-be-dir?) subdir))))]
         [_ (log-dream2nix-info "Reading package catalog from file ~a." pkgs-all-path)]
         [pkgs-all (with-input-from-file pkgs-all-path read)]
         [pkg-in-stdlib? (lambda (pkg-name)
                           (or ;; Some people add racket itself as a dependency for some reason
                            (string=? pkg-name "racket")
                            (let ([pkg (hash-ref pkgs-all pkg-name #f)])
                              (and pkg
                                   (ormap (lambda (tag)
                                            ;; XXX: would prefer to use memq, but tag is mutable for some reason
                                            (member tag  '("main-distribution" "main-tests")))
                                          (hash-ref pkg 'tags))))))]
         [dep-alist-from-catalog (hash-map pkgs-all
                                           (match-lambda**
                                            [(name (hash-table ('dependencies dependencies)))
                                             (let ([external-deps (filter-not pkg-in-stdlib? dependencies)])
                                               (cons name external-deps))]))]
         [compute-overridden-dep-lists
          (lambda (name dir)
            (cons name
                  (remove-duplicates
                   (filter-not pkg-in-stdlib?
                               (map dependency->name
                                    (dependencies dir))))))]
         [paths-from-repo
          ;; XXX: this probably doesn't capture every case since
          ;; Racket doesn't seem to enforce much structure in a
          ;; multi-package repo, but it accounts for the only cases
          ;; that a sane person would choose
          (if (string=? rel-path "")
              (list (cons package-name package-path))
              (let* ([info-exists? (lambda (dir) (get-info/full dir))]
                     [sibling-paths (filter info-exists?
                                            (filter directory-exists?
                                                    (directory-list parent-path #:build? #t)))]
                     [_ (log-dream2nix-info "Found ~a sibling packages." (length sibling-paths))]
                     [_ (for-each (lambda (path)
                                    (log-dream2nix-info "Found sibling package: ~a." path))
                                  sibling-paths)]
                     [dir-name (lambda (p)
                                 ;; XXX: maybe not very DRY
                                 (path->string
                                  (match/values (split-path p)
                                    ((_base dir-fragment _must-be-dir?) dir-fragment))))])
                (map (lambda (p) (cons (dir-name p) p)) sibling-paths)))]
         [dep-list-overrides
          (map (match-lambda [(cons name path) (compute-overridden-dep-lists name path)]) paths-from-repo)]
         [names-of-overridden-packages (apply set (map car dep-list-overrides))]
         [graph (make-immutable-hash (append dep-alist-from-catalog
                                             dep-list-overrides))]
         [dependency-subgraph (dfs graph package-name (make-immutable-hash))]
         [generic (make-immutable-hash
                   `((subsystem . "racket")
                     (location . ,rel-path)
                     (sourcesAggregatedHash . ,(json-null))
                     (defaultPackage . ,package-name)
                     (packages . ,(make-immutable-hash `((,(string->symbol package-name) . "0.0.0"))))))]
         [sources-from-catalog
          (hash-map pkgs-all
                    (match-lambda**
                     [(name (hash-table
                             ('versions
                              (hash-table
                               ('default
                                (hash-table
                                 ('source_url url)))))
                             ('checksum rev)))
                      (remote-pkg->source name url rev)]))]
         [sources-from-repo (if (string=? rel-path "")
                                (local-pkg->source package-name src-path)
                                (set-map names-of-overridden-packages
                                         (lambda (name)
                                           (local-pkg->source name (path->string (build-path parent-path (string-append-immutable name "/")))))))]
         [sources-hash-table (make-immutable-hash (append sources-from-catalog
                                                          sources-from-repo))]
         [sources (make-immutable-hash (hash-map dependency-subgraph
                                                 (lambda (name _v)
                                                   (cons (string->symbol name) (hash-ref sources-hash-table (string->symbol name))))))]
         [dream-lock (make-immutable-hash
                      `((_generic . ,generic)
                        (sources . ,sources)
                        (_subsystem . ,(make-immutable-hash))
                        (dependencies . ,(make-immutable-hash
                                          (hash-map dependency-subgraph
                                                    (lambda (name dep-list)
                                                      (cons (string->symbol name)
                                                            (make-immutable-hash `((0.0.0 . ,(map (lambda (dep-name) (list dep-name "0.0.0")) dep-list)))))))))))])
    (make-parent-directory* (getenv "RACKET_OUTPUT_FILE"))
    (with-output-to-file (getenv "RACKET_OUTPUT_FILE")
      (lambda () (write-json dream-lock))
      #:exists 'replace)))
