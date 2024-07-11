!!! info

    We assume that you already got a flakes-enabled [nix](https://nixos.org/) installed and at least a basic understanding of nix and flakes here.

    If that's not the case, check out the official documentation site at [nix.dev](https://nix.dev/) first!

In this tutorial, we are going to package [GNU hello](https://gnu.org/s/hello), a traditional example for build systems, in order to get started
with dream2nix and its [module system ](../modules.md).

## Start a project

We start by creating a new git repository with the following two files:

- `flake.nix` declares our inputs, dream2nix and nixpkgs, as well as a single package `hello` as an output.
  The package is declared by calling `dream2nix.lib.evalModules` with the definitions in `hello.nix`, nixpkgs
  and a helper module to let dream2nix know about your directory layout.

- `hello.nix` declares a dream2nix module that imports [mkDerivation](../reference/mkDerivation/index.md) and
  uses that to build GNU hello.

Check out the code below and don't miss the annotations, hidden behind those little plusses, to learn more!

!!! note

    And do not hesitate to message us on [matrix: #dream2nix:nixos.org](https://matrix.to/#/#dream2nix:nixos.org) if you found
    a mistake or if things are unclear!

### `flake.nix`

```nix title="flake.nix"
{
  description = "A flake for my dream2nix packages";

  inputs = { # (1)
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
  };

  outputs = {
    self,
    dream2nix,
    nixpkgs,
  }:
  let
    eachSystem = nixpkgs.lib.genAttrs [ # (2)
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  in {
    packages = eachSystem (system: {
      hello = dream2nix.lib.evalModules { # (3)
        packageSets.nixpkgs = nixpkgs.legacyPackages.${system}; # (4)
        modules = [
          ./hello.nix # (5)
          { # (6)
            paths.projectRoot = ./.;
            paths.projectRootFile = "flake.nix";
            paths.package = ./.;
          }
        ];
      };
      default = self.packages.${system}.hello;  # (7)
    });
  };
}
```

1. Import dream2nix and tell nix to use whatever version of nixpkgs dream2nix declares. You can use other versions, but this it what we run our automated tests with.
2. Define a helper function that allows us to reduce boilerplate and still support all of of the listed systems for our package.
3. Create our package, called `hello` here, by *evaluating* the given dream2nix [modules](../modules.md).
4. Pass the given instance of nixpkgs to build our package with as a *module argument*.
5. Include our package definition from `hello.nix`. See below for its contents!
6. Define relative paths to aid dream2nix to find lock files and so on during *evaluation time*. These settings should work for repos containing multiple python projects as simpler ones.
7. We declare `hello` to be the default package. This allows us to just call i.e. `nix build .#` instead of `nix build .#hello`.

### `hello.nix`

```nix title="hello.nix"
{ # (1)
  dream2nix,
  config,
  lib,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation # (2)
  ];

  # (3)
  name = "hello";
  version = "2.12.1";

  # (4)
  mkDerivation = {
    src = builtins.fetchTarball {
      url = "https://ftp.gnu.org/gnu/hello/hello-${config.version}.tar.gz";
      sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
    };
  };
}
```

1. Define a function, taking our *module arguments* and returning a *module*.
   Inputs include `dream2nix`, a reference to package itself in `config`, and the nixpkgs library in `lib`.
2. Import the [`mkDerivation`](../reference/mkDerivation/index.md) module.
3. Define `name` and `version` of the package. Unlike most other options, those are not namespaced and defined in dream2nix `core` module.
4. Define *module options* to further customize your build. In this case we just set `mkDerivation.src` to fetch a source tarball as well.
   But you could use other arguments from `pkgs.mkDerivation`, such as `buildInputs` or `buildPhase` here as well.

## Build it

!!! warning

    Be aware that nix will only "see" your files once
    they have been added to git's index, i.e. via `git add`!

    This is because nix copies flakes to `/nix/store` before evaluating
    them, but only those which are tracked by git. This can lead to confusion
    if nix errors hint at missing files while you are able to seem them
    in your shell.

With all that code added, building it should work like any other nix build:
   
```shell-session
$ git init
$ git add flake.nix hello.nix
$ nix build .#  # (1) 
$ ./result/bin/hello
Hello, World!
```

1. `.#` is a shorter form of `.#packages.x86_64-linux.default` (on `x86_64-linux` systems).

## Lock it

Some of our our modules such as [pip](../reference/pip/index.md) require a custom lock file
added to your repository in order to pin your dependencies and store metadata which we can't
acquire during *evaluation time*.

We don't need one in the `hello` example above. If you add a dream2nix module that does,
you will receive an error during building, with the error message telling you the command
you need to run. Generally:

```shell-session
$ nix run .#default.lock
$ git add lock.json
```

## Going further

Check out our guides, the reference documentation and [examples](https://github.com/nix-community/dream2nix/tree/main/examples/packages/languages)
to learn more about the various modules and options to learn more about language-specific helpers to package and distribute your software with dream2nix.

Once you have imported a module, this module will make ecosystem-dependent functions, such as [`mkDerivation`](../reference/mkDerivation/index.md) or [`buildPythonPackage`](../reference/buildPythonPackage/index.md), available to your package modules.

And don't forget to join our communities at [matrix: #dream2nix:nixos.org](https://matrix.to/#/#dream2nix:nixos.org) and [github: nix-community/dream2nix](https://github.com/nix-community/dream2nix) to ask questions and learn from each other. Feedback we receive
there helps us to improve code & documentation as we go.
