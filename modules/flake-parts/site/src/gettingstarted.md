## Getting started

To package a piece of software with dream2nix, you'd typically start with
a bare-bones dream2nix flake like this:

```nix
{
  description = "My flake a dream2nix package";

  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.follows = "dream2nix/nixpkgs";
  };

  outputs = inputs @ {
    self,
    dream2nix,
    nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
  in {
    packages.${system}.default = dream2nix.lib.evalModules {
      packageSets.nixpkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages.${system};
      modules = [
        ./default.nix
        {
          paths.projectRoot = ./.;
          paths.projectRootFile = "flake.nix";
          paths.package = ./.;
        }
      ];
    };
  };
}
```

And a `default.nix` that looks like this:

```nix
{
  config,
  lib,
  dream2nix,
  ...
}: {
  imports = [
    # dream2nix modules go here
  ];

  deps = {nixpkgs, ...}: {
    # dependencies go here
  };

  name = "my-package-name";
  version = "2.7.1";

  # Ecosystem-dependent package definition goes here
}
```

To find out which dream2nix modules to import, browse through the modules
on the left and the [examples](./examples.md). When getting started, the
'single-language' collection will be most helpful. Once you're comfortable
packaging a single single-language project, you could look into packaging
a repository containing multiple packages, or a multi-language package.

Once you have imported a module, this module will make ecosystem-dependent
functions available to create your package definition, such as `mkDerivation`
or `buildPythonPackage`.

### Building

Now, `git add` your `flake.nix` and `default.nix`. Depending on the module
you selected, you will generate and commit a `lock.json` describing the
'pinned' dependencies of your project. The error message produced by
`nix build .` should tell you how to generate this lock file, likely
something like `nix run .#default.lock`.

