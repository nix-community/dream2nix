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
        ./default.nix # (2)
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

Things get a bit more interesting in `default.nix` where we define a package module which fetches Pillow from pypi and builds it with minimal features - just JPEG support. Click the plus to expand any code annotation below for details.
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
    python = nixpkgs.python3; # (2)
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
8. `pip` uses binary wheel files if available by default. We will not do so in order to ensure a build from source.

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


## Example: my-tool

In our second example, we package are going to package a simple, fictional python package called `my_tool`. Its code and nix expressions
are stored in the same repository. For reference, they are  available in full in [./examples/packages/languages/python-local-development](https://github.com/nix-community/dream2nix/tree/main/examples/packages/languages/python-local-development).

### Code

```nix title="default.nix"
{
  config,
  lib,
  dream2nix,
  ...
}: let
  pyproject = lib.importTOML (config.mkDerivation.src + /pyproject.toml); # (1)
in {
  imports = [
    dream2nix.modules.dream2nix.pip # (2)
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python3; # (3)
  };

  inherit (pyproject.project) name version; # (4)

  mkDerivation = {
    src = lib.cleanSourceWith { # (5)
      src = lib.cleanSource ./.;
      filter = name: type:
        !(builtins.any (x: x) [
          (lib.hasSuffix ".nix" name)
          (lib.hasPrefix "." (builtins.baseNameOf name))
          (lib.hasSuffix "flake.lock" name)
        ]);
    };
  };
 
  buildPythonPackage = {
    pyproject = true;  # (6)
    pythonImportsCheck = [ # (7)
      "my_tool"
    ];
  };

  pip = {
    # (8)
    requirementsList =
      pyproject.build-system.requires or []
      ++ pyproject.project.dependencies or [];
      
    flattenDependencies = true; # (9)

    overrides.click = { # (10)
      buildPythonPackage.pyproject = true;
      mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.flit-core];
    };
  };
}
```

1. Load `pyproject.toml` from our source directory, which is the filtered
source defined in `mkDerivation.src` below.
2. Import the dream2nix [pip module](../reference/pip/index.md) into our module
3. Define external, non-python dependencies. We use whatever the latest `python3` in nixpkgs is as our python.
4. Get our projects `name` and `version` straight from `pyproject.toml`. You could of course also hard-code them here if e.g. your project still uses `setup.py`.
5. Define the source for our project. Here we take the current directory, but filter out `*.nix` files, hidden files and `flake.lock` before copying to `/nix/store` in order to avoid unecessary rebuilds.
6. Tell the dream2nix [buildPythonPackage module](../reference/buildPythonPackage/index.md), imported by the pip module to use pyproject-specific hooks here.
Don't set it if your project doesn't include a `pyproject.toml` or your are using a wheel.
7. Tell the [buildPythonPackage module](../reference/buildPythonPackage/index.md) to verify that it can import the given python module from our package after a build.
8. Declare a list of requirements for `pip` to lock by concatenating
both the build-systems and normal dependencies in `pyproject.toml`.
9. By default, the [pip module](../reference/pip/index.md) assumes that it finds the top-level package inside the lock file. This isn't the case
here as the top-level package comes from the local repository. So we
instruct the module to just install all requirements into a flat environment.
10. Declare overrides for package attributes that can't be detected heuristically by dream2nix yet. Here: use pyproject-hooks for click and
add `poetry-core` to its build-time dependencies.

### Build it

Just as in the same example, we need to lock our python dependencies and add the lock file before we build our package:

```shell-session
$ git init
$ git add flake.nix default.nix
$ nix run .#default.lock
[...]
lock file written to [...]/lock.x86_64-linux.json
Add this file to git if flakes is used.
$ git add lock.json
$ nix build .#
$ ./result/bin/my_tool
Hello world!
```

# Development Shells

Now that we got `my_tool` built, let's try out a *devShell* for it. A shell environment, containing an [editable install](#editable-installs) of our
package , all its dependencies and scripts as well as other tools that are useful during development, but shouldn't end up in shipped packages.

!!! notice

    If you use a *flat layout*, i.e. your python module is in the top-level of your repo you
    might discover that you can just import it if you start a python process there.
    This works because python searches the current directory for modules, but it will miss its
    dependencies and scripts declared in `pyproject.toml` won't be on the path.

To get started, add the following definition to your `flake.nix` (it's the same as in the [example](https://github.com/nix-community/dream2nix/blob/main/examples/packages/languages/python-local-development/flake.nix), so we omit some sections marked with `[...]`). Click on the pluses to expand annotations in the code below:

```nix title="flake.nix"
{
  # [...]
  outputs = {
    self,
    dream2nix,
    nixpkgs,
  }: {
  # [...]
  devShells = eachSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system}; # (1)
      my_tool = self.packages.${system}.default; # (2)
      python = my_tool.config.deps.python; # (3)
    in {
      default = pkgs.mkShell { # (4)
        inputsFrom = [my_tool.devShell]; # (5)
        packages = [
          python.pkgs.python-lsp-server # (6)
          python.pkgs.python-lsp-ruff
          python.pkgs.pylsp-mypy
          python.pkgs.ipython

          pkgs.ruff # (7)
          pkgs.black
        ];
      };
    });
  };
}
```

1. Get an instance of `nixpkgs` to use for `mkShell`, `ruff`, etc below.
2. Get our default package, `my_tool` from this flakes outputs...
3. ...and a reference to the python interpreter it uses. 
4. Call `pkgs.mkShell` in order to be able to add custom `packages` or a `shellHook` to it. You could just use `my_tool.devShell` here if you are happy with the defaults.
5. Get inputs from `mytool.devShell`, this includes your package & its dependencies and a `shellHook` to set up editable installs.
6. Use `python.pkgs` to get additional python tools into the shell while ensuring that the correct python interpreter is used.
7. Use `pkgs` to get tools which aren't implemented in python, such as `ruff` and `black`.

With that done, let's start a development shell, an ipython interpreter in it, import `my_tool` and `requests`, its dependency and
see where they are imported from:

```shell-session
$ nix develop
evaluating derivation 'git+file://[path_to_your_repo]#devShells.x86_64-linux.default'
Some python dependencies of /Users/phaer/src/dream2nix/examples/packages/languages/python-local-development are installed in editable mode
  my-tool
    installed at: .
$ ipython
[...]
In [1]: import my_tool
In [2]: my_tool.__file__
Out[2]: '[path_to_your_repo]/src/my_tool/__init__.py'
In [3]: import requests
In [4]: requests.__file__
Out[4]: '/nix/store/[nix hash]-python3-3.11.9-env/lib/python3.11/site-packages/requests/__init__.py'
```

*  `my_tool` is imported from your repository, as it's an editable install, akin to `pip install -e .`
* `requests` is loaded from a python environment, generated by our expression above. Changes to it will only be visible after the shell is restarted.

All the other tools declared in our `devShell` above, i.e. `ruff` and `black` should be in `PATH` and/or `PYTHONPATH` as well.

