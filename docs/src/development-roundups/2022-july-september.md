# Development Roundup July - September 2022

In the period of 3 months, [62 pull requests were merged](https://github.com/nix-community/dream2nix/pulls?q=is%3Apr+sort%3Acreated-asc+merged%3A2022-09+merged%3A2022-08+merged%3A2022-07+).

## Most Notable Changes

### Indexers
Dream2nix now offers an interface for defining `indexers`. Indexers are programs that can query a package repository (think of npm, or crates.io) for package information. Read [more about indexers in our docs](../intro/indexers.html).

Indexers can be used to automatically import packages from all kinds of ecosystems into the nix domain. For example the `libraries-io` indexer can be used to query libraries.io for the 5000 most popular nodejs packages and convert them to nix packages.

One nice use case for indexers is to test dream2nix by continuously building large auto generated package sets while monitoring the success rate and get useful information from build failures.

Currently we already have this testing infrastructure set up for nodejs and rust (more will be added soon). The package sets can be found in the repo: [nix-community/dream2nix-auto-test](https://github.com/nix-community/dream2nix-auto-test)

### development shells
Besides the usual packages, many builders in dream2nix do now also output dev-shell(s) via the `devShells` attribute. This should allow developers to quickly spin up a shell environment on arbitrary projects with the required dependencies available to start hacking.

### Begin moving to nixos module system
We started a larger refactoring effort, separating dream2nix internals into nixos modules. The goal of this undertaking is to gain:

- better flexibility within the framework. People should have an easier time to modify and extend the framework
- type safety between important components of dream2nix
- type checked and automatically documented user interfaces (similar to search.nixos.org for nixos)
- better integration into nixos itself

This is only partially complete yet, as we have to refactor module by module carefully while making sure to not break the current API. Currently, only translators, fetchers, builders and discoverers use the module system. Once the internals are `modularized`, the final piece of work will be creating a new user interface using nixos modules as well.

## More Changes

- Improvements on several subsystems including haskell, nodejs, python, rust
- Improvements of some community overrides
- Added quick start guides to the documentation
- Several improvements for the documentation
- Added integration tests

- Added subsystems:
  - debian
  - php
- Added support for translating formats:
  - debian: debian-binary (impure)
  - php: composer-lock  (pure)
  - haskell: hackage (impure) - given a package name, retrieve metadata from hackage
- Added builders for:
  - debian `simple-debian`: download and patch binary releases from debian repos
  - php `simple-php`: build dependencies in a combined derivation
  - php `granular-php`: build dependencies in separate derivations
- Added indexers:
  - libraries-io: queries [libraries.io](https://libraries.io/) for package sets
