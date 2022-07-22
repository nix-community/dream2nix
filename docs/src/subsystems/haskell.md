# Haskell subsystem

This section documents the Haskell subsystem.

Get involved:
- [understand dream2nix architecture](../intro/architectural-considerations.md#architecture)
- [understand dream2nix translator types](../intro/translators.md)
- [try out examples](https://github.com/nix-community/dream2nix/tree/main/examples)
- [find Issues](https://github.com/nix-community/dream2nix/issues?q=is%3Aissue+is%3Aopen+label%3Ahaskell)
- [find TODOs](https://sourcegraph.com/search?q=context:global+repo:%5Egithub%5C.com/nix-community/dream2nix%24+file:haskell/+TODO&patternType=literal)

## Status
The Haskell subsystems is currently work in progress.
It is in a state where it can be used, but will potentially fail on many projects, because some important features are missing.
Currently we have a builder for haskell and several translators (see table below).

The main elements which are missing:

- a pure translator for cabal.project.freeze
- an impure cabal translator, that works with any cabal based project by generating a cabal.project.freeze file. This should be fairly simple. Once we have the pure cabal.project.freeze translator, the impure translator can just execute `cabal freeze` and then call out to the existing pure translator.
- detecting which GHC version must be used for a project
- source different GHC versions. For now we should probably just support all ghc versions from nixpkgs because those are cached on nixos.org. If the translated project requires a different ghc version, the user should be allowed to override this, or pick a different nixpkgs.
- add an indexer for stackage/hackage. That should allow us to build a repository with the most common haskell libraries equivalent to dream2nix-crates-io or dream2nix-npm. This will allow us to improve our builders and translators based on the errors we get.


## Examples
flake.nix
```nix
{{#include ../../../examples/haskell_stack-lock/flake.nix}}
```

see more examples under: [/examples](https://github.com/nix-community/dream2nix/tree/main/examples)

## Translators

The source code of the implementations can be found [here](https://github.com/nix-community/dream2nix/tree/main/src/subsystems/haskell/translators).


**translator**   | stack-lock      | cabal-plan  | cabal-freeze         |
-----------|-----------------|-------------|----------------------|
**file name**  | stack.yaml.lock | plan.json   | cabal.project.freeze |
**status** | implemented     | implemented | missing              |
