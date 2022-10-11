# Fetchers

This section describes the available source code fetchers. A fetcher is responsible for loading sources defined in the generic lockfile described earlier.

## Fetcher structure

Here is the implementation of the simple `path` fetcher:
```nix
{{#include ../../../src/fetchers/path/default.nix}}
```

It defines `inputs` which are the required arguments it expects to
receive when invoked.
Under `outputs` is a function that returns an object with `calcHash` and
`fetched` function attributes.

- `calcHash`: receives an algorithm and outputs the source hash, it
  is used while generating the dream-lock file.
- `fetched`: receives a `hash` and returns the fetched source.

It is important to remember that nix enforces reproducibility, to
download something from nix we need to be sure it is exactly what we
expect: usually enforced by comparing hashes. And you will see that
almost all fetchers need to be supplied with a `hash` of the source being
fetched.

## Implemented fetchers

The fetcher name corresponds to the source `type` used to invoke it.

You can inspect the implementation of all the builders
[here](https://github.com/nix-community/dream2nix/tree/main/src/fetchers).

### path

Fetches from a path. Useful when we already have the source.

Inputs:
- path

_Does not require a `hash` since nix can check integrity of paths._

### http

Fetches from a http address.

Inputs:
- url
- hash

### git

Fetches from a git commit.

Inputs:
- url
- rev

_Does not require a `hash` since nix can use the `rev` to check for
integrity instead._

### github

Fetches from a GitHub repository commit.

Inputs:
- owner
- repo
- rev
- hash

### gitlab

Fetches from a GitLab repository commit.

Inputs:
- owner
- repo
- rev
- hash

### npm

Fetches from npm registry.

Inputs:
- pname
- version
- hash

### pypi-sdist

Fetches from pypi registry.

Inputs:
- pname
- version
- hash

### crates-io

Fetches from crates.io registry.

Inputs:
- pname
- version
- hash
