# Haskell Cabal build

## Build project

```console
$ nix build .#checks.x86_64-linux.example-package-haskell-cabal
```

## Generate lock file

```console
$ nix run .#checks.x86_64-linux.example-package-haskell-cabal.lock
```
