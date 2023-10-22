# evaluate packages from `/**/modules/drvs` and export them via `flake.packages`
{
  self,
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    flip
    foldl
    mapAttrs'
    mapAttrsToList
    ;
  inherit
    (builtins)
    mapAttrs
    readDir
    ;

  packageCategories = readDir (self + "/examples/packages");

  readExamples = dirName: let
    examplesPath = self + /examples/packages + "/${dirName}";
    examples = readDir examplesPath;
  in
    flip mapAttrs examples
    (name: _: {
      module = examplesPath + "/${name}";
      packagePath = "/examples/packages/${dirName}/${name}";
    });

  importFlake = flakeFile: let
    self' = (import flakeFile).outputs {
      dream2nix = self;
      nixpkgs = inputs.nixpkgs;
      self = self';
    };
  in
    self';

  importFlakeSmall = flakeFile: let
    self' = (import flakeFile).outputs {
      dream2nix = modulesFlake;
      nixpkgs = inputs.nixpkgs;
      self = self';
    };
  in
    self';

  modulesFlake = import (self + /modules) {};

  # Type: [ {${name} = {module, packagePath} ]
  allExamples = mapAttrsToList (dirName: _: readExamples dirName) packageCategories;

  exampleModules = foldl (a: b: a // b) {} allExamples;

  # create a template for each example package
  packageTempaltes = flip mapAttrs exampleModules (name: def: {
    description = "Example package ${name}";
    path = def.module;
  });
in {
  flake.templates =
    packageTempaltes
    // {
      # add repo templates
      repo.description = "Dream2nix repo without flakes";
      repo.path = self + /examples/dream2nix-repo;
      repo-flake.description = "Dream2nix repo with flakes";
      repo-flake.path = self + /examples/dream2nix-repo-flake;
    };

  perSystem = {
    system,
    config,
    pkgs,
    ...
  }: let
    # A module imported into every package setting up the eval cache
    setup = {config, ...}: {
      paths.projectRoot = self;
      eval-cache.enable = true;
      deps.npm = inputs.nixpkgs.legacyPackages.${system}.nodejs.pkgs.npm.override (old: rec {
        version = "8.19.4";
        src = builtins.fetchTarball {
          url = "https://registry.npmjs.org/npm/-/npm-${version}.tgz";
          sha256 = "0xmvjkxgfavlbm8cj3jx66mlmc20f9kqzigjqripgj71j6b2m9by";
        };
      });
    };

    # evaluates the package behind a given module
    makeDrv = modules: let
      evaled = self.lib.evalModules {
        modules = modules ++ [self.modules.dream2nix.core];
        packageSets = {
          nixpkgs = inputs.nixpkgs.legacyPackages.${system};
          writers = config.writers;
        };
      };
    in
      evaled.config.public;

    allModules = flip mapAttrs' exampleModules (name: module: {
      name = "example-package-${name}";
      value = [
        module.module
        setup
        {
          paths.package = module.packagePath;
        }
      ];
    });

    # map all modules in /examples to a package output in the flake.
    checks =
      lib.optionalAttrs
      (system == "x86_64-linux")
      (
        (lib.mapAttrs (_: drvModules: makeDrv drvModules) allModules)
        // {
          example-repo =
            (import (self + /examples/dream2nix-repo) {
              dream2nixSource = self;
              inherit pkgs;
            })
            .hello;
          example-repo-flake =
            (importFlake (self + /examples/dream2nix-repo-flake/flake.nix)).packages.${system}.hello;
          example-repo-flake-pdm =
            (importFlakeSmall (self + /examples/dream2nix-repo-flake-pdm/flake.nix)).packages.${system}.my-project;
        }
      );

    # work around a bug in nix-fast-build / nix-eval jobs
    # TODO: remove this
    checksWithSystem = lib.mapAttrs (_: drv: drv // {inherit system;}) checks;
  in {
    checks = checksWithSystem;
  };
}
