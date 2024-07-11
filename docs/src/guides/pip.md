---
title: Build a python project with pip
---

!!! info

    We recommend reading our [Getting Started](./getting-started.md) guide first if you have not done so yet!

this guide we are going to take a look at two annotated examples using the [pip module](../reference/pip/index.md):

- The first one builds [Pillow](https://python-pillow.org/) from upstream sources fetched from PyPi.
- The second one builds a fictional python project living in the same repository as the nix sources
  and a development environment around it.

## Start with a flake

We start both examples by creating a new git repository and adding almost the same `flake.nix` template we already used in [Getting Started](./getting-started.md#start-a-project). The only difference
are the packages name, `default` instead of `hello`:

```nix title="flake.nix"
{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
  };

  outputs = {
    self,
    dream2nix,
    nixpkgs,
  }:
  let
      eachSystem = nixpkgs.lib.genAttrs [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  in {
  packages = eachSystem (system: {
    default = dream2nix.lib.evalModules { # (1)
      packageSets.nixpkgs = nixpkgs.legacyPackages.${system};
      modules = [
        ./default.nix (2)
        {
          paths.projectRoot = ./.;
          paths.projectRootFile = "flake.nix";
          paths.package = ./.;
        }
      ];
    };
  });
}
```

1. We call our package attribute `default` here...
2. ...and the nix file `default.nix` here.

## Example: Pillow

Things get a bit more interesting in `default.nix` where we define a package module which fetches Pillow from pypi and builds it with minial features - just JPEG support. Click the plus to expand any code annotation below for details.
The code we are going to end up with is also available in [./examples/packages/languages/python-packaging-pillow](https://github.com/nix-community/dream2nix/tree/main/examples/packages/languages/python-packaging-pillow).

### Code

```nix title="default.nix"
{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.pip # (1)
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python311; # (2)
    inherit # (3)
      (nixpkgs)
      pkg-config
      zlib
      libjpeg
      ;
  };

  name = "pillow"; # (4)
  version = "10.4.0";

  mkDerivation = { # (5)
    nativeBuildInputs = [
      config.deps.pkg-config
    ];
    propagatedBuildInputs = [
      config.deps.zlib
      config.deps.libjpeg
    ];
  };

  buildPythonPackage = { # (6)
    pythonImportsCheck = [
      "PIL"
    ];
  };

  pip = {
    requirementsList = ["${config.name}==${config.version}"]; # (7)
    pipFlags = [ # (8)
      "--no-binary"
      ":all:"
    ];
  };
}
```

1. Import the dream2nix [pip module](../reference/pip/index.md) into our module.
2. Declare external dependencies, like the python interpreter to use and libraries from nixpkgs. We use whatever the latest `python3` in nixpkgs is as our python.
3. Declare which build tools we need to pull from nixpkgs for use in `mkDerivation` below.
4. Declare name and version of our package. Those will also be used for `pip.requirementsList` below.
5. Set dependencies, `pkg-config` is only required
during build-time, while the libraries should be propagated. We use `config.deps` instead of a conventional `pkg` here to be able to "override" inputs via the [module system](../modules.md).
6. Tell the [buildPythonPackage module](../reference/buildPythonPackage/index.md) to verify that it can import the given python module from our package after a build.
7. Tell the [pip module](../reference/pip/index.md) which dependencies to lock using the same syntax as 
a `requirements.txt` file. Here: `pillow==10.4.0`.
8. `pip` uses binary wheel files if available by default, we well it not to do so in order to ensure
a build from source.

### Initialise the repostory

If you use `git`, you need to add `flake.nix` and `default.nix` to your git index so that they get copied to the `/nix/store` and the commands below see them:

```shell-session
$ git init
$ git add flake.nix default.nix
```

### Create a lock file

The next step is to create a lock file by running the packages `lock` attribute. This does a `pip install --dry-run` under the hood and pins the exact packages pip would install.

```shell-session
$ nix run .#default.lock
$ git add lock.json
```

!!! note

    Due to limitations in `pip`s cross-platform support, the resulting
    lock-files are platform-specific!
    We therefore recommend setting `paths.lockFile` to `lock.${system}.json`
    for all projects where you use the pip module.

    Check out the [pdm module](../reference/WIP-python-pdm/index.md) if you need a solution that
    allows locking for multiple platforms at once!

### Build it

After that's done, we can finally build it:

```shell-session
$ nix build .#default
```

Congratulations, you just built your first python package with dream2nix! The resulting package can be used with any other nix python package as long as it uses the same version of python.

