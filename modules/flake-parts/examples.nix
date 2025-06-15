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

  dream2nixFlake = import ../../. {};

  packageCategories =
    lib.filterAttrs
    (name: type: type == "directory")
    (readDir ../../examples/packages);

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
      dream2nix = dream2nixFlake;
      nixpkgs = inputs.nixpkgs;
      self = self';
    };
  in
    self';

  # Type: [ {${name} = {module, packagePath} ]
  allExamplesList = mapAttrsToList (dirName: _: readExamples dirName) packageCategories;

  exampleFlakes = foldl (a: b: a // b) {} allExamplesList;

  # create a template for each example package
  packageTempaltes = flip mapAttrs exampleFlakes (name: def: {
    description = "Example package ${name}";
    path = def.dir;
  });

  allExamples = flip mapAttrs' exampleFlakes (name: example: {
    name = "example-${name}";
    value = example.flake;
  });
in {
  flake.templates =
    packageTempaltes
    // {
      # add repo templates
      repo.description = "Dream2nix repo without flakes";
      repo.path = ../../examples/repo-with-packages;
      repo-flake.description = "Dream2nix repo with flakes";
      repo-flake.path = ../../examples/repo-with-packages-flake;
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
      flake.packages.${system}.default or {};

    allPackages' =
      lib.mapAttrs
      (_: flakeFile: getPackage flakeFile)
      allExamples;

    # remove all packages that are not available for the current system
    allPackages =
      lib.filterAttrs
      (_: package: package != {})
      allPackages';

    # map all modules in /examples to a package output in the flake.
    checks =
      lib.optionalAttrs
      (system == "x86_64-linux" || system == "aarch64-darwin")
      (
        allPackages
        // {
          repo-with-packages = let
            imported =
              (import ../../examples/repo-with-packages {
                dream2nixSource = ../..;
                inherit pkgs;
              })
              .hello;
          in
            imported;
          repo-with-packages-flake =
            (importFlake ../../examples/repo-with-packages-flake/flake.nix).packages.${system}.hello;
        }
      );

    # work around a bug in nix-fast-build / nix-eval jobs
    # TODO: remove this
    checksWithSystem = lib.mapAttrs (_: drv: drv // {inherit system;}) checks;
  in {
    checks = checksWithSystem;
  };
}
