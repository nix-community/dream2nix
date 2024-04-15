# Inspect the API of a package
Downstream users can inspect the api of any consumed package as well as raw package modules

## Load the dream2nix shell
```shell
nix-shell https://dream2nix.dev -A devShells.default
```

## Get manual of package module
Assuming a package module in `./upstream/my-package.nix`

```shell
$ dream2nix man ./upstream/my-package.nix
```

## Get manual of derivation
Assuming derivations defined via `./upstream/default.nix`

```shell
dream2nix man ./upstream/default.nix -A packages.my-package
```

## Get manual of flake attribute
Assuming derivations defined via a flake on github

```shell
dream2nix man github:user/repo#some-package
```
