# package examples

This directory contains examples for modules defining packages.
All modules can be used as templates to create new packages.

Each package module is defined by a directory containing a `default.nix`.

## How to use

All examples are self contained via their own `flake.nix`.

To use multiple packages in a repository, keep only each packages' `default.nix` and put them under a top-level `flake.nix` instead, as shown in the `repo examples` in [/examples](../../examples).

## Usage example

For example, in order to initialize a php-package from `packages/languages/php-packaging/`:

```shellSession
# create new single package repo for php
$ mkdir my-dream2nix-package
$ cd my-dream2nix-package
$ nix flake init -t github:nix-community/dream2nix#templates.php-packaging
wrote: /tmp/my-dream2nix-package/flake.nix
wrote: /tmp/my-dream2nix-package/default.nix

# git add (in case git is used)
git add .

# interact with the package
$ nix flake show
[...]
$ nix build
[...]
```
