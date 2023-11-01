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

  packageCategories = readDir (../../examples/packages);

  readExamples = dirName: let
    examplesPath = ../../examples/packages + "/${dirName}";
    examples = readDir examplesPath;
  in
    flip mapAttrs examples
    (name: _: {
      dir = examplesPath + "/${name}";
      flake = examplesPath + "/${name}/flake.nix";
    });

  importFlake = flakeFile: let
    self' = (import flakeFile).outputs {
      dream2nix = self;
      nixpkgs = inputs.nixpkgs;
      self = self';
    };
  in
    self';

  # importFlakeSmall = flakeFile: let
  #   self' = (import flakeFile).outputs {
  #     dream2nix = dream2nixFlake;
  #     nixpkgs = inputs.nixpkgs;
  #     self = self';
  #   };
  # in
  #   self';

  # dream2nixFlake = import (../../.) {};

  # Type: [ {${name} = {module, packagePath} ]
  allExamplesList = mapAttrsToList (dirName: _: readExamples dirName) packageCategories;

  exampleFlakes = foldl (a: b: a // b) {} allExamplesList;

  # create a template for each example package
  packageTempaltes = flip mapAttrs exampleFlakes (name: def: {
    description = "Example package ${name}";
    path = def.dir;
  });

  allExamples = flip mapAttrs' exampleFlakes (name: example: {
    name = "example-package-${name}";
    value = example.flake;
  });
in {
  flake.templates =
    packageTempaltes
    // {
      # add repo templates
      repo.description = "Dream2nix repo without flakes";
      repo.path = ../../examples/repo;
      repo-flake.description = "Dream2nix repo with flakes";
      repo-flake.path = ../../examples/repo-flake;
    };

  perSystem = {
    system,
    config,
    pkgs,
    ...
  }: let
    # evaluates the package behind a given module
    getPackage = flakeFile: let
      flake = importFlake flakeFile;
    in
      flake.packages.${system}.default;

    # map all modules in /examples to a package output in the flake.
    checks =
      lib.optionalAttrs
      (system == "x86_64-linux")
      (
        (lib.mapAttrs (_: flakeFile: getPackage flakeFile) allExamples)
        // {
          example-repo = let
            imported =
              (import (../../examples/repo) {
                dream2nixSource = ../..;
                inherit pkgs;
              })
              .hello;
          in
           imported;
          example-repo-flake =
            (importFlake (../../examples/repo-flake/flake.nix)).packages.${system}.hello;
          # example-repo-flake-pdm =
          #   (importFlakeSmall (../../examples/repo-flake-pdm/flake.nix)).packages.${system}.my-project;
        }
      );

    # work around a bug in nix-fast-build / nix-eval jobs
    # TODO: remove this
    checksWithSystem = lib.mapAttrs (_: drv: drv // {inherit system;}) checks;
  in {
    checks = checksWithSystem;
  };
}
